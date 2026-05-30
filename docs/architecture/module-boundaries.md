# Module Boundaries

## `PulseOps.Identity`

Owns:

- organization registration
- API key generation, hashing, authentication, and revocation
- default queue bootstrap through the queue provisioner

Must not own:

- job lifecycle transitions
- worker execution
- webhook delivery

## `PulseOps.Queues`

Owns:

- queue configuration
- queue validation
- synchronization from domain queues into Oban runtime queues

Must not own:

- tenant authentication
- job attempt recording
- webhook policy decisions

## `PulseOps.Jobs`

Owns:

- job creation and idempotency
- job state machine
- retry and cancel operations
- attempts and lifecycle events
- worker handler orchestration
- reconciler and retention pruner
- webhook security helpers and circuit breaker

Must not own:

- HTTP response formatting
- API key parsing
- Grafana or Prometheus configuration files

## `PulseOpsWeb`

Owns:

- routes and controllers
- request validation boundary
- auth and rate-limit plugs
- error JSON contract
- health, readiness, and metrics endpoints

Must not own:

- database transaction rules
- retry semantics
- tenant bootstrap internals

## Extension Points

- Add a new worker by extending the job handler allowlist, tests, OpenAPI
  examples, and event/error documentation.
- Add a new queue policy by updating queue changesets, provisioning logic,
  OpenAPI docs, and concurrency tests.
- Add a new external event export by introducing an outbox/event-store path
  described in [ADR 002](../adr/002-job-events-before-event-store.md).
