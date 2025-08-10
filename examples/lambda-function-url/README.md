# Lambda Function URL

This example demonstrates how to deploy the Slack bot using an AWS Lambda Function URL instead of API Gateway.

## Usage

```hcl
module "slack_bot" {
  source = "../.."

  slack_bot_token      = var.slack_bot_token
  bedrock_model_id     = var.bedrock_model_id
  slack_signing_secret = var.slack_signing_secret
  tags                 = var.tags

  use_function_url     = true
  function_url         = var.function_url # Optional: override the generated function URL
}
```

- Set `use_function_url = true` to enable Lambda Function URL mode.
- Optionally set `function_url` to override the generated URL in the Slack manifest.

## Variables
See `variables.tf` for all configurable options.

## Outputs
See `outputs.tf` for available outputs.

## Deploy

1. Set your Slack credentials in `terraform.tfvars` or via environment variables.
2. Run `terraform init && terraform apply`.
3. Use the output `slack_bot_endpoint_url` as the request URL in your Slack app manifest.

<!-- BEGIN_TF_DOCS -->


## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |

## Providers

No providers.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bedrock_model_id"></a> [bedrock\_model\_id](#input\_bedrock\_model\_id) | The Bedrock model ID to use for AI responses | `string` | `"anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_function_url"></a> [function\_url](#input\_function\_url) | The Lambda Function URL to use in the Slack manifest if use\_function\_url is true. | `string` | `""` | no |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Name of the Lambda function | `string` | `"lambda-function-url-terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | The Slack bot token for authentication | `string` | n/a | yes |
| <a name="input_slack_signing_secret"></a> [slack\_signing\_secret](#input\_slack\_signing\_secret) | The Slack signing secret for verification | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | The ARN of the Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | The name of the Lambda function |
| <a name="output_slack_bot_endpoint_url"></a> [slack\_bot\_endpoint\_url](#output\_slack\_bot\_endpoint\_url) | The URL used to verify the Slack app (API Gateway or Lambda Function URL) |

## Resources

No resources.
<!-- END_TF_DOCS -->