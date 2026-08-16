##############################################################################
# CoreDNS: the cluster's DNS addon, plus its Security-Groups-for-Pods policy.
#
# The addon is not declared inside modules/eks's own `addons` block -- it
# must not be created until the kube-system Fargate profile exists
# (foundation's module.fargate_profile), or it has nowhere to schedule at
# cluster bring-up.
#
# Instantiated from terraform/envs/prod/platform, not foundation, because
# the SecurityGroupPolicy below is a Kubernetes API object foundation has
# no provider for -- see platform's own providers.tf comment for why the
# two-stage split exists at all. Bundling the addon itself in here too
# (rather than splitting it back out to foundation) keeps CoreDNS's AWS
# resource and its Kubernetes resource in one module instead of two root
# modules coordinating around a shared naming convention.
##############################################################################

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
  description       = "Kubernetes API server -- watches Service/Endpoints/EndpointSlice"
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
