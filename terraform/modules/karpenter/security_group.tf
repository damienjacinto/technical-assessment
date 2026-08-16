# Security Groups for Pods, scoping down from the shared cluster SG.
# Requires AmazonEKSVPCResourceController (modules/eks/main.tf). Ports
# are Karpenter v1 defaults -- reconcile against chart values before
# bumping var.karpenter_chart_version.
resource "aws_security_group" "controller" {
  name        = "${var.name_prefix}-karpenter-controller-sg"
  description = "Karpenter controller pod (Security Groups for Pods)"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-karpenter-controller-sg" })
}

# Unrestricted, not scoped to vpc_cidr/443: narrow egress broke the
# controller repeatedly (EC2/SQS/Pricing APIs, Pod Identity Agent) --
# iam.tf's IAM policy is the real boundary here.
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

# cluster_security_group_id alongside the custom SG, not instead: groupIds
# *replaces* Fargate's default cluster SG. Without it, pods hang in an
# endless "Pod provisioning timed out" loop (hit this directly).
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
