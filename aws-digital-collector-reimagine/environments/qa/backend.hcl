bucket         = "my-terraform-state-qa"     # TODO: your S3 bucket for qa state
key            = "outbound-calling-app/qa/terraform.tfstate"
region         = "us-east-1"                  # TODO: your AWS region
dynamodb_table = "terraform-locks-qa"         # TODO: your DynamoDB table for state locking
encrypt        = true
