resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${var.root_name}-lambda-data"
}

