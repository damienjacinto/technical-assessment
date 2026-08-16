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

variable "cluster_security_group_id" {
  description = "EKS cluster security group ID. A SecurityGroupPolicy's custom security group replaces the cluster security group Fargate normally attaches by default, not adds to it -- without this included alongside the custom SG, Fargate pod provisioning times out repeatedly (AWS-documented behavior, not an edge case)."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's OIDC identity provider -- the controller's IRSA trust policy Federated principal. Pod Identity doesn't work on Fargate (see this module's own main.tf), so the controller -- the one Fargate-hosted, AWS-API-consuming component in this stack -- uses IRSA instead."
  type        = string
}

variable "oidc_provider" {
  description = "Cluster OIDC issuer without the https:// prefix -- the controller's IRSA trust policy condition-key prefix."
  type        = string
}

variable "karpenter_chart_version" {
  description = "karpenter Helm chart version to install. Must be >= 1.9 for Kubernetes 1.35"
  type        = string
  default     = "1.14.0"
}

variable "bottlerocket_ami_version" {
  description = "Bottlerocket alias version for the EC2NodeClass amiSelectorTerms"
  type        = string
  default     = "v1.64.0"
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
