output "node_instance_profile_name" {
  value = aws_iam_instance_profile.node.name
}

output "controller_role_arn" {
  value = module.controller_pod_identity.role_arn
}

output "interruption_queue_name" {
  value = aws_sqs_queue.interruption.name
}
