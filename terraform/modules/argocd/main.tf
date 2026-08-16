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
        resources = local.argocd_resources.server
      }
      # Per-component, not shared: a single 256Mi limit reused everywhere
      # OOMKilled the controller, whose in-memory app state dwarfs the rest.
      controller = {
        resources = local.argocd_resources.controller
      }
      repoServer = {
        resources = local.argocd_resources.repo_server
      }
      applicationSet = {
        resources = local.argocd_resources.application_set
      }
      dex = {
        resources = local.argocd_resources.dex
      }
      redis = {
        resources = local.argocd_resources.redis
      }
      notifications = {
        resources = local.argocd_resources.notifications
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
  argocd_resources = {
    # Holds the live+desired state of every synced resource in memory --
    # by far the heaviest component.
    controller = {
      requests = { cpu = "500m", memory = "512Mi" }
      limits   = { memory = "1Gi" }
    }
    # Renders Helm/Kustomize per sync, incl. kube-prometheus-stack's ~300
    # resources -- memory spikes during templating, not steady-state.
    repo_server = {
      requests = { cpu = "200m", memory = "256Mi" }
      limits   = { memory = "512Mi" }
    }
    server = {
      requests = { cpu = "100m", memory = "128Mi" }
      limits   = { memory = "256Mi" }
    }
    application_set = {
      requests = { cpu = "100m", memory = "64Mi" }
      limits   = { memory = "128Mi" }
    }
    # Unused (local admin login only) but still deployed by the chart.
    dex = {
      requests = { cpu = "50m", memory = "32Mi" }
      limits   = { memory = "64Mi" }
    }
    redis = {
      requests = { cpu = "100m", memory = "128Mi" }
      limits   = { memory = "256Mi" }
    }
    notifications = {
      requests = { cpu = "50m", memory = "32Mi" }
      limits   = { memory = "64Mi" }
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
