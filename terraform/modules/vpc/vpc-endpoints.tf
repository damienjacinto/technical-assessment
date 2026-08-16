##############################################################################
# VPC Endpoints: keep image pulls, Pod Identity/STS credential exchange, and
# log delivery off the NAT/internet path entirely (resilience +
# defense-in-depth).
##############################################################################

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpc-endpoints-sg"
  description = "Interface VPC endpoints - HTTPS ingress from the private/app tier only"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc-endpoints-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "HTTPS from private/app tier"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoints_all_out" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "AWS PrivateLink egress for the interface endpoints own service traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Gateway endpoint: S3 (free, route-table based).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)
  tags              = merge(var.tags, { Name = "${var.name_prefix}-s3-endpoint" })
}

# Interface endpoints: ECR (image pulls), STS (Pod Identity credential
# exchange), CloudWatch Logs, KMS.
locals {
  interface_endpoint_services = [
    "ecr.api",
    "ecr.dkr",
    "sts",
    "logs",
    "kms",
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoint_services)

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-${replace(each.value, ".", "-")}-endpoint" })
}
