terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "github_token" {
  type = string
  sensitive = true
}

variable "database_url" {
  type = string
  sensitive = true
}

data "aws_caller_identity" "current" {}

