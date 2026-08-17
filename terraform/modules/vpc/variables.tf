variable "name_prefix" {
  description = "Canonical name prefix, e.g. \"redemption-prod\"."
  type        = string
}

variable "tags" {
  description = "Canonical tag map, threaded in from the env root module."
  type        = map(string)
}

variable "account_id" {
  description = "AWS account ID, used to make globally-unique S3 bucket names."
  type        = string
}

variable "aws_region" {
  description = "AWS region, used to build VPC endpoint service names."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block. Must be a /16 for the tier math in main.tf to produce the intended subnet sizes."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Exactly 3 Availability Zones to spread across."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 3
    error_message = "This design assumes exactly 3 AZs (see docs/ARCHITECTURE.md: topology spread, NodePool subnet coverage)."
  }
}

variable "cluster_name" {
  description = "EKS cluster name, used for subnet auto-discovery tags (AWS LB Controller, Karpenter)."
  type        = string
}

variable "database_port" {
  description = "Port the isolated database security group allows ingress on from the private tier."
  type        = number
  default     = 5432
}

variable "flow_log_retention_days" {
  description = "How long VPC flow logs are retained in S3 before expiry."
  type        = number
  default     = 90
}

variable "nat_gateway_mode" {
  description = <<-EOT
    "per_az" (implemented): one NAT Gateway per AZ, the long-established HA pattern.
    "regional": documented design intent (see NOTES.md) using Amazon VPC Regional NAT
    Gateway. NOT yet wired into this module's HCL, since its exact Terraform resource
    schema needs verifying against a current `hashicorp/aws` provider release before it's
    safe to ship in a revenue-critical stack. Setting this to "regional" today has no
    effect; per-AZ is used regardless, until that verification happens and the module is
    updated.
  EOT
  type        = string
  default     = "per_az"

  validation {
    condition     = contains(["per_az", "regional"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be \"per_az\" or \"regional\"."
  }
}
