variable "slack_bot_token" {
  description = "The Slack bot token for authentication"
  type        = string
  sensitive   = true
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "custom-lambda-zip-terraform-aws-slackbot-lambdalith"
}

variable "bedrock_model_id" {
  description = "The Bedrock model ID to use for AI responses"
  type        = string
  default     = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default = {
    Environment = "example"
    Project     = "slack-bot"
  }
}

variable "slack_signing_secret" {
  description = "The Slack signing secret for verification"
  type        = string
  sensitive   = true
  default     = "00000000000000000000000000000000"
}
