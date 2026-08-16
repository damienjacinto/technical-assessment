output "role_arn" {
  description = "IAM role ARN of external-secrets' Pod Identity."
  value       = module.pod_identity.role_arn
}
