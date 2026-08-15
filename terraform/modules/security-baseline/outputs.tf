output "general_kms_key_arn" {
  value = aws_kms_key.general.arn
}

output "waf_web_acl_arn" {
  description = "Consumed by the-redemption's Ingress via the alb.ingress.kubernetes.io/wafv2-acl-arn annotation."
  value       = aws_wafv2_web_acl.edge.arn
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}
