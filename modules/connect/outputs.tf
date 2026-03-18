output "instance_id" {
  description = "The ID of the Connect instance."
  value       = local.instance_id
}

output "instance_arn" {
  description = "The ARN of the Connect instance (null if using an existing instance)."
  value       = try(aws_connect_instance.this[0].arn, null)
}

output "contact_flow_ids" {
  description = "Map of contact flow names to their IDs."
  value       = { for k, v in aws_connect_contact_flow.this : k => v.contact_flow_id }
}

output "contact_flow_arns" {
  description = "Map of contact flow names to their ARNs."
  value       = { for k, v in aws_connect_contact_flow.this : k => v.arn }
}

output "contact_flow_module_ids" {
  description = "Map of contact flow module names to their IDs."
  value       = { for k, v in aws_connect_contact_flow_module.this : k => v.contact_flow_module_id }
}

output "contact_flow_module_arns" {
  description = "Map of contact flow module names to their ARNs."
  value       = { for k, v in aws_connect_contact_flow_module.this : k => v.arn }
}

output "hours_of_operation_ids" {
  description = "Map of hours of operation names to their IDs."
  value       = { for k, v in aws_connect_hours_of_operation.this : k => v.hours_of_operation_id }
}

output "queue_ids" {
  description = "Map of queue names to their IDs."
  value       = { for k, v in aws_connect_queue.this : k => v.queue_id }
}

output "queue_arns" {
  description = "Map of queue names to their ARNs."
  value       = { for k, v in aws_connect_queue.this : k => v.arn }
}
