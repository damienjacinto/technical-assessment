variable "argocd_chart_version" {
  description = "argo-cd Helm chart version to install."
  type        = string
  default     = "7.7.11"
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

variable "environment" {
  description = "Environment name, threaded into the-redemption's Application as a Helm value."
  type        = string
}

variable "waf_web_acl_arn" {
  description = "From the security-baseline module, wired into the-redemption's Ingress annotation."
  type        = string
}

variable "argo_app_labels" {
  description = "Labels applied to every ArgoCD Application this module creates."
  type        = map(string)
  default     = {}
}
