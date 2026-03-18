variable "project_name" {
  type        = string
  description = "Project name prefix for all resources."

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "repository" {
  type = object({
    name                 = string
    image_tag_mutability = optional(string, "IMMUTABLE")
    force_delete         = optional(bool, false)
    encryption = optional(object({
      encryption_type = optional(string, "AES256")
      kms_key         = optional(string, null)
    }), { encryption_type = "AES256", kms_key = null })
    image_scanning = optional(object({
      scan_on_push = optional(bool, true)
    }), { scan_on_push = true })
  })
  description = "ECR repository configuration."

  validation {
    condition     = length("${var.project_name}-${var.repository.name}") <= 256
    error_message = "Combined repository name (project_name-repository.name) must be 256 characters or fewer."
  }

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.repository.image_tag_mutability)
    error_message = "repository.image_tag_mutability must be one of: MUTABLE, IMMUTABLE."
  }

  validation {
    condition     = contains(["AES256", "KMS"], var.repository.encryption.encryption_type)
    error_message = "repository.encryption.encryption_type must be one of: AES256, KMS."
  }
}

variable "lifecycle_policy" {
  type        = string
  description = "JSON lifecycle policy document. If null, no lifecycle policy is created."
  default     = null
}

variable "repository_policy" {
  type        = string
  description = "JSON repository policy document for cross-account or service access. If null, no repository policy is created."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
  default     = {}
}
