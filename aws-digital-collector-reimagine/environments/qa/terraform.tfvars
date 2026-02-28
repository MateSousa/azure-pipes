aws_region  = "us-east-1"
environment = "qa"

vpc_id = "vpc-xxxxxxxxxxxxxxxxx" # TODO: your qa VPC ID
subnet_ids = [                   # TODO: your qa subnet IDs
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-yyyyyyyyyyyyyyyyy",
]
security_group_id = "sg-xxxxxxxxxxxxxxxxx" # TODO: your qa security group ID

execution_role_arn = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole" # TODO: your qa execution role ARN
task_role_arn      = "arn:aws:iam::123456789012:role/ecsTaskRole"          # TODO: your qa task role ARN

container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/outbound-calling-app:latest" # TODO: your qa ECR image URI

s3_bucket           = "my-bucket-qa"                         # TODO: your qa S3 bucket
s3_key              = "data/calls.csv"                       # TODO: your S3 key
connect_instance_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # TODO: your Connect instance ID
contact_flow_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # TODO: your Contact Flow ID
source_phone_number = "+1234567890"                          # TODO: your source phone number
