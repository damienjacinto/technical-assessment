variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "chart_version" {
  type    = string
  default = "1.10.0"
}

variable "tags" {
  type = map(string)
}
