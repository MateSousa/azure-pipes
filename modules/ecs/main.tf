resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-${var.cluster.name}"

  setting {
    name  = "containerInsights"
    value = var.cluster.container_insights
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  count = length(var.cluster.capacity_providers) > 0 ? 1 : 0

  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = var.cluster.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.cluster.default_capacity_provider_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}
