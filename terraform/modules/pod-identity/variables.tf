variable "name_prefix" {
  type = string
}

variable "role_suffix" {
  description = "Short, unique-within-stack suffix, e.g. \"karpenter-controller\", \"alb-controller\", \"the-redemption\"."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service_account_name" {
  type = string
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "inline_policy_json" {
  description = "Optional inline least-privilege policy JSON, for cases where no suitable AWS managed policy exists."
  type        = string
  default     = null
}

variable "tags" {
  type = map(string)
}
