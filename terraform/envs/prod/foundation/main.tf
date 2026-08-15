##############################################################################
# Stage 1 of 2: everything that must exist before the kubernetes/helm/kubectl
# Terraform providers can be configured against a live cluster (envs/prod/platform
# is stage 2). VPC, EKS control plane, the kube-system Fargate profile,
# security baseline, and the-redemption's placeholder Pod Identity role.
##############################################################################

locals {
  # Single source of truth for naming/tags -- every module below receives
  # these as inputs rather than inventing its own naming logic.
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

  name_prefix                   = local.name_prefix
  cluster_name                  = local.cluster_name
  cluster_version               = var.cluster_version
  vpc_id                        = module.vpc.vpc_id
  private_subnet_ids            = module.vpc.private_subnet_ids
  public_endpoint_allowed_cidrs = var.public_endpoint_allowed_cidrs
  tags                          = merge(local.tags, { Component = "compute-control-plane" })
}

module "fargate_profile" {
  source = "../../../modules/fargate-profile"

  name_prefix        = local.name_prefix
  cluster_name       = module.eks.cluster_name
  aws_region         = var.aws_region
  account_id         = data.aws_caller_identity.current.account_id
  private_subnet_ids = module.vpc.private_subnet_ids
  tags               = merge(local.tags, { Component = "compute-fargate" })
}

# CoreDNS must not be created until the kube-system Fargate profile exists,
# or it has nowhere to schedule at cluster bring-up -- see eks module's
# main.tf comment. That ordering is expressed here via depends_on.
module "coredns" {
  source = "../../../modules/coredns"

  cluster_name    = module.eks.cluster_name
  cluster_version = var.cluster_version
  tags            = merge(local.tags, { Component = "compute-control-plane" })

  depends_on = [module.fargate_profile]
}

module "security_baseline" {
  source = "../../../modules/security-baseline"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr
  tags        = merge(local.tags, { Component = "security" })
}

# the-redemption's own Pod Identity role. Deliberately zero permissions
# attached -- a least-privilege placeholder, since the data layer (what this
# role would actually need access to) is explicitly out of scope for this
# build. The ServiceAccount/role association wiring exists so a future
# data-layer decision only needs to attach a policy here, not touch app
# manifests.
module "pod_identity" {
  source = "../../../modules/pod-identity"

  name_prefix          = local.name_prefix
  role_suffix          = "the-redemption"
  cluster_name         = module.eks.cluster_name
  namespace            = "the-redemption"
  service_account_name = "the-redemption"
  managed_policy_arns  = []
  tags                 = merge(local.tags, { Component = "the-redemption-app" })
}
