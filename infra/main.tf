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

# 1. -Generate a unique hex string (4 bytes = 8 characters)-
resource "random_id" "bucket_suffix" {
  byte_length = 4
}


# 2. -The Target S3 Bucket (The Trigger Source); Interpolate that stable random ID into your bucket name-
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "mimi-lambda-uploads-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# 3. -Serverless DB: file tracking table-
resource "aws_dynamodb_table" "file_tracking" {
  name = "mimi_file_tracking_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "FileID" # This is the primary partition key
  attribute {
    name = "FileID"
    type = "S" # S stands for String
  }
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
# COMPUTE & EVENT TIER (LAMBDA FN)
# =============================================================


# 1. Zip the Python code authomatically
data "archive_file" "lambda_zip" {
	type		= "zip"
	source_file	= "${path.module}/../src/lambda_function.py"
	output_path	= "${path.module}/lambda_function.zip"
}

# 2. Create the Lambda Function
resource "aws_lambda_function" "s3_processor" {
	filename	= data.archive_file.lambda_zip.output_path
	function_name	= "mimi_s3_processor"
	role		= aws_iam_role.lambda_exec_role.arn
	handler		= "lambda_function.handler" # Matches filename.function_name
	runtime		= "python3.12"		    # Standard runtime Upgrade from 3.9 to 3.12 to prevent EOL deprecation errors
        
        source_code_hash = data.archive_file.lambda_zip.output_base64sha256 # This forces an update every time the py code changes.

        environment {
          variables = {
            SNS_TOPIC_ARN = aws_sns_topic.file_alerts.arn
            DYNAMODB_TABLE = aws_dynamodb_table.file_tracking.name # New link to the DB    
         }
    }

}

# 3. Give S3 permission to invoke this specific Lambda function
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action	= "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.arn
  principal	= "s3.amazonaws.com"
  source_arn	= aws_s3_bucket.upload_bucket.arn
}

# 4. Tell the S3 Bucket to send notifications to Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket	= aws_s3_bucket.upload_bucket.id

  lambda_function {
	lambda_function_arn = aws_lambda_function.s3_processor.arn
	events		    = ["s3:ObjectCreated:*"] # Trigger on any new file
    }

    # Ensure permission exits before creating the notification
    depends_on = [aws_lambda_permission.allow_s3]
}

# =============================================================
# 4. SECURITY TIER (IAM)
# =============================================================

# 1. -The IAM Role for Lambda (Trust Policy)-
resource "aws_iam_role" "lambda_exec_role" {
  name = "serverless_lambda_role"


    # This policy telles AWS: "Allow the Lambda service to assume this role"
    assume_role_policy = jsonencode({
	Version		= "2012-10-17"
	Statement	= [{
	  Action	= "sts:AssumeRole"
	  Effect	= "Allow"
	  Principal	= {Service = "lambda.amazonaws.com"}
         }]
      })
}

# 2. -Attach the Basic Execution Policy to the Role-
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role	      = aws_iam_role.lambda_exec_role.name
    # This AWS-managed policy grants permission to write logs to CloudWatch
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# 3. -Grant Lambda explicit permissioon to publish specifically to this SNS topic-
resource "aws_iam_role_policy" "lambda_sns_policy" {
  name = "lambda_sns_publish_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
       {
        Sid    = "AllowSNSPublish"
        Action = "sns:Publish"
        Effect  = "Allow"
        Resource = aws_sns_topic.file_alerts.arn
       },
       {
        Sid    = "AllowDynamoDBWrite"
        Action = "dynamodb:PutItem"
        Effect = "Allow"
        Resource = aws_dynamodb_table.file_tracking.arn
       },
       {
        Sid    = "AllowS3Read"
        Action = "s3:GetObject"
        Effect = "Allow"
        Resource = "${aws_s3_bucket.upload_bucket.arn}/*"
       }
   ]
 })
}

