# Security baseline: general-purpose KMS key (this file), the app's
# Security-Group-for-Pods (security_group.tf), and the ALB IP allowlist
# (alb-allowlist.tf, alb-ip-restrict-sg.tf). No WAF in this module.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "general" {
  description             = "${var.name_prefix} general-purpose encryption (Secrets Manager, EBS)"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.general_kms.json
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-general-kms" })
}

resource "aws_kms_alias" "general" {
  name          = "alias/${var.name_prefix}-general"
  target_key_id = aws_kms_key.general.key_id
}

data "aws_iam_policy_document" "general_kms" {
  #checkov:skip=CKV_AWS_109:Root full-access statement mirrors AWS's own implicit default KMS key policy, not a bespoke grant. See comment above.
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt*",
      "kms:Describe*",
      "kms:Encrypt*",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}
