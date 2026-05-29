output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs.task_definition_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.function_arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge schedule rule"
  value       = module.eventbridge.rule_arn
}

output "lambda_log_group" {
  description = "CloudWatch log group for the Lambda function"
  value       = module.lambda.log_group_name
}
