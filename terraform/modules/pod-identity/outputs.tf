output "role_arn" {
  description = "ARN of the IAM role created for this ServiceAccount's Pod Identity association."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role created for this ServiceAccount's Pod Identity association."
  value       = aws_iam_role.this.name
}
