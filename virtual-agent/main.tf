locals {
  name_prefix = "connect-poc-${var.environment}"

  tags = {
    Environment = var.environment
    Application = "virtual-agent"
    ManagedBy   = "terraform"
  }
}

# ---------- CloudWatch Log Group for ECS Tasks ----------
module "ecs_logs" {
  source = "../aws-digital-collector-reimagine/modules/cloudwatch"

  log_group_name    = "/ecs/${local.name_prefix}-virtual-agent"
  retention_in_days = 30
  tags              = local.tags
}

# ---------- ECS Cluster + Task Definition ----------
module "ecs" {
  source = "./modules/ecs"

  cluster_name       = "connect-poc-cluster"
  task_family        = "ConnectPoc-TaskDef"
  container_name     = "virtual-agent"
  container_image    = var.container_image
  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn
  log_group_name     = module.ecs_logs.log_group_name
  aws_region         = var.aws_region
  cpu                = 256
  memory             = 512
  tags               = local.tags

  environment_variables = {
    AWS_DEFAULT_REGION = var.aws_region
  }
}

# ---------- Lambda Function (ECS Scheduler) ----------
module "lambda" {
  source = "./modules/lambda"

  function_name        = "ConnectPoc-EcsScheduler"
  runtime              = "python3.12"
  handler              = "index.handler"
  timeout              = 60
  memory_size          = 128
  filename             = var.lambda_filename
  s3_bucket            = var.lambda_s3_bucket
  s3_key               = var.lambda_s3_key
  ecs_cluster_arn      = module.ecs.cluster_arn
  task_definition_arn  = module.ecs.task_definition_arn
  execution_role_arn   = var.execution_role_arn
  task_role_arn        = var.task_role_arn
  agents_config        = jsonencode(var.agents)
  container_name       = module.ecs.container_name
  subnet_ids           = var.subnet_ids
  security_group_ids   = [var.security_group_id]
  log_retention_days   = 30
  reserved_concurrency = 1
  tags                 = local.tags

  environment_variables = {
    SUBNET_IDS         = join(",", var.subnet_ids)
    SECURITY_GROUP_IDS = var.security_group_id
  }
}

# ---------- EventBridge Schedule (Weekdays at 7 AM EST) ----------
module "eventbridge" {
  source = "./modules/eventbridge"

  rule_name            = "ConnectPoc-DailySchedule"
  description          = "Triggers virtual agent ECS scheduler Lambda every weekday at 7 AM EST"
  schedule_expression  = "cron(0 12 ? * MON-FRI *)" # 12 UTC = 7 AM EST
  lambda_function_arn  = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
  enabled              = var.schedule_enabled
  tags                 = local.tags
}
