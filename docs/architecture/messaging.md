# Messaging and Async Execution

PulseOps uses Oban and PostgreSQL as the durable execution backend. There is no
RabbitMQ broker in this slice, so broker terms are mapped to the Oban-backed
implementation below.

## Topology

- Exchange: not applicable; HTTP is the publisher surface and Oban is the
  durable executor.
- Queues: tenant-defined `queues` rows are synchronized into Oban queue names.
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

## Test Evidence

- `test/pulse_ops/jobs/execution_worker_test.exs` covers success, transient
  failure, dead-lettering, timeout failures, and correlation propagation.
- `test/pulse_ops/jobs_test.exs` covers idempotency, retry/cancel lifecycle
  rules, hot-path queue provisioning regression, and terminal-state
  reconciliation.
- `test/pulse_ops/queues/provisioner_test.exs` covers Oban queue synchronization.
