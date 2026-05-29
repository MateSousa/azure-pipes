########################################
# Project
########################################

variable "project_name" {
  description = "Project name used as a prefix for all resources."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

########################################
# Dispatcher Lambda
########################################

variable "dispatcher" {
  description = "Dispatcher Lambda configuration. Verifies the GitHub webhook signature, mints an org-scoped runner registration token via the GitHub App, and calls ecs:RunTask to launch a single ephemeral runner."
  type = object({
    name      = optional(string, "github-runner-dispatcher")
    image_uri = string
    memory    = optional(number, 256)
    timeout   = optional(number, 30)
    role_arn  = string
  })

  validation {
    condition     = length("${var.project_name}-${var.dispatcher.name}") <= 64
    error_message = "Combined function name (project_name-dispatcher.name) must be 64 characters or fewer."
  }

  validation {
    condition     = var.dispatcher.memory >= 128 && var.dispatcher.memory <= 10240
    error_message = "dispatcher.memory must be between 128 and 10240 MB."
  }

  validation {
    condition     = var.dispatcher.timeout >= 1 && var.dispatcher.timeout <= 900
    error_message = "dispatcher.timeout must be between 1 and 900 seconds."
  }

  validation {
    condition     = can(regex("^arn:aws:iam::\\d{12}:role/.+$", var.dispatcher.role_arn))
    error_message = "dispatcher.role_arn must be a valid IAM role ARN."
  }
}

########################################
# Runner Task
########################################

variable "runner" {
  description = "Ephemeral GitHub runner Fargate task configuration. Tasks are launched on-demand by the dispatcher; container env (REG_TOKEN, ORG, RUNNER_LABELS) is injected per RunTask via containerOverrides."
  type = object({
    family             = optional(string, "github-runner")
    container_name     = optional(string, "runner")
    container_image    = string
    cpu                = optional(string, "1024")
    memory             = optional(string, "2048")
    execution_role_arn = string
    task_role_arn      = string
    runner_label       = optional(string, "fargate")
    extra_env          = optional(map(string), {})
  })

  validation {
    condition     = can(regex("^arn:aws:iam::", var.runner.execution_role_arn))
    error_message = "runner.execution_role_arn must be a valid IAM ARN."
  }

  validation {
    condition     = can(regex("^arn:aws:iam::", var.runner.task_role_arn))
    error_message = "runner.task_role_arn must be a valid IAM ARN."
  }
}

########################################
# ECS Cluster (existing)
########################################

variable "ecs" {
  description = "Existing ECS cluster to launch runner tasks in."
  type = object({
    cluster_arn = string
  })

  validation {
    condition     = can(regex("^arn:aws:ecs:", var.ecs.cluster_arn))
    error_message = "ecs.cluster_arn must be a valid ECS cluster ARN."
  }
}

########################################
# Networking
########################################

variable "network" {
  description = "Network configuration for runner tasks. Subnets must have egress to api.github.com, ECR, Secrets Manager, and CloudWatch Logs (NAT or VPC endpoints)."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
    assign_public_ip   = optional(bool, false)
  })

  validation {
    condition     = length(var.network.subnet_ids) > 0
    error_message = "network.subnet_ids must contain at least one subnet."
  }

  validation {
    condition     = length(var.network.security_group_ids) > 0
    error_message = "network.security_group_ids must contain at least one security group."
  }
}

########################################
# Secrets Manager references
########################################

variable "secrets" {
  description = "ARNs of Secrets Manager secrets the dispatcher reads at runtime. Create these out-of-band (the values must not live in Terraform state)."
  type = object({
    app_id_arn          = string
    app_private_key_arn = string
    webhook_secret_arn  = string
    org_arn             = string
  })

  validation {
    condition = alltrue([
      can(regex("^arn:aws:secretsmanager:", var.secrets.app_id_arn)),
      can(regex("^arn:aws:secretsmanager:", var.secrets.app_private_key_arn)),
      can(regex("^arn:aws:secretsmanager:", var.secrets.webhook_secret_arn)),
      can(regex("^arn:aws:secretsmanager:", var.secrets.org_arn)),
    ])
    error_message = "All secret ARNs must be valid Secrets Manager ARNs."
  }
}

########################################
# API Gateway
########################################

variable "api" {
  description = "HTTP API (webhook receiver) configuration."
  type = object({
    name = optional(string, "github-runner-webhook")
    throttle = optional(object({
      burst_limit = number
      rate_limit  = number
    }))
  })
  default = {}

  validation {
    condition     = length("${var.project_name}-${var.api.name}") <= 128
    error_message = "Combined API name (project_name-api.name) must be 128 characters or fewer."
  }
}

########################################
# Logging
########################################

variable "logging" {
  description = "CloudWatch retention for the dispatcher Lambda, runner task, and API access logs."
  type = object({
    dispatcher_retention_days = optional(number, 14)
    runner_retention_days     = optional(number, 14)
    api_retention_days        = optional(number, 30)
  })
  default = {}

  validation {
    condition = alltrue([
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0], var.logging.dispatcher_retention_days),
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0], var.logging.runner_retention_days),
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0], var.logging.api_retention_days),
    ])
    error_message = "Retention values must be valid CloudWatch Log Group retention values."
  }
}

########################################
# Tags
########################################

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
