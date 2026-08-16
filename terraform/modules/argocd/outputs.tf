output "argocd_namespace" {
  description = "Kubernetes namespace ArgoCD is installed into."
  value       = helm_release.argocd.namespace
}
