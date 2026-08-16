variable "project" {
  description = "Project name, used as the first component of local.name_prefix."
  type        = string
  default     = "redemption"
}

variable "environment" {
  description = "This is the \"prod\" instance of the per-environment pattern -- see docs/ARCHITECTURE.md naming/tagging section. A future terraform/envs/staging/ would set this to \"staging\"."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region this environment is deployed to."
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Exactly 3 Availability Zones. Defaults to the first 3 available in aws_region if left empty."
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "VPC CIDR block. Must be a /16 for the tier math in terraform/modules/vpc/main.tf to produce the intended subnet sizes."
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "See terraform/modules/eks/variables.tf for the versioning policy (latest-minus-one, not bleeding edge)."
  type        = string
  default     = "1.35"
}

variable "public_endpoint_allowed_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. Least privilege: your office/VPN/CI runner ranges, never 0.0.0.0/0."
  type        = list(string)
  default     = []
}

variable "owner" {
  description = "Team tag value."
  type        = string
  default     = "sre"
}

variable "repository" {
  description = "Repository URL, stamped onto local.tags as the Repository tag value."
  type        = string
  default     = "https://github.com/damienjacinto/technical-assessment"
}
