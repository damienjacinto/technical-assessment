# Public API endpoint access: interim choice

`public_endpoint_allowed_cidrs` is left empty in the real, gitignored
`terraform.tfvars`. When `public_endpoint_enabled = true` and no explicit CIDRs are
configured, `main.tf`'s `data.http.my_ip` queries `https://checkip.amazonaws.com` at
plan/apply time and restricts the public endpoint to whichever machine is currently
running `terraform apply`, as a `/32`. This is how `terraform apply`/`kubectl` reach the
cluster directly from a laptop without a hardcoded IP going stale.

**This is a deliberate simplification, not the target design**, and it has a real,
knowingly-accepted cost: `endpoint_public_access_cidrs` becomes non-deterministic across
operators/CI runners. Every `apply` from a different network re-triggers an EKS VPC
config update to swap the CIDR to whoever's applying right now. A teammate applying
right after you, or a CI runner with an ephemeral IP, will each flip it again. That's
extra API churn and a `plan` that always shows a diff unless the same machine/network
applied last.

The right long-term answer is for the EKS API server to have **private access only**
(`public_endpoint_enabled = false`) with all human/CI access going through something
that already lives inside the VPC. e.g., an SSM-managed bastion (no public IP, no
inbound security group rule, access brokered entirely through IAM + Session Manager) or
a self-hosted CI runner sitting in the private subnets. Either removes the public
endpoint's attack surface entirely instead of narrowing it to a CIDR that changes with
whoever's laptop last ran `apply`.

**Before this is considered done:**
1. Stand up the SSM bastion (or private CI runner) as its own module.
2. Flip `public_endpoint_enabled` to `false` in `envs/prod/foundation`.
3. Remove `public_endpoint_allowed_cidrs` from the real `terraform.tfvars`. With
   `public_endpoint_enabled = false` it's no longer read by anything, and
   `data.http.my_ip`'s `count` guard means it stops being queried at all.

**If the auto-detect churn becomes a problem before then:** set explicit
`public_endpoint_allowed_cidrs` (real office/VPN/CI runner ranges) in `terraform.tfvars`
instead of leaving it empty. That's a static value `data.http.my_ip` never overrides
(see the `count` guard in `main.tf`).
