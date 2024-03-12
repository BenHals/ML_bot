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
