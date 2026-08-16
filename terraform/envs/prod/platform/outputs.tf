output "karpenter_interruption_queue_name" {
  description = "SQS queue Karpenter consumes Spot interruption/rebalance events from."
  value       = module.karpenter.interruption_queue_name
}

output "alb_controller_role_arn" {
  description = "IAM role ARN of the AWS Load Balancer Controller's Pod Identity."
  value       = module.alb_controller.role_arn
}

output "argocd_namespace" {
  description = "Kubernetes namespace ArgoCD is installed into."
  value       = module.argocd.argocd_namespace
}

output "external_secrets_role_arn" {
  description = "Not consumed by any manifest -- Pod Identity's role<->ServiceAccount pairing happens entirely on the AWS side. Exposed for visibility only."
  value       = module.external_secrets_pod_identity.role_arn
}
