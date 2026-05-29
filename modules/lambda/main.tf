########################################
# Locals
########################################

locals {
  is_zip          = var.source_config.package_type == "Zip"
  is_python       = local.is_zip && can(regex("^python", var.lambda.runtime))
  placeholder_dir = local.is_python ? "${path.module}/placeholders/python" : "${path.module}/placeholders/nodejs"
}

########################################
# Auto-zip placeholder
########################################

data "archive_file" "this" {
  count       = local.is_zip ? 1 : 0
  type        = "zip"
  source_dir  = local.placeholder_dir
  output_path = "${path.module}/.zip/${var.project_name}-${var.lambda.name}.zip"
}

########################################
# CloudWatch Log Group
########################################

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.project_name}-${var.lambda.name}"
  retention_in_days = var.logging.retention_in_days
  tags              = var.tags
}

########################################
# Lambda Function
########################################

resource "aws_lambda_function" "this" {
  function_name = "${var.project_name}-${var.lambda.name}"
  description   = var.lambda.description
  handler       = local.is_zip ? var.lambda.handler : null
  runtime       = local.is_zip ? var.lambda.runtime : null
  role          = var.iam.role_arn

  memory_size                    = var.lambda.memory
  timeout                        = var.lambda.timeout
  reserved_concurrent_executions = var.lambda.reserved_concurrency == -1 ? null : var.lambda.reserved_concurrency
  publish                        = var.lambda.publish
  architectures                  = var.lambda.architectures
  layers                         = var.lambda.layers

  # Packaging — Zip (placeholder, real code deployed via CI/CD)
  package_type     = var.source_config.package_type
  filename         = local.is_zip ? data.archive_file.this[0].output_path : null
  source_code_hash = local.is_zip ? data.archive_file.this[0].output_base64sha256 : null

  # Packaging — Image
  image_uri = local.is_zip ? null : var.source_config.image_uri

  # VPC
  dynamic "vpc_config" {
    for_each = length(var.network.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.network.subnet_ids
      security_group_ids = var.network.security_group_ids
    }
  }

  # Environment variables
  dynamic "environment" {
    for_each = length(var.lambda.environment_variables) > 0 ? [1] : []
    content {
      variables = var.lambda.environment_variables
    }
  }

  # Ephemeral storage
  ephemeral_storage {
    size = var.lambda.ephemeral_storage_size
  }

  # Tracing
  tracing_config {
    mode = var.tracing.mode
  }

  # Logging
  logging_config {
    log_format = var.logging.log_format
    log_group  = aws_cloudwatch_log_group.this.name
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = var.tags

  # Real code is deployed via CI/CD — don't revert to placeholder on apply
  lifecycle {
    ignore_changes = [filename, source_code_hash, image_uri]
  }
}
