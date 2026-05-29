########################################
# HTTP API
########################################

resource "aws_apigatewayv2_api" "this" {
  name                         = "${var.project_name}-${var.api.name}"
  description                  = var.api.description
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = var.api.disable_execute_api_endpoint

  dynamic "cors_configuration" {
    for_each = var.api.cors_configuration == null ? [] : [var.api.cors_configuration]
    content {
      allow_credentials = cors_configuration.value.allow_credentials
      allow_headers     = cors_configuration.value.allow_headers
      allow_methods     = cors_configuration.value.allow_methods
      allow_origins     = cors_configuration.value.allow_origins
      expose_headers    = cors_configuration.value.expose_headers
      max_age           = cors_configuration.value.max_age
    }
  }

  tags = var.tags

  # Routes and integrations are defined out-of-band by the OpenAPI deploy
  # workflow (apigatewayv2 reimport-api). AWS populates `body` after a
  # reimport — ignore it here so terraform plan doesn't fight the workflow.
  lifecycle {
    ignore_changes = [body]
  }
}

########################################
# Access Log Group
########################################

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.project_name}-${var.api.name}"
  retention_in_days = var.stage.access_log_retention_days
  tags              = var.tags
}

########################################
# Stage
########################################

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage.name
  auto_deploy = var.stage.auto_deploy

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      authorizerError         = "$context.authorizer.error"
    })
  }

  dynamic "default_route_settings" {
    for_each = var.stage.throttle == null ? [] : [var.stage.throttle]
    content {
      throttling_burst_limit = default_route_settings.value.burst_limit
      throttling_rate_limit  = default_route_settings.value.rate_limit
    }
  }

  tags = var.tags
}

########################################
# VPC Link — for HTTP_PROXY routes targeting a private ALB
########################################

resource "aws_apigatewayv2_vpc_link" "this" {
  count = var.vpc_link == null ? 0 : 1

  name               = "${var.project_name}-${var.api.name}-${var.vpc_link.name}"
  subnet_ids         = var.vpc_link.subnet_ids
  security_group_ids = var.vpc_link.security_group_ids

  tags = var.tags
}

########################################
# Lambda invoke permissions
#
# Routes live in the OpenAPI spec deployed by CI/CD, but every Lambda that an
# AWS_PROXY integration may target still needs lambda:InvokeFunction granted to
# API Gateway. The source_arn wildcard covers all stages/methods/routes for
# this API, so adding/removing routes in OpenAPI doesn't require touching TF.
########################################

resource "aws_lambda_permission" "invokable" {
  for_each = { for l in var.invokable_lambdas : l.name => l }

  statement_id  = "AllowAPIGatewayInvoke-${each.value.name}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*/*"
}
