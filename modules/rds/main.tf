locals {
  is_cluster  = var.topology == "cluster"
  is_instance = var.topology == "instance"

  name         = "${var.project_name}-rds-${var.environment}"
  sg_name      = "${var.project_name}-rds-sg-${var.environment}"
  subnets_name = "${var.project_name}-rds-subnets-${var.environment}"

  default_ports = {
    "postgres"          = 5432
    "aurora-postgresql" = 5432
    "mysql"             = 3306
    "mariadb"           = 3306
    "aurora-mysql"      = 3306
    "sqlserver-ex"      = 1433
    "sqlserver-web"     = 1433
    "sqlserver-se"      = 1433
    "sqlserver-ee"      = 1433
  }

  port = coalesce(var.engine.port, local.default_ports[var.engine.name])

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

resource "aws_db_subnet_group" "this" {
  name        = local.subnets_name
  description = "Subnet group for ${local.name}"
  subnet_ids  = var.network.subnet_ids

  tags = merge(local.tags, {
    Name = local.subnets_name
  })
}

resource "aws_security_group" "this" {
  name        = local.sg_name
  description = "Database access for ${local.name}"
  vpc_id      = var.network.vpc_id

  tags = merge(local.tags, {
    Name = local.sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "from_apps" {
  count = length(var.network.ingress_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.network.ingress_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port
  description                  = "DB ingress from application security group"

  tags = local.tags
}

resource "aws_db_instance" "this" {
  count = local.is_instance ? 1 : 0

  identifier     = local.name
  engine         = var.engine.name
  engine_version = var.engine.version
  instance_class = var.instance.instance_class

  allocated_storage     = var.instance.allocated_storage
  max_allocated_storage = var.instance.max_allocated_storage
  storage_type          = var.instance.storage_type
  storage_encrypted     = var.instance.storage_encrypted
  kms_key_id            = var.instance.kms_key_id
  iops                  = var.instance.iops
  license_model         = var.instance.license_model

  db_name  = var.database.name
  username = var.database.master_username
  port     = local.port

  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.instance.kms_key_id

  multi_az               = var.instance.multi_az
  publicly_accessible    = var.network.publicly_accessible
  vpc_security_group_ids = [aws_security_group.this.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  parameter_group_name = var.engine.parameter_group_family

  backup_retention_period         = var.database.backup_retention_days
  backup_window                   = var.database.backup_window
  maintenance_window              = var.database.maintenance_window
  deletion_protection             = var.database.deletion_protection
  skip_final_snapshot             = var.database.skip_final_snapshot
  final_snapshot_identifier       = var.database.skip_final_snapshot ? null : "${local.name}-final"
  apply_immediately               = var.database.apply_immediately
  auto_minor_version_upgrade      = var.database.auto_minor_version_upgrade
  copy_tags_to_snapshot           = var.database.copy_tags_to_snapshot
  enabled_cloudwatch_logs_exports = var.database.enabled_cloudwatch_logs_exports

  performance_insights_enabled          = var.database.performance_insights_enabled
  performance_insights_retention_period = var.database.performance_insights_enabled ? var.database.performance_insights_retention_period : null

  monitoring_interval = var.database.monitoring_interval
  monitoring_role_arn = var.database.monitoring_interval > 0 ? var.database.monitoring_role_arn : null

  tags = merge(local.tags, {
    Name = local.name
  })
}

resource "aws_rds_cluster" "this" {
  count = local.is_cluster ? 1 : 0

  cluster_identifier = local.name
  engine             = var.engine.name
  engine_version     = var.engine.version

  database_name   = var.database.name
  master_username = var.database.master_username
  port            = local.port

  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.cluster.kms_key_id

  storage_encrypted    = var.cluster.storage_encrypted
  kms_key_id           = var.cluster.kms_key_id
  db_subnet_group_name = aws_db_subnet_group.this.name

  vpc_security_group_ids          = [aws_security_group.this.id]
  db_cluster_parameter_group_name = var.engine.parameter_group_family

  backup_retention_period         = var.database.backup_retention_days
  preferred_backup_window         = var.database.backup_window
  preferred_maintenance_window    = var.database.maintenance_window
  deletion_protection             = var.database.deletion_protection
  skip_final_snapshot             = var.database.skip_final_snapshot
  final_snapshot_identifier       = var.database.skip_final_snapshot ? null : "${local.name}-final"
  apply_immediately               = var.database.apply_immediately
  copy_tags_to_snapshot           = var.database.copy_tags_to_snapshot
  enabled_cloudwatch_logs_exports = var.database.enabled_cloudwatch_logs_exports

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.cluster.serverlessv2 != null ? [var.cluster.serverlessv2] : []
    content {
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
    }
  }

  tags = merge(local.tags, {
    Name = local.name
  })
}

resource "aws_rds_cluster_instance" "this" {
  count = local.is_cluster ? var.cluster.instance_count : 0

  identifier         = "${local.name}-${count.index}"
  cluster_identifier = aws_rds_cluster.this[0].id
  instance_class     = var.cluster.instance_class
  engine             = var.engine.name
  engine_version     = var.engine.version

  publicly_accessible        = var.network.publicly_accessible
  db_subnet_group_name       = aws_db_subnet_group.this.name
  auto_minor_version_upgrade = var.database.auto_minor_version_upgrade
  apply_immediately          = var.database.apply_immediately
  copy_tags_to_snapshot      = var.database.copy_tags_to_snapshot
  monitoring_interval        = var.database.monitoring_interval
  monitoring_role_arn        = var.database.monitoring_interval > 0 ? var.database.monitoring_role_arn : null

  performance_insights_enabled          = var.database.performance_insights_enabled
  performance_insights_retention_period = var.database.performance_insights_enabled ? var.database.performance_insights_retention_period : null

  tags = merge(local.tags, {
    Name = "${local.name}-${count.index}"
  })
}
