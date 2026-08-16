##############################################################################
# kube-system Fargate profile: CoreDNS + the Karpenter controller run here,
# not on Karpenter-managed EC2 nodes.
#
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

resource "aws_cloudwatch_log_group" "fargate" {
  name = "/aws/eks/${var.cluster_name}/fargate"
  # Operational/debugging logs (CoreDNS queries, Karpenter's provisioning
  # decisions), not a security audit trail -- shorter retention than the
  # WAF log group's 1 year is appropriate here.
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_iam_role_policy" "fargate_logging" {
  name = "${var.name_prefix}-fargate-logging"
  role = aws_iam_role.fargate_pod_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:${aws_cloudwatch_log_group.fargate.name}:*"
    }]
  })
}

resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = "${var.name_prefix}-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn

  subnet_ids = var.private_subnet_ids

  # Label-scoped on purpose, not `namespace = "kube-system"` alone: every
  # other kube-system controller (ALB controller, ...) relies on these two
  # selectors staying this precise to stay OFF Fargate implicitly, rather
  # than each one needing its own anti-affinity to opt out. Broadening
  # either selector (e.g. dropping the label match) would silently pull
  # those controllers onto Fargate too.

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
