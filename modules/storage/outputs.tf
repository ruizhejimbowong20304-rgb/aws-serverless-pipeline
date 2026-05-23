output "bucket_id" {
  description = "The ID (name) of the S3 bucket"
  value = aws_s3_bucket.upload_bucket.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value =  aws_s3_bucket.upload_bucket.arn
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  value = aws_dynamodb_table.file_tracking.name
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table"
  value = aws_dynamodb_table.file_tracking.arn
}
