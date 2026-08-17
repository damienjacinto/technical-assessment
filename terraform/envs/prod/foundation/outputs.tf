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

output "cluster_version" {
  description = "Kubernetes version running on the EKS control plane. Platform's module.coredns needs this to pick compatible addon versions."
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "The EKS-managed cluster security group. See modules/eks/outputs.tf for why this specific one, not the similarly-named-but-different alternative the upstream module also exposes."
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the cluster's OIDC identity provider. Platform's module.karpenter needs this for its controller's IRSA trust policy (Pod Identity doesn't work on Fargate)."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "Cluster OIDC issuer without the https:// prefix. Platform's module.karpenter needs this for its controller's IRSA trust policy condition keys."
  value       = module.eks.oidc_provider
}

output "fargate_log_group_name" {
  description = "CloudWatch Logs group Fargate pod logs ship to. Platform's aws-logging ConfigMap points the Fargate log router at this."
  value       = module.fargate_profile.log_group_name
}

output "karpenter_node_iam_role_name_prefix" {
  description = "Not the node role itself (created in platform). Exposed here only as the naming convention platform must follow, so foundation stays the single source of truth for naming."
  value       = local.name_prefix
}

output "alb_ip_restricted_sg_id" {
  description = "Security group restricting both ALBs to the allowlisted IPs at the network layer, created by the security baseline module."
  value       = module.security_baseline.alb_ip_restricted_sg_id
}

output "general_kms_key_arn" {
  description = "ARN of the general-purpose KMS key created by the security baseline module."
  value       = module.security_baseline.general_kms_key_arn
}

output "app_security_group_id" {
  description = "Security group ID for application workloads, created by the security baseline module."
  value       = module.security_baseline.app_security_group_id
}
