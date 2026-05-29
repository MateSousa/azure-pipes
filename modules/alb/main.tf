################################################################################
# Application Load Balancer
################################################################################

resource "aws_lb" "this" {
  name                             = "${var.project_name}-${var.alb.name}"
  internal                         = var.alb.internal
  load_balancer_type               = "application"
  security_groups                  = var.network.security_group_ids
  subnets                          = var.network.subnet_ids
  idle_timeout                     = var.alb.idle_timeout
  enable_deletion_protection       = var.alb.enable_deletion_protection
  enable_http2                     = var.alb.enable_http2
  drop_invalid_header_fields       = var.alb.drop_invalid_header_fields
  enable_cross_zone_load_balancing = var.alb.enable_cross_zone_load_balancing

  tags = var.tags
}

################################################################################
# Target Group
################################################################################

resource "aws_lb_target_group" "this" {
  name                 = "${var.project_name}-${var.target_group.name}"
  port                 = var.target_group.port
  protocol             = var.target_group.protocol
  target_type          = var.target_group.target_type
  vpc_id               = var.network.vpc_id
  deregistration_delay = var.target_group.deregistration_delay
  slow_start           = var.target_group.slow_start

  health_check {
    enabled             = var.target_group.health_check.enabled
    path                = var.target_group.health_check.path
    port                = var.target_group.health_check.port
    protocol            = var.target_group.health_check.protocol
    healthy_threshold   = var.target_group.health_check.healthy_threshold
    unhealthy_threshold = var.target_group.health_check.unhealthy_threshold
    timeout             = var.target_group.health_check.timeout
    interval            = var.target_group.health_check.interval
    matcher             = var.target_group.health_check.matcher
  }

  dynamic "stickiness" {
    for_each = var.target_group.stickiness != null ? [var.target_group.stickiness] : []

    content {
      type            = stickiness.value.type
      cookie_duration = stickiness.value.cookie_duration
      enabled         = stickiness.value.enabled
    }
  }

  tags = var.tags
}

################################################################################
# Listener
################################################################################

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener.port
  protocol          = var.listener.protocol
  ssl_policy        = var.listener.ssl_policy
  certificate_arn   = var.listener.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = var.tags
}

################################################################################
# HTTP -> HTTPS Redirect Listener (conditional)
################################################################################

resource "aws_lb_listener" "redirect" {
  count             = var.https_redirect ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}
