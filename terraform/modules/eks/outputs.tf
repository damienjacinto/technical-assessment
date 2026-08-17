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
}

output "cluster_version" {
  description = "Kubernetes version running on the EKS control plane."
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = <<-EOT
    The EKS-managed cluster security group (what Fargate attaches to pods
    by default, and what a custom SecurityGroupPolicy's groupIds must also
    include alongside its own SG, see modules/coredns and
    modules/karpenter). Deliberately module.eks.cluster_primary_security_group_id
    here, NOT the confusingly-similarly-named module.eks.cluster_security_group_id.
    That one is a different, module-created additional security group
    (aws_security_group.cluster in the upstream module), not the actual
    EKS-managed cluster SG. Wiring the wrong one silently produces a valid
    but useless SecurityGroupPolicy: it stays two-entries "fixed"-looking
    while pods still get stuck in an endless Fargate provisioning-timeout
    loop, since the SG that's actually missing is still missing.
  EOT
  value       = module.eks.cluster_primary_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN assumed by the EKS control plane."
  value       = module.eks.cluster_iam_role_arn
}

output "secrets_kms_key_arn" {
  description = "ARN of the KMS key used for Kubernetes Secrets envelope encryption."
  value       = module.eks.kms_key_arn
}

output "oidc_provider_arn" {
  description = "ARN of the cluster's OIDC identity provider. The Federated principal an IRSA trust policy needs. Only Karpenter's controller uses this (see modules/karpenter/main.tf); everything else uses Pod Identity."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "Cluster OIDC issuer, without the https:// prefix. The condition-key prefix (\"<this>:sub\", \"<this>:aud\") an IRSA trust policy's StringEquals conditions need."
  value       = module.eks.oidc_provider
}
