variable "git_repo_url" {
  description = "This repo's git URL -- ArgoCD Applications point their source.repoURL here."
  type        = string
}

variable "git_revision" {
  type    = string
  default = "main"
}

variable "karpenter_chart_version" {
  type    = string
  default = "1.1.1"
}

variable "bottlerocket_ami_version" {
  type    = string
  default = "v1.61.0"
}

variable "alb_controller_chart_version" {
  type    = string
  default = "1.10.0"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.7.11"
}
