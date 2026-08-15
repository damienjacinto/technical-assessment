variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name, e.g. \"redemption-prod-eks\"."
  type        = string
}

variable "cluster_version" {
  description = <<-EOT
    Kubernetes version for the control plane. Versioning policy (see
    docs/ARCHITECTURE.md): track "latest minus one" EKS-supported minor
    version, not the newest release -- current is 1.36 (GA June 2026), so
    the default here is 1.35, not 1.36. Only jump to the newest minor if a
    specific feature it introduces is actually needed; otherwise staying
    one behind means the version has had a few months of the rest of the
    ecosystem (controllers, Helm charts, this team's own tooling) catching
    up to it before this cluster runs it.
  EOT
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  type = string
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
  description = "CIDRs allowed to reach the public API endpoint -- least privilege, never 0.0.0.0/0 for a revenue-critical cluster."
  type        = list(string)
}

variable "cluster_enabled_log_types" {
  description = "Control plane log types shipped to CloudWatch Logs. Default is all five EKS supports."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "tags" {
  type = map(string)
}
