# Reusable EKS Pod Identity module: one IAM role + association per
# ServiceAccount, never node-wide IAM. Requires the eks-pod-identity-agent
# addon (terraform/modules/eks/main.tf) to vend credentials at runtime.

data "aws_iam_policy_document" "trust" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name_prefix}-${var.role_suffix}-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count  = var.create_inline_policy ? 1 : 0
  name   = "${var.name_prefix}-${var.role_suffix}-policy"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.this.arn
  tags            = var.tags
}
