bucket         = "my-terraform-state-dev"    # TODO: your S3 bucket for dev state
key            = "outbound-calling-app/dev/terraform.tfstate"
region         = "us-east-1"                 # TODO: your AWS region
dynamodb_table = "terraform-locks-dev"       # TODO: your DynamoDB table for state locking
encrypt        = true
