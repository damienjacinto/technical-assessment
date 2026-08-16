# argocd-apps: app-of-apps root

This directory is the source for the single root `app-of-apps` `Application` Terraform
creates ([`terraform/modules/argocd/main.tf`](../../terraform/modules/argocd/main.tf)).
ArgoCD syncs this whole directory recursively (`source.directory.recurse: true`), which
here means exactly two things:

- **`infra-apps.yaml`**: one `ApplicationSet` with a `list` generator, covering the 7
  infra-apps that share an identical shape (source path
  `kubernetes/infra-apps/<name>`, same repo/revision, same sync policy, only the
  destination namespace differs). Adding another uniformly-shaped infra-app is a new
  `elements` entry, not a new file.
- **`the-redemption.yaml`**: its own explicit `Application` -- it needs an extra Helm
  value (`environment`) and a different source path prefix
  (`kubernetes/apps/the-redemption`, not `kubernetes/infra-apps/...`), so it's the one
  case not worth forcing into the generator's template.

**Trade-off accepted knowingly:** these manifests are plain, git-committed YAML, not
templated by Terraform -- so `repoURL`/`targetRevision` are hardcoded (once, in
`infra-apps.yaml`'s template, and again in `the-redemption.yaml`) rather than
parameterized via `var.git_repo_url`/`var.git_revision` the way the old
directly-created-per-app `Application` resources were. Forking this repo or renaming the
default branch means updating both places. The root `app-of-apps` Application itself (in
`terraform/modules/argocd/main.tf`) still reads those variables normally -- only its
children lost that indirection.

**`tempo` is deliberately not included here** -- its chart under
`kubernetes/infra-apps/tempo/` doesn't exist (removed separately, unrelated to this
migration).

**Requires the ApplicationSet controller**, bundled unconditionally by the pinned
`argo-cd` chart version (`terraform/modules/argocd/main.tf`'s `var.argocd_chart_version`)
-- confirmed against that chart version's `templates/argocd-applicationset/deployment.yaml`
directly, since some chart versions/configurations gate it behind
`applicationSet.enabled`. Re-check that if the chart version ever changes.

**the-redemption's WAF ACL ARN** is the one value the old per-app `Application`
resources injected live from Terraform (`source.helm.valuesObject.ingress.wafAclArn`).
Static YAML can't carry a live value, so that seam moved: `terraform/envs/prod/platform/main.tf`
writes the ARN into a `kube-system` ConfigMap instead, and
[`kubernetes/apps/the-redemption/templates/ingress.yaml`](../apps/the-redemption/templates/ingress.yaml)
reads it via Helm's `lookup()` at render time, falling back to the chart's own
`values.yaml` placeholder when there's no live cluster to look up against (local
`helm lint`/`helm template`, CI).
