# VPC: 3 AZ, 3-tier subnetting (public/private/isolated database), NAT
# egress. Built on terraform-aws-modules/vpc/aws rather than hand-rolled
# resources. The standard, heavily exercised way to do this.

locals {
  # Disjoint /16 carve-out: public /24 (ALB+NAT ENIs), private /19
  # (nodes+pods), database /21 (isolated, no NAT/IGW route).
  public_subnet_newbits   = 8 # base /16 + 8 bits = /24
  private_subnet_newbits  = 3 # base /16 + 3 bits = /19
  database_subnet_newbits = 5 # base /16 + 5 bits = /21

  # Offsets chosen so no tier's netnum range overlaps another's.
  private_subnet_netnum_offset  = 1  # skips netnum 0, inside the public /24s
  database_subnet_netnum_offset = 16 # skips the private /19 range (1-3)

  public_subnets = [
    for i, az in var.azs : cidrsubnet(var.vpc_cidr, local.public_subnet_newbits, i)
  ]
  private_subnets = [
    for i, az in var.azs : cidrsubnet(var.vpc_cidr, local.private_subnet_newbits, i + local.private_subnet_netnum_offset)
  ]
  database_subnets = [
    for i, az in var.azs : cidrsubnet(var.vpc_cidr, local.database_subnet_newbits, i + local.database_subnet_netnum_offset)
  ]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6" # requires AWS provider >= 6.0, see providers.tf

  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.database_subnets

  # NAT: one NAT Gateway per AZ, the standard HA pattern.
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # Database tier stays isolated: no NAT, no IGW route. The module defaults
  # already do this (no route added unless explicitly requested), stated
  # here for clarity rather than relying on an implicit default.
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_nat_gateway_route      = false
  create_database_internet_gateway_route = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs -> KMS-encrypted S3, ACCEPT + REJECT.
  enable_flow_log                   = true
  flow_log_destination_type         = "s3"
  flow_log_destination_arn          = aws_s3_bucket.flow_logs.arn
  flow_log_traffic_type             = "ALL"
  flow_log_file_format              = "parquet"
  flow_log_max_aggregation_interval = 60

  # AWS Load Balancer Controller subnet auto-discovery convention.
  public_subnet_tags = merge(var.tags, {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
  private_subnet_tags = merge(var.tags, {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    # Karpenter's default subnet discovery selector.
    "karpenter.sh/discovery" = var.cluster_name
  })
  database_subnet_tags = merge(var.tags, {
    Component = "database-isolated"
  })

  tags = var.tags
}
