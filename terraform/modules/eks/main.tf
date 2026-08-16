##############################################################################
# EKS cluster: control plane only. No EC2 node groups are created here --
# Karpenter (module.karpenter, in the platform stage) provisions all EC2
# capacity for workloads, and kube-system (CoreDNS + the Karpenter
# controller itself) runs on the Fargate profile from module.fargate_profile.
# That split solves the bootstrap chicken-and-egg: Karpenter can't run only
# on the nodes it provisions, or an empty cluster could never scale up.
##############################################################################

# Auto-detected fallback for public_endpoint_allowed_cidrs, queried only
# when actually needed (public endpoint on, no explicit CIDRs given) to
# avoid an unnecessary external call otherwise -- e.g. a fully-private
# cluster's plan/apply never hits the network for this. Uses AWS's own
# IP-echo endpoint rather than a third-party one, since this stack already
# trusts AWS.
#
# Trade-off accepted knowingly: this makes endpoint_public_access_cidrs
# non-deterministic across operators/CI runners -- every apply from a
# different network re-triggers an EKS VPC config update to swap the CIDR
# to whichever machine is applying right now. Set
# public_endpoint_allowed_cidrs explicitly once real office/VPN/CI runner
# ranges exist (see modules/eks/NOTES.md for the target design) to get a
# stable value instead.
data "http" "my_ip" {
  count = var.public_endpoint_enabled && length(var.public_endpoint_allowed_cidrs) == 0 ? 1 : 0

  url = "https://checkip.amazonaws.com"
  request_headers = {
    Accept = "text/plain"
  }
}

locals {
  public_endpoint_allowed_cidrs = length(var.public_endpoint_allowed_cidrs) > 0 ? var.public_endpoint_allowed_cidrs : (
    var.public_endpoint_enabled ? ["${trimspace(data.http.my_ip[0].response_body)}/32"] : []
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  endpoint_private_access      = true
  endpoint_public_access       = var.public_endpoint_enabled
  endpoint_public_access_cidrs = local.public_endpoint_allowed_cidrs
  enabled_log_types            = var.cluster_enabled_log_types

  create_kms_key                = true
  kms_key_description           = "${var.name_prefix} EKS Kubernetes Secrets envelope encryption"
  kms_key_enable_default_policy = true
  encryption_config = {
    resources = ["secrets"]
  }

  # No IRSA: every ServiceAccount in this stack authenticates via EKS Pod Identity instead
  enable_irsa = false

  iam_role_additional_policies = {
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }

  # No managed/self-managed node groups: see module docstring above.
  eks_managed_node_groups  = {}
  self_managed_node_groups = {}

  addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  tags = var.tags
}
