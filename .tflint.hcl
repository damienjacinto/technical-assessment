plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.48.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_variables" {
  # Off: several variables in this repo are self-explanatory from their
  # name+type alone (e.g. vpc_id, tags) -- a description isn't load-bearing
  # documentation there, and requiring one everywhere would just produce
  # noise ("VPC ID." as a description) rather than real clarity.
  enabled = false
}

rule "terraform_required_version" {
  # Off for child modules specifically: only the three root modules
  # (terraform/bootstrap, terraform/envs/prod/{foundation,platform}) declare
  # required_version, deliberately -- a version constraint on every child
  # module too would just be N copies of the same constraint to keep in
  # sync, not real protection, since Terraform resolves the constraint at
  # the root regardless.
  enabled = false
}

rule "terraform_required_providers" {
  # Off for the same reason: child modules inherit provider requirements
  # from whichever root module composes them; declaring `required_providers`
  # in each of the 8 modules here would be pure boilerplate, not a real
  # guardrail, since none of these modules are published/consumed standalone
  # outside this repo.
  enabled = false
}
