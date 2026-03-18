variable "project_name" {
  description = "Project name used as a prefix for resource naming."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "service" {
  description = "ECS service configuration."
  type = object({
    name                              = string
    desired_count                     = optional(number, 1)
    launch_type                       = optional(string, "FARGATE")
    platform_version                  = optional(string, "LATEST")
    scheduling_strategy               = optional(string, "REPLICA")
    force_new_deployment              = optional(bool, true)
    enable_execute_command            = optional(bool, false)
    health_check_grace_period_seconds = optional(number, null)
    propagate_tags                    = optional(string, "SERVICE")
  })

  validation {
    condition     = var.service.desired_count >= 0 && var.service.desired_count <= 10
    error_message = "desired_count must be between 0 and 10."
  }

  validation {
    condition     = contains(["FARGATE", "EC2"], var.service.launch_type)
    error_message = "launch_type must be either FARGATE or EC2."
  }
}

variable "ecs" {
  description = "ECS cluster and task definition configuration."
  type = object({
    cluster_id          = string
    task_definition_arn = string
    container_name      = string
    container_port      = optional(number, null)
  })

  validation {
    condition     = var.ecs.container_port == null ? true : (var.ecs.container_port >= 1 && var.ecs.container_port <= 65535)
    error_message = "container_port must be null or between 1 and 65535."
  }
}

variable "network" {
  description = "Network configuration for the ECS service."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
    assign_public_ip   = optional(bool, false)
  })
}

variable "load_balancer" {
  description = "Load balancer configuration. Set to null to disable."
  type = object({
    target_group_arn = string
  })
  default = null
}

variable "deployment" {
  description = "Deployment configuration for the ECS service."
  type = object({
    minimum_healthy_percent = optional(number, 100)
    maximum_percent         = optional(number, 200)
    deployment_circuit_breaker = optional(object({
      enable   = bool
      rollback = bool
    }), null)
  })
  default = {}
}

variable "autoscaling" {
  description = "Autoscaling configuration. Set to null to disable."
  type = object({
    min_capacity        = number
    max_capacity        = number
    cpu_target_value    = optional(number, null)
    memory_target_value = optional(number, null)
    scale_in_cooldown   = optional(number, 300)
    scale_out_cooldown  = optional(number, 300)
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
