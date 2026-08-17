variable "name_prefix" {
  description = "Prefix used to name resources created by this module."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster the controller manages Ingresses/Services for."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the controller provisions ALBs/target groups in."
  type        = string
}

variable "aws_region" {
  description = "AWS region, passed to the Helm chart's `region` value."
  type        = string
}

variable "chart_version" {
  description = "aws-load-balancer-controller Helm chart version to install. main.tf's IAM policy is reconciled against this exact version's app release. Re-verify that reconciliation whenever this changes."
  type        = string
  default     = "3.5.0"
}

variable "tags" {
  description = "Tags applied to all resources created by this module, and to ALBs/target groups the controller provisions at runtime."
  type        = map(string)
}
