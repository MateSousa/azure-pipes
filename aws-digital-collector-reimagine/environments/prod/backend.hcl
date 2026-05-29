bucket         = "my-terraform-state-prod"   # TODO: your S3 bucket for prod state
key            = "outbound-calling-app/prod/terraform.tfstate"
region         = "us-east-1"                  # TODO: your AWS region
dynamodb_table = "terraform-locks-prod"       # TODO: your DynamoDB table for state locking
encrypt        = true
