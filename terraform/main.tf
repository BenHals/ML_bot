terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

data "aws_iam_policy_document" "api_gateway_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_logging_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging_policy.json
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-lambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role" "apigateway_role" {
  name               = "api-gateway-role"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "api_gateway_logging" {
  role       = aws_iam_role.apigateway_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
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
  runtime          = "python3.11"
  handler          = "test_lambda_function.lambda_handler"
  timeout          = 10
  layers           = [aws_lambda_layer_version.python_layer.arn]
  environment {
    variables = {
      DISCORD_PUBLIC_KEY = var.DISCORD_PUBLIC_KEY
    }
  }
  depends_on = [aws_iam_role_policy_attachment.lambda_logging]
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

# resource "aws_api_gateway_method_settings" "YOUR_settings" {
#   rest_api_id = aws_api_gateway_rest_api.discord_entry.id
#   stage_name  = "test"
#   method_path = "*/*"
#   settings {
#     logging_level      = "INFO"
#     data_trace_enabled = true
#     metrics_enabled    = true
#   }
# }

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
  type                    = "AWS"
  uri                     = aws_lambda_function.test_lambda_function.invoke_arn
  passthrough_behavior    = "NEVER"
  request_templates = {
    "application/json" = <<EOF
##  See http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-mapping-template-reference.html
##  This template will pass through all parameters including path, querystring, header, stage variables, and context through to the integration endpoint via the body/payload
##  'rawBody' allows passthrough of the (unsurprisingly) raw request body; similar to flask.request.data
#set($allParams = $input.params())
{
"rawBody": "$util.escapeJavaScript($input.body).replace("\'", "'")",
"body-json" : $input.json('$'),
"params" : {
#foreach($type in $allParams.keySet())
    #set($params = $allParams.get($type))
"$type" : {
    #foreach($paramName in $params.keySet())
    "$paramName" : "$util.escapeJavaScript($params.get($paramName))"
        #if($foreach.hasNext),#end
    #end
}
    #if($foreach.hasNext),#end
#end
},
"stage-variables" : {
#foreach($key in $stageVariables.keySet())
"$key" : "$util.escapeJavaScript($stageVariables.get($key))"
    #if($foreach.hasNext),#end
#end
},
"context" : {
    "account-id" : "$context.identity.accountId",
    "api-id" : "$context.apiId",
    "api-key" : "$context.identity.apiKey",
    "authorizer-principal-id" : "$context.authorizer.principalId",
    "caller" : "$context.identity.caller",
    "cognito-authentication-provider" : "$context.identity.cognitoAuthenticationProvider",
    "cognito-authentication-type" : "$context.identity.cognitoAuthenticationType",
    "cognito-identity-id" : "$context.identity.cognitoIdentityId",
    "cognito-identity-pool-id" : "$context.identity.cognitoIdentityPoolId",
    "http-method" : "$context.httpMethod",
    "stage" : "$context.stage",
    "source-ip" : "$context.identity.sourceIp",
    "user" : "$context.identity.user",
    "user-agent" : "$context.identity.userAgent",
    "user-arn" : "$context.identity.userArn",
    "request-id" : "$context.requestId",
    "resource-id" : "$context.resourceId",
    "resource-path" : "$context.resourcePath"
    }
}
EOF
  }
}

resource "aws_api_gateway_deployment" "name" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.discord_entry.id
  stage_name  = "test"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigateway_role.arn
}

output "base_url" {
  value = aws_api_gateway_deployment.name.invoke_url
}


