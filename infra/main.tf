terraform {
  required_providers {
    aws = {
     source  = "hashicorp/aws"
     version = "~> 5.0" 
    }  
  }

# ---This connects to the NEW isolation backend you created earlier---

    backend "s3" {
	bucket		= "mimi-terraform-state-1778340781"
	key		= "serverless/terraform.tfstate"
	region		= "eu-central-1"
	dynamodb_table  = "mimi-serverless-locks"
	encrypt		= true
	profile		= "admin-test"
  }  
}

provider "aws" {
  region  = "eu-central-1"
  profile = "admin-test"


# -Enterprise Tagging: Applies these tags to every resource below it automatically-
  default_tags{
    tags = {
      Environment = "Dev"
      Project     = "Serverless-lab"
      Owner       = "Mimi"
      ManagedBy   = "Terraform"
     } 
   }
}

# ==============================================================
# 1. DATA & STORAGE TIER
# ==============================================================

module "storage" {
  source = "../modules/storage"
  environment = "dev"
  prefix = "mimi"
}

# Use moved blocks to COOP during transit into code modularity 
# to prevent terraform from destroying existing DB and bucket
 
moved {
  from = random_id.bucket_suffix
  to = module.storage.random_id.bucket_suffix
}

moved {
  from = aws_s3_bucket.upload_bucket
  to = module.storage.aws_s3_bucket.upload_bucket
}

moved {
  from = aws_dynamodb_table.file_tracking
  to = module.storage.aws_dynamodb_table.file_tracking
}

# =============================================================
# MESSAGING TIER
# =============================================================

resource "aws_sns_topic" "file_alerts" {
  name = "mimi_file_upload_alerts"
}

resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.file_alerts.arn
  protocol = "email"
  endpoint = "ruizhejimbowong20304@gmail.com" # Put target email address here.
}



# =============================================================
# 3. COMPUTE & EVENT TIER (LAMBDA FN)
# =============================================================

module "compute" {
  source = "../modules/compute"
  environment = "dev"
  prefix = "mimi"

  lambda_role_arn = module.security.lambda_role_arn

  # These are still sitting in your root main.tf for now
  sns_topic_arn = aws_sns_topic.file_alerts.arn

  # Pulling from the storage module outputs!
  dynamodb_table_name = module.storage.dynamodb_table_name
  bucket_id = module.storage.bucket_id
  bucket_arn = module.storage.bucket_arn
}

moved {
  from = aws_lambda_function.s3_processor
  to = module.compute.aws_lambda_function.s3_processor
}

moved {
  from = aws_lambda_permission.allow_s3
  to = module.compute.aws_lambda_permission.allow_s3
}

moved {
  from = aws_s3_bucket_notification.bucket_notification
  to = module.compute.aws_s3_bucket_notification.bucket_notification
}

# =============================================================
# 4. SECURITY TIER (IAM)
# =============================================================

module "security" {
  source = "../modules/security"
  environment = "dev"
  prefix = "mimi"

# Pulling the SNS topic (still in root for now)
  sns_topic_arn = aws_sns_topic.file_alerts.arn


# Pulling from the Storage Module Outputs
  dynamodb_table_arn = module.storage.dynamodb_table_arn
  bucket_arn = module.storage.bucket_arn
}

moved {
  from = aws_iam_role.lambda_exec_role
  to = module.security.aws_iam_role.lambda_exec_role
}

moved {
  from = aws_iam_role_policy_attachment.lambda_policy
  to = module.security.aws_iam_role_policy_attachment.lambda_policy
}

moved {
  from = aws_iam_role_policy.lambda_app_policy
  to = module.security.aws_iam_role_policy.lambda_app_policy
}
