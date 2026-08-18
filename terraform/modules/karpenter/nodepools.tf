# EC2NodeClass/NodePool live here, in Terraform, not GitOps. See main.tf.
# kubectl_manifest, not kubernetes_manifest: that provider fetches the
# CRD schema at *plan* time, which fails before helm.tf installs it.

resource "kubectl_manifest" "ec2nodeclass" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = var.name_prefix
    }
    spec = {
      amiFamily = "Bottlerocket"
      # Pinned (var.bottlerocket_ami_version), not "@latest". Karpenter's
      # own docs recommend against latest for production: it drifts
      # silently with no PR attached to the change.
      amiSelectorTerms = [
        { alias = "bottlerocket@${var.bottlerocket_ami_version}" },
      ]
      role = aws_iam_role.node.name
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } },
      ]
      # Not kubernetes.io/cluster/<name>=owned: that tag also matches
      # EKS's cluster primary SG (modules/eks/main.tf), which broke the
      # ALB Controller's target-group-binding reconciler. This tag is
      # unique to the dedicated node SG.
      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } },
      ]
      tags = merge(var.tags, { ManagedBy = "karpenter" })
    }
  })

  depends_on = [helm_release.karpenter, helm_release.karpenter_crd]
}

# Dedicated tooling pool, kept off the app's own capacity via a taint.
# Only pods with a matching toleration (kubernetes/infra-apps/*/values.yaml)
# land here. the-redemption and capacity-buffer deliberately don't get it.
resource "kubectl_manifest" "nodepool_tools" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "tools"
    }
    spec = {
      weight = 10
      template = {
        metadata = {
          labels = { "capacity-tier" = "tools" }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = var.name_prefix
          }
          taints = [
            { key = "dedicated", value = "tools", effect = "NoSchedule" },
          ]
          requirements = [
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values = [
                "m6i.large",
                "m6i.xlarge",
                "m5.large",
                "m5.xlarge",
                "c6i.large",
                "c6i.xlarge"
              ]
            },
            { key = "topology.kubernetes.io/zone", operator = "In", values = ["us-east-1a", "us-east-1b", "us-east-1c"] },
          ]
          expireAfter = "24h"
        }
      }
      limits = {
        cpu    = "50"
        memory = "100Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "5m"
        budgets = [
          { nodes = "20%" },
        ]
      }
    }
  })

  depends_on = [kubectl_manifest.ec2nodeclass]
}
