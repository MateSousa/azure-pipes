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
# API association
########################################

variable "api_id" {
  description = "ID of the HTTP API this authorizer attaches to."
  type        = string
}

variable "api_execution_arn" {
  description = "Execution ARN of the HTTP API. Used by the lambda permission so API Gateway can invoke the authorizer."
  type        = string
}

########################################
# Lambda — pass-through to modules/lambda
########################################

variable "lambda" {
  description = "Authorizer Lambda configuration. Mirrors modules/lambda's lambda input."
  type = object({
    name                   = string
    description            = optional(string, "Lambda authorizer")
    handler                = optional(string, "index.handler")
    runtime                = optional(string, "nodejs20.x")
    memory                 = optional(number, 256)
    timeout                = optional(number, 10)
    reserved_concurrency   = optional(number, -1)
    publish                = optional(bool, false)
    architectures          = optional(list(string), ["x86_64"])
    ephemeral_storage_size = optional(number, 512)
    environment_variables  = optional(map(string), {})
    layers                 = optional(list(string), [])
  })
}

variable "source_config" {
  description = "Lambda packaging. Same shape as modules/lambda.source_config."
  type = object({
    image_uri    = optional(string, null)
    package_type = optional(string, "Zip")
  })
  default = {
    package_type = "Zip"
  }
}

variable "iam" {
  description = "IAM role for the authorizer Lambda."
  type = object({
    role_arn = string
  })
}

variable "network" {
  description = "VPC config for the authorizer Lambda. Required if it needs to reach private resources (e.g. RDS in a private subnet)."
  type = object({
    subnet_ids         = optional(list(string), [])
    security_group_ids = optional(list(string), [])
  })
  default = {
    subnet_ids         = []
    security_group_ids = []
  }
}

variable "logging" {
  description = "CloudWatch logging configuration for the authorizer Lambda."
  type = object({
    retention_in_days = optional(number, 14)
    log_format        = optional(string, "Text")
  })
  default = {
    retention_in_days = 14
    log_format        = "Text"
  }
}

variable "tracing" {
  description = "X-Ray tracing configuration for the authorizer Lambda."
  type = object({
    mode = optional(string, "PassThrough")
  })
  default = {
    mode = "PassThrough"
  }
}

########################################
# Authorizer
########################################

variable "authorizer" {
  description = "API Gateway v2 authorizer settings. authorizer_result_ttl_in_seconds controls how long API Gateway caches the auth decision per identity source value (0 disables the cache)."
  type = object({
    name                              = optional(string, "auth")
    authorizer_type                   = optional(string, "REQUEST")
    identity_sources                  = optional(list(string), ["$request.header.Authorization"])
    authorizer_result_ttl_in_seconds  = optional(number, 300)
    authorizer_payload_format_version = optional(string, "2.0")
    enable_simple_responses           = optional(bool, true)
  })
  default = {}

  validation {
    condition     = contains(["REQUEST", "JWT"], var.authorizer.authorizer_type)
    error_message = "authorizer_type must be REQUEST or JWT (this module is for REQUEST/Lambda authorizers; use HTTP API JWT integration directly for JWT)."
  }

  validation {
    condition     = var.authorizer.authorizer_result_ttl_in_seconds >= 0 && var.authorizer.authorizer_result_ttl_in_seconds <= 3600
    error_message = "authorizer_result_ttl_in_seconds must be between 0 and 3600."
  }

  validation {
    condition     = contains(["1.0", "2.0"], var.authorizer.authorizer_payload_format_version)
    error_message = "authorizer_payload_format_version must be 1.0 or 2.0."
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
