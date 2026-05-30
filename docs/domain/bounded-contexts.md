# Bounded Contexts

PulseOps is implemented as a modular monolith. Boundaries are enforced through
Phoenix contexts and explicit data ownership rather than service boundaries.

## Identity

Module: `PulseOps.Identity`

Responsibilities:

- Register organizations.
- Issue, authenticate, and revoke API keys.
- Keep tenant identity separate from job execution.

Owned concepts:

- Organization
- API key

## Queues

Module: `PulseOps.Queues`

Responsibilities:

- Define tenant queue policy.
- Synchronize domain queues with Oban runtime queues.
- Keep concurrency, timeout, retry, and pause semantics visible to the API.

Owned concepts:

- Queue
- Queue policy
- Provisioning

## Jobs

Module: `PulseOps.Jobs`

Responsibilities:

- Create jobs idempotently.
- Track lifecycle state.
- Record attempts and events.
- Retry, cancel, reconcile, and prune jobs.
- Enforce webhook execution safety through job handlers.

Owned concepts:

- Job
- Attempt
- Job event
- Worker handler
- Retention pruner
- Reconciler
- Webhook policy

## Web API

Module: `PulseOpsWeb`

Responsibilities:

- Expose versioned JSON API endpoints.
- Enforce API key authentication and rate limits.
- Convert domain errors to consistent HTTP errors.
- Expose health, readiness, and metrics endpoints.

Owned concepts:

- Controllers
- Plugs
- Error response contract

## Observability

Modules: `PulseOps.Observability`, `PulseOpsWeb.Telemetry`, job telemetry
helpers.

Responsibilities:

- Emit domain metrics.
- Propagate request and correlation IDs.
- Provide logs, health probes, readiness checks, and Prometheus metrics.
