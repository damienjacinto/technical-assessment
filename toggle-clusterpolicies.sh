#!/usr/bin/env bash
# Toggles spec.admission on every ClusterPolicy. Safe against ArgoCD's
# selfHeal: the infra-apps ApplicationSet's ignoreDifferences already
# excludes .spec.admission on ClusterPolicy, so this patch won't get
# reverted on the next sync.
#
# Usage:
#   ./toggle-clusterpolicies.sh disable   # spec.admission: false (default)
#   ./toggle-clusterpolicies.sh enable    # spec.admission: true

set -euo pipefail

mode="${1:-disable}"
case "$mode" in
  disable) admission=false ;;
  enable)  admission=true ;;
  *) echo "usage: $0 [disable|enable]" >&2; exit 1 ;;
esac

policies=$(kubectl get clusterpolicy -o jsonpath='{.items[*].metadata.name}')

if [ -z "$policies" ]; then
  echo "No ClusterPolicies found."
  exit 0
fi

for name in $policies; do
  echo "Setting spec.admission=$admission on $name"
  kubectl patch clusterpolicy "$name" --type=merge -p "{\"spec\":{\"admission\":$admission}}"
done
