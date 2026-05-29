variable "rule_name" {
  description = "Name of the EventBridge rule"
  type        = string
}

variable "description" {
  description = "Description of the EventBridge rule"
  type        = string
  default     = ""
}

variable "schedule_expression" {
  description = "Schedule expression (cron or rate)"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the target Lambda function"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the target Lambda function"
  type        = string
}

variable "enabled" {
  description = "Whether the rule is enabled"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
