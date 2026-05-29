output "authorizer_id" {
  description = "ID of the API Gateway v2 authorizer. Pass this to modules/api-gateway as default_authorizer_id (or to specific routes)."
  value       = aws_apigatewayv2_authorizer.this.id
}

output "function_arn" {
  description = "ARN of the authorizer Lambda function."
  value       = module.lambda.function_arn
}

output "function_name" {
  description = "Name of the authorizer Lambda function."
  value       = module.lambda.function_name
}

output "function_invoke_arn" {
  description = "Invoke ARN of the authorizer Lambda function."
  value       = module.lambda.function_invoke_arn
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for the authorizer Lambda."
  value       = module.lambda.log_group_name
}
