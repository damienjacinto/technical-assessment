# NAT Gateway mode: implementation status

`docs/ARCHITECTURE.md` documents **Amazon VPC Regional NAT Gateway** (GA November 2025)
as the intended design: a single, VPC-scoped NAT Gateway that AWS automatically expands
and contracts across AZs, with automatic per-AZ connection-capacity scaling.

That document also states explicitly that this is a young feature (GA ~9 months at time
of writing) that should be validated against AWS's SLA in a lower environment before
being trusted for this revenue-critical service, with the classic one-NAT-Gateway-per-AZ
design kept as the documented fallback.

**This module implements only the per-AZ fallback as real, executable HCL.** `var.nat_gateway_mode`
exists and accepts `"regional"`, but currently has no effect: `"per_az"` is used regardless
of the setting.

**Update (2026-08-16): schema verified, blocked on the wrapper module instead.**
Confirmed against the pinned `hashicorp/aws` provider (v6.60.0, satisfies `~> 6.0`) that
regional NAT Gateway is real and supported: `aws_nat_gateway` gained `availability_mode =
"regional"` in provider v6.24.0 (Dec 2025), with an `availability_zone_address` block for
manual EIP/AZ assignment, or auto mode (omit the block) where AWS expands/contracts AZ
coverage automatically. Verified via the provider's own resource docs and by grepping the
installed binary for the schema fields (`availability_mode`, `availability_zone_address`,
`auto_provision_zones`, `auto_scaling_ips`) -- they're present.

The blocker is one layer up: this module doesn't call `aws_nat_gateway` directly, it
delegates to the community `terraform-aws-modules/vpc/aws` module (pinned `~> 6.6`). That
wrapper module's own `aws_nat_gateway` resource (see its vendored source,
`aws_nat_gateway.this` in its main.tf) has no `availability_mode` input at all -- it only
knows the classic per-AZ/single-NAT pattern. This is a tracked, unresolved upstream gap:
[terraform-aws-modules/terraform-aws-vpc#1281](https://github.com/terraform-aws-modules/terraform-aws-vpc/issues/1281).

**Before switching this to regional NAT Gateway:**
1. ~~Confirm the current `hashicorp/aws` provider version's schema for regional NAT
   Gateway.~~ Done above.
2. Either wait for terraform-aws-modules/vpc/aws to ship native `availability_mode`
   support, or hand-roll NAT here: set `enable_nat_gateway = false` on `module.vpc` (so
   the wrapper stops creating per-AZ NAT gateways/EIPs) and add a standalone
   `aws_nat_gateway` resource with `availability_mode = "regional"` plus the private
   subnet route(s) pointing at it, written directly in this module. That trades "NAT logic
   fully inside the well-tested community module" for "regional NAT Gateway today" --
   deliberately not done as part of this note, pending an explicit decision to take that
   trade for a revenue-critical stack.
3. Whichever path is taken, `terraform plan` it against a real (non-production) AWS
   account and validate the AZ-failure behavior claims from AWS's announcement blog
   directly, since the blog post used as the source for this design doesn't fully spell
   out that behavior.
4. Only then flip the default and remove this note.
