terraform {
  required_version = ">= 1.11.0"
}

module "slack_bot" {
  source = "../.."

  # Include the module's default deps AND add one extra to demonstrate overrides
  requirements_inline = [
    "boto3==1.39.4",
    "urllib3==2.0.7",
    "slack-bolt>=1.21,<2",
    "slack-sdk>=3.33.1,<4",
    "openai>=1.95.1",
    "backoff==2.2.1",
  ]

  slack_bot_token      = var.slack_bot_token
  bedrock_model_id     = var.bedrock_model_id
  slack_signing_secret = var.slack_signing_secret
  tags                 = var.tags

  lambda_function_name = var.lambda_function_name
}
