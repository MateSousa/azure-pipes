terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  project_name = "myproject"
  tags = {
    Project     = "myproject"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  # Backend Lambdas the API routes to. Real code is deployed via CI/CD;
  # modules/lambda ships a placeholder zip so terraform apply succeeds out of the box.
  backend_lambdas = {
    get_user = {
      description = "Returns the authenticated user record"
      handler     = "index.handler"
      runtime     = "nodejs20.x"
      memory      = 256
      timeout     = 10
    }
    dashboard = {
      description = "Aggregates dashboard data for the authenticated user"
      handler     = "index.handler"
      runtime     = "nodejs20.x"
      memory      = 256
      timeout     = 15
    }
  }
}

# -----------------------------------------------------------------------------
# IAM (looked up from existing roles — replace with aws_iam_role resources if
# you want this example to be self-contained)
# -----------------------------------------------------------------------------

data "aws_iam_role" "lambda" {
  name = "${local.project_name}-lambda-exec"
}

data "aws_iam_role" "authorizer" {
  name = "${local.project_name}-authorizer-exec"
}

# -----------------------------------------------------------------------------
# Networking + backend ALB (supplied by the caller — wire these to your VPC /
# ALB module outputs, or pass them via a .tfvars file)
#
# The ECS service sits behind an internal ALB with an HTTP :80 listener.
# API Gateway reaches that listener privately over the VPC Link, so the hop
# stays inside the VPC — but it is plaintext. Keep the ALB security group
# locked so only the VPC Link security group can reach :80.
# -----------------------------------------------------------------------------

variable "vpc_link_subnet_ids" {
  description = "Private subnet IDs the VPC Link places its ENIs in. Typically the same subnets as the backend ALB."
  type        = list(string)

  validation {
    condition     = length(var.vpc_link_subnet_ids) > 0
    error_message = "Provide at least one subnet ID for the VPC Link."
  }
}

variable "vpc_link_security_group_ids" {
  description = "Security group IDs attached to the VPC Link ENIs. The backend ALB's security group must allow inbound :80 from these."
  type        = list(string)

  validation {
    condition     = length(var.vpc_link_security_group_ids) > 0
    error_message = "Provide at least one security group ID for the VPC Link."
  }
}

variable "backend_alb_listener_arn" {
  description = "ARN of the internal ALB's HTTP :80 listener that fronts the ECS service. This is the HTTP_PROXY route's integration target."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:elasticloadbalancing:.+:listener/app/.+$", var.backend_alb_listener_arn))
    error_message = "backend_alb_listener_arn must be an Application Load Balancer listener ARN."
  }
}

# -----------------------------------------------------------------------------
# Backend Lambdas (one per route — for_each over local.backend_lambdas)
# -----------------------------------------------------------------------------

module "backend_lambdas" {
  source   = "../../lambda"
  for_each = local.backend_lambdas

  project_name = local.project_name

  lambda = {
    name        = each.key
    description = each.value.description
    handler     = each.value.handler
    runtime     = each.value.runtime
    memory      = each.value.memory
    timeout     = each.value.timeout
  }

  iam = {
    role_arn = data.aws_iam_role.lambda.arn
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# API Gateway (HTTP API) — created first so the authorizer can attach to it
# -----------------------------------------------------------------------------

module "api" {
  source = "../../api-gateway"

  project_name = local.project_name

  api = {
    name        = "main"
    description = "Public HTTP API for ${local.project_name}"

    cors_configuration = {
      allow_origins = ["https://app.example.com"]
      allow_methods = ["GET", "POST", "OPTIONS"]
      allow_headers = ["Authorization", "Content-Type"]
      max_age       = 600
    }
  }

  stage = {
    name        = "$default"
    auto_deploy = true
    throttle = {
      burst_limit = 100
      rate_limit  = 50
    }
    access_log_retention_days = 30
  }

  default_authorizer_id = module.authorizer.authorizer_id

  # VPC Link — lets HTTP_PROXY routes reach the private backend ALB.
  vpc_link = {
    subnet_ids         = var.vpc_link_subnet_ids
    security_group_ids = var.vpc_link_security_group_ids
  }

  # Routes themselves live in openapi.yaml inside the API code repo and are
  # deployed via the reusable-deploy-apigateway-openapi.yml workflow. This
  # module only grants the Lambdas listed below permission to be invoked by
  # API Gateway — every Lambda that an aws_proxy integration in openapi.yaml
  # references must appear here. HTTP_PROXY (ALB) routes don't need entries.
  invokable_lambdas = [
    {
      name = "get_user"
      arn  = module.backend_lambdas["get_user"].function_arn
    },
    {
      name = "dashboard"
      arn  = module.backend_lambdas["dashboard"].function_arn
    },
  ]

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Lambda Authorizer (Entra-backed JWT validation)
#
# Reference handler: ./src/authorizer (index.js + package.json). modules/lambda
# deploys a placeholder zip on apply and ignores later code changes — CI/CD
# zips ./src/authorizer and ships it to the "${local.project_name}-authorizer"
# function. The authorizer is integration-agnostic: it returns the same
# allow/deny decision whether a route's target is a Lambda or ECS-behind-an-ALB.
# -----------------------------------------------------------------------------

module "authorizer" {
  source = "../../lambda-authorizer"

  project_name      = local.project_name
  api_id            = module.api.api_id
  api_execution_arn = module.api.execution_arn

  iam = {
    role_arn = data.aws_iam_role.authorizer.arn
  }

  lambda = {
    name        = "authorizer"
    description = "Validates Entra-issued JWTs and returns simple-response auth decision"
    handler     = "index.handler"
    runtime     = "nodejs20.x"
    memory      = 256
    timeout     = 10
    environment_variables = {
      ENTRA_TENANT_ID = "00000000-0000-0000-0000-000000000000"
      ENTRA_AUDIENCE  = "api://myproject"
      ENTRA_ISSUER    = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
    }
  }

  authorizer = {
    # 5-minute cache: API GW won't re-invoke the authorizer for the same
    # Authorization header value within this window. Set to 0 while debugging.
    authorizer_result_ttl_in_seconds = 300
    identity_sources                 = ["$request.header.Authorization"]
    enable_simple_responses          = true
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "api_endpoint" {
  description = "Base URL of the HTTP API (e.g. https://abc123.execute-api.us-east-1.amazonaws.com)."
  value       = module.api.api_endpoint
}

output "stage_invoke_url" {
  description = "Stage invoke URL — append a route key to call it (e.g. <url>/dashboard)."
  value       = module.api.stage_invoke_url
}

output "authorizer_id" {
  description = "ID of the API Gateway authorizer."
  value       = module.authorizer.authorizer_id
}

output "vpc_link_id" {
  description = "ID of the VPC Link fronting the ECS backend."
  value       = module.api.vpc_link_id
}
