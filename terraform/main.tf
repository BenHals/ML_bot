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

resource "aws_lambda_function" "test_lambda_function" {
  function_name    = "test_lambda"
  filename         = "test_lambda_package.zip"
  source_code_hash = data.archive_file.test_lambda_package.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.10"
  handler          = "test_lambda_function.lambda_handler"
  timeout          = 10
}

resource "aws_instance" "app_server" {
  ami           = "ami-07e1aeb90edb268a3"
  instance_type = "t2.micro"

  tags = {
    Name = "ExampleAppServerInstance"
  }
}
