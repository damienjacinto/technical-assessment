# Points at the bucket terraform/bootstrap creates. Backend blocks can't
# interpolate variables, so this is literal, following its naming.

terraform {
  backend "s3" {
    bucket       = "redemption-tfstate"
    key          = "prod/foundation/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
