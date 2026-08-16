locals {
  foundation = data.terraform_remote_state.foundation.outputs
}

# Fargate's built-in log router
resource "kubernetes_namespace" "aws_observability" {
  metadata {
    name = "aws-observability"
    labels = {
      aws-observability = "enabled"
    }
  }
}

resource "kubernetes_config_map" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.aws_observability.metadata[0].name
  }

  data = {
    "output.conf" = <<-EOT
      [OUTPUT]
          Name                cloudwatch_logs
          Match               *
          region              ${local.foundation.aws_region}
          log_group_name      ${local.foundation.fargate_log_group_name}
          log_stream_prefix   fargate-
          auto_create_group   false
    EOT
  }
}

module "coredns" {
  source = "../../../modules/coredns"

  name_prefix               = local.foundation.name_prefix
  cluster_name              = local.foundation.cluster_name
  cluster_version           = local.foundation.cluster_version
  vpc_id                    = local.foundation.vpc_id
  vpc_cidr                  = local.foundation.vpc_cidr
  cluster_security_group_id = local.foundation.cluster_security_group_id
  tags                      = merge(local.foundation.tags, { Component = "compute-control-plane" })
}

module "karpenter" {
  source = "../../../modules/karpenter"

  name_prefix               = local.foundation.name_prefix
  cluster_name              = local.foundation.cluster_name
  cluster_endpoint          = local.foundation.cluster_endpoint
  vpc_id                    = local.foundation.vpc_id
  vpc_cidr                  = local.foundation.vpc_cidr
  cluster_security_group_id = local.foundation.cluster_security_group_id
  oidc_provider_arn         = local.foundation.oidc_provider_arn
  oidc_provider             = local.foundation.oidc_provider
  karpenter_chart_version   = var.karpenter_chart_version
  bottlerocket_ami_version  = var.bottlerocket_ami_version
  tags                      = merge(local.foundation.tags, { Component = "compute-autoscaling" })
  depends_on                = [module.coredns]
}

module "alb_controller" {
  source = "../../../modules/alb-controller"

  name_prefix   = local.foundation.name_prefix
  cluster_name  = local.foundation.cluster_name
  vpc_id        = local.foundation.vpc_id
  aws_region    = local.foundation.aws_region
  chart_version = var.alb_controller_chart_version
  tags          = merge(local.foundation.tags, { Component = "networking-ingress" })

  depends_on = [module.karpenter]
}

module "external_secrets" {
  source = "../../../modules/external-secrets"

  name_prefix  = local.foundation.name_prefix
  cluster_name = local.foundation.cluster_name
  tags         = merge(local.foundation.tags, { Component = "security-secrets" })
  depends_on   = [module.karpenter]
}

# the-redemption's own Pod Identity role
module "the_redemption_pod_identity" {
  source = "../../../modules/pod-identity"

  name_prefix          = local.foundation.name_prefix
  role_suffix          = "the-redemption"
  cluster_name         = local.foundation.cluster_name
  namespace            = "the-redemption"
  service_account_name = "the-redemption"
  managed_policy_arns  = []
  tags                 = merge(local.foundation.tags, { Component = "the-redemption-app" })
}

# the-redemption's ALB security group ID is only known after Terraform
# creates it (security-baseline, in foundation)
resource "kubernetes_config_map" "redemption_ingress_config" {
  metadata {
    name      = "redemption-ingress-config"
    namespace = "kube-system"
  }

  data = {
    albSecurityGroupId = local.foundation.alb_ip_restricted_sg_id
  }
}

module "argocd" {
  source = "../../../modules/argocd"

  argocd_chart_version = var.argocd_chart_version
  git_repo_url         = var.git_repo_url
  git_revision         = var.git_revision

  alb_security_group_id = local.foundation.alb_ip_restricted_sg_id

  argo_app_labels = {
    "app.kubernetes.io/part-of"    = "redemption"
    "app.kubernetes.io/managed-by" = "argocd"
  }
  depends_on = [module.karpenter, module.alb_controller]
}
