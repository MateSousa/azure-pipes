variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks and Lambda VPC config"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks and Lambda"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "container_image" {
  description = "Docker image URI for the virtual agent container"
  type        = string
}

variable "lambda_filename" {
  description = "Path to the Lambda deployment zip (mutually exclusive with lambda_s3_*)"
  type        = string
  default     = null
}

variable "lambda_s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package"
  type        = string
  default     = null
}

variable "lambda_s3_key" {
  description = "S3 key for the Lambda deployment package"
  type        = string
  default     = null
}

variable "schedule_enabled" {
  description = "Whether the EventBridge schedule is enabled"
  type        = bool
  default     = true
}

variable "agents" {
  description = "List of virtual agent configurations. Each agent will get its own ECS task with AGENT_ID injected via container overrides."
  type = list(object({
    agent_id    = string
    agent_name  = string
    environment = optional(map(string), {})
  }))

  validation {
    condition     = length(var.agents) > 0
    error_message = "At least one agent must be configured."
  }

  validation {
    condition     = alltrue([for a in var.agents : length(a.agent_id) <= 36])
    error_message = "agent_id must be 36 characters or fewer (ECS startedBy limit)."
  }

  validation {
    condition     = length(distinct([for a in var.agents : a.agent_id])) == length(var.agents)
    error_message = "agent_id values must be unique."
  }
}
