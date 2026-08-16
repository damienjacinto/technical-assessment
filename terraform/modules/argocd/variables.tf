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

variable "alb_security_group_id" {
  description = "Security group restricting this Ingress's ALB to the allowlisted IPs, e.g. local.foundation.alb_ip_restricted_sg_id via foundation's remote state. This is this Ingress's actual access control -- no WAF in front of it."
  type        = string
}
