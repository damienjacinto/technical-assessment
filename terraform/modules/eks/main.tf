##############################################################################
# EKS cluster: control plane only. No EC2 node groups are created here --
# Karpenter (module.karpenter, in the platform stage) provisions all EC2
# capacity for workloads, and kube-system (CoreDNS + the Karpenter
# controller itself) runs on the Fargate profile from module.fargate_profile.
# That split solves the bootstrap chicken-and-egg: Karpenter can't run only
# on the nodes it provisions, or an empty cluster could never scale up.
##############################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0" # requires AWS provider >= 6.0 -- see providers.tf

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Private endpoint always on; public endpoint restricted to explicit
  # CIDRs (least privilege) rather than 0.0.0.0/0.
  endpoint_private_access      = true
  endpoint_public_access       = var.public_endpoint_enabled
  endpoint_public_access_cidrs = var.public_endpoint_allowed_cidrs

  enabled_log_types = var.cluster_enabled_log_types

  # Envelope encryption for Kubernetes Secrets. Owned here rather than by
  # security-baseline: security-baseline's app security group needs this
  # module's cluster_security_group_id output, so having this module in
  # turn depend on security-baseline for a KMS key would be circular. This
  # key is scoped to exactly one concern (secrets envelope encryption) and
  # the underlying module's own well-tested default handles rotation/policy,
  # so self-managing it here is the pragmatic call.
  create_kms_key                = true
  kms_key_description           = "${var.name_prefix} EKS Kubernetes Secrets envelope encryption"
  kms_key_enable_default_policy = true
  encryption_config = {
    resources = ["secrets"]
  }

  # No IRSA: every ServiceAccount in this stack authenticates via EKS Pod
  # Identity instead (see modules/pod-identity), so the OIDC IdP IRSA
  # depends on isn't needed -- one less standing trust relationship.
  enable_irsa = false

  # Required for Security Groups for Pods (SecurityGroupPolicy) on the
  # kube-system Fargate profile -- v21 of this module stopped attaching it
  # by default (previously implicit). Without it, the VPC Resource
  # Controller can't manage the branch ENIs a SecurityGroupPolicy needs, and
  # every Fargate pod silently falls back to the broad, shared cluster
  # security group regardless of what SecurityGroupPolicy exists.
  iam_role_additional_policies = {
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }

  # No managed/self-managed node groups: see module docstring above.
  eks_managed_node_groups  = {}
  self_managed_node_groups = {}

  addons = {
    vpc-cni = {
      before_compute = true
      # v21 defaults most_recent to true, which is what we want, but stated
      # explicitly rather than relying on a default that could change again.
      most_recent = true
      configuration_values = jsonencode({
        env = {
          # Multiplies pod density per ENI -- the standard fix for VPC CNI
          # IP exhaustion under a 10x flash-sale scale-out.
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
    # coredns is intentionally NOT declared here. It must not be created
    # until the kube-system Fargate profile exists (module.fargate_profile),
    # otherwise it has nowhere to schedule at cluster-bring-up time. That
    # ordering dependency is expressed at the composition level in
    # envs/prod/foundation/main.tf via an explicit depends_on, not baked
    # into this reusable module.
  }

  tags = var.tags
}
