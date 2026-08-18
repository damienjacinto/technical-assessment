#!/usr/bin/env bash
# Simulates the flash-sale 10x traffic spike (docs/ARCHITECTURE.md) against
# the-redemption, to watch KEDA scale replicas and Karpenter scale nodes in
# response. Three phases - baseline, 10x spike, cooldown - each printing
# the actual achieved requests/sec so you can compare against KEDA's
# ScaledObject threshold (50 rps, kubernetes/apps/the-redemption/templates/
# scaledobject.yaml).
#
# Usage: scripts/load-test.sh <url> [baseline_concurrency] [multiplier] [phase_seconds]
#   url: the ALB directly, e.g. http://k8s-theredem-...elb.amazonaws.com/
#   Defaults: baseline concurrency 5, 10x multiplier, 5 minutes/phase.
#
# Heads-up: this goes through the ALB's WAFv2 rate-based rule
# (docs/ARCHITECTURE.md), deliberately set generous enough not to punish
# real flash-sale traffic - but a sustained single-IP spike can still get
# throttled by it. If requests start failing partway through a phase,
# check the WAF, not just the app/pods.
#
# Watch it land, in another terminal:
#   scripts/pods-by-nodepool.sh the-redemption
#   kubectl get scaledobject,hpa -n the-redemption -w
set -euo pipefail

url="${1:?Usage: scripts/load-test.sh <url> [baseline_concurrency] [multiplier] [phase_seconds]}"
# ab requires a path and fails instantly (not even a connection attempt)
# on a bare hostname - "http://host" errors, "http://host/" doesn't.
[[ "${url#*://}" == */* ]] || url="${url}/"
baseline="${2:-5}"
multiplier="${3:-10}"
phase_seconds="${4:-300}"
spike=$((baseline * multiplier))

echo "Target: ${url}"
echo

run_phase() {
  local label="$1" concurrency="$2" seconds="$3"
  echo "=== ${label}: ${concurrency} concurrent requests for ${seconds}s ==="
  # || true: a phase failing (e.g. the WAF starts throttling) shouldn't
  # silently kill the whole script under pipefail - show ab's raw output
  # instead so the failure is visible.
  ab -q -c "$concurrency" -t "$seconds" -n 100000000 "$url" 2>&1 |
    grep -E "Requests per second|Time per request|Failed requests|Non-2xx" ||
    echo "(phase failed - is the target still reachable? check the WAF too)"
  echo
}

run_phase "Baseline" "$baseline" "$phase_seconds"
run_phase "10x SPIKE" "$spike" "$phase_seconds"
run_phase "Cooldown (back to baseline)" "$baseline" "$phase_seconds"
