variable "project_name" {
  description = "Name of the project, used as a prefix for resource names."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "environment" {
  description = "Deployment environment, used as a suffix for resource names (e.g. dev, qa, stage, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, stage, prod."
  }
}

variable "tags" {
  description = "Tags to apply to every resource created by this module."
  type        = map(string)
  default     = {}
}

variable "network" {
  description = "VPC, subnet placement, and ingress sources for the database."
  type = object({
    vpc_id                     = string
    subnet_ids                 = list(string)
    ingress_security_group_ids = optional(list(string), [])
    publicly_accessible        = optional(bool, false)
  })

  validation {
    condition     = length(var.network.subnet_ids) >= 2
    error_message = "network.subnet_ids must contain at least two subnets in different AZs (RDS subnet group requirement)."
  }
}

variable "engine" {
  description = "Database engine selection."
  type = object({
    name                   = string
    version                = string
    port                   = optional(number, null)
    parameter_group_family = optional(string, null)
  })

  validation {
    condition = contains([
      "postgres",
      "mysql",
      "mariadb",
      "sqlserver-ex",
      "sqlserver-web",
      "sqlserver-se",
      "sqlserver-ee",
      "aurora-postgresql",
      "aurora-mysql",
    ], var.engine.name)
    error_message = "engine.name must be one of: postgres, mysql, mariadb, sqlserver-ex/web/se/ee, aurora-postgresql, aurora-mysql."
  }
}

variable "topology" {
  description = "Deployment topology: 'instance' for a single aws_db_instance, 'cluster' for an Aurora cluster."
  type        = string

  validation {
    condition     = contains(["instance", "cluster"], var.topology)
    error_message = "topology must be one of: instance, cluster."
  }

  validation {
    condition     = var.topology != "cluster" || (startswith(var.engine.name, "aurora-") && var.cluster != null)
    error_message = "When topology = \"cluster\", engine.name must start with \"aurora-\" and var.cluster must be set."
  }

  validation {
    condition     = var.topology != "instance" || (!startswith(var.engine.name, "aurora-") && var.instance != null)
    error_message = "When topology = \"instance\", engine.name must not start with \"aurora-\" and var.instance must be set."
  }
}

variable "instance" {
  description = "Configuration for the single-instance topology (aws_db_instance). Required when topology = \"instance\"."
  type = object({
    instance_class        = string
    allocated_storage     = optional(number, 20)
    max_allocated_storage = optional(number, null)
    storage_type          = optional(string, "gp3")
    storage_encrypted     = optional(bool, true)
    kms_key_id            = optional(string, null)
    multi_az              = optional(bool, false)
    iops                  = optional(number, null)
    license_model         = optional(string, null)
  })
  default = null
}

variable "cluster" {
  description = "Configuration for the Aurora cluster topology. Required when topology = \"cluster\"."
  type = object({
    instance_class    = string
    instance_count    = optional(number, 2)
    storage_encrypted = optional(bool, true)
    kms_key_id        = optional(string, null)
    serverlessv2 = optional(object({
      min_capacity = number
      max_capacity = number
    }), null)
  })
  default = null

  validation {
    condition     = var.cluster == null ? true : var.cluster.instance_count >= 1
    error_message = "cluster.instance_count must be at least 1."
  }
}

variable "database" {
  description = "Cross-topology database knobs: initial database, master user, backups, maintenance, observability."
  type = object({
    name                                  = optional(string, null)
    master_username                       = string
    deletion_protection                   = optional(bool, true)
    backup_retention_days                 = optional(number, 7)
    backup_window                         = optional(string, "03:00-04:00")
    maintenance_window                    = optional(string, "sun:04:00-sun:05:00")
    skip_final_snapshot                   = optional(bool, false)
    apply_immediately                     = optional(bool, false)
    auto_minor_version_upgrade            = optional(bool, true)
    copy_tags_to_snapshot                 = optional(bool, true)
    performance_insights_enabled          = optional(bool, true)
    performance_insights_retention_period = optional(number, 7)
    monitoring_interval                   = optional(number, 0)
    monitoring_role_arn                   = optional(string, null)
    enabled_cloudwatch_logs_exports       = optional(list(string), [])
  })

  validation {
    condition     = var.database.backup_retention_days >= 0 && var.database.backup_retention_days <= 35
    error_message = "database.backup_retention_days must be between 0 and 35."
  }

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.database.monitoring_interval)
    error_message = "database.monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }

  validation {
    condition     = var.database.monitoring_interval == 0 || var.database.monitoring_role_arn != null
    error_message = "database.monitoring_role_arn is required when monitoring_interval > 0."
  }
}
