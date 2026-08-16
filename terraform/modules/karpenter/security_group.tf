# Security Groups for Pods, scoping the controller down from the broad
# shared cluster SG every unmatched Fargate pod otherwise falls back to.
# Requires AmazonEKSVPCResourceController on the cluster role
# (modules/eks/main.tf). Ports are Karpenter's v1 defaults (webhook 8443,
# metrics 8080, health 8081) -- reconcile against chart values for
# var.karpenter_chart_version before applying, these shift across releases.
resource "aws_security_group" "controller" {
  name        = "${var.name_prefix}-karpenter-controller-sg"
  description = "Karpenter controller pod (Security Groups for Pods)"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-karpenter-controller-sg" })
}

# Unrestricted, not scoped to var.vpc_cidr/443: narrow egress broke the
# controller three separate times (EC2/SQS/Pricing APIs, the Pod Identity
# Agent's link-local endpoint, ...) before this. A controller calling AWS
# APIs it doesn't fully enumerate in advance isn't a good fit for
# network-layer scoping -- the IAM policy in iam.tf is the real boundary.
resource "aws_vpc_security_group_egress_rule" "controller_all_out" {
  security_group_id = aws_security_group.controller.id
  description       = "Unrestricted -- see comment above"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
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

# var.cluster_security_group_id alongside the custom SG, not instead of it:
# a SecurityGroupPolicy's groupIds *replaces* Fargate's default cluster SG
# rather than adding to it. Without it, the pod hangs in an endless "Pod
# provisioning timed out" loop (AWS-documented; hit this directly).
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
        groupIds = [aws_security_group.controller.id, var.cluster_security_group_id]
      }
    }
  })
}
