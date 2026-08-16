output "role_arn" {
  description = "IAM role ARN of the AWS Load Balancer Controller's Pod Identity."
  value       = module.pod_identity.role_arn
}
