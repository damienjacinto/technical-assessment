##############################################################################
# ArgoCD: installs the controller, then creates the ArgoCD `Application` CRs
# directly (not an app-of-apps indirection -- unnecessary at this repo's
# size; documented in docs/ARCHITECTURE.md as the pattern to graduate to
# once the number of Applications grows).
#
# Every static infra app just points at a path in this git repo with
# committed values.yaml defaults. the-redemption is the one exception: it
# needs the WAF ACL ARN, which only exists after Terraform has run, so that's
# injected via valuesObject here -- this is the legitimate seam between
# Terraform-owned infra and GitOps-owned app config. It no longer needs its
# IAM role ARN injected the same way: that pairing is now handled entirely
# on the AWS side by the aws_eks_pod_identity_association in
# terraform/envs/prod/foundation/main.tf, not by a value threaded into the
# chart's ServiceAccount annotation.
##############################################################################

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = false
        }
      }
    })
  ]
}

locals {
  # name -> destination namespace. Each controller gets its own namespace
  # (standard convention) rather than everything piling into kube-system.
  # karpenter-nodepools is deliberately NOT here: NodePool/EC2NodeClass are
  # created directly by terraform/modules/karpenter instead, to avoid a
  # bootstrap deadlock (see that module's main.tf) -- ArgoCD's own pods need
  # a NodePool to exist before ArgoCD can be up to sync one.
  infra_apps = {
    "capacity-buffer"       = "kube-system"
    "keda"                  = "keda"
    "argo-rollouts"         = "argo-rollouts"
    "kyverno"               = "kyverno"
    "external-secrets"      = "external-secrets"
    "otel-collector"        = "observability"
    "kube-prometheus-stack" = "observability"
    "tempo"                 = "observability"
  }
}

resource "kubernetes_manifest" "infra_app" {
  for_each = local.infra_apps

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = each.key
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      labels     = var.argo_app_labels
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = var.git_revision
        path           = "kubernetes/infra-apps/${each.key}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = each.value
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "the_redemption" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "the-redemption"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      labels     = var.argo_app_labels
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = var.git_revision
        path           = "kubernetes/apps/the-redemption"
        helm = {
          valuesObject = {
            environment = var.environment
            ingress = {
              wafAclArn = var.waf_web_acl_arn
            }
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "the-redemption"
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}
