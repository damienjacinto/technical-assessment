variable "git_repo_url" {
  description = "This repo's git URL -- ArgoCD Applications point their source.repoURL here."
  type        = string
}

variable "git_revision" {
  description = "Git revision (branch/tag) ArgoCD Applications track as source.targetRevision."
  type        = string
  default     = "main"
}

variable "karpenter_chart_version" {
  description = "karpenter Helm chart version to install."
  type        = string
  default     = "1.1.1"
}

variable "bottlerocket_ami_version" {
  description = "Bottlerocket alias version for Karpenter's EC2NodeClass amiSelectorTerms -- see terraform/modules/karpenter/variables.tf for the versioning policy."
  type        = string
  default     = "v1.61.0"
}

variable "alb_controller_chart_version" {
  description = "aws-load-balancer-controller Helm chart version to install."
  type        = string
  default     = "1.10.0"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version to install."
  type        = string
  default     = "7.7.11"
}
