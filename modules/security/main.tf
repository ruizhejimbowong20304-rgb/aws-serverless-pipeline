# The Base Role
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.prefix}_${var.environment}_lambda_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com"}
    }]
  })
}

# The AWS Basic Execution Policy (for CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# The Custom Least Privilege Policy
resource "aws_iam_role_policy" "lambda_app_policy" {
  name = "${var.prefix}_${var.environment}_least_privilege_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "AllowSNSPublish"
      Action = "sns:Publish"
      Effect = "Allow"
      Resource = var.sns_topic_arn
    },
    {
      Sid = "AllowDynamoDBWrite"
      Action = "dynamodb:PutItem"
      Effect = "Allow"
      Resource = var.dynamodb_table_arn
    },
    {
      Sid = "AllowS3Read"
      Action = "s3:GetObject"
      Effect = "Allow"
      Resource = "${var.bucket_arn}/*"
    }]
  })
}
