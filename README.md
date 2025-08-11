# AWS Slack Bot with Bedrock Integration

A Terraform module for deploying a Python based [AI assistant or agent](https://docs.slack.dev/ai/developing-ai-apps) Slack App on AWS Lambda.

## Use Case
I built this mainly to explore building simple GenAI apps in Slack using Amazon Bedrock. It is inspired by the [Deploy a Slack gateway for Amazon Bedrock](https://aws.amazon.com/blogs/machine-learning/deploy-a-slack-gateway-for-amazon-bedrock/) blogpost by AWS.

![alt text](architecture.png)

This module is for you if you want to crank out a quick protoype and/or want to have all your code in a monolithic lambda. It uses the [lazy listener pattern](https://tools.slack.dev/bolt-python/concepts/lazy-listeners/) to allow you perform long running processes while still meeting Slacks 3 second reply requirement.  If you want a microservice based approach, I highly recommend [@amancevice's](https://github.com/amancevice) excellent [module](https://github.com/amancevice/terraform-aws-slackbot).

## Prerequisites
Docker

## Setup

Important: The initial apply uses placeholder Slack credentials so the app and manifest can be created. The bot will not respond in Slack until you replace `slack_bot_token` and `slack_signing_secret` with real values and re-apply.

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
   Run `terraform apply`. This uses dummy default values for `slack_bot_token` and `slack_signing_secret` to create your Slack Lambda and generate a Slack app manifest.
   - Manifest location: Written to the directory where you run Terraform as `slack_app_manifest.json`.
   - Also available via outputs: `slack_app_manifest_file` (path) and `slack_app_manifest_content` (JSON).
   - Stored in SSM Parameter Store at `/slack-app/<lambda_function_name>/manifest`.

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
You can also find the generated manifest stored as an SSM Parameter Store parameter at `/slack-app/<lambda_function_name>/manifest`.

---



## Architecture

The module creates the following AWS resources:

- AWS Lambda function for processing Slack events (with configurable source code)
- Lambda layer for Python dependencies
- Lambda function URL or API Gateway HTTP API for webhook endpoint
- Secrets Manager secrets for Slack bot token and signing secret
- CloudWatch log groups for logging
- IAM roles and policies
- Parameter Store for generated Slack App manifest

It ships with sample lambda function code so you can verify functionality. However, you can choose to use your own lambda using either the zip or directory custom sources described [below](#custom-lambda-source-code)

## Configuring Lambda Function Source

The module supports three methods for providing Lambda function source code:

Only one mode should be used at a time, controlled by `lambda_source_type`:
- default: Do not set `lambda_source_path`.
- directory: Set `lambda_source_type = "directory"` and set `lambda_source_path` to your source folder.
- zip: Set `lambda_source_type = "zip"` and set `lambda_source_path` to your built zip file.

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

In this mode, once your lambda is completely deployed by Terraform, you will switch to a development cycle that uses the lambda local development [Console to IDE](https://aws.amazon.com/blogs/aws/simplify-serverless-development-with-console-to-ide-and-remote-debugging-for-aws-lambda/) workflow.

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

In this mode, you want to continue using Terraform to manage the deployment of the lambda.

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

In this mode, you want to continue using Terraform to manage the deployment of the lambda, but prefer a zip based workflow that could potentially be built in a previous CI build step which is then passed into this module.

Note: Only set `lambda_source_path` when `lambda_source_type` is `directory` or `zip`. If you leave `lambda_source_type = "default"`, the template-based source will be used and any provided path will be ignored.

## Lambda Layer for Dependencies

The module builds and attaches a Lambda layer from a `requirements.txt` file. How the requirements are chosen depends on the source mode:

- Default mode: By default uses the module's built-in `lambda/requirements.txt`. You can override this via:
   - `requirements_inline` — list of dependency specifiers rendered into a requirements file, or
   - `requirements_txt_override_path` — path to a requirements.txt on your machine.
   The inline list takes precedence if both are provided.
- Directory mode: Uses the `requirements.txt` file located in your custom source directory (`lambda_source_path`).
- Zip mode: Your ZIP provides the function code. The module still builds and attaches a dependency layer using the module's built-in `lambda/requirements.txt` (or your overrides if set as above). Ensure your ZIP either excludes those dependencies (to keep it slim) or that versions are compatible with the layer. If you need full control, prefer directory mode.

### How it works:

1. **Requirements file**: Place your Python dependencies in `requirements.txt` in the same directory as your Lambda code
2. **Automatic building (requires Docker)**: The module builds the layer using Docker for the linux/amd64 architecture. Ensure Docker is installed and running.
3. **Layer attachment**: The layer is automatically attached to the Lambda function

Notes:
- Docker is required for building the layer in default and directory modes; without Docker, the build will fail.
- For zip mode, package dependencies in your zip, or rely on the generated layer to keep your zip slim.

### Examples (Default mode overrides)

Inline list:

```hcl
module "slack_bot" {
   source = "mbuotidem/slackbot-lambdalith/aws"

   requirements_inline = [
      "boto3==1.34.131",
      "slack-bolt>=1.21,<2"
   ]
}
```

File path override:

```hcl
module "slack_bot" {
   source = "mbuotidem/slackbot-lambdalith/aws"

   requirements_txt_override_path = "/absolute/path/to/requirements.txt"
}
```


### Example requirements.txt:

```txt
boto3==1.34.131
urllib3==2.0.7
requests==2.31.0
slack-bolt>=1.21,<2
slack-sdk>=3.33.1,<4
```

## Choosing your endpoint: Lambda Function URL vs API Gateway

Control this with the `use_function_url` input.

- Lambda Function URL (set `use_function_url = true`)
   - Pros: Simplest and lowest-cost; fewer resources, fastest latency
   - Cons: Fewer features (no custom domain, less secure)
   - When to choose: Prototypes and minimal setups where a public unauthenticated URL is acceptable (Slack request signing still protects your handler but not from denial of wallet attacks).

- API Gateway HTTP API (default)
   - Pros: Custom domains, WAF, richer logging/monitoring; includes a dispatcher Lambda that returns immediately to satisfy Slack’s 3-second requirement and invokes the main Lambda asynchronously.
   - Cons: Slightly higher cost/complexity, extra hop reduces latency
   - When to choose: Production or when you need API features and tighter controls.

The module always outputs `slack_bot_endpoint_url` with the correct URL that Slack will call and that is embedded in the generated manifest.

## Application signals (optional)

Set `enable_application_signals = true` to enable AWS Distro for OpenTelemetry (ADOT) "Application Signals" for Lambda. The module attaches the OpenTelemetry layer and configures auto-instrumentation so you get traces/metrics correlation out of the box. This adds small runtime overhead and may incur additional observability costs.

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

Tip: The function name is available in Terraform outputs as `lambda_function_name`, or you can find it in the AWS Console under Lambda.

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
| <a name="input_enable_application_signals"></a> [enable\_application\_signals](#input\_enable\_application\_signals) | If true, enables Application signals for monitoring and observability. | `bool` | `false` | no |
| <a name="input_enable_dispatcher_provisioned_concurrency"></a> [enable\_dispatcher\_provisioned\_concurrency](#input\_enable\_dispatcher\_provisioned\_concurrency) | Enable provisioned concurrency for the dispatcher Lambda to eliminate cold starts | `bool` | `true` | no |
| <a name="input_lambda_env_vars"></a> [lambda\_env\_vars](#input\_lambda\_env\_vars) | Environment variables to add to Lambda | `map(string)` | <pre>{<br/>  "BEDROCK_MODEL_INFERENCE_PROFILE": "us.anthropic.claude-3-5-sonnet-20241022-v2:0"<br/>}</pre> | no |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Name of the Lambda function | `string` | `"terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_lambda_layer_name"></a> [lambda\_layer\_name](#input\_lambda\_layer\_name) | Name of the Lambda layer | `string` | `"terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_lambda_source_path"></a> [lambda\_source\_path](#input\_lambda\_source\_path) | Path to custom Lambda function source code (zip file or directory) | `string` | `""` | no |
| <a name="input_lambda_source_type"></a> [lambda\_source\_type](#input\_lambda\_source\_type) | Type of Lambda source: 'default', 'zip', or 'directory' | `string` | `"default"` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda function timeout in seconds | `number` | `30` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs in CloudWatch | `number` | `731` | no |
| <a name="input_opentelemetry_python_layer_arns"></a> [opentelemetry\_python\_layer\_arns](#input\_opentelemetry\_python\_layer\_arns) | Map of AWS region to OpenTelemetry Lambda Layer ARN for Python. | `map(string)` | <pre>{<br/>  "af-south-1": "arn:aws:lambda:af-south-1:904233096616:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ap-east-1": "arn:aws:lambda:ap-east-1:888577020596:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ap-northeast-1": "arn:aws:lambda:ap-northeast-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "ap-northeast-2": "arn:aws:lambda:ap-northeast-2:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "ap-northeast-3": "arn:aws:lambda:ap-northeast-3:615299751070:layer:AWSOpenTelemetryDistroPython:12",<br/>  "ap-south-1": "arn:aws:lambda:ap-south-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "ap-south-2": "arn:aws:lambda:ap-south-2:796973505492:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ap-southeast-1": "arn:aws:lambda:ap-southeast-1:615299751070:layer:AWSOpenTelemetryDistroPython:12",<br/>  "ap-southeast-2": "arn:aws:lambda:ap-southeast-2:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "ap-southeast-3": "arn:aws:lambda:ap-southeast-3:039612877180:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ap-southeast-4": "arn:aws:lambda:ap-southeast-4:713881805771:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ca-central-1": "arn:aws:lambda:ca-central-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-central-1": "arn:aws:lambda:eu-central-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-central-2": "arn:aws:lambda:eu-central-2:156041407956:layer:AWSOpenTelemetryDistroPython:10",<br/>  "eu-north-1": "arn:aws:lambda:eu-north-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-south-1": "arn:aws:lambda:eu-south-1:257394471194:layer:AWSOpenTelemetryDistroPython:10",<br/>  "eu-south-2": "arn:aws:lambda:eu-south-2:490004653786:layer:AWSOpenTelemetryDistroPython:10",<br/>  "eu-west-1": "arn:aws:lambda:eu-west-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-west-2": "arn:aws:lambda:eu-west-2:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-west-3": "arn:aws:lambda:eu-west-3:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "il-central-1": "arn:aws:lambda:il-central-1:746669239226:layer:AWSOpenTelemetryDistroPython:10",<br/>  "me-central-1": "arn:aws:lambda:me-central-1:739275441131:layer:AWSOpenTelemetryDistroPython:10",<br/>  "me-south-1": "arn:aws:lambda:me-south-1:980921751758:layer:AWSOpenTelemetryDistroPython:10",<br/>  "sa-east-1": "arn:aws:lambda:sa-east-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "us-east-1": "arn:aws:lambda:us-east-1:615299751070:layer:AWSOpenTelemetryDistroPython:16",<br/>  "us-east-2": "arn:aws:lambda:us-east-2:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "us-west-1": "arn:aws:lambda:us-west-1:615299751070:layer:AWSOpenTelemetryDistroPython:20",<br/>  "us-west-2": "arn:aws:lambda:us-west-2:615299751070:layer:AWSOpenTelemetryDistroPython:20"<br/>}</pre> | no |
| <a name="input_python_version"></a> [python\_version](#input\_python\_version) | Python version for the Lambda layer | `string` | `"3.12"` | no |
| <a name="input_requirements_inline"></a> [requirements\_inline](#input\_requirements\_inline) | Inline list of Python dependency specifiers to render into a requirements.txt for the Lambda layer. Takes precedence over requirements\_txt\_override\_path when non-empty. | `list(string)` | `[]` | no |
| <a name="input_requirements_txt_override_path"></a> [requirements\_txt\_override\_path](#input\_requirements\_txt\_override\_path) | Path to a requirements.txt file to use for building the Lambda layer (takes precedence over the module's default when provided). | `string` | `""` | no |
| <a name="input_slack_app_description"></a> [slack\_app\_description](#input\_slack\_app\_description) | Description of the Slack app assistant | `string` | `"Hi, I am an assistant built using Bolt for Python. I am here to help you out!"` | no |
| <a name="input_slack_app_name"></a> [slack\_app\_name](#input\_slack\_app\_name) | Name of the Slack app in the manifest | `string` | `"Bolt Python Assistant"` | no |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | The Slack bot token for authentication | `string` | `"xoxb-"` | no |
| <a name="input_slack_signing_secret"></a> [slack\_signing\_secret](#input\_slack\_signing\_secret) | The Slack signing secret for verification | `string` | `"asigningsecret"` | no |
| <a name="input_slack_slash_command"></a> [slack\_slash\_command](#input\_slack\_slash\_command) | Slash command for the Slack app | `string` | `"/start-process"` | no |
| <a name="input_slack_slash_command_description"></a> [slack\_slash\_command\_description](#input\_slack\_slash\_command\_description) | The description for the slash command | `string` | `"Ask a question to the Bedrock bot"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |
| <a name="input_use_function_url"></a> [use\_function\_url](#input\_use\_function\_url) | If true, use Lambda Function URL instead of API Gateway. Dispatcher Lambda and API Gateway will not be created. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_id"></a> [api\_gateway\_id](#output\_api\_gateway\_id) | The ID of the API Gateway (if created) |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | The ARN of the Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | The name of the Lambda function |
| <a name="output_lambda_layer_arn"></a> [lambda\_layer\_arn](#output\_lambda\_layer\_arn) | The ARN of the Lambda layer (if created) |
| <a name="output_lambda_layer_version"></a> [lambda\_layer\_version](#output\_lambda\_layer\_version) | The version of the Lambda layer (if created) |
| <a name="output_slack_app_manifest_content"></a> [slack\_app\_manifest\_content](#output\_slack\_app\_manifest\_content) | The content of the generated Slack app manifest |
| <a name="output_slack_app_manifest_file"></a> [slack\_app\_manifest\_file](#output\_slack\_app\_manifest\_file) | The path to the generated Slack app manifest file |
| <a name="output_slack_bot_endpoint_url"></a> [slack\_bot\_endpoint\_url](#output\_slack\_bot\_endpoint\_url) | The URL used to verify the Slack app (API Gateway or Lambda Function URL) |
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
| [aws_cloudwatch_event_bus.bus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus) | resource |
| [aws_cloudwatch_log_group.slack_bot_api_access_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.slack_bot_dispatcher_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.slack_bot_lambda_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.slack_bot_dispatcher_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.slack_bot_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.slack_bot_dispatcher_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.slack_bot_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.dispatcher_lambda_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_application_signals](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.slack_bot_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.slack_bot_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function_url.slack_bot_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url) | resource |
| [aws_lambda_layer_version.dependencies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_layer_version) | resource |
| [aws_lambda_permission.api_gateway_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_provisioned_concurrency_config.slack_bot_dispatcher_concurrency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_provisioned_concurrency_config) | resource |
| [aws_secretsmanager_secret.slack_bot_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.slack_signing_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.slack_bot_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.slack_signing_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_ssm_parameter.slack_app_manifest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [local_file.dispatcher_lambda_code](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.lambda_code](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.requirements_inline_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.slack_app_manifest](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.lambda_code_trigger](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.lambda_layer_build](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.requirements_inline_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [time_static.slack_bot_token_update](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [time_static.slack_signing_secret_update](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
<!-- END_TF_DOCS -->
