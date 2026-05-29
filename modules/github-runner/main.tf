########################################
# Locals
########################################

locals {
  dispatcher_name      = "${var.project_name}-${var.dispatcher.name}"
  runner_family        = "${var.project_name}-${var.runner.family}"
  api_name             = "${var.project_name}-${var.api.name}"
  runner_log_group     = "/ecs/${local.runner_family}"
  dispatcher_log_group = "/aws/lambda/${local.dispatcher_name}"
  api_log_group        = "/aws/apigateway/${local.api_name}"
}

########################################
# CloudWatch Log Groups
########################################

resource "aws_cloudwatch_log_group" "runner" {
  name              = local.runner_log_group
  retention_in_days = var.logging.runner_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "dispatcher" {
  name              = local.dispatcher_log_group
  retention_in_days = var.logging.dispatcher_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "api" {
  name              = local.api_log_group
  retention_in_days = var.logging.api_retention_days
  tags              = var.tags
}

########################################
# Runner Task Definition
#
# Ephemeral: one task per job. The dispatcher injects REG_TOKEN, ORG, and
# RUNNER_LABELS per-invocation via containerOverrides, so nothing job-specific
# is baked in here.
########################################

resource "aws_ecs_task_definition" "runner" {
  family                   = local.runner_family
  cpu                      = var.runner.cpu
  memory                   = var.runner.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.runner.execution_role_arn
  task_role_arn            = var.runner.task_role_arn

  container_definitions = jsonencode([
    merge(
      {
        name      = var.runner.container_name
        image     = var.runner.container_image
        essential = true
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = local.runner_log_group
            "awslogs-region"        = data.aws_region.current.name
            "awslogs-stream-prefix" = "runner"
          }
        }
      },
      length(var.runner.extra_env) > 0 ? {
        environment = [for k, v in var.runner.extra_env : { name = k, value = v }]
      } : {},
    )
  ])

  tags = var.tags
}

data "aws_region" "current" {}

########################################
# Dispatcher Lambda
#
# Container-image package. The image bundles handler.py and its Python deps
# (PyJWT, cryptography, requests). Built and pushed out-of-band; users update
# the dispatcher by bumping dispatcher.image_uri.
########################################

resource "aws_lambda_function" "dispatcher" {
  function_name = local.dispatcher_name
  role          = var.dispatcher.role_arn
  package_type  = "Image"
  image_uri     = var.dispatcher.image_uri
  memory_size   = var.dispatcher.memory
  timeout       = var.dispatcher.timeout

  environment {
    variables = {
      CLUSTER_ARN                = var.ecs.cluster_arn
      TASK_DEFINITION            = aws_ecs_task_definition.runner.family
      CONTAINER_NAME             = var.runner.container_name
      SUBNETS                    = join(",", var.network.subnet_ids)
      SECURITY_GROUPS            = join(",", var.network.security_group_ids)
      ASSIGN_PUBLIC_IP           = var.network.assign_public_ip ? "ENABLED" : "DISABLED"
      RUNNER_LABEL               = var.runner.runner_label
      APP_ID_SECRET_ARN          = var.secrets.app_id_arn
      APP_PRIVATE_KEY_SECRET_ARN = var.secrets.app_private_key_arn
      WEBHOOK_SECRET_ARN         = var.secrets.webhook_secret_arn
      ORG_SECRET_ARN             = var.secrets.org_arn
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.dispatcher.name
  }

  tags       = var.tags
  depends_on = [aws_cloudwatch_log_group.dispatcher]
}

########################################
# HTTP API (webhook receiver)
########################################

resource "aws_apigatewayv2_api" "this" {
  name          = local.api_name
  description   = "GitHub webhook receiver for self-hosted runner dispatch."
  protocol_type = "HTTP"
  tags          = var.tags
}

resource "aws_apigatewayv2_integration" "dispatcher" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.dispatcher.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.dispatcher.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  dynamic "default_route_settings" {
    for_each = var.api.throttle == null ? [] : [var.api.throttle]
    content {
      throttling_burst_limit = default_route_settings.value.burst_limit
      throttling_rate_limit  = default_route_settings.value.rate_limit
    }
  }

  tags = var.tags
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatcher.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
