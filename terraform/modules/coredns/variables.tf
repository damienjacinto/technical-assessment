variable "cluster_name" {
  description = "EKS cluster the CoreDNS addon is installed on."
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version -- selects which CoreDNS addon versions are compatible."
  type        = string
}

variable "tags" {
  description = "Tags applied to the CoreDNS addon."
  type        = map(string)
}
