# Package the Python code
data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "${path.module}/../../src/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip" 
}

# The Lambda Function
resource "aws_lambda_function" "s3_processor" {
  filename = data.archive_file.lambda_zip.output_path
  function_name = "${var.prefix}_${var.environment}_s3_processor"
  role = var.lambda_role_arn
  handler = "lambda_function.handler"
  runtime = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }
}

# Allow S3 to trigger the Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id = "AllowExecutionFromS3Bucket"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.arn
  principal = "s3.amazonaws.com"
  source_arn = var.bucket_arn
}

# The actual trigger connecting S3 to Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}
