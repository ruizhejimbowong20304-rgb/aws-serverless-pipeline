variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type = string
}

variable "prefix" {
  description = "Prefix for naming resources"
  type = string
}

variable "sns_topic_arn" {
  description = "The ARN of the SNS topic for alerts"
  type = string
}

variable "dynamodb_table_arn" {
  description = "The ARN of the Dynamodb table"
  type = string
}

variable "bucket_arn" {
  description = "The ARN of the S3 upload bucket"
  type = string
}

