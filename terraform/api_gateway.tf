
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

resource "aws_iam_role" "apigateway_role" {
  name               = "api-gateway-role"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "api_gateway_logging" {
  role       = aws_iam_role.apigateway_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
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
  function_name = aws_lambda_function.command_handler_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.discord_entry.execution_arn}/*/*"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.discord_entry.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.command_handler_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "name" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.discord_entry.id
  stage_name  = "test"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigateway_role.arn
}
