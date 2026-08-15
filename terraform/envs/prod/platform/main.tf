locals {
  foundation = data.terraform_remote_state.foundation.outputs
}

module "karpenter" {
  source = "../../../modules/karpenter"

  name_prefix              = local.foundation.name_prefix
  cluster_name             = local.foundation.cluster_name
  cluster_endpoint         = local.foundation.cluster_endpoint
  vpc_id                   = local.foundation.vpc_id
  vpc_cidr                 = local.foundation.vpc_cidr
  karpenter_chart_version  = var.karpenter_chart_version
  bottlerocket_ami_version = var.bottlerocket_ami_version
  tags                     = merge(local.foundation.tags, { Component = "compute-autoscaling" })
}

##############################################################################
# CoreDNS's Security-Groups-for-Pods. Lives here, not in foundation
# (terraform/envs/prod/foundation/main.tf's module.coredns), because
# SecurityGroupPolicy is a Kubernetes API object and foundation deliberately
# has no kubernetes/kubectl provider configured -- see that stage's own
# providers.tf comment for why. Every Fargate pod that doesn't match a
# SecurityGroupPolicy falls back to the broad, shared cluster security
# group; this scopes CoreDNS to only what it actually needs.
#
# Accepted bootstrap caveat: on a true from-scratch bring-up, CoreDNS's pod
# already exists (created in the prior foundation apply) by the time this
# SecurityGroupPolicy is created here -- Security-Groups-for-Pods assigns
# the SG at pod ENI creation, so CoreDNS runs on the default cluster SG
# until its pod next recreates for some other reason (an addon version
# bump, a Fargate rotation). Self-resolving, not a functional break.
##############################################################################

resource "aws_security_group" "coredns" {
  name        = "${local.foundation.name_prefix}-coredns-sg"
  description = "CoreDNS pods (Security Groups for Pods)"
  vpc_id      = local.foundation.vpc_id
  tags        = merge(local.foundation.tags, { Name = "${local.foundation.name_prefix}-coredns-sg", Component = "compute-control-plane" })
}

resource "aws_vpc_security_group_ingress_rule" "coredns_dns_udp" {
  security_group_id = aws_security_group.coredns.id
  description       = "DNS queries from anywhere in the VPC"
  cidr_ipv4         = local.foundation.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "coredns_dns_tcp" {
  security_group_id = aws_security_group.coredns.id
  description       = "DNS queries (TCP fallback) from anywhere in the VPC"
  cidr_ipv4         = local.foundation.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "coredns_upstream_dns" {
  security_group_id = aws_security_group.coredns.id
  description       = "Forwarding to the VPC's Amazon-provided DNS resolver"
  cidr_ipv4         = local.foundation.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "coredns_api_server" {
  security_group_id = aws_security_group.coredns.id
  description       = "Kubernetes API server -- watches Service/Endpoints/EndpointSlice"
  cidr_ipv4         = local.foundation.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "kubectl_manifest" "coredns_security_group_policy" {
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
        groupIds = [aws_security_group.coredns.id]
      }
    }
  })
}

module "alb_controller" {
  source = "../../../modules/alb-controller"

  name_prefix   = local.foundation.name_prefix
  cluster_name  = local.foundation.cluster_name
  vpc_id        = local.foundation.vpc_id
  aws_region    = local.foundation.aws_region
  chart_version = var.alb_controller_chart_version
  tags          = merge(local.foundation.tags, { Component = "networking-ingress" })
}

# External Secrets Operator's controller role. Scoped to only the
# secretsmanager paths this project would ever use -- least privilege, not
# a blanket secretsmanager:* grant. Pod Identity pairs this role with the
# ServiceAccount entirely on the AWS side (the aws_eks_pod_identity_association
# below) -- unlike IRSA, kubernetes/infra-apps/external-secrets doesn't need
# this role's ARN threaded into it at all, so there's no
# static-YAML-with-ACCOUNT_ID-placeholder seam to keep in sync here.
module "external_secrets_pod_identity" {
  source = "../../../modules/pod-identity"

  name_prefix          = local.foundation.name_prefix
  role_suffix          = "external-secrets"
  cluster_name         = local.foundation.cluster_name
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  inline_policy_json   = data.aws_iam_policy_document.external_secrets.json
  tags                 = merge(local.foundation.tags, { Component = "security-secrets" })
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${local.foundation.aws_region}:${local.foundation.account_id}:secret:${local.foundation.name_prefix}/*"
    ]
  }
}

module "argocd" {
  source = "../../../modules/argocd"

  argocd_chart_version = var.argocd_chart_version
  git_repo_url         = var.git_repo_url
  git_revision         = var.git_revision
  environment          = local.foundation.environment
  waf_web_acl_arn      = local.foundation.waf_web_acl_arn

  argo_app_labels = {
    "app.kubernetes.io/part-of"    = "redemption"
    "app.kubernetes.io/managed-by" = "argocd"
  }

  # ArgoCD's own Applications don't strictly need Karpenter/ALB controller
  # to exist first, but the workloads those Applications deploy (pods
  # needing nodes, an Ingress needing the controller) do -- ordering this
  # way avoids a burst of transient "unschedulable"/"no controller found"
  # noise right after the first apply.
  depends_on = [module.karpenter, module.alb_controller]
}
