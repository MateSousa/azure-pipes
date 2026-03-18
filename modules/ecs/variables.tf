variable "project_name" {
  description = "The name of the project."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "cluster" {
  description = "Configuration for the ECS cluster."
  type = object({
    name               = string
    container_insights = optional(string, "enabled")
    capacity_providers = optional(list(string), [])
    default_capacity_provider_strategy = optional(list(object({
      capacity_provider = string
      weight            = optional(number, 0)
      base              = optional(number, 0)
    })), [])
  })

  validation {
    condition     = length("${var.project_name}-${var.cluster.name}") <= 255
    error_message = "The combined cluster name (project_name-cluster.name) must be 255 characters or fewer."
  }

  validation {
    condition     = contains(["enabled", "disabled"], var.cluster.container_insights)
    error_message = "container_insights must be either \"enabled\" or \"disabled\"."
  }
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default     = {}
}
