output "task_definition_arn" {
  description = "Full ARN of the task definition (includes revision)."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_arn_without_revision" {
  description = "ARN of the task definition without the revision number."
  value       = aws_ecs_task_definition.this.arn_without_revision
}

output "task_definition_revision" {
  description = "Revision number of the task definition."
  value       = aws_ecs_task_definition.this.revision
}

output "task_definition_family" {
  description = "Family name of the task definition."
  value       = aws_ecs_task_definition.this.family
}

output "container_name" {
  description = "Name of the container defined in the task."
  value       = var.task.container_name
}

output "container_port" {
  description = "Port exposed by the container (null for batch tasks)."
  value       = var.task.container_port
}

output "log_group_name" {
  description = "Name of the CloudWatch log group."
  value       = local.log_group_name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group, or null if not created by this module."
  value       = try(aws_cloudwatch_log_group.this[0].arn, null)
}
