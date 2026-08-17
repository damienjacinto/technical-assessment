output "node_instance_profile_name" {
  description = "IAM instance profile name attached to EC2 nodes Karpenter launches."
  value       = aws_iam_instance_profile.node.name
}

output "controller_role_arn" {
  description = "IAM role ARN of the Karpenter controller's IRSA role (not Pod Identity. See main.tf for why)."
  value       = aws_iam_role.controller.arn
}

output "interruption_queue_name" {
  description = "SQS queue Karpenter consumes Spot interruption/rebalance events from."
  value       = aws_sqs_queue.interruption.name
}
