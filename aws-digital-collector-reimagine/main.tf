locals {
  name_prefix = "outbound-call-${var.environment}"

  tags = {
    Environment = var.environment
    Application = "outbound-calling-app"
    ManagedBy   = "terraform"
  }
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  log_group_name    = "/ecs/${local.name_prefix}"
  retention_in_days = 30
  tags              = local.tags
}

module "alb" {
  source = "./modules/alb"

  name               = local.name_prefix
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = [var.security_group_id]
  container_port     = 3000
  health_check_path  = "/health"
  internal           = true
  tags               = local.tags
}

module "ecs" {
  source = "./modules/ecs"

  cluster_name       = local.name_prefix
  task_family        = local.name_prefix
  cpu                = 256
  memory             = 512
  container_name     = "outbound-calling-app"
  container_image    = var.container_image
  container_port     = 3000
  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn
  subnet_ids         = var.subnet_ids
  security_group_ids = [var.security_group_id]
  target_group_arn   = module.alb.target_group_arn
  desired_count      = 1
  log_group_name     = module.cloudwatch.log_group_name
  aws_region         = var.aws_region
  tags               = local.tags

  environment_variables = {
    CONNECT_INSTANCE_ID = var.connect_instance_id
    CONTACT_FLOW_ID     = var.contact_flow_id
    SOURCE_PHONE_NUMBER = var.source_phone_number
    S3_BUCKET           = var.s3_bucket
    S3_KEY              = var.s3_key
    AWS_REGION          = var.aws_region
    NODE_ENV            = var.environment == "prod" ? "production" : "development"
  }
}
