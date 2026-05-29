variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "task_family" {
  description = "Family name for the task definition"
  type        = string
}

variable "cpu" {
  description = "CPU units for the task (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory (MiB) for the task"
  type        = number
  default     = 512
}

variable "container_name" {
  description = "Name of the container"
  type        = string
}

variable "container_image" {
  description = "Docker image for the container"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the ECS service"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for the ECS service"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region for log configuration"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "command" {
  description = "Command to run in the container"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to ECS resources"
  type        = map(string)
  default     = {}
}
