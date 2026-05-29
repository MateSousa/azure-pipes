# IAM Role for Lambda
resource "aws_iam_role" "this" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Least-privilege: ECS RunTask only on the specific task definition
resource "aws_iam_role_policy" "ecs_run_task" {
  name = "${var.function_name}-ecs-run-task"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecs:RunTask"
        Resource = var.task_definition_arn
        Condition = {
          ArnEquals = {
            "ecs:cluster" = var.ecs_cluster_arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          var.execution_role_arn,
          var.task_role_arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ECS ListTasks and DescribeTasks for checking running agents
resource "aws_iam_role_policy" "ecs_describe" {
  name = "${var.function_name}-ecs-describe"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Logs
resource "aws_iam_role_policy" "logs" {
  name = "${var.function_name}-logs"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.this.arn}:*"
      }
    ]
  })
}

# VPC access for Lambda (if subnet_ids provided)
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Lambda Function
resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size
  filename      = var.filename
  s3_bucket     = var.s3_bucket
  s3_key        = var.s3_key

  environment {
    variables = merge(var.environment_variables, {
      ECS_CLUSTER_ARN     = var.ecs_cluster_arn
      TASK_DEFINITION_ARN = var.task_definition_arn
      AGENTS_CONFIG       = var.agents_config
      CONTAINER_NAME      = var.container_name
    })
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  reserved_concurrent_executions = var.reserved_concurrency

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = var.tags
}
