output "alb_id" {
  description = "The ID of the ALB."
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "The ARN of the ALB."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB for use with CloudWatch Metrics."
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "The DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "The ARN of the target group."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "The ARN suffix of the target group for use with CloudWatch Metrics."
  value       = aws_lb_target_group.this.arn_suffix
}

output "target_group_name" {
  description = "The name of the target group."
  value       = aws_lb_target_group.this.name
}

output "listener_arn" {
  description = "The ARN of the listener."
  value       = aws_lb_listener.this.arn
}

output "redirect_listener_arn" {
  description = "The ARN of the HTTP to HTTPS redirect listener, or null if not created."
  value       = try(aws_lb_listener.redirect[0].arn, null)
}
