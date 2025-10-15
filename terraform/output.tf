output "ECR_Repository_URI" {
  value = aws_ecr_repository.sample_repo.repository_url
}

output "Lambda_Name" {
  value = aws_lambda_function.ecr_postprocessor.function_name
}

output "SNS_Topic_ARN" {
  value = aws_sns_topic.image_push_topic.arn
}
