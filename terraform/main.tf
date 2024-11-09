terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
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
# get authorization credentials to push to ecr
data "aws_ecr_authorization_token" "token" {}

locals {
  clean_image_repo_url = replace(data.aws_ecr_authorization_token.token.proxy_endpoint, "https://", "")
}

provider "docker" {
  registry_auth {
    address  = data.aws_ecr_authorization_token.token.proxy_endpoint
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

locals {
  lambda_requirements_path = "${path.root}/../requirements.txt"
}
