##############################################################################
# Points at the bucket created once by terraform/bootstrap. Backend blocks
# can't interpolate variables, so this is literal -- it follows the same
# {project}-tfstate naming bootstrap/main.tf produces.
#
##############################################################################

terraform {
  backend "s3" {
    bucket       = "redemption-tfstate"
    key          = "prod/foundation/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
