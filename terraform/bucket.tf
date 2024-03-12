resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${var.root_name}-${var.lambda_layer_suffix}"
}

