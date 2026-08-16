variable "name_prefix" {
  description = "Prefix used to name resources created by this module."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster the CoreDNS addon is installed on."
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version -- selects which CoreDNS addon versions are compatible."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the CoreDNS security group is created in."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block -- the CoreDNS security group's ingress/egress rules are scoped to this range."
  type        = string
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group ID. A SecurityGroupPolicy's custom security group replaces the cluster security group Fargate normally attaches by default, not adds to it -- without this included alongside the custom SG, Fargate pod provisioning times out repeatedly (AWS-documented behavior, not an edge case)."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
