variable "project_name" {
  description = "The name of the project, used as a prefix for resource naming."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "role" {
  description = "Configuration for the IAM role."
  type = object({
    name                  = string
    description           = optional(string, "")
    path                  = optional(string, "/")
    max_session_duration  = optional(number, 3600)
    force_detach_policies = optional(bool, false)
    assume_role_principals = list(object({
      type        = string
      identifiers = list(string)
    }))
    assume_role_conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  })

  validation {
    condition     = length(var.role.name) <= 64
    error_message = "role.name must be 64 characters or fewer."
  }

  validation {
    condition     = startswith(var.role.path, "/")
    error_message = "role.path must start with '/'."
  }

  validation {
    condition     = var.role.max_session_duration >= 3600 && var.role.max_session_duration <= 43200
    error_message = "role.max_session_duration must be between 3600 and 43200."
  }
}

variable "policies" {
  description = "Managed and inline policies to attach to the IAM role."
  type = object({
    managed_policy_arns = optional(list(string), [])
    inline_policies = optional(list(object({
      name   = string
      policy = string
    })), [])
  })

  validation {
    condition     = alltrue([for arn in var.policies.managed_policy_arns : can(regex("^arn:aws:iam::", arn))])
    error_message = "Each managed_policy_arns entry must match the ARN format 'arn:aws:iam::'."
  }
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default     = {}
}
