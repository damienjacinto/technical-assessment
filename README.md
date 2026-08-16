# The Redemption — EKS Platform

Business-critical hotel-points-deduction microservice on Amazon EKS. Steady baseline
traffic, sudden 10x Flash Sale spikes, zero-downtime target. Terraform + GitOps
built for a 3-person SRE team.

## Repository map

```
technical-assessment/
├── docs/                       Architecture writeup, team plan
├── scripts/                    validate-kubernetes.sh, lint-iam-actions.py (pre-commit/CI)
├── terraform/
│   ├── bootstrap/              State backend (S3, native locking) — apply once, by itself
│   ├── modules/                 vpc, eks, fargate-profile, coredns, pod-identity,
│   │                            karpenter, alb-controller, external-secrets,
│   │                            security-baseline, argocd
│   └── envs/prod/
│       ├── foundation/          Stage 1: VPC, EKS, Fargate profile, security baseline
│       └── platform/            Stage 2: Karpenter, ALB Controller, ArgoCD
└── kubernetes/
    ├── argocd-apps/               App-of-apps root: infra-apps ApplicationSet + the-redemption Application
    ├── infra-apps/                ArgoCD-managed: capacity-buffer, keda,
    │                              argo-rollouts, kyverno, external-secrets,
    │                              otel-collector, kube-prometheus-stack
    └── apps/the-redemption/       The application Helm chart
```

`terraform/envs/prod` is built as one environment among several, not a one-off: the
`terraform/modules/*` it wires together don't hardcode anything prod-specific, so a
future `terraform/envs/staging/` would reuse those same modules as-is, just with its own
`terraform.tfvars` and state.

## Prerequisites

- An AWS account, with credentials configured locally (AWS CLI v2, or equivalent) and
  permissions to create the resources under `terraform/`.
- **Terraform >= 1.10** (`required_version` in every root module).
- Region: **`us-east-1`**, hardcoded in `terraform/bootstrap/main.tf`'s `aws_region`
  default and literally in every `backend.tf` (Terraform backend blocks can't
  interpolate variables). Changing region means updating both.

## Deploy

1. **State backend** — once, with local state, before anything else:
   ```
   cd terraform/bootstrap
   terraform init
   terraform apply    # creates the redemption-tfstate S3 bucket in us-east-1
   ```

   > [!WARNING]
   > The bucket name `redemption-tfstate` is not read from a variable past this point —
   > Terraform backend blocks can't interpolate variables, so it's hardcoded literally in
   > `terraform/envs/prod/{foundation,platform}/backend.tf` and in `platform`'s
   > `data.terraform_remote_state.foundation` block. If you change `project` (and
   > therefore the bucket name) in this step, you must update all three of those
   > references to match, or the next steps' `terraform init` will fail to find the
   > backend.

2. **Foundation** — VPC, EKS, Fargate profile, security baseline. `terraform.tfvars.example`
   is a template, not a ready-to-apply file — copy it, then edit the copy before
   applying: at minimum, set `public_endpoint_allowed_cidrs` to your actual IP/CIDR
   range (never `0.0.0.0/0`) so the EKS API endpoint isn't left open to the internet:
   ```
   cd terraform/envs/prod/foundation
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars   # customize values, if necessary
   terraform init
   terraform apply
   ```
3. **Platform** — Karpenter, AWS Load Balancer Controller, ArgoCD. This stage
   configures the `kubernetes`/`helm`/`kubectl` providers against the cluster
   foundation just created, which is why it's a separate `terraform init`/`apply`
   from foundation rather than one stack. Again, copy `terraform.tfvars.example`
   to `terraform.tfvars` and edit the copy before applying:
   ```
   cd terraform/envs/prod/platform
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars   # customize values, if necessary
   terraform init
   terraform apply
   ```

Full design writeup, with diagrams and the reasoning behind every decision, is in
**[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)**. Team/task breakdown is in
**[`docs/TEAM-PLAN.md`](docs/TEAM-PLAN.md)**.
