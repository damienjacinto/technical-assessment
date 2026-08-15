##############################################################################
# CoreDNS: the cluster's DNS addon. Not declared inside modules/eks's own
# `addons` block -- it must not be created until the kube-system Fargate
# profile exists (modules/fargate-profile), or it has nowhere to schedule at
# cluster bring-up. That ordering dependency is expressed by the caller via
# depends_on on this module (see terraform/envs/prod/foundation/main.tf),
# not baked in here, since this module has no direct input tying it to the
# Fargate profile's own resources.
#
# Its Security-Groups-for-Pods SecurityGroupPolicy lives in
# terraform/envs/prod/platform/main.tf, not here -- SecurityGroupPolicy is a
# Kubernetes API object, and this module (instantiated from foundation) only
# has the aws provider available. See that stage's own providers.tf comment
# for why the two-stage split exists in the first place.
##############################################################################

# most_recent = true, same as vpc-cni/kube-proxy/eks-pod-identity-agent in
# modules/eks's own addons block -- resolved explicitly rather than
# omitting addon_version, which would leave AWS's EKS API to silently pick
# its own default version at creation time (not something this repo would
# actually be choosing, and not visible in this HCL or state).
data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = var.cluster_name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.coredns.version
  tags          = var.tags
}
