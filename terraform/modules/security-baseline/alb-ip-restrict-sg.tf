# Actual access control for both ALBs: blocks non-allowlisted IPs at the
# network layer (local.alb_allowlist_cidrs). Referenced via the
# security-groups annotation on both Ingresses, replacing the AWS Load
# Balancer Controller's auto-managed SG (0.0.0.0/0 by default).
resource "aws_security_group" "alb_ip_restricted" {
  name        = "${var.name_prefix}-alb-ip-restricted"
  description = "ALB ingress restricted to the allowlisted IPs"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-alb-ip-restricted" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_allowlist" {
  for_each = toset(local.alb_allowlist_cidrs)

  security_group_id = aws_security_group.alb_ip_restricted.id
  description       = "HTTP from an allowlisted IP. Both ALBs are HTTP-only, no ACM cert"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb_ip_restricted.id
  description       = "To the app/admin pods in the VPC"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
