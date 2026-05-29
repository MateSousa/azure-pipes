output "api_id" {
  description = "ID of the HTTP API."
  value       = aws_apigatewayv2_api.this.id
}

output "api_arn" {
  description = "ARN of the HTTP API."
  value       = aws_apigatewayv2_api.this.arn
}

output "api_endpoint" {
  description = "URI of the HTTP API (e.g. https://abc123.execute-api.us-east-1.amazonaws.com)."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "execution_arn" {
  description = "Execution ARN of the HTTP API. Use this when granting Lambda invoke permission from outside the module."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "stage_id" {
  description = "ID of the stage."
  value       = aws_apigatewayv2_stage.this.id
}

output "stage_invoke_url" {
  description = "Full invoke URL for the stage (e.g. https://abc123.execute-api.us-east-1.amazonaws.com or https://.../<stage>)."
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "access_log_group_name" {
  description = "Name of the CloudWatch Log Group receiving access logs."
  value       = aws_cloudwatch_log_group.access.name
}

output "access_log_group_arn" {
  description = "ARN of the CloudWatch Log Group receiving access logs."
  value       = aws_cloudwatch_log_group.access.arn
}

output "vpc_link_id" {
  description = "ID of the VPC Link, or null when no HTTP_PROXY routes are defined."
  value       = var.vpc_link == null ? null : aws_apigatewayv2_vpc_link.this[0].id
}
