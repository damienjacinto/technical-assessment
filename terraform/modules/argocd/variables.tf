variable "argocd_chart_version" {
  type    = string
  default = "7.7.11"
}

variable "git_repo_url" {
  description = "This repo's git URL, as ArgoCD Applications' source.repoURL."
  type        = string
}

variable "git_revision" {
  type    = string
  default = "main"
}

variable "environment" {
  type = string
}

variable "waf_web_acl_arn" {
  description = "From the security-baseline module, wired into the-redemption's Ingress annotation."
  type        = string
}

variable "argo_app_labels" {
  type    = map(string)
  default = {}
}
