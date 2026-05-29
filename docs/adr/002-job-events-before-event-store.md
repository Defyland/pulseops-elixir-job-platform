# ADR 002: Use Transactional Job Tables and Audit Logs Before a Full Event Store

## Status

Accepted.

## Context

PulseOps needs reliable job execution history, retries, dead-letter state, manual
replay decisions, and operator auditability. There are two plausible designs:

- Full event store/event sourcing, where job state is rebuilt from event streams.
- Transactional job tables plus append-only audit logs, where state is queried
  directly and events explain how it changed.

Event sourcing would add event versioning, snapshots, projection rebuilds,
stream ordering, event upcasters, replay tooling, and operational runbooks for
projection drift. Those are valid capabilities, but they are not required for
the current product slice.

## Decision

PulseOps keeps transactional tables as the source of truth:

- `jobs` for current public state.
- `job_attempts` for execution attempts.
- `job_events` for append-only lifecycle audit.
- `oban_jobs` for durable executor state.

PulseOps should introduce a dedicated event store only when the product has a
clear event-stream requirement that cannot be served by transactional tables and
audit logs.

## When To Keep Transactional Tables + Audit Logs

Use the current model when:

- The API needs fast reads by tenant, status, queue, and job ID.
- Operators need a timeline for one job, not arbitrary stream replay.
- Job state changes are transactional with API writes or Oban telemetry.
- Replay is manual, explicit, and low volume.
- History retention is tenant-scoped and can prune terminal jobs.
- The primary consistency question is "what is the current state of this job?"
- External consumers do not require ordered event subscriptions.

This is the right fit for PulseOps today because job control is operational and
state-centric. The audit log supports diagnosis, while the `jobs` table remains
simple to query, index, test, and expose through OpenAPI.

## When To Introduce An Event Store

Add an event store when at least one of these becomes a hard requirement:

- External systems subscribe to a durable ordered stream of job events.
- Product needs projection rebuilds for multiple read models.
- Compliance requires immutable event retention independent of job retention.
- Manual replay becomes frequent and needs event-level simulation.
- Event history must outlive the transactional job row.
- Multiple bounded contexts consume job lifecycle events asynchronously.
- The platform needs temporal queries such as "rebuild tenant state as of T".

At that point, `job_events` can become the source for an outbox or migration
bridge, but the transition should be deliberate. Event store adoption should not
be a refactor hidden inside normal feature work.

## Replay Guidance

Retry and replay are different operations:

- Retry reuses the same job and asks Oban to execute it again.
- Replay is an administrative decision to re-run intent after reviewing payload,
  prior attempts, failure class, tenant, queue policy, and webhook policy.

Before adding event-store replay, PulseOps should require:

- operator identity
- replay reason
- original job ID
- payload hash or payload version
- target queue
- dry-run validation result
- idempotency key for the replay action

## Consequences

Positive:

- Job reads remain straightforward and indexed.
- Business state is not hidden behind projection rebuilds.
- Tests can assert state and audit history directly.
- Retention pruning is simple and tenant-specific.
- Oban remains the durable execution engine without an extra storage system.

Negative:

- `job_events` are audit logs, not a complete event-sourced aggregate stream.
- Projection rebuilds are not supported.
- Cross-service event subscriptions require future outbox/event-store work.
- Historical replay is operationally constrained by retained rows.

## Migration Path If Requirements Change

1. Add an outbox table or event stream writer transactionally beside
   `job_events`.
2. Backfill events from retained `jobs`, `job_attempts`, and `job_events`.
3. Publish exported event schemas with explicit versions.
4. Build read projections from the new event stream.
5. Keep `jobs` as the serving model until projections are proven correct.
6. Only then consider event-sourced state reconstruction for new domains.

## Non-Goals

- Do not use an event store merely to make the architecture sound more advanced.
- Do not rebuild current job state from events in the hot path.
- Do not allow replay to bypass authorization, idempotency, queue policy,
  webhook egress policy, or audit logging.
