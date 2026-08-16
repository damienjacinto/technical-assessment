variable "name_prefix" {
  description = "Prefix used to name resources created by this module."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster Karpenter provisions EC2 capacity for."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API server endpoint, passed to the Karpenter Helm chart's settings.clusterEndpoint value."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC Karpenter-managed EC2 nodes are launched in."
  type        = string
}

variable "vpc_cidr" {
  description = "For the controller's Security-Groups-for-Pods rules -- see aws_security_group.controller."
  type        = string
}

variable "karpenter_chart_version" {
  description = "karpenter Helm chart version to install."
  type        = string
  default     = "1.1.1"
}

variable "bottlerocket_ami_version" {
  description = <<-EOT
    Bottlerocket alias version for the EC2NodeClass's amiSelectorTerms.
    Pinned per docs/ARCHITECTURE.md's "latest-minus-one, not bleeding edge"
    policy -- see https://github.com/bottlerocket-os/bottlerocket/releases.
    Bumping this is a deliberate PR, same as every other pinned version in
    this repo.
  EOT
  type        = string
  default     = "v1.61.0"
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
