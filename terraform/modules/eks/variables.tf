variable "name_prefix" {
  description = "Prefix used to name resources created by this module."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, e.g. \"redemption-prod-eks\"."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the control plane. Versioning policy: latest-minus-one, not bleeding edge -- see docs/ARCHITECTURE.md."
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "ID of the VPC the EKS control plane ENIs are created in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the control plane ENIs and (indirectly, via Karpenter) worker nodes live in."
  type        = list(string)
}

variable "public_endpoint_enabled" {
  description = "Whether the EKS API server's public endpoint is enabled at all. Private access is always on regardless."
  type        = bool
  default     = true
}

variable "public_endpoint_allowed_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint -- real, internet-routable ranges only (office/VPN/CI runner), never 0.0.0.0/0."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.public_endpoint_allowed_cidrs, "0.0.0.0/0")
    error_message = "public_endpoint_allowed_cidrs must never contain 0.0.0.0/0 for a revenue-critical cluster."
  }

  validation {
    condition = alltrue([
      for cidr in var.public_endpoint_allowed_cidrs :
      !can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.|192\\.168\\.)", cidr))
    ])
    error_message = "public_endpoint_allowed_cidrs must be real, internet-routable CIDRs -- EKS rejects RFC1918 private ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) in this field."
  }
}

variable "additional_admin_principal_arns" {
  description = "Extra IAM principal ARNs (users or roles) to grant cluster-admin access via EKS Access Entries"
  type        = list(string)
  default     = []
}

variable "cluster_enabled_log_types" {
  description = "Control plane log types shipped to CloudWatch Logs. Default is all five EKS supports."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}

variable "addon_versions" {
  description = "Explicit version to pin per EKS addon (key = addon name: vpc-cni, kube-proxy, eks-pod-identity-agent, metrics-server). An addon left out of this map falls back to most_recent, which re-resolves on every plan and diffs whenever AWS ships a new build -- pin it here once you've captured the currently-applied version to make plans deterministic."
  type        = map(string)
  default     = {}
}
