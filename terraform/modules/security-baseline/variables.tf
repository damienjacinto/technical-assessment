variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "rate_limit_per_5min" {
  description = "WAF rate-based rule limit: requests per 5-minute window, per source IP."
  type        = number
  default     = 10000
}

variable "tags" {
  type = map(string)
}
