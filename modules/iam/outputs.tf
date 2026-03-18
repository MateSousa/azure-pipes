output "role_arn" {
  description = "The ARN of the IAM role."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "The name of the IAM role."
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "The stable and unique string identifying the IAM role."
  value       = aws_iam_role.this.id
}

output "role_unique_id" {
  description = "The unique ID assigned by AWS to the IAM role."
  value       = aws_iam_role.this.unique_id
}

output "role_create_date" {
  description = "The creation date of the IAM role."
  value       = aws_iam_role.this.create_date
}
