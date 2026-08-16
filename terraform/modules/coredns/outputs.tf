output "addon_arn" {
  description = "ARN of the CoreDNS EKS addon."
  value       = aws_eks_addon.coredns.arn
}

output "security_group_id" {
  description = "Security group ID for CoreDNS pods (Security Groups for Pods)."
  value       = aws_security_group.this.id
}
