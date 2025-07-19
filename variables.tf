# TODO: Make bot policy dynamic based on passed in vars
variable "slack_signing_secret" {
  description = "The Slack signing secret for verification"
  type        = string
  sensitive   = true
  default     = "asigningsecret"
}

variable "slack_bot_token" {
  description = "The Slack bot token for authentication"
  type        = string
  sensitive   = true
  default     = "xoxb-"

  validation {
    condition     = can(regex("^xoxb-", var.slack_bot_token))
    error_message = "Slack bot token must start with 'xoxb-'."
  }
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "terraform-aws-slackbot-lambdalith"
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 731
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "bedrock_model_id" {
  description = "The Bedrock model ID to use for AI responses"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

# Obtain from https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html
variable "bedrock_model_inference_profile" {
  description = "Inference profile ID to use"
  type        = string
  default     = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "lambda_layer_name" {
  description = "Name of the Lambda layer"
  type        = string
  default     = "terraform-aws-slackbot-lambdalith"
}

variable "python_version" {
  description = "Python version for the Lambda layer"
  type        = string
  default     = "3.12"

  validation {
    condition     = contains(["3.8", "3.9", "3.10", "3.11", "3.12"], var.python_version)
    error_message = "Python version must be one of: 3.8, 3.9, 3.10, 3.11, 3.12."
  }
}

variable "lambda_source_path" {
  description = "Path to custom Lambda function source code (zip file or directory)"
  type        = string
  default     = ""
}

variable "lambda_source_type" {
  description = "Type of Lambda source: 'default', 'zip', or 'directory'"
  type        = string
  default     = "default"
  validation {
    condition     = contains(["default", "zip", "directory"], var.lambda_source_type)
    error_message = "lambda_source_type must be 'default', 'zip', or 'directory'."
  }
  validation {
    condition     = var.lambda_source_type == "default" || var.lambda_source_path != ""
    error_message = "lambda_source_path must be provided when lambda_source_type is 'zip' or 'directory'."
  }
}

variable "slack_app_name" {
  description = "Name of the Slack app in the manifest"
  type        = string
  default     = "Bolt Python Assistant"
}

variable "slack_app_description" {
  description = "Description of the Slack app assistant"
  type        = string
  default     = "Hi, I am an assistant built using Bolt for Python. I am here to help you out!"
}

variable "slack_slash_command" {
  description = "Slash command for the Slack app"
  type        = string
  default     = "/start-process"
}

variable "slack_slash_command_description" {
  description = "The description for the slash command"
  type        = string
  default     = "Ask a question to the Bedrock bot"
}
