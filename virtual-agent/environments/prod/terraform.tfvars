aws_region  = "us-east-1"
environment = "prod"

subnet_ids = [ # TODO: your prod subnet IDs
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-yyyyyyyyyyyyyyyyy",
]
security_group_id = "sg-xxxxxxxxxxxxxxxxx" # TODO: your prod security group ID

execution_role_arn = "arn:aws:iam::484395054994:role/ecsTaskExecutionRole" # TODO: your prod execution role ARN
task_role_arn      = "arn:aws:iam::484395054994:role/ecsTaskRole"          # TODO: your prod task role ARN

container_image = "484395054994.dkr.ecr.us-east-1.amazonaws.com/connect-poc-virtual-agent:latest" # TODO: your ECR image URI

lambda_filename  = "lambda/ecs_scheduler.zip"
lambda_s3_bucket = null
lambda_s3_key    = null

schedule_enabled = true

agents = [
  {
    agent_id    = "virtual-agent-prod-001"
    agent_name  = "Prod Virtual Agent 001"
    environment = {}
  }
]
