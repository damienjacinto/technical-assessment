variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  description = "For the controller's Security-Groups-for-Pods rules -- see aws_security_group.controller."
  type        = string
}

variable "karpenter_chart_version" {
  type    = string
  default = "1.1.1"
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
  type = map(string)
}
