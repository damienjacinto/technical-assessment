##############################################################################
# kube-system Fargate profile: CoreDNS + the Karpenter controller run here,
# not on Karpenter-managed EC2 nodes.
#
# Why: (1) bootstrap chicken-and-egg -- if Karpenter only ran on the nodes
# it provisions, an empty cluster could never scale up from zero; Fargate is
# a substrate that always exists independent of NodePool state. (2)
# blast-radius isolation -- CoreDNS is cluster-critical (every Service
# depends on DNS resolution) and shouldn't share EC2 capacity that gets
# churned by Spot interruptions, consolidation, or an AZ failure.
##############################################################################

resource "aws_iam_role" "fargate_pod_execution" {
  name = "${var.name_prefix}-fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:eks:${var.aws_region}:${var.account_id}:fargateprofile/${var.cluster_name}/*"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution" {
  role       = aws_iam_role.fargate_pod_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = "${var.name_prefix}-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn

  subnet_ids = var.private_subnet_ids

  # CoreDNS.
  selector {
    namespace = "kube-system"
    labels = {
      "k8s-app" = "kube-dns"
    }
  }

  # The Karpenter controller (standard label set by its Helm chart).
  selector {
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "karpenter"
    }
  }

  tags = var.tags
}
