variable "name_prefix" {
  description = "Prefix used to name resources created by this module, and the Secrets Manager path prefix (\"<name_prefix>/*\") the IAM policy scopes access to."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster the Pod Identity association is created against."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
