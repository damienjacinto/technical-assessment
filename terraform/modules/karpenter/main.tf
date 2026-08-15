##############################################################################
# Karpenter: controller Pod Identity role, EC2 node IAM role/instance profile,
# the Helm release for the controller itself, and its NodePool/EC2NodeClass.
#
# NodePool/EC2NodeClass are created here, in Terraform, not in GitOps --
# deliberately, to break a real bootstrap deadlock: ArgoCD's own pods aren't
# Fargate-eligible (module.fargate_profile only selects kube-system), so they
# need a Karpenter-provisioned EC2 node to schedule onto. But Karpenter can't
# provision anything without a NodePool, and a NodePool synced by ArgoCD
# can't exist until ArgoCD's own pods are already running. Creating the
# NodePool/EC2NodeClass in the same apply as the Helm release breaks that
# cycle: by the time ArgoCD installs later in this same platform stage, a
# NodePool already exists for it to land on.
#
# Trade-off accepted knowingly: NodePool tuning (limits, disruption budgets,
# flash-sale blackout windows) now needs a `terraform apply` + review instead
# of a GitOps commit, and these 3 resources lose kubeconform's Kubernetes
# schema validation (scripts/validate-kubernetes.sh) -- `terraform validate`
# doesn't check a manifest's content against the K8s OpenAPI schema, so a
# typo'd/missing required field here only surfaces at `apply` time against
# the live API server, not in CI.
#
# These use kubectl_manifest (alekc/kubectl provider), not the built-in
# kubernetes_manifest: kubernetes_manifest fetches its target CRD's schema
# at *plan* time, which fails on a from-scratch cluster since the
# EC2NodeClass/NodePool CRDs (installed by the Helm release below) don't
# exist yet at the start of the very first apply -- depends_on only orders
# applies, it doesn't defer that plan-time schema fetch. kubectl_manifest
# applies these as opaque YAML instead, so it never hits that wall; a
# single `terraform apply` here always works, no -target step needed.
#
# The controller pod runs on the kube-system Fargate profile (see
# module.fargate_profile) -- EKS's Fargate scheduler auto-injects the
# eks.amazonaws.com/compute-type=fargate nodeSelector onto any pod matching
# a Fargate profile's namespace+label selector, so nothing extra is needed
# here to pin it there.
##############################################################################

module "controller_pod_identity" {
  source = "../pod-identity"

  name_prefix          = var.name_prefix
  role_suffix          = "karpenter-controller"
  cluster_name         = var.cluster_name
  namespace            = "kube-system"
  service_account_name = "karpenter"
  inline_policy_json   = data.aws_iam_policy_document.karpenter_controller.json
  tags                 = var.tags
}

# Representative Karpenter controller policy, following the shape of
# Karpenter's official getting-started IAM policy. Reconcile this against
# the current Karpenter docs for the pinned chart version
# (var.karpenter_chart_version) before applying -- required actions have
# shifted across Karpenter's v1 API releases and this is security-sensitive.
data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "AllowScopedEC2InstanceActions"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:RunInstances",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/karpenter.sh/discovery"
      values   = [var.cluster_name]
    }
  }

  statement {
    sid    = "AllowScopedInstanceTermination"
    effect = "Allow"
    actions = [
      "ec2:TerminateInstances",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/karpenter.sh/discovery"
      values   = [var.cluster_name]
    }
  }

  statement {
    sid    = "AllowDescribeAndPricingActions"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "eks:DescribeCluster",
      "pricing:GetProducts",
      "ssm:GetParameter",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowPassingNodeRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.node.arn]
  }

  statement {
    sid    = "AllowInterruptionQueueActions"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.interruption.arn]
  }
}

##############################################################################
# EC2 node IAM role Karpenter launches instances with. No SSH: SSM Session
# Manager access instead, so there's no key-pair/bastion attack surface.
##############################################################################

resource "aws_iam_role" "node" {
  name = "${var.name_prefix}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name_prefix}-karpenter-node-profile"
  role = aws_iam_role.node.name
  tags = var.tags
}

##############################################################################
# SQS queue for EC2 Spot interruption / rebalance-recommendation /
# instance-terminating events, which Karpenter consumes to cordon and
# proactively reschedule before termination rather than reacting to a bare
# eviction.
##############################################################################

