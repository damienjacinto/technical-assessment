##############################################################################
# ArgoCD: installs the controller, then a single root "app of apps"
# Application whose source is kubernetes/argocd-apps/, synced recursively --
# an ApplicationSet (list generator) for the uniformly-shaped infra-apps,
# plus one explicit Application for the-redemption (see that directory's
# own NOTES.md). Terraform no longer templates each child Application
# individually; it only creates this one root object, and ArgoCD
# reconciles everything under it from git from then on.
#
# Graduated from directly-created-per-app Applications (see
# docs/ARCHITECTURE.md) once the number of Applications grew enough that
# per-app Terraform indirection stopped paying for itself.
#
# the-redemption's WAF ACL ARN -- previously injected here via
# source.helm.valuesObject, the one live Terraform value any child
# Application needed -- is no longer threaded through Terraform at all now
# that Applications are static YAML: terraform/envs/prod/platform/main.tf
# writes it to a ConfigMap instead, and the chart reads it live via Helm's
# lookup() function at render time. See that ConfigMap resource's own
# comment, and kubernetes/apps/the-redemption/templates/ingress.yaml.
##############################################################################

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
      }
    })
  ]
}

resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
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
  }

  depends_on = [helm_release.argocd]
}
