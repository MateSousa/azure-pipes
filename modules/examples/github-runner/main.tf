locals {
  project_name = var.project_name

  tags = {
    Project     = var.project_name
    Environment = "dev"
    Application = "github-runner"
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Secrets Manager — GitHub App credentials & webhook secret
#
# Secrets are created empty and the values are populated out-of-band so they
# never enter Terraform state. After `terraform apply`, run:
#
#   aws secretsmanager put-secret-value --secret-id <arn> --secret-string <val>
#
# for each of the four secrets below.
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "app_id" {
  name        = "${local.project_name}/github-runner/app-id"
  description = "GitHub App ID"
  tags        = local.tags
}

resource "aws_secretsmanager_secret" "app_private_key" {
  name        = "${local.project_name}/github-runner/app-private-key"
  description = "GitHub App private key (PEM)"
  tags        = local.tags
}

resource "aws_secretsmanager_secret" "webhook_secret" {
  name        = "${local.project_name}/github-runner/webhook-secret"
  description = "GitHub webhook signing secret"
  tags        = local.tags
}

resource "aws_secretsmanager_secret" "org" {
  name        = "${local.project_name}/github-runner/org"
  description = "GitHub organization slug"
  tags        = local.tags
}

# -----------------------------------------------------------------------------
# Security group for runner tasks — egress only.
# -----------------------------------------------------------------------------

module "runner_sg" {
  source = "../../sg"

  project_name = local.project_name

  security_group = {
    name        = "github-runner"
    description = "Ephemeral GitHub Actions runner tasks (egress only)"
    vpc_id      = var.vpc_id
  }

  egress_rules = [
    {
      description = "HTTPS to GitHub, ECR, Secrets Manager, Logs"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
  ]

  tags = local.tags
}

# -----------------------------------------------------------------------------
# IAM — runner task execution role (pulls image, writes logs, reads no secrets)
# -----------------------------------------------------------------------------

module "runner_execution_role" {
  source = "../../iam"

  project_name = local.project_name

  role = {
    name = "github-runner-exec"
    assume_role_principals = [{
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }]
  }

  policies = {
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    ]
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# IAM — runner task role (what GitHub workflows execute with)
#
# Start empty. Attach managed/inline policies as workflows need them.
# -----------------------------------------------------------------------------

module "runner_task_role" {
  source = "../../iam"

  project_name = local.project_name

  role = {
    name = "github-runner-task"
    assume_role_principals = [{
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }]
  }

  policies = {}

  tags = local.tags
}

# -----------------------------------------------------------------------------
# IAM — dispatcher Lambda role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "dispatcher_inline" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.project_name}-github-runner-dispatcher:*"]
  }

  statement {
    sid     = "ReadGitHubSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.app_id.arn,
      aws_secretsmanager_secret.app_private_key.arn,
      aws_secretsmanager_secret.webhook_secret.arn,
      aws_secretsmanager_secret.org.arn,
    ]
  }

  statement {
    sid       = "RunRunnerTask"
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = ["arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/${local.project_name}-github-runner:*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.ecs_cluster_arn]
    }
  }

  statement {
    sid     = "PassRunnerRoles"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      module.runner_execution_role.role_arn,
      module.runner_task_role.role_arn,
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

module "dispatcher_role" {
  source = "../../iam"

  project_name = local.project_name

  role = {
    name = "github-runner-dispatcher"
    assume_role_principals = [{
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }]
  }

  policies = {
    inline_policies = [
      {
        name   = "dispatcher"
        policy = data.aws_iam_policy_document.dispatcher_inline.json
      },
    ]
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# GitHub runner — dispatcher + runner task definition + webhook API
# -----------------------------------------------------------------------------

module "github_runner" {
  source = "../../github-runner"

  project_name = local.project_name

  dispatcher = {
    image_uri = var.dispatcher_image_uri
    role_arn  = module.dispatcher_role.role_arn
  }

  runner = {
    container_image    = var.runner_image_uri
    execution_role_arn = module.runner_execution_role.role_arn
    task_role_arn      = module.runner_task_role.role_arn
    runner_label       = "fargate"
  }

  ecs = {
    cluster_arn = var.ecs_cluster_arn
  }

  network = {
    subnet_ids         = var.subnet_ids
    security_group_ids = [module.runner_sg.security_group_id]
  }

  secrets = {
    app_id_arn          = aws_secretsmanager_secret.app_id.arn
    app_private_key_arn = aws_secretsmanager_secret.app_private_key.arn
    webhook_secret_arn  = aws_secretsmanager_secret.webhook_secret.arn
    org_arn             = aws_secretsmanager_secret.org.arn
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "webhook_url" {
  description = "Paste this into the GitHub App's Webhook URL field."
  value       = module.github_runner.webhook_url
}

output "dispatcher_function_name" {
  value = module.github_runner.dispatcher_function_name
}

output "secret_arns" {
  description = "ARNs of the four secrets to populate via `aws secretsmanager put-secret-value`."
  value = {
    app_id          = aws_secretsmanager_secret.app_id.arn
    app_private_key = aws_secretsmanager_secret.app_private_key.arn
    webhook_secret  = aws_secretsmanager_secret.webhook_secret.arn
    org             = aws_secretsmanager_secret.org.arn
  }
}
