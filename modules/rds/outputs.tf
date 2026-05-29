output "identifier" {
  description = "Identifier of the RDS instance or Aurora cluster."
  value       = local.is_cluster ? aws_rds_cluster.this[0].cluster_identifier : aws_db_instance.this[0].identifier
}

output "endpoint" {
  description = "Connection endpoint (writer endpoint for Aurora)."
  value       = local.is_cluster ? aws_rds_cluster.this[0].endpoint : aws_db_instance.this[0].endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint for Aurora clusters; null for single-instance topology."
  value       = local.is_cluster ? aws_rds_cluster.this[0].reader_endpoint : null
}

output "port" {
  description = "Port the database is listening on."
  value       = local.port
}

output "master_user_secret_arn" {
  description = "ARN of the AWS-managed Secrets Manager secret holding the master user credentials. Wire this into ECS task definition `secrets[]` to inject the password at runtime."
  value = local.is_cluster ? (
    aws_rds_cluster.this[0].master_user_secret[0].secret_arn
    ) : (
    aws_db_instance.this[0].master_user_secret[0].secret_arn
  )
}

output "security_group_id" {
  description = "ID of the security group attached to the database. Add egress rules from your application SG to this on the database port."
  value       = aws_security_group.this.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group created by this module."
  value       = aws_db_subnet_group.this.name
}
