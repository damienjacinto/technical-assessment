locals {
  foundation = data.terraform_remote_state.foundation.outputs
}

# Fargate's built-in log router looks for this exact namespace/ConfigMap
# name/shape -- without it, every Fargate pod's logs (CoreDNS queries,
# Karpenter's provisioning decisions) are silently dropped, not errored;
# `kubectl describe pod` on a Fargate pod shows a "LoggingDisabled ...
# configmap \"aws-logging\" not found" Event, easy to miss since nothing
# actually fails. The log group itself and the pod execution role's write
# permissions are created in foundation (terraform/modules/fargate-profile)
# -- this is only the Kubernetes-side config pointing the log router at
# that already-created group, same foundation/platform AWS-vs-Kubernetes
# split as everything else in this file.
#
# Pods already running when this first applies won't retroactively start
# logging -- the log router reads this config at pod start, not live.
# Self-resolving the same way the CoreDNS SecurityGroupPolicy bootstrap
# caveat is (modules/coredns/main.tf): the next natural pod recreation
# (addon version bump, Fargate rotation) picks it up, or force it sooner
# with `kubectl delete pod -n kube-system -l k8s-app=kube-dns` /
# `-l app.kubernetes.io/name=karpenter`.
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

# the-redemption's own Pod Identity role. Deliberately zero permissions
# attached -- a least-privilege placeholder, since the data layer (what this
# role would actually need access to) is explicitly out of scope for this
# build. The ServiceAccount/role association wiring exists so a future
# data-layer decision only needs to attach a policy here, not touch app
# manifests.
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

# the-redemption's WAF ACL ARN is only known after Terraform creates it
# (security-baseline, in foundation). the-redemption's Application is now
# static YAML (kubernetes/argocd-apps/the-redemption.yaml, synced via the
# app-of-apps root Application below) -- static YAML can't carry a live
# Terraform value the way the old per-app valuesObject injection could.
# This ConfigMap is the new seam: written here from a live Terraform value,
# read by the chart at render time via Helm's lookup() -- see
# kubernetes/apps/the-redemption/templates/ingress.yaml. Lives in
# kube-system (always exists) rather than the-redemption's own namespace,
# so there's no ordering dependency on ArgoCD having created that
# namespace yet.
resource "kubernetes_config_map" "redemption_waf_config" {
  metadata {
    name      = "redemption-waf-config"
    namespace = "kube-system"
  }

  data = {
    wafAclArn = local.foundation.waf_web_acl_arn
  }
}

# module "argocd" {
#   source = "../../../modules/argocd"

#   argocd_chart_version = var.argocd_chart_version
#   git_repo_url         = var.git_repo_url
#   git_revision         = var.git_revision

#   argo_app_labels = {
#     "app.kubernetes.io/part-of"    = "redemption"
#     "app.kubernetes.io/managed-by" = "argocd"
#   }

#   # The root Application's own children don't strictly need Karpenter/ALB
#   # controller to exist first, but the workloads those children deploy
#   # (pods needing nodes, an Ingress needing the controller) do -- ordering
#   # this way avoids a burst of transient "unschedulable"/"no controller
#   # found" noise right after the first apply.
#   depends_on = [module.karpenter, module.alb_controller]
# }
