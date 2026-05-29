# PulseOps Event Contracts

PulseOps treats job history as an operational audit trail, not as the primary
source of truth for state reconstruction. The current source of truth is the
transactional model in PostgreSQL: `jobs`, `job_attempts`, `job_events`,
`queues`, and Oban's `oban_jobs`.

Events exist to answer these questions:

- What happened to this job?
- Which attempt produced this outcome?
- Was the final state caused by normal execution, retry exhaustion, operator
  action, webhook policy, or reconciliation?
- Is this job safe to retry or manually replay?

## Architectural Direction

- Keep job state queryable in `jobs`.
- Keep attempt-level execution evidence in `job_attempts`.
- Keep append-only lifecycle evidence in `job_events`.
- Use Oban as the durable executor and retry scheduler.
- Use a future event store only when the product needs stream replay,
  projection rebuilds, or external event subscriptions at scale.
- Treat manual replay as a privileged administrative operation, not as a normal
  retry path.

## Persisted Job Lifecycle Events

These are the event types the platform should expose as the stable audit
language for jobs.

| Event | Current producer | Meaning | Required metadata |
| --- | --- | --- | --- |
| `job.created` | `PulseOps.Jobs.create_job/2` | The API accepted and persisted a job request. | queue, worker, scheduled_at |
| `job.started` | Oban start telemetry | A worker attempt started. | attempt, queue, worker |
| `job.succeeded` | Oban stop telemetry | The attempt completed successfully and the job reached a terminal success state. | attempt, duration_ms, result summary |
| `job.failed` | Oban exception telemetry | The attempt failed but retry budget may remain. | attempt, duration_ms, error kind, error message |
| `job.dead_lettered` | Oban discard/exhausted retry path | The job reached terminal failure and requires operator action for re-execution. | attempt, retry count, error kind, error message |
| `job.cancelled` | Operator/API cancellation | The job was cancelled by an authorized actor or reconciled from Oban cancellation. | actor, requested_at, reason |
| `job.retried` | Operator/API retry | A terminal or retryable job was explicitly sent back to execution. | actor, requested_at, reason |

## Worker Operational Events

Worker events are operational signals. They do not need to become separate
public `job_events` rows unless an external consumer needs them. Today they are
represented through Oban telemetry, attempts, logs, metrics, and job lifecycle
events.

| Event | Source | Purpose |
| --- | --- | --- |
| `worker.attempt_started` | Oban start telemetry | Open an execution attempt and mark the public job `running`. |
| `worker.attempt_succeeded` | Oban stop telemetry | Close the attempt and emit `job.succeeded`. |
| `worker.attempt_failed` | Oban exception telemetry | Close the attempt and emit `job.failed` or `job.dead_lettered`. |
| `worker.attempt_cancelled` | Oban stop/exception telemetry | Close the attempt and emit `job.cancelled`. |
| `worker.state_reconciled` | `PulseOps.Jobs.Reconciler` | Repair stale public state when Oban is already terminal. |
| `worker.retention_pruned` | `PulseOps.Jobs.RetentionPruner` | Remove terminal job history after tenant retention expires. |

## Retry Policy

- Retry budget is bounded by `max_attempts`.
- Oban owns retry scheduling and backoff.
- PulseOps mirrors each attempt into `job_attempts`.
- A transient failure should leave the public job as `retryable`.
- Retry exhaustion should move the public job to `dead_lettered`.
- Retrying a dead-lettered job is an operator action and must append
  `job.retried`.
- Retry should preserve the original `job_id`, `correlation_id`, payload, and
  audit history.

## Dead-Letter Policy

A job is dead-lettered when execution cannot continue automatically.

Dead-letter events must include:

- final attempt number
- configured `max_attempts`
- error kind and message
- worker name
- queue name
- correlation ID
- whether the terminal state came from direct telemetry or reconciliation

Operational expectations:

- Dead-lettered jobs are not automatically replayed.
- Operators must provide a reason before retry/replay.
- Replay tooling must show original payload, final error, attempts, and events.
- Alerts should fire on elevated dead-letter rate, not on a single isolated
  dead-letter.

## Idempotency Policy

PulseOps uses two related but different idempotency concepts.

API job creation:

- `organization_id + idempotency_key` identifies a create request.
- Repeating the same request with the same idempotency key returns the existing
  job instead of creating a duplicate.
- `external_ref` is also tenant-scoped and unique when present.

Event consumption:

- External consumers should deduplicate by `event_id` if events are exported in
  the future.
- Internal `job_events` are append-only audit rows and should not be mutated to
  "fix" history.

Replay:

- Retry reuses the same `job_id`.
- Manual replay should create an explicit operator action and either reuse the
  same job through retry or create a new job with a replay-specific
  idempotency key such as `replay:<original_job_id>:<operator_action_id>`.
- Replay must never silently bypass tenant isolation, queue policy, timeout
  budget, webhook egress policy, or rate limits.

## Replay Decision Matrix

| Scenario | Action | Rationale |
| --- | --- | --- |
| Transient worker crash and attempts remain | Let Oban retry automatically. | No operator decision required. |
| Job is `dead_lettered` due temporary dependency outage | Operator retry same job. | Preserve history and correlation. |
| Job payload was wrong | Create a corrected new job. | Original job history should remain immutable. |
| Webhook blocked by SSRF/private-network policy | Do not replay until policy or destination is corrected. | Policy failures are not transient delivery failures. |
| Contract drift after deploy | Use controlled replay after validating payload version. | Prevent replaying incompatible historical payloads. |

## Supervision Direction

The supervision tree should preserve these failure boundaries:

- `Repo` owns database connectivity.
- `Oban` owns durable execution and retry scheduling.
- `PulseOps.RateLimiter` owns local cleanup and delegates distributed buckets to
  PostgreSQL when configured.
- `PulseOps.Jobs.WebhookCircuitBreaker` isolates repeated webhook destination
  failures.
- `PulseOps.Queues.Provisioner` keeps domain queues synchronized with Oban.
- `PulseOps.Jobs.Reconciler` repairs stale terminal state.
- `PulseOps.Jobs.RetentionPruner` removes old terminal history.

Worker failures should fail the attempt, not the application supervisor.
Supervisor restarts should recover infrastructure processes, not hide domain
failures. Domain failures belong in `job_attempts`, `job_events`, metrics, and
alerts.

## Event Envelope For Future Export

If PulseOps exports events externally, every event should include:

- `event_id`
- `event_type`
- `schema_version`
- `occurred_at`
- `producer`
- `organization_id`
- `queue_name`
- `job_id`
- `attempt`
- `correlation_id`
- `payload`

Schema example: [job_lifecycle_event.v1.json](job_lifecycle_event.v1.json).
