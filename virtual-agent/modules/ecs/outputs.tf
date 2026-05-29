output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "container_name" {
  description = "Name of the container in the task definition"
  value       = var.container_name
}
