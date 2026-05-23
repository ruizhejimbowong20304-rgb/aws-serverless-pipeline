variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type = string
}

variable "prefix" {
  description = "Prefix for naming resources"
  type = string
}

variable "lambda_role_arn" {
  description = "The ARN of the IAM role for Lambda execution"
  type = string
}

variable "sns_topic_arn" {
  description = "The ARN of the SNS topic for alerts"
  type = string
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type =  string
}

variable "bucket_id" {
  description = "The ID of the S3 Upload bucket"
  type = string
}

variable "bucket_arn" {
  description = "The ARN of the S3 upload bucket"
  type = string
}
