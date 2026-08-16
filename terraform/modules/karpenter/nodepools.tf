# EC2NodeClass/NodePool live here, in Terraform, not GitOps -- see main.tf.
# kubectl_manifest (alekc/kubectl), not the built-in kubernetes_manifest:
# that provider fetches its target CRD's schema at *plan* time, which fails
# on a from-scratch cluster since these CRDs (installed by helm.tf) don't
# exist yet at the first apply's start.

resource "kubectl_manifest" "ec2nodeclass" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = var.name_prefix
    }
    spec = {
      amiFamily = "Bottlerocket"
      # Pinned (var.bottlerocket_ami_version), not "@latest" -- Karpenter's
      # own docs recommend against latest for production: it drifts
      # silently with no PR attached to the change.
      amiSelectorTerms = [
        { alias = "bottlerocket@${var.bottlerocket_ami_version}" },
      ]
      role = aws_iam_role.node.name
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } },
      ]
      securityGroupSelectorTerms = [
        { tags = { "kubernetes.io/cluster/${var.cluster_name}" = "owned" } },
      ]
      tags = merge(var.tags, { ManagedBy = "karpenter" })
    }
  })

  depends_on = [helm_release.karpenter]
}

# On-demand baseline + Spot burst overflow, tiered by an *enforced* limits
# ceiling (not just weight). See docs/ARCHITECTURE.md's Scalability
# Strategy section.
resource "kubectl_manifest" "nodepool_on_demand_baseline" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "on-demand-baseline"
    }
    spec = {
      weight = 100
      template = {
        metadata = {
          labels = { "capacity-tier" = "on-demand-baseline" }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = var.name_prefix
          }
          requirements = [
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values = [
                "m6i.large", "m6i.xlarge",
                "m5.large", "m5.xlarge",
                "c6i.large", "c6i.xlarge",
              ]
            },
            { key = "topology.kubernetes.io/zone", operator = "In", values = ["us-east-1a", "us-east-1b", "us-east-1c"] },
          ]
          # Bounds node lifetime so drift/leaks can't accumulate silently,
          # and exercises the pod-rescheduling/PDB path continuously.
          expireAfter = "24h"
        }
      }
      limits = {
        cpu    = "200"
        memory = "400Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30m"
        budgets = [
          { nodes = "20%" },
          # Flash-sale blackout: 0 disruption so recycling/consolidation
          # never rotates capacity out at peak load. Placeholder schedule.
          { nodes = "0", schedule = "0 12 * * 5", duration = "2h" },
        ]
      }
    }
  })

  depends_on = [kubectl_manifest.ec2nodeclass]
}

# Absorbs everything past the baseline ceiling -- the flash-sale spike
# lands here by construction.
resource "kubectl_manifest" "nodepool_spot_burst" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "spot-burst"
    }
    spec = {
      weight = 50
      template = {
        metadata = {
          labels = { "capacity-tier" = "spot-burst" }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = var.name_prefix
          }
          requirements = [
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values = [
                "m6i.large", "m6i.xlarge",
                "m5.large", "m5.xlarge",
                "c6i.large", "c6i.xlarge",
                "m6a.large", "m6a.xlarge",
                "c6a.large", "c6a.xlarge",
              ]
            },
            { key = "topology.kubernetes.io/zone", operator = "In", values = ["us-east-1a", "us-east-1b", "us-east-1c"] },
          ]
          expireAfter = "24h"
        }
      }
      limits = {
        cpu    = "2000"
        memory = "4000Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
        budgets = [
          { nodes = "50%" },
          { nodes = "0", schedule = "0 12 * * 5", duration = "2h" },
        ]
      }
    }
  })

  depends_on = [kubectl_manifest.ec2nodeclass]
}

# Dedicated tooling pool, kept off the app's own capacity via a taint --
# only pods with a matching toleration (kubernetes/infra-apps/*/values.yaml)
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
              values   = ["m6i.large", "m5.large", "c6i.large"]
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
