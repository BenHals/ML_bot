data "archive_file" "test_slow_command_lambda_source" {
  type        = "zip"
  source_file = "${var.artifact_source_path}/${var.test_slow_command_name_prefix}_${var.lambda_source_suffix}.py"
  output_path = "${var.archive_path}/${var.test_slow_command_name_prefix}_${var.lambda_source_suffix}.zip"
}

resource "aws_lambda_function" "test_slow_command_lambda" {
  function_name    = "test_slow_command_lambda"
  filename         = "${var.archive_path}/${var.test_slow_command_name_prefix}_${var.lambda_source_suffix}.zip"
  source_code_hash = data.archive_file.test_slow_command_lambda_source.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "${var.test_slow_command_name_prefix}_${var.lambda_source_suffix}.lambda_handler"
  timeout          = 10
  layers           = [aws_lambda_layer_version.command_handler_lambda_layer.arn]
  environment {
    variables = {
      DISCORD_PUBLIC_KEY = var.DISCORD_PUBLIC_KEY
      DISCORD_APP_ID     = var.DISCORD_APP_ID
      DISCORD_BOT_TOKEN  = var.DISCORD_BOT_TOKEN
    }
  }
  depends_on = [aws_iam_role_policy_attachment.lambda_logging]
}
