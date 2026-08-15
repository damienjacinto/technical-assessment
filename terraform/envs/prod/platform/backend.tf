terraform {
  backend "s3" {
    bucket       = "terraform-tfstate"
    key          = "prod/platform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
