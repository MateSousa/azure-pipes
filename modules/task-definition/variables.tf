variable "project_name" {
  description = "Project name used as a prefix for resource naming."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "task" {
  description = "ECS task definition configuration."
  type = object({
    family                   = string
    cpu                      = string
    memory                   = string
    network_mode             = optional(string, "awsvpc")
    requires_compatibilities = optional(list(string), ["FARGATE"])
    container_name           = string
    container_image          = string
    container_port           = optional(number, null)
    protocol                 = optional(string, "tcp")
    command                  = optional(list(string), null)
    entry_point              = optional(list(string), null)
    essential                = optional(bool, true)
    readonly_root_filesystem = optional(bool, false)
    environment_variables    = optional(map(string), {})
    secrets                  = optional(map(string), {})
    health_check = optional(object({
      command      = list(string)
      interval     = optional(number, 30)
      timeout      = optional(number, 5)
      retries      = optional(number, 3)
      start_period = optional(number, 0)
    }), null)
  })

  validation {
    condition     = length("${var.project_name}-${var.task.family}") <= 255
    error_message = "The combined length of project_name and task family (project_name-family) must be 255 characters or fewer."
  }

  validation {
    condition     = var.task.container_port == null ? true : (var.task.container_port >= 1 && var.task.container_port <= 65535)
    error_message = "container_port must be null or between 1 and 65535."
  }
}

variable "iam" {
  description = "IAM role ARNs for the ECS task."
  type = object({
    execution_role_arn = string
    task_role_arn      = string
  })

  validation {
    condition     = can(regex("^arn:aws:iam::", var.iam.execution_role_arn))
    error_message = "execution_role_arn must be a valid IAM ARN (arn:aws:iam::...)."
  }

  validation {
    condition     = can(regex("^arn:aws:iam::", var.iam.task_role_arn))
    error_message = "task_role_arn must be a valid IAM ARN (arn:aws:iam::...)."
  }
}

variable "logging" {
  description = "CloudWatch logging configuration for the ECS task."
  type = object({
    log_group_name    = optional(string, null)
    region            = string
    retention_in_days = optional(number, 14)
    create_log_group  = optional(bool, true)
  })
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
