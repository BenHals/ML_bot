data "archive_file" "command_handler_lambda_source" {
  type        = "zip"
  source_dir  = "${var.artifact_source_path}/${var.command_handler_name_prefix}_${var.lambda_source_suffix}"
  output_path = "${var.archive_path}/${var.command_handler_name_prefix}_${var.lambda_source_suffix}.zip"
}

resource "null_resource" "command_handler_lambda_layer" {
  triggers = {
    requirements = filesha1(local.lambda_requirements_path)
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      rm -rf ${var.archive_path}/python/
      mkdir ${var.archive_path}/python
      python3.11 -m pip install -r ${local.lambda_requirements_path} -t ${var.archive_path}/python/
      cd ${var.archive_path}
      zip -r ${var.command_handler_name_prefix}_${var.lambda_layer_suffix}.zip python/
    EOT
  }
}

resource "aws_s3_object" "command_handler_lambda_layer_zip" {
  bucket     = aws_s3_bucket.lambda_bucket.id
  key        = "${var.command_handler_name_prefix}_${var.lambda_layer_suffix}.zip"
  source     = "${var.archive_path}/${var.command_handler_name_prefix}_${var.lambda_layer_suffix}.zip"
  depends_on = [null_resource.command_handler_lambda_layer]
}

resource "aws_lambda_layer_version" "command_handler_lambda_layer" {
  layer_name   = "command_handler_lambda_layer"
  description  = "Layer for discord command handler lambda"
  s3_bucket    = aws_s3_bucket.lambda_bucket.id
  s3_key       = aws_s3_object.command_handler_lambda_layer_zip.key
  depends_on   = [aws_s3_object.command_handler_lambda_layer_zip]
  skip_destroy = true
  # source_code_hash = filebase64sha256("${var.archive_path}/${var.command_handler_name_prefix}_${var.lambda_layer_suffix}.zip")
}

resource "aws_lambda_function" "command_handler_lambda" {
  function_name    = "command_handler_lambda"
  filename         = "${var.archive_path}/${var.command_handler_name_prefix}_${var.lambda_source_suffix}.zip"
  source_code_hash = data.archive_file.command_handler_lambda_source.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "command-handler_lambda-source.lambda_handler"
  timeout          = 10
  layers           = [aws_lambda_layer_version.command_handler_lambda_layer.arn]
  environment {
    variables = {
      DISCORD_PUBLIC_KEY = var.DISCORD_PUBLIC_KEY
    }
  }
  depends_on = [aws_iam_role_policy_attachment.lambda_logging]
}
