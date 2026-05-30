# Non-Goals

PulseOps intentionally avoids several features in this portfolio slice.

## Browser UI

The API is the product surface. A UI would add frontend scope without proving
more about backend architecture, lifecycle consistency, or operability.

## Full Event Sourcing

The current problem needs current job state plus audit history. A full event
store would add projection rebuilds, upcasters, snapshots, replay tooling, and
operational runbooks before the product has event-stream requirements.

See [ADR 002](../adr/002-job-events-before-event-store.md).

## RabbitMQ as the Primary Executor

Oban provides durable PostgreSQL-backed execution, retries, scheduling, and
telemetry with one fewer infrastructure dependency. RabbitMQ can be added later
as an ingress adapter if broker-native routing becomes a product requirement.

## OAuth/OIDC

High-entropy API keys are sufficient for this backend challenge. OAuth/OIDC,
SAML, and workload identity are deferred until the platform needs delegated
identity, human admin sessions, or enterprise SSO.

## Real Customer Production Operations

The repository includes production-shaped code, runbooks, CI, Docker, alerts,
and deployment reference files. It does not provision managed PostgreSQL, page
rotations, secret managers, compliance processes, or production traffic.

See [production gap analysis](../architecture/production-gap-analysis.md).
