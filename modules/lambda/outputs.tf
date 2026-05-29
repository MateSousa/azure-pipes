output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_qualified_arn" {
  description = "Qualified ARN of the Lambda function (includes version or alias)."
  value       = aws_lambda_function.this.qualified_arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function (for API Gateway integration)."
  value       = aws_lambda_function.this.invoke_arn
}

output "function_version" {
  description = "Latest published version of the Lambda function."
  value       = aws_lambda_function.this.version
}

output "function_last_modified" {
  description = "Date the Lambda function was last modified."
  value       = aws_lambda_function.this.last_modified
}

output "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the deployment package."
  value       = aws_lambda_function.this.source_code_hash
}

output "source_code_size" {
  description = "Size in bytes of the deployment package."
  value       = aws_lambda_function.this.source_code_size
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group."
  value       = aws_cloudwatch_log_group.this.arn
}
