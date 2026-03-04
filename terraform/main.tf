# Task Management Application - AWS Infrastructure
#
# Usage:
#   terraform init      # Initialize Terraform
#   terraform plan      # Preview changes
#   terraform apply     # Create all resources
#   terraform destroy   # DELETE ALL RESOURCES (stops billing)
#
# IMPORTANT: Run 'terraform destroy' when not using the application to avoid AWS charges!

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "task-management"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Random suffix for globally unique names
resource "random_id" "suffix" {
  byte_length = 4
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}
