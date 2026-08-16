output "fargate_profile_arn" {
  description = "ARN of the kube-system Fargate profile."
  value       = aws_eks_fargate_profile.kube_system.arn
}

output "fargate_profile_status" {
  description = "Current status of the kube-system Fargate profile."
  value       = aws_eks_fargate_profile.kube_system.status
}

output "pod_execution_role_arn" {
  description = "IAM role ARN Fargate assumes to run pods on this profile."
  value       = aws_iam_role.fargate_pod_execution.arn
}
