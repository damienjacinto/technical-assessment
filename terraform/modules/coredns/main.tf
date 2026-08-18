# CoreDNS addon + its Security-Groups-for-Pods policy. Not in modules/eks's
# `addons` block. Can't create before the Fargate profile exists.
# Instantiated from platform: needs a Kubernetes provider foundation lacks.

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

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-coredns-sg"
  description = "CoreDNS pods (Security Groups for Pods)"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-coredns-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "dns_udp" {
  security_group_id = aws_security_group.this.id
  description       = "DNS queries from anywhere in the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "dns_tcp" {
  security_group_id = aws_security_group.this.id
  description       = "DNS queries (TCP fallback) from anywhere in the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "kubelet_metrics" {
  security_group_id = aws_security_group.this.id
  description       = "kubelet resource metrics, scraped by metrics-server"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 10250
  to_port           = 10250
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "coredns_metrics" {
  security_group_id = aws_security_group.this.id
  description       = "CoreDNS own Prometheus metrics, scraped by kube-prometheus-stack ServiceMonitor"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 9153
  to_port           = 9153
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "upstream_dns" {
  security_group_id = aws_security_group.this.id
  description       = "Forwarding to the VPC Amazon-provided DNS resolver"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "api_server" {
  security_group_id = aws_security_group.this.id
  description       = "Kubernetes API server. Watches Service/Endpoints/EndpointSlice"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "kubectl_manifest" "security_group_policy" {
  yaml_body = yamlencode({
    apiVersion = "vpcresources.k8s.aws/v1beta1"
    kind       = "SecurityGroupPolicy"
    metadata = {
      name      = "coredns"
      namespace = "kube-system"
    }
    spec = {
      podSelector = {
        matchLabels = {
          "k8s-app" = "kube-dns"
        }
      }
      securityGroups = {
        groupIds = [aws_security_group.this.id, var.cluster_security_group_id]
      }
    }
  })
}