resource "aws_sqs_queue" "interruption" {
  name = "${var.name_prefix}-karpenter-interruption"
  # 5 minutes: Karpenter polls and consumes these events continuously, so
  # they should never need to sit in the queue for long -- a short
  # retention just bounds how long a stale event could theoretically
  # linger if the controller were briefly down, not a value Karpenter
  # itself requires.
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgeAndSpotServiceToSendMessages"
        Effect    = "Allow"
        Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.interruption.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name = "${var.name_prefix}-karpenter-spot-interruption"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "rebalance_recommendation" {
  name = "${var.name_prefix}-karpenter-rebalance"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "rebalance_recommendation" {
  rule = aws_cloudwatch_event_rule.rebalance_recommendation.name
  arn  = aws_sqs_queue.interruption.arn
}

##############################################################################
# Security Groups for Pods: every Fargate pod that doesn't match a
# SecurityGroupPolicy silently falls back to the broad, shared EKS cluster
# security group -- this scopes the controller down to only what it needs.
# Requires the AmazonEKSVPCResourceController policy on the cluster role
# (see terraform/modules/eks/main.tf) and no VPC CNI configuration, since
# this cluster's Fargate-only pods use a SecurityGroupPolicy directly rather
# than the branch-ENI path EC2-node pods would need.
#
# Ports are Karpenter's documented v1 defaults (webhook 8443, metrics 8080,
# health probe 8081) -- reconcile against the actual chart values for
# var.karpenter_chart_version before applying; these have shifted across
# Karpenter releases before (see the controller IAM policy's own comment
# above for the same caveat).
##############################################################################

resource "aws_security_group" "controller" {
  name        = "${var.name_prefix}-karpenter-controller-sg"
  description = "Karpenter controller pod (Security Groups for Pods)"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-karpenter-controller-sg" })
}

resource "aws_vpc_security_group_egress_rule" "controller_https_out" {
  security_group_id = aws_security_group.controller.id
  description       = "AWS API calls via VPC interface endpoints, and the Kubernetes API server"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "controller_webhook" {
  security_group_id = aws_security_group.controller.id
  description       = "Admission/conversion webhook, called by the API server"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "controller_metrics" {
  security_group_id = aws_security_group.controller.id
  description       = "Prometheus scrape"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "controller_health_probe" {
  security_group_id = aws_security_group.controller.id
  description       = "Liveness/readiness probe"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 8081
  to_port           = 8081
  ip_protocol       = "tcp"
}

resource "kubectl_manifest" "controller_security_group_policy" {
  yaml_body = yamlencode({
    apiVersion = "vpcresources.k8s.aws/v1beta1"
    kind       = "SecurityGroupPolicy"
    metadata = {
      name      = "karpenter-controller"
      namespace = "kube-system"
    }
    spec = {
      podSelector = {
        matchLabels = {
          "app.kubernetes.io/name" = "karpenter"
        }
      }
      securityGroups = {
        groupIds = [aws_security_group.controller.id]
      }
    }
  })
}

##############################################################################
# The Karpenter controller itself.
##############################################################################

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "kube-system"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_chart_version
  create_namespace = false

  # Ensures the SecurityGroupPolicy exists before the controller's first
  # pod is created -- SGs-for-Pods assigns the security group at pod ENI
  # creation time, so a policy added after the pod already exists wouldn't
  # take effect until the pod happens to restart for some other reason.
  depends_on = [kubectl_manifest.controller_security_group_policy]

  values = [
    yamlencode({
      # No serviceAccount.annotations override: Pod Identity ties
      # module.controller_pod_identity's role to this ServiceAccount via
      # the aws_eks_pod_identity_association, not a role-arn annotation.
      # The chart's default ServiceAccount name ("karpenter") already
      # matches what that association was created for.
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = aws_sqs_queue.interruption.name
      }
      # Belt-and-suspenders alongside the Fargate profile's own selector
      # match -- makes the intent explicit in the chart values too.
      nodeSelector = {
        "eks.amazonaws.com/compute-type" = "fargate"
      }
    })
  ]
}

##############################################################################
# EC2NodeClass: the launch template Karpenter uses for both NodePools below.
# depends_on the Helm release because its CRD (installed by the chart) must
# exist before the API server will accept an instance of it.
##############################################################################

resource "kubectl_manifest" "ec2nodeclass" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = var.name_prefix
    }
    spec = {
      amiFamily = "Bottlerocket"
      # Karpenter v1's EC2NodeClass requires amiSelectorTerms explicitly --
      # amiFamily alone is no longer sufficient. Pinned to a specific
      # release (var.bottlerocket_ami_version) rather than "@latest", which
      # Karpenter's own docs recommend against for production: it drifts
      # silently whenever AWS publishes a new Bottlerocket AMI, with no
      # PR/review attached to that change.
      amiSelectorTerms = [
        { alias = "bottlerocket@${var.bottlerocket_ami_version}" },
      ]
      role = aws_iam_role.node.name
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } },
      ]
      # "owned" (not "shared", which is what the VPC module's subnets carry)
      # matches the tag terraform-aws-modules/eks/aws auto-applies to the
      # cluster security group it creates -- Karpenter's canonical example
      # configs target that exact tag.
      securityGroupSelectorTerms = [
        { tags = { "kubernetes.io/cluster/${var.cluster_name}" = "owned" } },
      ]
      # ManagedBy overridden to "karpenter" (var.tags carries "terraform"):
      # these are tags Karpenter stamps onto the EC2 instances/ENIs/volumes
      # it provisions dynamically, not onto a Terraform-managed resource.
      tags = merge(var.tags, { ManagedBy = "karpenter" })
    }
  })

  depends_on = [helm_release.karpenter]
}

