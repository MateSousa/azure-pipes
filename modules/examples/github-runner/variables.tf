variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources."
  type        = string
  default     = "myproject"
}

variable "ecs_cluster_arn" {
  description = "ARN of the existing ECS cluster the runner tasks will run in."
  type        = string
}

variable "vpc_id" {
  description = "ID of the existing VPC."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs with egress to api.github.com (via NAT or VPC endpoints + a NAT for github.com itself)."
  type        = list(string)
}

variable "dispatcher_image_uri" {
  description = "Container image URI for the dispatcher Lambda. Build from modules/github-runner/dispatcher/ and push to ECR."
  type        = string
}

variable "runner_image_uri" {
  description = "Container image URI for the GitHub Actions runner. Build from modules/github-runner/runner/ and push to ECR."
  type        = string
}
