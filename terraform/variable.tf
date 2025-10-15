variable "region" {
  default = "ap-southeast-2"
}

variable "ecr_repo_name" {
  default = "sample-app-repo"
}

variable "ddb_table_name" {
  default = "sample-app-image-log"
}

variable "sns_topic_name" {
  default = "sample-app-topic"
}

variable "lambda_name" {
  default = "ecr-postprocessor"
}

variable "notification_email" {
  default = "heeteshkamthe09@gmail.com"
}
