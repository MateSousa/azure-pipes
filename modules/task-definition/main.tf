locals {
  log_group_name = coalesce(var.logging.log_group_name, "/ecs/${var.project_name}-${var.task.family}")
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  count             = var.logging.create_log_group ? 1 : 0
  name              = local.log_group_name
  retention_in_days = var.logging.retention_in_days
  tags              = var.tags
}

# ------------------------------------------------------------------------------
# ECS Task Definition
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project_name}-${var.task.family}"
  cpu                      = var.task.cpu
  memory                   = var.task.memory
  network_mode             = var.task.network_mode
  requires_compatibilities = var.task.requires_compatibilities
  execution_role_arn       = var.iam.execution_role_arn
  task_role_arn            = var.iam.task_role_arn

  container_definitions = jsonencode([
    merge(
      {
        name                   = var.task.container_name
        image                  = var.task.container_image
        essential              = var.task.essential
        readonlyRootFilesystem = var.task.readonly_root_filesystem
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = local.log_group_name
            "awslogs-region"        = var.logging.region
            "awslogs-stream-prefix" = "ecs"
          }
        }
      },
      var.task.container_port != null ? {
        portMappings = [
          {
            containerPort = var.task.container_port
            protocol      = var.task.protocol
          }
        ]
      } : {},
      length(var.task.environment_variables) > 0 ? {
        environment = [
          for k, v in var.task.environment_variables : {
            name  = k
            value = v
          }
        ]
      } : {},
      length(var.task.secrets) > 0 ? {
        secrets = [
          for k, v in var.task.secrets : {
            name      = k
            valueFrom = v
          }
        ]
      } : {},
      var.task.command != null ? { command = var.task.command } : {},
      var.task.entry_point != null ? { entryPoint = var.task.entry_point } : {},
      var.task.health_check != null ? {
        healthCheck = {
          command     = var.task.health_check.command
          interval    = var.task.health_check.interval
          timeout     = var.task.health_check.timeout
          retries     = var.task.health_check.retries
          startPeriod = var.task.health_check.start_period
        }
      } : {}
    )
  ])

  tags = var.tags
}
