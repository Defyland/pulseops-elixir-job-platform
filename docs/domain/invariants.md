# Domain Invariants

## Tenant Isolation

Every organization-scoped query must include `organization_id`. Cross-tenant job,
queue, API key, retry, and cancel attempts must not reveal whether the target
resource exists.

Evidence:

- `docs/api/authorization-matrix.md`
- `test/pulse_ops_web/controllers/job_controller_test.exs`
- `test/pulse_ops_web/controllers/api_key_controller_test.exs`

## Idempotent Job Creation

For a given organization, an idempotency key can create at most one job. Repeated
requests with the same key return the existing job instead of duplicating work.

Evidence:

- `docs/architecture/data-consistency.md`
- `test/pulse_ops/jobs_test.exs`

## Bounded Retry

A job cannot retry forever. Retry budget is bounded by queue/job policy and
terminal failure is represented as `dead_lettered`.

Evidence:

- `docs/events/README.md`
- `test/pulse_ops/jobs/execution_worker_test.exs`

## Append-Only Execution Evidence

Attempts and events describe what happened. They should not be rewritten to hide
failures, reconciliation, or operator actions.

Evidence:

- `docs/events/README.md`
- `docs/adr/002-job-events-before-event-store.md`

## Webhook Safety

Webhook execution must not bypass egress policy. Unsafe destinations are policy
failures, not transient delivery failures.

Evidence:

- `docs/security/threat-model.md`
- `test/pulse_ops/jobs/webhook_security_test.exs`

## Retention Safety

Retention pruning removes terminal history only. Active `queued`, `running`, and
`retryable` jobs must not be deleted even if they are older than the retention
window.

Evidence:

- `docs/architecture/data-consistency.md`
- `test/pulse_ops/jobs/retention_pruner_test.exs`
