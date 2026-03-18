########################################
# Auto-zip
########################################

data "archive_file" "this" {
  count       = var.source_config.source_path != null ? 1 : 0
  type        = "zip"
  source_dir  = var.source_config.source_path
  output_path = "${path.module}/.zip/${var.project_name}-${var.lambda.name}.zip"
}

########################################
# Locals
########################################

locals {
  use_archive      = var.source_config.source_path != null && var.source_config.package_type == "Zip"
  filename         = local.use_archive ? data.archive_file.this[0].output_path : var.source_config.filename
  source_code_hash = local.use_archive ? data.archive_file.this[0].output_base64sha256 : var.source_config.source_code_hash
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
  handler       = var.source_config.package_type == "Image" ? null : var.lambda.handler
  runtime       = var.source_config.package_type == "Image" ? null : var.lambda.runtime
  role          = var.iam.role_arn

  memory_size                    = var.lambda.memory
  timeout                        = var.lambda.timeout
  reserved_concurrent_executions = var.lambda.reserved_concurrency == -1 ? null : var.lambda.reserved_concurrency
  publish                        = var.lambda.publish
  architectures                  = var.lambda.architectures
  layers                         = var.lambda.layers

  # Packaging — Zip
  package_type      = var.source_config.package_type
  filename          = var.source_config.package_type == "Zip" ? local.filename : null
  source_code_hash  = var.source_config.package_type == "Zip" ? local.source_code_hash : null
  s3_bucket         = var.source_config.package_type == "Zip" ? var.source_config.s3_bucket : null
  s3_key            = var.source_config.package_type == "Zip" ? var.source_config.s3_key : null
  s3_object_version = var.source_config.package_type == "Zip" ? var.source_config.s3_object_version : null

  # Packaging — Image
  image_uri = var.source_config.package_type == "Image" ? var.source_config.image_uri : null

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
}
