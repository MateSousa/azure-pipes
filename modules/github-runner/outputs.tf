output "webhook_url" {
  description = "Invoke URL for the GitHub App webhook. Paste this into the GitHub App's Webhook URL field."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  description = "HTTP API ID."
  value       = aws_apigatewayv2_api.this.id
}

output "api_execution_arn" {
  description = "HTTP API execution ARN (e.g. for additional lambda permissions)."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "dispatcher_function_arn" {
  description = "ARN of the dispatcher Lambda."
  value       = aws_lambda_function.dispatcher.arn
}

output "dispatcher_function_name" {
  description = "Name of the dispatcher Lambda."
  value       = aws_lambda_function.dispatcher.function_name
}

output "runner_task_definition_arn" {
  description = "ARN of the runner ECS task definition (latest revision)."
  value       = aws_ecs_task_definition.runner.arn
}

output "runner_task_definition_family" {
  description = "Family name of the runner ECS task definition."
  value       = aws_ecs_task_definition.runner.family
}

output "runner_log_group_name" {
  description = "CloudWatch log group containing runner task logs."
  value       = aws_cloudwatch_log_group.runner.name
}

output "dispatcher_log_group_name" {
  description = "CloudWatch log group containing dispatcher Lambda logs."
  value       = aws_cloudwatch_log_group.dispatcher.name
}