##############################################################################
# NodePools: guaranteed on-demand baseline + Spot burst overflow, tiered by
# an *enforced* limits ceiling (not just weight, which is only a soft
# scheduling preference). See docs/ARCHITECTURE.md's Scalability Strategy
# section for the full reasoning.
##############################################################################

# Guaranteed capacity for steady-state traffic. weight: 100 makes Karpenter
# prefer this pool, but the real guarantee is `limits` below: once that
# ceiling is saturated Karpenter physically cannot schedule more here, so
# overflow (the 10x flash-sale spike) falls through to spot-burst by
# construction, not by hoping the scheduler picks right.
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
              # Diversified across families/sizes -- more bin-packing
              # headroom, and the standard mitigation for capacity risk
              # even on-demand.
              values = [
                "m6i.large", "m6i.xlarge",
                "m5.large", "m5.xlarge",
                "c6i.large", "c6i.xlarge",
              ]
            },
            { key = "topology.kubernetes.io/zone", operator = "In", values = ["us-east-1a", "us-east-1b", "us-east-1c"] },
          ]
          # Cordon/drain/replace every node at most a day old, rolling,
          # respecting PDBs -- bounds node lifetime so long-lived nodes
          # can't mask config drift, slow leaks, or unpatched packages, and
          # continuously exercises the pod-rescheduling/PDB path instead of
          # that only getting tested during a real incident.
          expireAfter = "24h"
        }
      }
      limits = {
        # Sized to steady-state traffic -- tune against real load-test data
        # before this ever sees production traffic.
        cpu    = "200"
        memory = "400Gi"
      }
      disruption = {
        # No churn of steady-state capacity: only ever reclaim nodes that
        # are already empty, never consolidate/repack while serving traffic.
        consolidationPolicy = "WhenEmpty"
        # Required by the NodePool schema regardless of consolidationPolicy.
        # Deliberately longer than spot-burst's 1m -- an empty on-demand
        # node is far less likely to be transient bin-packing noise than an
        # empty spot node, so there's no cost pressure to reclaim it
        # immediately.
        consolidateAfter = "30m"
        budgets = [
          { nodes = "20%" },
          # Blackout window during a known flash sale: caps disruption at 0
          # nodes so the 24h expireAfter recycling and consolidation can
          # never rotate capacity out right when load is highest. Fill in
          # the real sale calendar here -- example below is a placeholder
          # recurring Friday 12:00-14:00 UTC window.
          { nodes = "0", schedule = "0 12 * * 5", duration = "2h" },
        ]
      }
    }
  })

  depends_on = [kubectl_manifest.ec2nodeclass]
}

# Absorbs everything past the on-demand-baseline ceiling -- the 10x
# flash-sale spike lands here by construction. Spot, cost-efficient, and
# aggressively consolidated once the spike passes.
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
              # Wider diversification than on-demand-baseline -- Spot
              # capacity risk is mitigated by spreading across more
              # families/sizes.
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
        # Aggressive cleanup once the spike passes: reclaim nodes that are
        # empty OR underutilized, not just empty.
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
        budgets = [
          { nodes = "50%" },
          # Same flash-sale blackout as on-demand-baseline -- keep in sync.
          { nodes = "0", schedule = "0 12 * * 5", duration = "2h" },
        ]
      }
    }
  })

  depends_on = [kubectl_manifest.ec2nodeclass]
}
