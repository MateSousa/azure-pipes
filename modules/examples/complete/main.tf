terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  project_name = "myproject"
  tags = {
    Project     = "myproject"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  lambdas = {
    auth = {
      description = "Authentication handler"
      handler     = "index.handler"
      runtime     = "nodejs20.x"
      memory      = 256
      timeout     = 30
      environment_variables = {
        TABLE_NAME = module.sessions_table.table_name
      }
    }
    fulfillment = {
      description           = "Lex fulfillment handler"
      handler               = "index.handler"
      runtime               = "nodejs20.x"
      memory                = 256
      timeout               = 60
      environment_variables = {}
    }
    ingest = {
      description           = "Data ingestion processor"
      handler               = "handler.main"
      runtime               = "python3.12"
      memory                = 512
      timeout               = 300
      environment_variables = {}
    }
    notify = {
      description           = "Notification sender"
      handler               = "index.handler"
      runtime               = "nodejs20.x"
      memory                = 128
      timeout               = 15
      environment_variables = {}
    }
    cleanup = {
      description           = "Scheduled cleanup job"
      handler               = "handler.main"
      runtime               = "python3.12"
      memory                = 128
      timeout               = 900
      environment_variables = {}
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Roles (looked up from existing roles)
# -----------------------------------------------------------------------------

data "aws_iam_role" "lambda" {
  name = "${local.project_name}-lambda-exec"
}

data "aws_iam_role" "ecs_execution" {
  name = "${local.project_name}-ecs-execution"
}

data "aws_iam_role" "ecs_task" {
  name = "${local.project_name}-ecs-task"
}

data "aws_iam_role" "lex" {
  name = "${local.project_name}-lex-bot"
}

# -----------------------------------------------------------------------------
# Lambda (for_each over local.lambdas)
# -----------------------------------------------------------------------------

module "lambdas" {
  source   = "../../lambda"
  for_each = local.lambdas

  project_name = local.project_name

  lambda = {
    name                  = each.key
    description           = each.value.description
    handler               = each.value.handler
    runtime               = each.value.runtime
    memory                = each.value.memory
    timeout               = each.value.timeout
    environment_variables = each.value.environment_variables
  }

  iam = {
    role_arn = data.aws_iam_role.lambda.arn
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# DynamoDB
# -----------------------------------------------------------------------------

module "sessions_table" {
  source = "../../dynamodb"

  project_name = local.project_name

  table = {
    name         = "sessions"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "pk"
    range_key    = "sk"
  }

  attributes = [
    { name = "pk", type = "S" },
    { name = "sk", type = "S" },
    { name = "gsi1pk", type = "S" },
    { name = "gsi1sk", type = "S" },
  ]

  global_secondary_indexes = [
    {
      name            = "gsi1"
      hash_key        = "gsi1pk"
      range_key       = "gsi1sk"
      projection_type = "ALL"
    }
  ]

  ttl = {
    enabled        = true
    attribute_name = "ttl"
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# ALB
# -----------------------------------------------------------------------------

module "web_alb" {
  source = "../../alb"

  project_name = local.project_name

  alb = {
    name     = "web"
    internal = false
  }

  network = {
    vpc_id             = "vpc-00000000000000000"
    subnet_ids         = ["subnet-aaa", "subnet-bbb"]
    security_group_ids = ["sg-alb"]
  }

  target_group = {
    name        = "web-tg"
    port        = 8080
    protocol    = "HTTP"
    target_type = "ip"

    health_check = {
      path    = "/health"
      matcher = "200"
    }
  }

  listener = {
    port            = 443
    protocol        = "HTTPS"
    ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/example"
  }

  https_redirect = true

  tags = local.tags
}

# -----------------------------------------------------------------------------
# ECR Repositories (for_each over local.lambdas)
# -----------------------------------------------------------------------------

module "ecr_repos" {
  source   = "../../ecr"
  for_each = local.lambdas

  project_name = local.project_name

  repository = {
    name = each.key
  }

  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = local.tags
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------

module "cluster" {
  source = "../../ecs"

  project_name = local.project_name

  cluster = {
    name               = "main"
    container_insights = "enabled"
    capacity_providers = ["FARGATE", "FARGATE_SPOT"]
    default_capacity_provider_strategy = [
      {
        capacity_provider = "FARGATE"
        weight            = 1
        base              = 1
      }
    ]
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# ECS Task Definition (web service)
# -----------------------------------------------------------------------------

module "web_task" {
  source = "../../task-definition"

  project_name = local.project_name

  task = {
    family          = "web"
    cpu             = "512"
    memory          = "1024"
    container_name  = "web"
    container_image = "${module.ecr_repos["auth"].repository_url}:latest"
    container_port  = 8080
    environment_variables = {
      TABLE_NAME = module.sessions_table.table_name
    }
  }

  iam = {
    execution_role_arn = data.aws_iam_role.ecs_execution.arn
    task_role_arn      = data.aws_iam_role.ecs_task.arn
  }

  logging = {
    region = "us-east-1"
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# ECS Task Definition (batch task — no port)
# -----------------------------------------------------------------------------

module "batch_task" {
  source = "../../task-definition"

  project_name = local.project_name

  task = {
    family          = "batch"
    cpu             = "256"
    memory          = "512"
    container_name  = "batch"
    container_image = "${module.ecr_repos["cleanup"].repository_url}:latest"
    command         = ["node", "worker.js"]
    environment_variables = {
      TABLE_NAME = module.sessions_table.table_name
    }
  }

  iam = {
    execution_role_arn = data.aws_iam_role.ecs_execution.arn
    task_role_arn      = data.aws_iam_role.ecs_task.arn
  }

  logging = {
    region = "us-east-1"
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# ECS Service (web — wires cluster + task definition + ALB)
# -----------------------------------------------------------------------------

module "web_service" {
  source = "../../service"

  project_name = local.project_name

  service = {
    name                              = "web"
    desired_count                     = 2
    health_check_grace_period_seconds = 60
    enable_execute_command            = true
  }

  ecs = {
    cluster_id          = module.cluster.cluster_id
    task_definition_arn = module.web_task.task_definition_arn
    container_name      = module.web_task.container_name
    container_port      = module.web_task.container_port
  }

  network = {
    subnet_ids         = ["subnet-aaa", "subnet-bbb"]
    security_group_ids = ["sg-ecs"]
  }

  load_balancer = {
    target_group_arn = module.web_alb.target_group_arn
  }

  deployment = {
    deployment_circuit_breaker = {
      enable   = true
      rollback = true
    }
  }

  autoscaling = {
    min_capacity     = 1
    max_capacity     = 4
    cpu_target_value = 70
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Connect
# -----------------------------------------------------------------------------

module "connect" {
  source = "../../connect"

  project_name = local.project_name

  instance = {
    create                   = true
    instance_alias           = "myproject-contact-center"
    identity_management_type = "CONNECT_MANAGED"
  }

  hours_of_operation = [
    {
      name      = "business-hours"
      time_zone = "America/New_York"
      config = [
        {
          day        = "MONDAY"
          start_time = { hours = 9, minutes = 0 }
          end_time   = { hours = 17, minutes = 0 }
        },
        {
          day        = "TUESDAY"
          start_time = { hours = 9, minutes = 0 }
          end_time   = { hours = 17, minutes = 0 }
        },
        {
          day        = "WEDNESDAY"
          start_time = { hours = 9, minutes = 0 }
          end_time   = { hours = 17, minutes = 0 }
        },
        {
          day        = "THURSDAY"
          start_time = { hours = 9, minutes = 0 }
          end_time   = { hours = 17, minutes = 0 }
        },
        {
          day        = "FRIDAY"
          start_time = { hours = 9, minutes = 0 }
          end_time   = { hours = 17, minutes = 0 }
        },
      ]
    }
  ]

  queues = [
    {
      name                    = "main-queue"
      description             = "Primary support queue"
      hours_of_operation_name = "business-hours"
    }
  ]

  contact_flows = [
    {
      name = "main-flow"
      type = "CONTACT_FLOW"
      content = jsonencode({
        Version     = "2019-10-30"
        StartAction = "greeting"
        Actions = [
          {
            Identifier = "greeting"
            Type       = "MessageParticipant"
            Parameters = { Text = "Welcome to support." }
            Transitions = {
              NextAction = "disconnect"
              Errors     = []
              Conditions = []
            }
          },
          {
            Identifier  = "disconnect"
            Type        = "DisconnectParticipant"
            Parameters  = {}
            Transitions = {}
          }
        ]
      })
    }
  ]

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Lex Bot
# -----------------------------------------------------------------------------

module "lex_bot" {
  source = "../../lex"

  project_name = local.project_name

  bot = {
    name        = "support-bot"
    description = "Customer support bot"
    role_arn    = data.aws_iam_role.lex.arn
  }

  locales = [
    {
      locale_id   = "en_US"
      description = "English (US)"
      voice_settings = {
        voice_id = "Joanna"
      }
    }
  ]

  intents = {
    en_US = [
      {
        name        = "Greeting"
        description = "Handles greetings"
        sample_utterances = [
          { utterance = "Hello" },
          { utterance = "Hi" },
          { utterance = "Hey there" },
        ]
        fulfillment_code_hook = {
          enabled = true
        }
      },
      {
        name        = "Help"
        description = "Handles help requests"
        sample_utterances = [
          { utterance = "I need help" },
          { utterance = "Can you help me" },
        ]
        fulfillment_code_hook = {
          enabled = true
        }
      }
    ]
  }

  bot_version = {
    create      = true
    description = "Initial version"
  }

  tags = local.tags
}
