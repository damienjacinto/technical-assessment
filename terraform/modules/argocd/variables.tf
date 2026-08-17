variable "argocd_chart_version" {
  description = "argo-cd Helm chart version to install."
  type        = string
  default     = "10.3.3"
}

variable "git_repo_url" {
  description = "This repo's git URL, as ArgoCD Applications' source.repoURL."
  type        = string
}

variable "git_revision" {
  description = "Git revision (branch/tag) ArgoCD Applications track as source.targetRevision."
  type        = string
  default     = "main"
}

variable "argo_app_labels" {
  description = "Labels applied to the root app-of-apps Application."
  type        = map(string)
  default     = {}
}
