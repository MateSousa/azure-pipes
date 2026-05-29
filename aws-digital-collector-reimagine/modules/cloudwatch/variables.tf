variable "log_group_name" {
  description = "Name of the CloudWatch log group"
  type        = string
}

variable "retention_in_days" {
  description = "Number of days to retain log events"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to the log group"
  type        = map(string)
  default     = {}
}
