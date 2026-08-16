output "node_instance_profile_name" {
  description = "IAM instance profile name attached to EC2 nodes Karpenter launches."
  value       = aws_iam_instance_profile.node.name
}

output "controller_role_arn" {
  description = "IAM role ARN of the Karpenter controller's Pod Identity."
  value       = module.controller_pod_identity.role_arn
}

output "interruption_queue_name" {
  description = "SQS queue Karpenter consumes Spot interruption/rebalance events from."
  value       = aws_sqs_queue.interruption.name
}
