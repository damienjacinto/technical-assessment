output "karpenter_interruption_queue_name" {
  description = "SQS queue Karpenter consumes Spot interruption/rebalance events from."
  value       = module.karpenter.interruption_queue_name
}

output "metrics_server_addon_version" {
  description = "Resolved metrics-server addon version currently installed. Capture into foundation's addon_versions (key \"metrics-server\") once stable, to pin it and make plans deterministic."
  value       = module.metrics_server.addon_version
}

output "alb_controller_role_arn" {
  description = "IAM role ARN of the AWS Load Balancer Controller's Pod Identity."
  value       = module.alb_controller.role_arn
}

output "external_secrets_role_arn" {
  description = "Not consumed by any manifest. Pod Identity's role<->ServiceAccount pairing happens entirely on the AWS side. Exposed for visibility only."
  value       = module.external_secrets.role_arn
}

output "the_redemption_pod_identity_role_arn" {
  description = "Not consumed by the argocd module. Pod Identity's role<->ServiceAccount pairing is done entirely on the AWS side via the aws_eks_pod_identity_association, unlike IRSA which needed the ARN threaded into the chart's ServiceAccount annotation. Exposed for a future data-layer decision to attach a policy against."
  value       = module.the_redemption_pod_identity.role_arn
}
