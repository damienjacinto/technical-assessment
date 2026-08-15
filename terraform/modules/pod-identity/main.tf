##############################################################################
# Reusable EKS Pod Identity module: one IAM role + one
# aws_eks_pod_identity_association per ServiceAccount.
#
# Every controller/workload in this stack that needs AWS API access gets its
# own instance of this module -- never node-wide IAM. That's the "least
# privilege" half of the security design: a compromised pod only has the
# permissions its own ServiceAccount was scoped to, not whatever the
# underlying EC2 instance profile happens to carry.
#
# Requires the eks-pod-identity-agent addon on the cluster (see
# terraform/modules/eks/main.tf) -- the agent DaemonSet is what actually
# vends credentials to pods at runtime; this module only creates the AWS
# side of the association.
##############################################################################

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
  count  = var.inline_policy_json == null ? 0 : 1
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
