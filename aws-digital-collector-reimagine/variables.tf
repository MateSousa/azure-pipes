variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the ALB and ECS service"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID"
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
  description = "Docker image URI (ECR)"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket for the application"
  type        = string
}

variable "s3_key" {
  description = "S3 key for the application data"
  type        = string
}

variable "connect_instance_id" {
  description = "Amazon Connect instance ID"
  type        = string
}

variable "contact_flow_id" {
  description = "Amazon Connect contact flow ID"
  type        = string
}

variable "source_phone_number" {
  description = "Source phone number for outbound calls"
  type        = string
}
