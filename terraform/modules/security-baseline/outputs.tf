output "general_kms_key_arn" {
  description = "ARN of the general-purpose KMS key (Secrets Manager, EBS)."
  value       = aws_kms_key.general.arn
}

output "app_security_group_id" {
  description = "Security group ID for the-redemption's app pods (Security Groups for Pods)."
  value       = aws_security_group.app.id
}

output "alb_ip_restricted_sg_id" {
  description = "Security group restricting ALB ingress to the allowlisted IPs at the network layer. Consumed via the alb.ingress.kubernetes.io/security-groups annotation on the-redemption's Ingress (via a ConfigMap lookup). ArgoCD has no Ingress; it's reached via kubectl port-forward."
  value       = aws_security_group.alb_ip_restricted.id
}
