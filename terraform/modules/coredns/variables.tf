variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version -- selects which CoreDNS addon versions are compatible."
  type        = string
}

variable "tags" {
  type = map(string)
}
