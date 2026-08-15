output "karpenter_interruption_queue_name" {
  value = module.karpenter.interruption_queue_name
}

output "alb_controller_role_arn" {
  value = module.alb_controller.role_arn
}

output "argocd_namespace" {
  value = module.argocd.argocd_namespace
}

output "external_secrets_role_arn" {
  description = "Not consumed by any manifest -- Pod Identity's role<->ServiceAccount pairing happens entirely on the AWS side. Exposed for visibility only."
  value       = module.external_secrets_pod_identity.role_arn
}
