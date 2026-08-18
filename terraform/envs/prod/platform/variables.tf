variable "git_repo_url" {
  description = "This repo's git URL. ArgoCD Applications point their source.repoURL here."
  type        = string
  default     = "https://github.com/damienjacinto/technical-assessment.git"
}

variable "git_revision" {
  description = "Git revision (branch/tag) ArgoCD Applications track as source.targetRevision."
  type        = string
  default     = "main"
}

variable "karpenter_chart_version" {
  description = "karpenter Helm chart version to install. See terraform/modules/karpenter/variables.tf for the Kubernetes-version compatibility constraint."
  type        = string
  default     = "1.14.0"
}

variable "bottlerocket_ami_version" {
  description = "Bottlerocket alias version for Karpenter's EC2NodeClass amiSelectorTerms. See terraform/modules/karpenter/variables.tf for the versioning policy."
  type        = string
  default     = "v1.64.0"
}

variable "alb_controller_chart_version" {
  description = "aws-load-balancer-controller Helm chart version to install. See terraform/modules/alb-controller/variables.tf, its IAM policy is reconciled against this exact version."
  type        = string
  default     = "3.5.0"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version to install."
  type        = string
  default     = "10.3.3"
}
