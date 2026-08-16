variable "name_prefix" {
  description = "Prefix used to name resources created by this module."
  type        = string
}

variable "role_suffix" {
  description = "Short, unique-within-stack suffix, e.g. \"karpenter-controller\", \"alb-controller\", \"the-redemption\"."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster the Pod Identity association is created against."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the ServiceAccount this role is associated with."
  type        = string
}

variable "service_account_name" {
  description = "Name of the ServiceAccount this role is associated with."
  type        = string
}

variable "managed_policy_arns" {
  description = "AWS managed policy ARNs to attach to this role."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Optional inline least-privilege policy JSON, for cases where no suitable AWS managed policy exists."
  type        = string
  default     = null
}

variable "create_inline_policy" {
  description = "Whether to create an inline policy from inline_policy_json"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
