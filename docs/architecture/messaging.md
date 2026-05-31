# Messaging and Async Execution

PulseOps uses Oban and PostgreSQL as the durable execution backend. There is no
RabbitMQ broker in this slice, so broker terms are mapped to the Oban-backed
implementation below.

## Topology

- Exchange: not applicable; HTTP is the publisher surface and Oban is the
  durable executor.
- Queues: tenant-defined `queues` rows are synchronized into tenant-scoped Oban
  runtime queue names. Each app node resynchronizes periodically so local Oban
  queue processes converge without putting provisioning on the enqueue hot path.
- Routing keys: the API routes jobs by `queue_name` or `queue_id`.
- Retry queues: Oban stores retryable jobs in `oban_jobs` with scheduled retry
  timing and per-job attempt limits.
- Dead-letter queue: exhausted jobs are represented as platform
  `dead_lettered` jobs and terminal Oban rows.

## Delivery Semantics

- Message idempotency is enforced with `organization_id + idempotency_key`.
- Consumer acknowledgement is represented by Oban moving a job to terminal
  state after `PulseOps.Jobs.ExecutionWorker.perform/1` returns.
- Correlation IDs are persisted on `jobs`, included in Oban job args, added to
  Logger metadata, written to `job_events`, and propagated to webhook requests.
- Attempt metadata is persisted in `job_attempts` for every execution start and
  terminal outcome.

## Failure Handling

- Transient worker errors become `retryable` while attempts remain.
- Exhausted worker failures become `dead_lettered`.
- Operator retry calls move dead-lettered jobs back into execution through Oban.
- Operator cancel calls update both the public job state and the Oban job.
- A periodic reconciler repairs public jobs stuck in `running` when the matching
  Oban row is already terminal.

## Lifecycle, Retry, DLQ, and Replay Direction

- The public lifecycle language is documented in
  [docs/events/README.md](../events/README.md).
- Retry means re-executing the same job while preserving `job_id`,
  `correlation_id`, attempts, and events.
- Dead-letter means automatic execution has stopped and operator intent is
  required before further execution.
- Replay should be treated as a privileged administrative operation, not as a
  hidden retry side effect.
- Replay should require a reason, actor, source job, payload/version review, and
  replay-specific idempotency key.
- Policy failures such as webhook SSRF/private-network blocking should not be
  retried until configuration or destination is corrected.

## Test Evidence

- `test/pulse_ops/jobs/execution_worker_test.exs` covers success, transient
  failure, dead-lettering, timeout failures, and correlation propagation.
- `test/pulse_ops/jobs_test.exs` covers idempotency, retry/cancel lifecycle
  rules, hot-path queue provisioning regression, and terminal-state
  reconciliation.
- `test/pulse_ops/queues/provisioner_test.exs` covers Oban queue synchronization.
