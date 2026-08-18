variable "cluster_name" {
  description = "EKS cluster the metrics-server addon is installed on."
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version. Selects which metrics-server addon versions are compatible."
  type        = string
}

variable "addon_version" {
  description = "Explicit metrics-server addon version to pin. Left null, resolves to most_recent, which re-resolves on every plan. Pin it once you've captured this module's addon_version output to make plans deterministic."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
