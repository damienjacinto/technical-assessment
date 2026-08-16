variable "name_prefix" {
  description = "Prefix used to name resources created by this module."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster this Fargate profile is created against."
  type        = string
}

variable "aws_region" {
  description = "AWS region, used to scope the pod execution role's trust policy to this cluster's Fargate profiles."
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used to scope the pod execution role's trust policy to this cluster's Fargate profiles."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs -- Fargate profiles cannot use public subnets."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
