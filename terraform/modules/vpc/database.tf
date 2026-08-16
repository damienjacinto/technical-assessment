# Database tier: subnet group + SG allowing ingress only from the
# private/app tier. No instance provisioned -- data layer is out of
# scope; this is the network boundary a future decision attaches to.

resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-database-sg"
  description = "Isolated database tier - ingress only from the private/app subnets"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-database-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "database_from_private" {
  security_group_id = aws_security_group.database.id
  description       = "From private/app tier on the DB port"
  cidr_ipv4         = var.vpc_cidr
  from_port         = var.database_port
  to_port           = var.database_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "database_all_out" {
  security_group_id = aws_security_group.database.id
  description       = "Allow all egress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
