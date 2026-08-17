# Stage 1 of 2: everything needed before the kubernetes/helm/kubectl
# providers can target a live cluster (platform is stage 2). VPC, EKS
# control plane, Fargate profile, security baseline -- Pod Identity roles
# live in platform instead, alongside what actually uses them.

locals {
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"

  azs = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = var.repository
    Owner       = var.owner
    # Reserved, not yet populated -- see docs/ARCHITECTURE.md naming/tagging
    # section: these get real values when the data layer lands, rather than
    # being retrofitted later.
    CostCenter         = ""
    DataClassification = ""
  }
}

module "vpc" {
  source = "../../../modules/vpc"

  name_prefix  = local.name_prefix
  tags         = merge(local.tags, { Component = "networking" })
  account_id   = data.aws_caller_identity.current.account_id
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr
  azs          = local.azs
  cluster_name = local.cluster_name
}

module "eks" {
  source = "../../../modules/eks"

  name_prefix                     = local.name_prefix
  cluster_name                    = local.cluster_name
  cluster_version                 = var.cluster_version
  vpc_id                          = module.vpc.vpc_id
  private_subnet_ids              = module.vpc.private_subnet_ids
  public_endpoint_allowed_cidrs   = var.public_endpoint_allowed_cidrs
  additional_admin_principal_arns = var.additional_admin_principal_arns
  addon_versions                  = var.addon_versions
  tags                            = merge(local.tags, { Component = "compute-control-plane" })
}

module "fargate_profile" {
  source = "../../../modules/fargate-profile"

  name_prefix        = local.name_prefix
  cluster_name       = module.eks.cluster_name
  aws_region         = var.aws_region
  account_id         = data.aws_caller_identity.current.account_id
  private_subnet_ids = module.vpc.private_subnet_ids
  kms_key_arn        = module.security_baseline.general_kms_key_arn
  tags               = merge(local.tags, { Component = "compute-fargate" })
}

module "security_baseline" {
  source = "../../../modules/security-baseline"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr
  tags        = merge(local.tags, { Component = "security" })
}
