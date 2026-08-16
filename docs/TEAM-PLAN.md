# Team Plan — 1 Senior, 2 Junior Engineers

## Principle

Split by blast radius. Senior owns what's expensive to get wrong; each Junior owns a
self-contained objective they can build and demo independently, pairing with the
Senior only where their work touches something the Senior owns.

## Senior — foundation, security, release safety

- **Objective**: a network-isolated, least-privilege cluster, safe to deploy to under
  load.
- **Owns**: network design, cluster foundation, identity/IAM, 10x capacity sizing,
  admission/network policy, canary release strategy, the GitOps repository structure
  (what lives where, how changes flow from PR to cluster).
- **Review gate**: mandatory on identity, network policy, network design; signs off on
  release-safety thresholds and flash-sale pre-warm timing.

## Junior A — delivery & scaling

- **Objective**: ship safely, scale automatically, on capacity the Senior already
  sized.
- **Owns**: rollout/traffic-shifting behavior, autoscaling triggers, CI pipeline.
- **Pairs with Senior on**: wiring rollout behavior to the capacity ceilings.

## Junior B — observability

- **Objective**: make health measurable, incidents diagnosable from a dashboard.
- **Owns**: telemetry pipeline, alert thresholds, the first ops dashboard.
- **Pairs with Senior on**: alert thresholds vs. what "revenue loss" means.

## Ongoing ownership

- **Flash-sale on-call**: rotates across all three; Senior is the escalation path.
  Building the scaling/alerting is not the same as watching it during a live sale.
- **Versioning policy cadence** (revisit "one minor behind" each Kubernetes minor
  release, ~every 4 months / 3x a year): Senior. Tied to two real schedules, not
  arbitrary: Kubernetes' own release cadence, and EKS's 14-month standard-support
  window per version — staying one minor behind keeps a comfortable margin before a
  version ages out of standard support into the pricier extended-support tier.

## Sequencing

1. Senior solo: network → identity → cluster foundation.
2. Senior: capacity tooling + GitOps bootstrap (Junior A shadows).
3. Junior A and Junior B in parallel: delivery/scaling vs. observability.
4. Senior: admission/network policy, once the app exists to validate against.
5. All three: validate the incident runbook against a real cluster.

## Avoids

No single-owner objective only one person understands. Every Junior area has one
scoped Senior review gate, not a full re-review — keeps the Senior from bottlenecking.
