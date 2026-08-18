# EKS control plane only. Karpenter provisions all EC2 capacity
# (platform stage), kube-system runs on Fargate. Breaks the bootstrap
# chicken-and-egg: Karpenter can't run only on nodes it provisions itself.

# Auto-detected fallback for public_endpoint_allowed_cidrs, queried only
# when needed (public endpoint on, no explicit CIDRs). Trade-off: makes
# the CIDR non-deterministic across operators. Set it explicitly once
# real office/VPN/CI ranges exist (modules/eks/NOTES.md).
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

  upgrade_policy = {
    support_type = "STANDARD"
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # This module's node SG and EKS's own cluster primary SG are both
  # tagged kubernetes.io/cluster/<name>=owned by default (docs/faq.md
  # "expected exactly one securityGroup tagged..."), which broke the ALB
  # Controller's target-group-binding reconciler. This unique tag lets
  # Karpenter's securityGroupSelectorTerms match only this SG.
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

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

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    for idx, arn in var.additional_admin_principal_arns : "admin-${idx}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  iam_role_additional_policies = {
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }

  # No managed/self-managed node groups: see module docstring above.
  eks_managed_node_groups  = {}
  self_managed_node_groups = {}

  addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = !contains(keys(var.addon_versions), "vpc-cni")
      addon_version  = try(var.addon_versions["vpc-cni"], null)
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      })
    }
    kube-proxy = {
      most_recent   = !contains(keys(var.addon_versions), "kube-proxy")
      addon_version = try(var.addon_versions["kube-proxy"], null)
    }
    eks-pod-identity-agent = {
      most_recent   = !contains(keys(var.addon_versions), "eks-pod-identity-agent")
      addon_version = try(var.addon_versions["eks-pod-identity-agent"], null)
    }
  }

  tags = var.tags
}
