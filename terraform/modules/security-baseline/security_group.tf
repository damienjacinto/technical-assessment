resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-the-redemption-sg"
  description = "the-redemption app pods (Security Groups for Pods)"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-the-redemption-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_vpc" {
  security_group_id = aws_security_group.app.id
  description       = "From within the VPC (ALB target group, in-cluster) on the app port"
  cidr_ipv4         = var.vpc_cidr
  from_port         = var.app_port
  to_port           = var.app_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_to_vpc" {
  security_group_id = aws_security_group.app.id
  description       = "To the rest of the VPC (database tier, in-cluster services)"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS AWS API calls via the VPC interface endpoints"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
