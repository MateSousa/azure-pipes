aws_region  = "us-east-1"
environment = "qa"

subnet_ids = [ # TODO: your qa subnet IDs
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-yyyyyyyyyyyyyyyyy",
]
security_group_id = "sg-xxxxxxxxxxxxxxxxx" # TODO: your qa security group ID

execution_role_arn = "arn:aws:iam::484395054994:role/ecsTaskExecutionRole" # TODO: your qa execution role ARN
task_role_arn      = "arn:aws:iam::484395054994:role/ecsTaskRole"          # TODO: your qa task role ARN

container_image = "484395054994.dkr.ecr.us-east-1.amazonaws.com/connect-poc-virtual-agent:latest" # TODO: your ECR image URI

lambda_filename  = "lambda/ecs_scheduler.zip"
lambda_s3_bucket = null
lambda_s3_key    = null

schedule_enabled = true

agents = [
  {
    agent_id    = "virtual-agent-qa-001"
    agent_name  = "QA Virtual Agent 001"
    environment = {}
  }
]
