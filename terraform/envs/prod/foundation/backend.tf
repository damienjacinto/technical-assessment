##############################################################################
# Points at the bucket created once by terraform/bootstrap. Backend blocks
# can't interpolate variables, so this is literal -- it follows the same
# {project}-tfstate-{account_id} naming bootstrap/main.tf produces.
#
# Locking is S3-native (use_lockfile, Terraform >= 1.10) -- no DynamoDB
# table; AWS's S3 backend handles locking itself via conditional writes.
##############################################################################

terraform {
  backend "s3" {
    bucket       = "terraform-tfstate"
    key          = "prod/foundation/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
