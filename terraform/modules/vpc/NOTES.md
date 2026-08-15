# NAT Gateway mode: implementation status

`docs/ARCHITECTURE.md` documents **Amazon VPC Regional NAT Gateway** (GA November 2025)
as the intended design: a single, VPC-scoped NAT Gateway that AWS automatically expands
and contracts across AZs, with automatic per-AZ connection-capacity scaling.

That document also states explicitly that this is a young feature (GA ~9 months at time
of writing) that should be validated against AWS's SLA in a lower environment before
being trusted for this revenue-critical service, with the classic one-NAT-Gateway-per-AZ
design kept as the documented fallback.

**This module implements only the per-AZ fallback as real, executable HCL.** The exact
`aws_nat_gateway` resource schema for regional mode was not something I could verify with
confidence — writing speculative attribute names into HCL that has to pass
`terraform validate` risks shipping code that's subtly wrong rather than obviously
unimplemented, which is worse. `var.nat_gateway_mode` exists and accepts `"regional"`,
but currently has no effect: `"per_az"` is used regardless of the setting.

**Before switching this to regional NAT Gateway:**
1. Confirm the current `hashicorp/aws` provider version's schema for regional NAT
   Gateway (`terraform providers schema -json` against a pinned provider version, or the
   provider's own changelog/docs).
2. Implement and `terraform plan` it against a real (non-production) AWS account.
3. Validate the AZ-failure behavior claims from AWS's announcement blog directly, since
   the blog post used as the source for this design doesn't fully spell out that
   behavior.
4. Only then flip the default and remove this note.
