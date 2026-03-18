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
# Lambda
########################################

variable "lambda" {
  description = "Lambda function configuration."
  type = object({
    name                   = string
    description            = optional(string, "")
    handler                = optional(string, "index.handler")
    runtime                = optional(string, "nodejs20.x")
    memory                 = optional(number, 128)
    timeout                = optional(number, 30)
    reserved_concurrency   = optional(number, -1)
    publish                = optional(bool, false)
    architectures          = optional(list(string), ["x86_64"])
    ephemeral_storage_size = optional(number, 512)
    environment_variables  = optional(map(string), {})
    layers                 = optional(list(string), [])
  })

  validation {
    condition     = length("${var.project_name}-${var.lambda.name}") <= 64
    error_message = "Combined function name (project_name-lambda.name) must be 64 characters or fewer."
  }

  validation {
    condition     = var.lambda.runtime == null || can(regex("^(nodejs|python|java|dotnet|ruby|provided)", var.lambda.runtime))
    error_message = "runtime must be a valid AWS Lambda runtime identifier or null (for Image package type)."
  }

  validation {
    condition     = var.lambda.memory >= 128 && var.lambda.memory <= 10240
    error_message = "memory must be between 128 and 10240 MB."
  }

  validation {
    condition     = var.lambda.timeout >= 1 && var.lambda.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }

  validation {
    condition     = alltrue([for a in var.lambda.architectures : contains(["x86_64", "arm64"], a)])
    error_message = "architectures must only contain x86_64 and/or arm64."
  }

  validation {
    condition     = var.lambda.ephemeral_storage_size >= 512 && var.lambda.ephemeral_storage_size <= 10240
    error_message = "ephemeral_storage_size must be between 512 and 10240 MB."
  }
}

########################################
# Source / Packaging
########################################

variable "source_config" {
  description = "Lambda deployment package configuration. For Zip package type, the module automatically uses a built-in placeholder — real code is deployed via CI/CD. For Image package type, provide image_uri."
  type = object({
    image_uri    = optional(string, null)
    package_type = optional(string, "Zip")
  })
  default = {
    package_type = "Zip"
  }

  validation {
    condition     = contains(["Zip", "Image"], var.source_config.package_type)
    error_message = "package_type must be either Zip or Image."
  }
}

########################################
# IAM
########################################

variable "iam" {
  description = "IAM configuration for the Lambda function."
  type = object({
    role_arn = string
  })

  validation {
    condition     = can(regex("^arn:aws:iam::\\d{12}:role/.+$", var.iam.role_arn))
    error_message = "role_arn must be a valid IAM role ARN (arn:aws:iam::<account-id>:role/<role-name>)."
  }
}

########################################
# Networking
########################################

variable "network" {
  description = "VPC configuration for the Lambda function."
  type = object({
    subnet_ids         = optional(list(string), [])
    security_group_ids = optional(list(string), [])
  })
  default = {
    subnet_ids         = []
    security_group_ids = []
  }
}

########################################
# Logging
########################################

variable "logging" {
  description = "CloudWatch logging configuration."
  type = object({
    retention_in_days = optional(number, 14)
    log_format        = optional(string, "Text")
  })
  default = {
    retention_in_days = 14
    log_format        = "Text"
  }

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0],
      var.logging.retention_in_days,
    )
    error_message = "retention_in_days must be one of the allowed CloudWatch Log Group retention values."
  }
}

########################################
# Tracing
########################################

variable "tracing" {
  description = "X-Ray tracing configuration."
  type = object({
    mode = optional(string, "PassThrough")
  })
  default = {
    mode = "PassThrough"
  }

  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing.mode)
    error_message = "tracing mode must be either Active or PassThrough."
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
