terraform {
  required_version = ">= 1.11.0"
}

module "slack_bot" {
  source = "../.."

  slack_bot_token      = var.slack_bot_token
  bedrock_model_id     = var.bedrock_model_id
  slack_signing_secret = var.slack_signing_secret
  tags                 = var.tags
  lambda_function_name = var.lambda_function_name
  # Enable Lambda Function URL instead of API Gateway
  use_function_url = true
  function_url     = var.function_url # Optional: override the generated function URL
}
