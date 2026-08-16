##############################################################################
# Flow logs bucket: dedicated KMS key + S3 bucket, private/encrypted.
##############################################################################

resource "aws_kms_key" "flow_logs" {
  description             = "${var.name_prefix} VPC flow logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-flow-logs-kms" })
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${var.name_prefix}-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

resource "aws_s3_bucket" "flow_logs" {
  bucket = "${var.name_prefix}-flow-logs-${var.account_id}"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-flow-logs" })
}

resource "aws_s3_bucket_versioning" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.flow_logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket                  = aws_s3_bucket.flow_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  rule {
    id     = "expire-old-flow-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.flow_log_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = var.flow_log_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
