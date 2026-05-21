terraform {
  required_providers {
    aws = {
     source  = "hashicorp/aws"
     version = "~> 5.0" 
    }  
  }

# This connects to the NEW isolation backend you created earlier

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
}

# 1. The Target S3 Bucket (The Trigger Source)
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "mimi-lambda-uploads-1778676923"

  tags = {
    Environment = "Dev"
    Project     = "Serverless-Lab"
  }
}

# 2. The IAM Role for Lambda (Trust Policy)
resource "aws_iam_role" "lambda_exec_role" {
  name = "serverless_lambda_role"


    # This policy telles AWS: "Allow the Lambda service to assume this role"
    assume_role_policy = jsonencode({
	Version		= "2012-10-17"
	Statement	= [{
	  Action	= "sts:AssumeRole"
	  Effect	= "Allow"
	  Principal	= {
		Service = "lambda.amazonaws.com"
                }
            }]
      })
}

# 3. Attach the Basic Execution Policy to the Role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role		= aws_iam_role.lambda_exec_role.name
    # This AWS-managed policy grants permission to write logs to CloudWatch
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Integrate with Lambda_function.py code

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
	runtime		= "python3.9"		    # Standard runtime
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
