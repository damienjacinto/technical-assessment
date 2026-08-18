variable "name_prefix" {
  description = "Prefix used to name resources created by this module."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the app security group is created in."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block. The app security group's ingress/egress rules are scoped to this range."
  type        = string
}

variable "app_port" {
  description = "Port the-redemption's app pods listen on."
  type        = number
  default     = 8080
}

variable "alb_allowlist_cidrs" {
  description = "CIDR allowlist for both ALBs' security group (aws_security_group.alb_ip_restricted). The only IPs allowed to reach the-redemption or ArgoCD at all. Empty list auto-detects the operator's current public IP via AWS's checkip endpoint at apply time. See alb-allowlist.tf's data.http.my_ip comment."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
