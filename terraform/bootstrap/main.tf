##############################################################################
# Terraform state backend bootstrap.
#
# This has to be applied ONCE, by itself, with local state, before any
# envs/<environment>/{foundation,platform} stack can use the S3 backend it
# creates here. Chicken-and-egg: you cannot store the state for the bucket
# that stores your state, inside that same bucket.
#
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#
# Every other root module in this repo points its backend.tf at the bucket
# created here. Locking is S3-native (`use_lockfile = true`, Terraform >=
# 1.10)
#
##############################################################################

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = var.project
      Component  = "terraform-state-backend"
      ManagedBy  = "terraform"
      Repository = var.repository
    }
  }
}

locals {
  state_bucket_name = "${var.project}-tfstate"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name
  # Deliberately no force_destroy
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "bound-noncurrent-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      newer_noncurrent_versions = 10
      noncurrent_days           = 3650
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
