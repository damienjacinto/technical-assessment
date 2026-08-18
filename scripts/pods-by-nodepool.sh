#!/usr/bin/env bash
# Lists every pod alongside the node it's running on and that node's
# Karpenter nodepool (karpenter.sh/nodepool label) - useful for checking
# where the-redemption/capacity-buffer/tooling actually landed across the
# on-demand-baseline/spot-burst/tools tiers (docs/ARCHITECTURE.md).
#
# Usage: scripts/pods-by-nodepool.sh [namespace] [--once]
#   No namespace: every namespace, like `kubectl get pods -A`.
#   Refreshes every 20s by default, for watching a rollout/consolidation
#   move pods across nodepools live. INTERVAL overrides the delay; --once
#   (or non-interactive stdout, e.g. piped to a file) runs a single pass.
set -euo pipefail

namespace_args=(-A)
once=0
for arg in "$@"; do
  case "$arg" in
    --once) once=1 ;;
    *) namespace_args=(-n "$arg") ;;
  esac
done

interval="${INTERVAL:-20}"

print_table() {
  local nodepool_by_node
  nodepool_by_node="$(kubectl get nodes -o json |
    jq -r '.items[] | [.metadata.name, (.metadata.labels["karpenter.sh/nodepool"] // "-")] | @tsv')"

  kubectl get pods "${namespace_args[@]}" -o json | jq -r --arg nodepools "$nodepool_by_node" '
    ($nodepools | split("\n") | map(select(length > 0) | split("\t")) | map({(.[0]): .[1]}) | add) as $pool |
    ["NAMESPACE", "POD", "STATE", "NODE", "NODEPOOL"],
    (.items[] | [.metadata.namespace, .metadata.name, (.status.phase // "-"), (.spec.nodeName // "-"), ($pool[.spec.nodeName // ""] // "-")])
    | @tsv
  ' | column -t
}

if [[ "$once" == "1" || ! -t 1 ]]; then
  print_table
  exit 0
fi

clear
while true; do
  frame="$(
    echo "Every ${interval}s - $(date -u +"%Y-%m-%dT%H:%M:%SZ") (Ctrl-C to stop)"
    echo
    print_table
  )"
  tput cup 0 0
  tput ed
  printf '%s\n' "$frame"
  sleep "$interval"
done
