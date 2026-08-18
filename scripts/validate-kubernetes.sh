#!/usr/bin/env bash
# Validates every piece of Kubernetes-bound content in this repo:
#   1. Helm chart lint + template render (the-redemption's own chart, plus
#      every kubernetes/infra-apps/* wrapper chart).
#   2. kubeconform schema validation of that rendered output, against
#      upstream Kubernetes schemas plus the community CRD catalog (covers
#      Argo Rollouts' Rollout/AnalysisTemplate, KEDA's ScaledObject,
#      Kyverno's ClusterPolicy, etc.). This catches real schema errors
#      (wrong/missing required fields) that neither "is this valid YAML"
#      nor "does Helm render it" can. Karpenter's NodePool/EC2NodeClass are
#      NOT covered here anymore. They're created by terraform/modules/karpenter
#      now (kubernetes_manifest, not a rendered chart), so `terraform validate`
#      is their only static check; schema errors there only surface at
#      `apply` time against the live API server.
#   3. kubeconform on capacity-buffer directly. it's a plain manifest
#      directory (no Chart.yaml), synced by ArgoCD's directory source, not
#      a Helm chart, so it skips step 1.
#
# Run manually with: scripts/validate-kubernetes.sh
# Runs automatically via pre-commit (see .pre-commit-config.yaml) and in CI
# (see .github/workflows/ci.yml). Same script both places, so a local
# pass means CI passes too.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
render_dir="$(mktemp -d)"
dep_updated_dirs=()

cleanup() {
  rm -rf "$render_dir"
  # helm dependency update fetches into charts/ and writes Chart.lock
  # inside the repo tree (gitignored, but left on disk). Clean those up
  # so re-running this script locally doesn't leave stale state around,
  # and so pre-commit doesn't flag "files were modified by this hook" for
  # artifacts nothing actually asked to keep.
  for dir in "${dep_updated_dirs[@]}"; do
    rm -rf "$dir/charts" "$dir/Chart.lock"
  done
}
trap cleanup EXIT

# CustomResourceDefinition kind is always skipped by kubeconform (a CRD
# manifest describes a schema, it isn't an instance of one). Expected,
# not a gap. -ignore-missing-schemas means a CRD this catalog genuinely
# doesn't have yet is skipped with a warning rather than failing the
# build; that trade-off is worth it here since new/uncommon CRDs
# (external-secrets' generator types, for example) do fall through the
# catalog, and blocking on that would be noise unrelated to whether our
# own manifests are correct.

# Uncached, kubeconform re-fetches every distinct CRD's schema (Rollout,
# ScaledObject, ClusterPolicy, NodePool, ...) from GitHub on every single
# run - the single slowest part of this whole script. Persisted outside
# the repo (~/.cache, not gitignore'd project state), same as Helm's own
# repository cache; schemas change rarely enough that staleness isn't a
# real concern here.
kubeconform_args=(
  -summary
  -ignore-missing-schemas
  -cache "${HOME}/.cache/kubeconform"
  -schema-location default
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
)
# kubeconform opens the cache dir rather than creating it, so a runner
# with no prior cache (fresh CI, or first local run) fails without this.
mkdir -p "${HOME}/.cache/kubeconform"

# Independent charts, independent remote repos: fetched in parallel, not
# one at a time in the main loop below. Each `helm dependency update` is
# network-bound (~8-10s) and there are 6 of them; serial made this script
# (and every pre-commit run/CI run using it) ~50s slower than it needed
# to be for no benefit, since none of these charts depend on each other.
echo "### Pre-fetching Helm chart dependencies (parallel) ###"
dep_pids=()
while IFS= read -r -d '' chart_yaml; do
  chart_dir="$(dirname "$chart_yaml")"
  if grep -q '^dependencies:' "$chart_yaml"; then
    dep_updated_dirs+=("$chart_dir")
    (helm dependency update "$chart_dir" >/dev/null) &
    dep_pids+=($!)
  fi
done < <(find "$repo_root/kubernetes" -name Chart.yaml -print0 | sort -z)
for pid in "${dep_pids[@]}"; do
  if ! wait "$pid"; then
    fail=1
  fi
done

echo "### Helm charts: lint + template + kubeconform ###"
while IFS= read -r -d '' chart_yaml; do
  chart_dir="$(dirname "$chart_yaml")"
  name="$(basename "$chart_dir")"
  echo "==> ${chart_dir#"$repo_root"/}"

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
for dir in capacity-buffer karpenter-nodepools; do
  path="$repo_root/kubernetes/infra-apps/$dir"
  echo "==> kubernetes/infra-apps/$dir"
  if ! kubeconform "${kubeconform_args[@]}" "$path"/*.yaml; then
    fail=1
  fi
done

exit $fail
