variable "project" {
  description = "Short project slug used to prefix all resource names (e.g. \"redemption\")."
  type        = string
  default     = "redemption"
}

variable "aws_region" {
  description = "AWS region the state backend lives in."
  type        = string
  default     = "us-east-1"
}

variable "repository" {
  description = "Source repository URL, for traceability on the Repository tag."
  type        = string
  default     = "https://github.com/damienjacinto/technical-assessment"
}
