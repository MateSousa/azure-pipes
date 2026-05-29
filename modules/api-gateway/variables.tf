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
# API
########################################

variable "api" {
  description = "HTTP API configuration."
  type = object({
    name                         = string
    description                  = optional(string, "")
    disable_execute_api_endpoint = optional(bool, false)
    cors_configuration = optional(object({
      allow_credentials = optional(bool, false)
      allow_headers     = optional(list(string), [])
      allow_methods     = optional(list(string), [])
      allow_origins     = optional(list(string), [])
      expose_headers    = optional(list(string), [])
      max_age           = optional(number, 0)
    }))
  })

  validation {
    condition     = length("${var.project_name}-${var.api.name}") <= 128
    error_message = "Combined API name (project_name-api.name) must be 128 characters or fewer."
  }
}

########################################
# Stage
########################################

variable "stage" {
  description = "Stage configuration. Default is the auto-deployed $default stage with a CloudWatch access log group."
  type = object({
    name        = optional(string, "$default")
    auto_deploy = optional(bool, true)
    throttle = optional(object({
      burst_limit = number
      rate_limit  = number
    }))
    access_log_retention_days = optional(number, 30)
  })
  default = {}

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0],
      var.stage.access_log_retention_days,
    )
    error_message = "access_log_retention_days must be one of the allowed CloudWatch Log Group retention values."
  }
}

########################################
# Invokable Lambdas
########################################

variable "invokable_lambdas" {
  description = "Lambdas this API is allowed to invoke. Each entry creates an aws_lambda_permission granting lambda:InvokeFunction to apigateway.amazonaws.com scoped to this API's execution ARN. Required for every Lambda referenced from an AWS_PROXY integration in the OpenAPI spec; HTTP_PROXY (ALB) routes don't need entries here."
  type = list(object({
    name = string
    arn  = string
  }))
  default = []

  validation {
    condition     = length(distinct([for l in var.invokable_lambdas : l.name])) == length(var.invokable_lambdas)
    error_message = "invokable_lambdas entries must have unique names."
  }
}

########################################
# VPC Link
########################################

variable "vpc_link" {
  description = "VPC Link for HTTP_PROXY routes (defined in OpenAPI) that target a private ALB. Leave null for a Lambda-only API."
  type = object({
    name               = optional(string, "vpc-link")
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null

  validation {
    condition     = var.vpc_link == null || length(coalesce(try(var.vpc_link.subnet_ids, []), [])) > 0
    error_message = "When vpc_link is set, it must include at least one subnet ID."
  }
}

########################################
# Default authorizer
########################################

variable "default_authorizer_id" {
  description = "Authorizer ID to use for routes whose authorization_type is CUSTOM/JWT and that don't set their own authorizer_id. Typically wired from the lambda-authorizer module's output."
  type        = string
  default     = null
}

########################################
# Tags
########################################

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
