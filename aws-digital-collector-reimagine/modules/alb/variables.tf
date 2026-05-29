variable "name" {
  description = "Name of the ALB"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the ALB"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for the ALB"
  type        = list(string)
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Health check path for the target group"
  type        = string
  default     = "/health"
}

variable "internal" {
  description = "Whether the ALB is internal"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to ALB resources"
  type        = map(string)
  default     = {}
}
