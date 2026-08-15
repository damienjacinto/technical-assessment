# The Redemption — EKS Platform

Business-critical hotel-points-deduction microservice on Amazon EKS. Steady baseline
traffic, sudden 10x Flash Sale spikes, zero-downtime target. Terraform + GitOps
(ArgoCD), built for a 3-person SRE team.

Full design writeup, with diagrams and the reasoning behind every decision, is in
**[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)**. Incident procedures are in
**[`docs/RUNBOOK.md`](docs/RUNBOOK.md)**. Team/task breakdown is in
**[`docs/TEAM-PLAN.md`](docs/TEAM-PLAN.md)**.

## Repository map

```
technical-assessment/
├── docs/                       Architecture writeup, runbook, team plan
├── terraform/
│   ├── bootstrap/              State backend (S3, native locking) — apply once, by itself
│   ├── modules/                 vpc, eks, fargate-profile, coredns, pod-identity,
│   │                            karpenter, alb-controller, security-baseline, argocd
│   └── envs/prod/
│       ├── foundation/          Stage 1: VPC, EKS, Fargate profile, security baseline
│       └── platform/            Stage 2: Karpenter, ALB Controller, ArgoCD
└── kubernetes/
    ├── infra-apps/               ArgoCD-managed: capacity-buffer, KEDA,
    │                             Argo Rollouts, Kyverno, External Secrets,
    │                             OTel Collector, kube-prometheus-stack, Tempo
    └── apps/the-redemption/      The application Helm chart
```

`terraform/envs/prod` is the first instance of a per-environment pattern, not a one-off —
a future `terraform/envs/staging/` reuses the exact same `terraform/modules/*`.

## Scope note

The data layer (what actually stores point balances) is explicitly **out of scope** for
this build — this is a compute/platform design. Every place a real data store would plug
in already exists as network/IAM boundary: an isolated database subnet tier with its own
security group (`terraform/modules/vpc`), and a zero-permission Pod Identity role placeholder for
the-redemption's ServiceAccount (`terraform/envs/prod/foundation/main.tf`) ready for a
policy to be attached once that decision is made.

The container image referenced in `kubernetes/apps/the-redemption/values.yaml` is a
placeholder standing in for the real application — business logic is out of scope the
same way.

## Deploy order

Requires an AWS account, Terraform >= 1.9, and `kubectl`/`helm` for verification after
the cluster exists. Not run in this environment — see **Verification** below for what
was actually checked here.

1. **State backend** (once, with local state):
   ```
   cd terraform/bootstrap
   terraform init && terraform apply
   ```
2. **Foundation** (VPC, EKS, Fargate profile, security baseline):
   ```
   cd terraform/envs/prod/foundation
   cp terraform.tfvars.example terraform.tfvars   # fill in real values
   # backend.tf and providers.tf reference the account ID from step 1 — replace
   # the ACCOUNT_ID placeholders in both files first.
   terraform init && terraform apply
   ```
3. **Platform** (Karpenter, AWS Load Balancer Controller, ArgoCD — configures the
   `kubernetes`/`helm` providers against the cluster foundation just created, which is
   exactly why this is a separate stage/state):
   ```
   cd terraform/envs/prod/platform
   cp terraform.tfvars.example terraform.tfvars   # set git_repo_url to this repo
   terraform init && terraform apply
   ```
4. From here, **ArgoCD reconciles everything else** — NodePools, KEDA, Argo Rollouts,
   Kyverno, External Secrets, the observability stack, and the-redemption itself — by
   watching this repo. No further manual `kubectl apply` steps.

## Verification

No live AWS account or Kubernetes cluster in the environment this was built in, so
verification here was static, not a real `apply`. `.github/workflows/ci.yml` runs
`pre-commit run --all-files` (`.pre-commit-config.yaml`) on every push/PR, which is the
same thing to run locally before committing:

- `terraform fmt -check -recursive` and `terraform validate` (after
  `terraform init -backend=false`) across `bootstrap/` and both `envs/prod/*` stacks.
- `tflint` (`.tflint.hcl`) and `checkov` (`.checkov.yaml`) across every Terraform module.
- `terraform-docs` (`.terraform-docs.yml`) keeps each `terraform/modules/*/README.md`
  generated from the module's actual variables/outputs/resources, not hand-maintained.
- `helm lint` and `helm template` against `kubernetes/apps/the-redemption` and every
  `kubernetes/infra-apps/*` wrapper chart
  ([`scripts/validate-kubernetes.sh`](scripts/validate-kubernetes.sh)).
- `kubeconform` schema validation of every rendered manifest (including
  `capacity-buffer`, which isn't a Helm chart) against upstream
  Kubernetes schemas plus the community CRD catalog -- this is what actually caught two
  real bugs during development: a missing required `consolidateAfter` on the
  `on-demand-baseline` NodePool, and a missing required `amiSelectorTerms` on the
  EC2NodeClass. Neither would have been caught by YAML-syntax or `helm template` checks
  alone.
- `renovate.json5` keeps Terraform providers/modules, Helm chart dependency versions,
  pre-commit hook revisions, and GitHub Actions versions from quietly going stale --
  exactly the category of problem (an outdated `hashicorp/aws` provider pin, an EKS
  module version that predated the provider's v6 breaking changes) that had to be found
  and fixed by hand during this build.

What that verification does **not** cover, and would need a real AWS account + cluster to
confirm: that `terraform apply` actually succeeds end to end, that the ArgoCD
Applications actually reconcile, that the canary AnalysisTemplate's PromQL queries match
real metric names once a real application image is instrumented, and the Regional NAT
Gateway question documented in `terraform/modules/vpc/NOTES.md`.
