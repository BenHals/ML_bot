terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket  = "ben-halstead-state"
    key     = "ML-bot-state/terraform.tfstate"
    region  = "ap-southeast-2"
    encrypt = true
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  lambda_requirements_path = "${path.root}/../requirements.txt"
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-lambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "archive_file" "test_lambda_package" {
  type        = "zip"
  source_file = "src/test_lambda_function.py"
  output_path = "test_lambda_package.zip"
}

resource "null_resource" "python_lambda_layer" {
  triggers = {
    requirements = filesha1(local.lambda_requirements_path)
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      rm -rf python/
      mkdir python
      pip install -r ${local.lambda_requirements_path} -t python/
      zip -r lambda_layer.zip python/
    EOT
  }
}

resource "aws_s3_object" "lambda_layer_zip" {
  bucket     = aws_s3_bucket.lambda_bucket.id
  key        = "lambda_layers/discord_python_layer/test_lambda_package.zip"
  source     = "lambda_layer.zip"
  depends_on = [null_resource.python_lambda_layer]
}

resource "aws_lambda_layer_version" "python_layer" {
  layer_name   = "lambda_python_layer"
  description  = "Layer for discord python lambda"
  s3_bucket    = aws_s3_bucket.lambda_bucket.id
  s3_key       = aws_s3_object.lambda_layer_zip.key
  depends_on   = [aws_s3_object.lambda_layer_zip]
  skip_destroy = true
}

resource "aws_lambda_function" "test_lambda_function" {
  function_name    = "test_lambda"
  filename         = "test_lambda_package.zip"
  source_code_hash = data.archive_file.test_lambda_package.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.10"
  handler          = "test_lambda_function.lambda_handler"
  timeout          = 10
  layers           = [aws_lambda_layer_version.python_layer.arn]
  environment {
    variables = {
      DISCORD_PUBLIC_KEY = var.DISCORD_PUBLIC_KEY
    }
  }
}

resource "aws_api_gateway_rest_api" "discord_entry" {
  name        = "DiscordEntrypoint"
  description = "Serverless discord bot entrypoint"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.discord_entry.id
  parent_id   = aws_api_gateway_rest_api.discord_entry.root_resource_id
  path_part   = "event"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.discord_entry.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.discord_entry.execution_arn}/*/*"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.discord_entry.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.test_lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "name" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.discord_entry.id
  stage_name  = "test"
}

output "base_url" {
  value = aws_api_gateway_deployment.name.invoke_url
}


