aws_region  = "us-east-1"
environment = "dev"

subnet_ids = [ # TODO: your dev subnet IDs
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-yyyyyyyyyyyyyyyyy",
]
security_group_id = "sg-xxxxxxxxxxxxxxxxx" # TODO: your dev security group ID

execution_role_arn = "arn:aws:iam::484395054994:role/ecsTaskExecutionRole" # TODO: your dev execution role ARN
task_role_arn      = "arn:aws:iam::484395054994:role/ecsTaskRole"          # TODO: your dev task role ARN

container_image = "484395054994.dkr.ecr.us-east-1.amazonaws.com/connect-poc-virtual-agent:latest" # TODO: your ECR image URI

lambda_filename  = "lambda/ecs_scheduler.zip" # TODO: path to Lambda zip, or use lambda_s3_bucket/lambda_s3_key
lambda_s3_bucket = null
lambda_s3_key    = null

schedule_enabled = true

agents = [
  {
    agent_id    = "virtual-agent-dev-001"
    agent_name  = "Dev Virtual Agent 001"
    environment = {}
  }
]
