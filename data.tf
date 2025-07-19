# Data sources
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Build Lambda layer from requirements.txt
resource "null_resource" "lambda_layer_build" {
  triggers = {
    requirements   = fileexists("${var.lambda_source_type == "directory" ? var.lambda_source_path : "${path.module}/lambda"}/requirements.txt") ? filemd5("${var.lambda_source_type == "directory" ? var.lambda_source_path : "${path.module}/lambda"}/requirements.txt") : ""
    python_version = var.python_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/layer_build/python

      # Use Docker to build Lambda layer with correct x86_64 architecture
      echo "Using Docker to build Lambda layer..."
      docker run --rm \
        --platform=linux/amd64 \
        --entrypoint="" \
        -v ${var.lambda_source_type == "directory" ? var.lambda_source_path : "${path.module}/lambda"}:/var/task:ro \
        -v ${path.module}/layer_build/python:/var/layer:rw \
        public.ecr.aws/lambda/python:${var.python_version} \
        /bin/bash -c "
          if [ -f /var/task/requirements.txt ]; then
            pip install -r /var/task/requirements.txt -t /var/layer --no-cache-dir
          else
            echo 'No requirements.txt found, skipping dependency installation'
          fi
        "
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${path.module}/layer_build"
  }
}

# Archive the Lambda layer
data "archive_file" "lambda_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer_build"
  output_path = "${path.module}/layer_build/lambda_layer.zip"

  depends_on = [null_resource.lambda_layer_build]
}

# Trigger for Lambda code changes
resource "null_resource" "lambda_code_trigger" {
  triggers = {
    shell_hash = sha256(join("", [
      file("${path.module}/lambda/index.py"),
      var.bedrock_model_inference_profile
    ]))
  }
}

# Create the Lambda function code
resource "local_file" "lambda_code" {
  count = var.lambda_source_path == "" ? 1 : 0

  content = templatefile("${path.module}/lambda/index.py", {
    bedrock_model_id = var.bedrock_model_inference_profile

  })
  filename = "${path.module}/lambda_build/index.py"

  # Force recreation when trigger changes
  lifecycle {
    replace_triggered_by = [
      null_resource.lambda_code_trigger
    ]
  }
}

# Archive the Lambda function code
data "archive_file" "lambda_zip" {
  count       = var.lambda_source_path == "" ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/lambda_build"
  output_path = "${path.module}/lambda_build/lambda_function.zip"

  depends_on = [local_file.lambda_code]
}

# Conditional archive file for custom Lambda source
data "archive_file" "custom_lambda_zip" {
  count       = var.lambda_source_type == "directory" ? 1 : 0
  type        = "zip"
  source_dir  = var.lambda_source_path
  output_path = "${path.module}/lambda_function_custom.zip"
}

data "aws_bedrock_foundation_model" "anthropic" {
  model_id = var.bedrock_model_id
}

