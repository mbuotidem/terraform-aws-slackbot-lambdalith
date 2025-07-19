# AWS Slack Bot with Bedrock Integration

A Terraform module for deploying a Python based [AI assistant or agent](https://docs.slack.dev/ai/developing-ai-apps) Slack App on AWS Lambda.

## Use Case
I built this mainly to explore building simple GenAI apps in Slack using Amazon Bedrock. It is inspired by the [Deploy a Slack gateway for Amazon Bedrock](https://aws.amazon.com/blogs/machine-learning/deploy-a-slack-gateway-for-amazon-bedrock/) blogpost by AWS.

![alt text](architecture.png)

This module is for you if you want to crank out a quick protoype and/or want to have all your code in a monolithic lambda. It uses the [lazy listener pattern](https://tools.slack.dev/bolt-python/concepts/lazy-listeners/) to allow you perform long running processes while still meeting Slacks 3 second reply requirement.  If you want a microservice based approach, I highly recommend [@amancevice's](https://github.com/amancevice) excellent [module](https://github.com/amancevice/terraform-aws-slackbot).

## Prerequisites
Docker

## Setup

```hcl
module "slack_bot" {
  source = "mbuotidem/slackbot-lambdalith/aws"

  # slack_bot_token      = "xoxb-your-bot-token"
  # slack_signing_secret = "your-signing-secret"

  # Optional: Customize your Slack app manifest
  slack_app_name                   = "My Custom Bot"
  slack_app_description            = "A custom bot built with Terraform and AWS Lambda"
  slack_slash_command              = "/slash-command"
  slack_slash_command_description  = "Executes my custom command"

  tags = {
    Environment = "production"
    Project     = "slack-bot"
  }
}
```

1. **Deploy the Terraform module**
   Run `terraform apply`. This will use dummy default values for `slack_bot_token` and `slack_signing_secret` to create your Slack Lambda and generate a Slack app manifest at `slack_app_manifest.json`.

2. **Create your Slack app using the manifest**
   - Go to [Slack API: Your Apps](https://api.slack.com/apps)
   - Click **Create New App** → **From an app manifest**
   - Select your workspace and click **Next**
   - Copy the contents of `slack_app_manifest.json` and paste into the manifest field
   - Click **Next**, review, and then **Create**

3. **Install the app in your Slack workspace**
   - Click **Install to Workspace** and authorize the app

4. **Retrieve Slack credentials**
   - Get the **Bot User OAuth Token** (starts with `xoxb-`) from the **OAuth & Permissions** page
   - Get the **Signing Secret** from the **Basic Information** page

5. **Update your Terraform configuration**
   - Uncomment and set `slack_bot_token` and `slack_signing_secret` in your module block

6. **Apply the changes**
   - Rerun `terraform apply` to update your deployment with the real credentials

---

**Tip:**
You can also find the generated manifest stored as an SSM Parameter Store parameter.

---



## Architecture

The module creates the following AWS resources:

- AWS Lambda function for processing Slack events (with configurable source code)
- Lambda layer for Python dependencies
- API Gateway HTTP API for webhook endpoint
- Secrets Manager secrets for Slack bot token and signing secret
- CloudWatch log groups for logging
- IAM roles and policies
- Parameter Store for generated Slack App manifest

It ships with sample lambda function code so you can verify functionality. However, you will ultimately want to wire up your own lambda using either the zip or directory custom sources described [below](#custom-lambda-source-code)

## Custom Lambda Source Code

The module supports three methods for providing Lambda function source code:

### Default (Template-based)
The default mode uses a template-based approach where the Lambda code is generated from `lambda/index.py` with configurable parameters:

```hcl
module "slack_bot" {
  source = "./path/to/terraform-aws-slackbot-lambdalith"

  # Uses default template with these parameters injected
  bedrock_model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"

  # other variables...
}
```

### Custom Directory
Provide a directory containing your custom Lambda source code:

```hcl
module "slack_bot" {
  source = "./path/to/terraform-aws-slackbot-lambdalith"

  lambda_source_type = "directory"
  lambda_source_path = "/path/to/your/lambda/code"

  # other variables...
}
```

### Custom ZIP File
Provide a pre-built ZIP file containing your Lambda function:

```hcl
module "slack_bot" {
  source = "./path/to/terraform-aws-slackbot-lambdalith"

  lambda_source_type = "zip"
  lambda_source_path = "/path/to/your/lambda_function.zip"

  # other variables...
}
```

## Lambda Layer for Dependencies

The module supports automatic creation of Lambda layers from a `requirements.txt` file. This works for both default mode (using the built-in `lambda/requirements.txt`) and directory mode (using a `requirements.txt` file in your custom directory). It does not apply to zip mode since the dependencies should be included in your pre-built ZIP file.

### How it works:

1. **Requirements file**: Place your Python dependencies in `requirements.txt` in the same directory as your Lambda code
2. **Automatic building**: The module builds the layer using Docker for correct x86_64 architecture
3. **Layer attachment**: The layer is automatically attached to the Lambda function


### Example requirements.txt:

```txt
boto3==1.34.131
urllib3==2.0.7
requests==2.31.0
slack-bolt>=1.21,<2
slack-sdk>=3.33.1,<4
```

## Troubleshooting

### Common Issues

1. **"Invalid signature" or "dispatch_failed" errors**: Verify your signing secret is correct
2. **Bot not responding**: Check CloudWatch logs for Lambda errors
3. **Permission denied**: Ensure your bot has the required OAuth scopes
4. **Timeout errors**: Increase `lambda_timeout` if needed

### Logs

Check CloudWatch logs for the Lambda function:
```bash
aws logs tail /aws/lambda/your-function-name --follow
```

<!-- BEGIN_TF_DOCS -->


## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.11.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.7.1 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.11.2 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bedrock_model_id"></a> [bedrock\_model\_id](#input\_bedrock\_model\_id) | The Bedrock model ID to use for AI responses | `string` | `"anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_bedrock_model_inference_profile"></a> [bedrock\_model\_inference\_profile](#input\_bedrock\_model\_inference\_profile) | Inference profile ID to use | `string` | `"us.anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Name of the Lambda function | `string` | `"terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_lambda_layer_name"></a> [lambda\_layer\_name](#input\_lambda\_layer\_name) | Name of the Lambda layer | `string` | `"terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_lambda_source_path"></a> [lambda\_source\_path](#input\_lambda\_source\_path) | Path to custom Lambda function source code (zip file or directory) | `string` | `""` | no |
| <a name="input_lambda_source_type"></a> [lambda\_source\_type](#input\_lambda\_source\_type) | Type of Lambda source: 'default', 'zip', or 'directory' | `string` | `"default"` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda function timeout in seconds | `number` | `30` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs in CloudWatch | `number` | `731` | no |
| <a name="input_python_version"></a> [python\_version](#input\_python\_version) | Python version for the Lambda layer | `string` | `"3.12"` | no |
| <a name="input_slack_app_description"></a> [slack\_app\_description](#input\_slack\_app\_description) | Description of the Slack app assistant | `string` | `"Hi, I am an assistant built using Bolt for Python. I am here to help you out!"` | no |
| <a name="input_slack_app_name"></a> [slack\_app\_name](#input\_slack\_app\_name) | Name of the Slack app in the manifest | `string` | `"Bolt Python Assistant"` | no |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | The Slack bot token for authentication | `string` | `"xoxb-"` | no |
| <a name="input_slack_signing_secret"></a> [slack\_signing\_secret](#input\_slack\_signing\_secret) | The Slack signing secret for verification | `string` | `"asigningsecret"` | no |
| <a name="input_slack_slash_command"></a> [slack\_slash\_command](#input\_slack\_slash\_command) | Slash command for the Slack app | `string` | `"/start-process"` | no |
| <a name="input_slack_slash_command_description"></a> [slack\_slash\_command\_description](#input\_slack\_slash\_command\_description) | The description for the slash command | `string` | `"Ask a question to the Bedrock bot"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_id"></a> [api\_gateway\_id](#output\_api\_gateway\_id) | The ID of the API Gateway |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | The ARN of the Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | The name of the Lambda function |
| <a name="output_lambda_layer_arn"></a> [lambda\_layer\_arn](#output\_lambda\_layer\_arn) | The ARN of the Lambda layer (if created) |
| <a name="output_lambda_layer_version"></a> [lambda\_layer\_version](#output\_lambda\_layer\_version) | The version of the Lambda layer (if created) |
| <a name="output_slack_app_manifest_content"></a> [slack\_app\_manifest\_content](#output\_slack\_app\_manifest\_content) | The content of the generated Slack app manifest |
| <a name="output_slack_app_manifest_file"></a> [slack\_app\_manifest\_file](#output\_slack\_app\_manifest\_file) | The path to the generated Slack app manifest file |
| <a name="output_slack_bot_endpoint_url"></a> [slack\_bot\_endpoint\_url](#output\_slack\_bot\_endpoint\_url) | The URL used to verify the Slack app |
| <a name="output_slack_bot_token_console_url"></a> [slack\_bot\_token\_console\_url](#output\_slack\_bot\_token\_console\_url) | The AWS console URL for the Slack bot token secret |
| <a name="output_slack_bot_token_secret_arn"></a> [slack\_bot\_token\_secret\_arn](#output\_slack\_bot\_token\_secret\_arn) | The ARN of the Secrets Manager secret containing the Slack bot token |
| <a name="output_slack_bot_token_secret_name"></a> [slack\_bot\_token\_secret\_name](#output\_slack\_bot\_token\_secret\_name) | The name of the Secrets Manager secret containing the Slack bot token |

## Resources

| Name | Type |
|------|------|
| [aws_apigatewayv2_api.slack_bot_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.slack_bot_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.slack_bot_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.slack_bot_endpoint_default_stage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.slack_bot_api_access_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.slack_bot_lambda_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.slack_bot_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.slack_bot_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.slack_bot_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_layer_version.dependencies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_layer_version) | resource |
| [aws_lambda_permission.api_gateway_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_secretsmanager_secret.slack_bot_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.slack_signing_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.slack_bot_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.slack_signing_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_ssm_parameter.slack_app_manifest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [local_file.lambda_code](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.slack_app_manifest](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.lambda_code_trigger](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.lambda_layer_build](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [time_static.slack_bot_token_update](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [time_static.slack_signing_secret_update](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
<!-- END_TF_DOCS -->
