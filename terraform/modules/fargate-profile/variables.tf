variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs -- Fargate profiles cannot use public subnets."
  type        = list(string)
}

variable "tags" {
  type = map(string)
}
