# Deployment Readiness

PulseOps should be deployed as an API process plus supervised worker processes. The current documentation focuses on the runtime shape before adding Kubernetes manifests.

## Current posture

- Phoenix API surface.
- Persistent job execution through Oban.
- Health, readiness, metrics, logs, and traces.
- Queue depth and worker lifecycle metrics.
- CI security and dependency checks.

## Deferred platform work

- Kubernetes manifests and Helm charts are deferred until queue topology and worker pools stabilize.
- Service mesh is deferred; application-level timeout, retry, DLQ, and webhook egress controls are the primary safety mechanisms.
- Multi-node rate limiting should use PostgreSQL-backed buckets or another shared store before production scale.
