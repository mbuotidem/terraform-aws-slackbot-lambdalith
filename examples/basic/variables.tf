variable "slack_bot_token" {
  description = "The Slack bot token for authentication"
  type        = string
  sensitive   = true
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
  description = "Slack signing secret for the app"
  type        = string
}
