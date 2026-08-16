#!/usr/bin/env bash
# Validates every piece of Kubernetes-bound content in this repo:
#   1. Helm chart lint + template render (the-redemption's own chart, plus
#      every kubernetes/infra-apps/* wrapper chart).
#   2. kubeconform schema validation of that rendered output, against
#      upstream Kubernetes schemas plus the community CRD catalog (covers
#      Argo Rollouts' Rollout/AnalysisTemplate, KEDA's ScaledObject,
#      Kyverno's ClusterPolicy, etc.) -- this catches real schema errors
#      (wrong/missing required fields) that neither "is this valid YAML"
#      nor "does Helm render it" can. Karpenter's NodePool/EC2NodeClass are
#      NOT covered here anymore -- they're created by terraform/modules/karpenter
#      now (kubernetes_manifest, not a rendered chart), so `terraform validate`
#      is their only static check; schema errors there only surface at
#      `apply` time against the live API server.
#   3. kubeconform on capacity-buffer directly -- it's a plain manifest
#      directory (no Chart.yaml), synced by ArgoCD's directory source, not
#      a Helm chart, so it skips step 1.
#
# Run manually with: scripts/validate-kubernetes.sh
# Runs automatically via pre-commit (see .pre-commit-config.yaml) and in CI
# (see .github/workflows/ci.yml) -- same script both places, so a local
# pass means CI passes too.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
render_dir="$(mktemp -d)"
dep_updated_dirs=()

cleanup() {
  rm -rf "$render_dir"
  # helm dependency update fetches into charts/ and writes Chart.lock
  # inside the repo tree (gitignored, but left on disk) -- clean those up
  # so re-running this script locally doesn't leave stale state around,
  # and so pre-commit doesn't flag "files were modified by this hook" for
  # artifacts nothing actually asked to keep.
  for dir in "${dep_updated_dirs[@]}"; do
    rm -rf "$dir/charts" "$dir/Chart.lock"
  done
}
trap cleanup EXIT

# CustomResourceDefinition kind is always skipped by kubeconform (a CRD
# manifest describes a schema, it isn't an instance of one) -- expected,
# not a gap. -ignore-missing-schemas means a CRD this catalog genuinely
# doesn't have yet is skipped with a warning rather than failing the
# build; that trade-off is worth it here since new/uncommon CRDs
# (external-secrets' generator types, for example) do fall through the
# catalog, and blocking on that would be noise unrelated to whether our
# own manifests are correct.
kubeconform_args=(
  -summary
  -ignore-missing-schemas
  -schema-location default
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
)

echo "### Helm charts: lint + template + kubeconform ###"
while IFS= read -r -d '' chart_yaml; do
  chart_dir="$(dirname "$chart_yaml")"
  name="$(basename "$chart_dir")"
  echo "==> ${chart_dir#"$repo_root"/}"

  if grep -q '^dependencies:' "$chart_yaml"; then
    helm dependency update "$chart_dir" >/dev/null
    dep_updated_dirs+=("$chart_dir")
  fi

  if ! helm lint "$chart_dir"; then
    fail=1
  fi
  if ! helm template test "$chart_dir" >"$render_dir/$name.yaml"; then
    fail=1
  fi
done < <(find "$repo_root/kubernetes" -name Chart.yaml -print0 | sort -z)

if ! kubeconform "${kubeconform_args[@]}" "$render_dir"/*.yaml; then
  fail=1
fi

echo
echo "### Plain manifest directories: kubeconform ###"
for dir in capacity-buffer; do
  path="$repo_root/kubernetes/infra-apps/$dir"
  echo "==> kubernetes/infra-apps/$dir"
  if ! kubeconform "${kubeconform_args[@]}" "$path"/*.yaml; then
    fail=1
  fi
done

exit $fail
