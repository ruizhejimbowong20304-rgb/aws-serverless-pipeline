# Generate the random suffix
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# The S3 bucket
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "${var.prefix}-${var.environment}-uploads-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# The DynamoDB Table
resource "aws_dynamodb_table" "file_tracking" {
  name = "${var.prefix}_${var.environment}_file_tracking_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "FileID"

  attribute {
    name = "FileID"
    type = "S"
  }
}
