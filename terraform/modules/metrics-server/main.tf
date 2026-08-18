# metrics-server as an EKS addon, not in modules/eks's `addons` block: the
# addon schedules onto Karpenter's "tools" nodepool, which doesn't exist yet
# at foundation-stage cluster creation. Instantiated from platform instead,
# after module.karpenter. Same pattern as modules/coredns.

data "aws_eks_addon_version" "metrics_server" {
  addon_name         = "metrics-server"
  kubernetes_version = var.cluster_version
  most_recent        = var.addon_version == null
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name  = var.cluster_name
  addon_name    = "metrics-server"
  addon_version = coalesce(var.addon_version, data.aws_eks_addon_version.metrics_server.version)

  configuration_values = jsonencode({
    replicas = 1
    nodeSelector = {
      "karpenter.sh/nodepool" = "tools"
    }
    tolerations = [
      { key = "dedicated", operator = "Equal", value = "tools", effect = "NoSchedule" },
    ]
  })

  tags = var.tags
}
