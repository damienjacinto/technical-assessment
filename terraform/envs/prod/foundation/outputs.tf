##############################################################################
# Consumed by envs/prod/platform via a terraform_remote_state data source.
##############################################################################

output "name_prefix" {
  value = local.name_prefix
}

output "tags" {
  value = local.tags
}

output "environment" {
  value = var.environment
}

output "aws_region" {
  value = var.aws_region
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "azs" {
  value = local.azs
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "database_subnet_ids" {
  value = module.vpc.database_subnet_ids
}

output "database_subnet_group_name" {
  value = module.vpc.database_subnet_group_name
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "karpenter_node_iam_role_name_prefix" {
  description = "Not the node role itself (created in platform) -- exposed here only as the naming convention platform must follow, so foundation stays the single source of truth for naming."
  value       = local.name_prefix
}

output "waf_web_acl_arn" {
  value = module.security_baseline.waf_web_acl_arn
}

output "general_kms_key_arn" {
  value = module.security_baseline.general_kms_key_arn
}

output "app_security_group_id" {
  value = module.security_baseline.app_security_group_id
}

output "the_redemption_pod_identity_role_arn" {
  description = "Not consumed by the argocd module -- Pod Identity's role<->ServiceAccount pairing is done entirely on the AWS side via the aws_eks_pod_identity_association, unlike IRSA which needed the ARN threaded into the chart's ServiceAccount annotation. Exposed for a future data-layer decision to attach a policy against."
  value       = module.pod_identity.role_arn
}
