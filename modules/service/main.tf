locals {
  cluster_name = element(split("/", var.ecs.cluster_id), length(split("/", var.ecs.cluster_id)) - 1)
}

resource "aws_ecs_service" "this" {
  name                   = "${var.project_name}-${var.service.name}"
  cluster                = var.ecs.cluster_id
  task_definition        = var.ecs.task_definition_arn
  desired_count          = var.service.desired_count
  launch_type            = var.service.launch_type
  platform_version       = var.service.platform_version
  scheduling_strategy    = var.service.scheduling_strategy
  force_new_deployment   = var.service.force_new_deployment
  enable_execute_command = var.service.enable_execute_command
  propagate_tags         = var.service.propagate_tags

  health_check_grace_period_seconds = var.load_balancer != null ? var.service.health_check_grace_period_seconds : null

  deployment_minimum_healthy_percent = var.deployment.minimum_healthy_percent
  deployment_maximum_percent         = var.deployment.maximum_percent

  network_configuration {
    subnets          = var.network.subnet_ids
    security_groups  = var.network.security_group_ids
    assign_public_ip = var.network.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer != null ? [var.load_balancer] : []
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = var.ecs.container_name
      container_port   = var.ecs.container_port
    }
  }

  dynamic "deployment_circuit_breaker" {
    for_each = var.deployment.deployment_circuit_breaker != null ? [var.deployment.deployment_circuit_breaker] : []
    content {
      enable   = deployment_circuit_breaker.value.enable
      rollback = deployment_circuit_breaker.value.rollback
    }
  }

  tags = var.tags
}

resource "aws_appautoscaling_target" "this" {
  count              = var.autoscaling != null ? 1 : 0
  max_capacity       = var.autoscaling.max_capacity
  min_capacity       = var.autoscaling.min_capacity
  resource_id        = "service/${local.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.autoscaling != null && var.autoscaling.cpu_target_value != null ? 1 : 0
  name               = "${var.project_name}-${var.service.name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling.cpu_target_value
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown
    scale_out_cooldown = var.autoscaling.scale_out_cooldown
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count              = var.autoscaling != null && var.autoscaling.memory_target_value != null ? 1 : 0
  name               = "${var.project_name}-${var.service.name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling.memory_target_value
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown
    scale_out_cooldown = var.autoscaling.scale_out_cooldown
  }
}
