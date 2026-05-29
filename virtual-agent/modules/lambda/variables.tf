variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "filename" {
  description = "Path to the Lambda deployment package (mutually exclusive with s3_bucket/s3_key)"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key for the Lambda deployment package"
  type        = string
  default     = null
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster to run tasks in"
  type        = string
}

variable "task_definition_arn" {
  description = "ARN of the ECS task definition to run"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the ECS task execution role (for iam:PassRole)"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role (for iam:PassRole)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "environment_variables" {
  description = "Additional environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "reserved_concurrency" {
  description = "Reserved concurrent executions (set to 1 to prevent parallel runs)"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "agents_config" {
  description = "JSON-encoded list of agent configurations"
  type        = string
}

variable "container_name" {
  description = "Container name in the task definition (used for containerOverrides)"
  type        = string
}
