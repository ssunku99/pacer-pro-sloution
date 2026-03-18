provider "aws" {
  region = "us-east-1"
}

# --- EC2 Instance ---
resource "aws_instance" "web_app" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"
  tags = { Name = "web-app-server" }
}

# --- SNS Topic ---
resource "aws_sns_topic" "alerts" {
  name = "ec2-remediation-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "your-email@example.com"
}

# --- IAM Role for Lambda (least privilege) ---
resource "aws_iam_role" "lambda_role" {
  name = "lambda-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "lambda-permissions"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:RebootInstances"]
        Resource = aws_instance.web_app.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# --- Lambda Function ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../lambda_function"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "remediation" {
  function_name    = "ec2-auto-remediation"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      EC2_INSTANCE_ID = aws_instance.web_app.id
      SNS_TOPIC_ARN   = aws_sns_topic.alerts.arn
    }
  }
}

# --- Function URL (webhook endpoint for Sumo Logic) ---
resource "aws_lambda_function_url" "webhook" {
  function_name      = aws_lambda_function.remediation.function_name
  authorization_type = "NONE"
}

# --- Outputs ---
output "webhook_url" {
  value = aws_lambda_function_url.webhook.function_url
}
