provider "aws" {
  region = var.region
}

# -----------------------------
# 1️ ECR Repository
# -----------------------------
resource "aws_ecr_repository" "sample_repo" {
  name = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}

# -----------------------------
# 2️ DynamoDB Table
# -----------------------------
resource "aws_dynamodb_table" "image_log" {
  name         = var.ddb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "imageTag"

  attribute {
    name = "imageTag"
    type = "S"
  }
}

# -----------------------------
# 3️ SNS Topic
# -----------------------------
resource "aws_sns_topic" "image_push_topic" {
  name = var.sns_topic_name
}

# Optional email subscription
resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.image_push_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# -----------------------------
# 4️ Lambda Function
# -----------------------------
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_ecr_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ddb_sns_policy" {
  name = "lambda-ddb-sns-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "sns:Publish"
        ]
        Resource = [
          aws_dynamodb_table.image_log.arn,
          aws_sns_topic.image_push_topic.arn
        ]
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ecr_postprocessor.py"
  output_path = "${path.module}/lambda/ecr_postprocessor.zip"
}

resource "aws_lambda_function" "ecr_postprocessor" {
  function_name = var.lambda_name
  depends_on = [data.archive_file.lambda_zip]
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.10"
  handler       = "ecr_postprocessor.lambda_handler"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 10

  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.image_log.name
      SNS_ARN   = aws_sns_topic.image_push_topic.arn
    }
  }
}

# -----------------------------
# 5️ EventBridge Rule + Target
# -----------------------------
resource "aws_cloudwatch_event_rule" "jenkins_push_rule" {
  name        = "JenkinsECRPushRule"
  description = "Triggers Lambda on Jenkins ECR Image Push"
  event_pattern = jsonencode({
    "source"      : ["custom.jenkins"],
    "detail-type" : ["ECR Image Push"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.jenkins_push_rule.name
  target_id = "LambdaTrigger"
  arn       = aws_lambda_function.ecr_postprocessor.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecr_postprocessor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.jenkins_push_rule.arn
}

