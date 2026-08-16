output "addon_arn" {
  description = "ARN of the CoreDNS EKS addon."
  value       = aws_eks_addon.coredns.arn
}
