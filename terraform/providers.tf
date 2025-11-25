terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
  required_version = ">= 1.2"
}

provider "aws" {
  region = "us-east-2"
}
