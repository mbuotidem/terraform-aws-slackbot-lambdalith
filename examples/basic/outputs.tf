output "slack_webhook_url" {
  description = "URL to configure in your Slack app for event subscriptions"
  value       = module.slack_bot.slack_bot_endpoint_url
}

output "secret_manager_console_url" {
  description = "AWS console URL to manage the Slack bot token"
  value       = module.slack_bot.slack_bot_token_console_url
}

output "lambda_function_name" {
  description = "Name of the created Lambda function"
  value       = module.slack_bot.lambda_function_name
}

output "lambda_layer_info" {
  description = "Information about the Lambda layer"
  value = {
    arn     = module.slack_bot.lambda_layer_arn
    version = module.slack_bot.lambda_layer_version
  }
}
