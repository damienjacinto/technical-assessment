output "name_prefix" {
  description = "The \"<project>-<environment>\" prefix used to name resources across modules."
  value       = local.name_prefix
}

output "tags" {
  description = "Common tag set applied to all resources in this environment."
  value       = local.tags
}

output "environment" {
  description = "Environment name (e.g. \"prod\")."
  value       = var.environment
}

output "aws_region" {
  description = "AWS region this environment is deployed to."
  value       = var.aws_region
}

output "account_id" {
  description = "AWS account ID the current provider is authenticated against."
  value       = data.aws_caller_identity.current.account_id
}

output "azs" {
  description = "Availability zones in use for this environment."
  value       = local.azs
}

output "vpc_id" {
  description = "ID of the VPC created for this environment."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC created for this environment."
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets."
  value       = module.vpc.database_subnet_ids
}

output "database_subnet_group_name" {
  description = "Name of the RDS subnet group spanning the database subnets."
  value       = module.vpc.database_subnet_group_name
}

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "karpenter_node_iam_role_name_prefix" {
  description = "Not the node role itself (created in platform) -- exposed here only as the naming convention platform must follow, so foundation stays the single source of truth for naming."
  value       = local.name_prefix
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL created by the security baseline module."
  value       = module.security_baseline.waf_web_acl_arn
}

output "general_kms_key_arn" {
  description = "ARN of the general-purpose KMS key created by the security baseline module."
  value       = module.security_baseline.general_kms_key_arn
}

output "app_security_group_id" {
  description = "Security group ID for application workloads, created by the security baseline module."
  value       = module.security_baseline.app_security_group_id
}

output "the_redemption_pod_identity_role_arn" {
  description = "Not consumed by the argocd module -- Pod Identity's role<->ServiceAccount pairing is done entirely on the AWS side via the aws_eks_pod_identity_association, unlike IRSA which needed the ARN threaded into the chart's ServiceAccount annotation. Exposed for a future data-layer decision to attach a policy against."
  value       = module.pod_identity.role_arn
}
