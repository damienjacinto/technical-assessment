# ArgoCD: installs the controller, then a single root "app of apps"
# Application syncing kubernetes/argocd-apps/ recursively. Graduated from
# per-app Terraform-created Applications (docs/ARCHITECTURE.md).

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  max_history      = 5
  force_update     = false
  recreate_pods    = true
  wait             = true

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = false
        }
        # Local admin login (chart default) is the only auth -- access
        # control is the IP allowlist security group below, not identity.
      }
      # controller: generic (HTTPS backend is enough for the browser UI);
      # "aws" mode is only needed once the CLI needs direct gRPC. No
      # hostname/path prefix -- access control is security-groups,
      # shared allowlist with the-redemption's (alb-ip-restrict-sg.tf).
      server = {
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          pathType         = "Prefix"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"      = "ip"
            "alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
            "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
            "alb.ingress.kubernetes.io/security-groups"  = var.alb_security_group_id
          }
        }
        resources = local.component_resources
      }
      # BestEffort (chart default) starved repo-server of CPU on a cold
      # start, missing its 1s liveness-probe timeout and crash-looping it.
      # Sized for every component, same reasoning could hit any of them.
      controller = {
        resources = local.component_resources
      }
      repoServer = {
        resources = local.component_resources
      }
      applicationSet = {
        resources = local.component_resources
      }
      dex = {
        resources = local.component_resources
      }
      redis = {
        resources = local.component_resources
      }
      notifications = {
        resources = local.component_resources
      }
      global = {
        nodeSelector = {
          "karpenter.sh/nodepool" = "tools"
        }
        tolerations = [
          {
            key      = "dedicated"
            operator = "Equal"
            value    = "tools"
            effect   = "NoSchedule"
          }
        ]
      }
    })
  ]
}

locals {
  component_resources = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      memory = "256Mi"
    }
  }
}


# kubectl_manifest, not kubernetes_manifest: that provider fetches the
# target CRD's schema at *plan* time, which fails on a from-scratch
# cluster since helm_release.argocd hasn't installed it yet. Same fix as
# terraform/modules/karpenter/nodepools.tf.
resource "kubectl_manifest" "app_of_apps" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "app-of-apps"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      labels     = var.argo_app_labels
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = var.git_revision
        path           = "kubernetes/argocd-apps"
        directory = {
          recurse = true
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })

  depends_on = [helm_release.argocd]
}
