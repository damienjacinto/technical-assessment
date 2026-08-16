# external-secrets: Pod Identity role + least-privilege Secrets Manager
# policy. The controller is an ArgoCD-managed infra-app, not deployed
# here -- this is just the AWS-side wiring it needs.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "pod_identity" {
  source = "../pod-identity"

  name_prefix          = var.name_prefix
  role_suffix          = "external-secrets"
  cluster_name         = var.cluster_name
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  inline_policy_json   = data.aws_iam_policy_document.external_secrets.json
  create_inline_policy = true
  tags                 = var.tags
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/*"
    ]
  }
}
