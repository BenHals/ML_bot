# data "archive_file" "test_slow_command_lambda_source" {
#   type        = "zip"
#   source_dir  = "${var.artifact_source_path}/${var.test_slow_command_name_prefix}_${var.lambda_source_suffix}"
#   output_path = "${var.archive_path}/${var.test_slow_command_name_prefix}_${var.lambda_source_suffix}.zip"
# }

resource "docker_image" "slow_command_lambda" {
  name = "slow_command_lambda"
  build {
    context = "${var.artifact_source_path}/${var.test_slow_command_name_prefix}_${var.lambda_source_suffix}"
    tag     = ["slow_command_lambda:latest"]
  }
  # triggers = {
  #   dir_sha1 = sha1(join("", [for f in fileset("${path.module}/${var.artifact_source_path}/${var.test_slow_command_name_prefix}_${var.lambda_source_suffix}", "*") : filesha1(f)]))
  # }
}

resource "docker_tag" "slow_command_lambda_tag" {
  source_image = "slow_command_lambda:latest"
  target_image = "${local.clean_image_repo_url}/${aws_ecr_repository.lambda_ecr_repository.name}:latest"
}
# push image to ecr repo
resource "docker_registry_image" "media-handler" {
  name       = "${local.clean_image_repo_url}/${aws_ecr_repository.lambda_ecr_repository.name}:latest"
  depends_on = [docker_tag.slow_command_lambda_tag]
}

resource "aws_ecr_repository" "lambda_ecr_repository" {
  name                 = "lambda_ecr_repository"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_lambda_function" "test_slow_command_lambda" {
  function_name = "test_slow_command_lambda"
  package_type  = "Image"
  image_uri     = "${local.clean_image_repo_url}/${aws_ecr_repository.lambda_ecr_repository.name}:latest"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 600
  environment {
    variables = {
      DISCORD_PUBLIC_KEY = var.DISCORD_PUBLIC_KEY
      DISCORD_APP_ID     = var.DISCORD_APP_ID
      DISCORD_BOT_TOKEN  = var.DISCORD_BOT_TOKEN
    }
  }
  depends_on = [aws_iam_role_policy_attachment.lambda_logging, docker_registry_image.media-handler]
}
