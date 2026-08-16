variable "name_prefix" {
  description = "Prefix used to name resources created by this module."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the app security group is created in."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block -- the app security group's ingress/egress rules are scoped to this range."
  type        = string
}

variable "app_port" {
  description = "Port the-redemption's app pods listen on."
  type        = number
  default     = 8080
}

variable "rate_limit_per_5min" {
  description = "WAF rate-based rule limit: requests per 5-minute window, per source IP."
  type        = number
  default     = 10000
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
}
