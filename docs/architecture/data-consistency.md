# Data Consistency and Transaction Boundaries

## Transaction boundaries

### Organization bootstrap

- `PulseOps.Identity.register_organization/1` creates the organization, default
  queue, and bootstrap API key in one database transaction.
- Failure in any step rolls back the whole bootstrap flow.

### Job creation

- `PulseOps.Jobs.create_job/2` inserts the public `jobs` row, inserts the Oban
  job, and writes the initial audit event inside one transaction boundary.
- Runtime queue provisioning happens during organization bootstrap and queue
  create/update flows, not on every enqueue. This keeps queue metadata changes
  off the request hot path under load.
- Each node also periodically resynchronizes domain queues from PostgreSQL into
  local Oban queue processes. That keeps `local_only` queue operations safe
  while allowing nodes to converge after a queue is created elsewhere.
- Idempotency is checked before the transaction and enforced again by a unique
  database constraint on `organization_id + idempotency_key`. Reused keys are
  compared against a deterministic request fingerprint so payload drift becomes
  an explicit conflict instead of an accidental dedupe.

### Retry and cancel

- Retry and cancel both update the public `jobs` row and append a `job_events`
  record in one transaction.
- Oban retry/cancel commands are issued inside the same transactional function so
  the platform state and executor intent move together.

### Oban lifecycle reconciliation

- The normal source of truth for `queued -> running -> terminal` transitions is
  Oban telemetry, which persists `jobs`, `job_attempts`, and `job_events` state
  as workers start and stop.
- A periodic reconciler scans platform jobs still marked `running` whose
  `oban_jobs` row is already terminal (`completed`, `discarded`, or
  `cancelled`).
- Reconciliation locks the platform row with `FOR UPDATE`, rewrites the terminal
  state idempotently, upserts the attempt record, and appends a terminal audit
  event marked as `reconciled`.
- This is a safety net for overload or deploy windows where the Oban terminal
  event completed but persistence of the mirrored platform state was missed.

### Retention pruning

- `PulseOps.Jobs.prune_expired_jobs/1` deletes terminal job history after each
  tenant's `organization.retention_days` window.
- Only `succeeded`, `dead_lettered`, and `cancelled` jobs are pruned. Active
  `queued`, `running`, and `retryable` jobs are intentionally preserved even if
  old.
- Pruning removes `job_events`, `job_attempts`, matching `oban_jobs`, and the
  public `jobs` row in one database transaction.
- `PulseOps.Jobs.RetentionPruner` schedules the operation in production
  runtime children.

### Distributed rate limiting

- Local development can keep `API_RATE_LIMIT_STORAGE=ets`.
- Production should set `API_RATE_LIMIT_STORAGE=postgres` so every app node
  increments the same `(identifier, bucket)` row.
- `rate_limit_buckets` uses an atomic PostgreSQL upsert and expires old buckets
  through the limiter cleanup cycle.

## Constraints and indexes

### Unique constraints

- `organizations.slug`
- `api_keys.key_prefix`
- `api_keys.organization_id + name`
- `queues.organization_id + name`
- `jobs.organization_id + external_ref` when present
- `jobs.organization_id + idempotency_key` when present
- `job_attempts.job_id + attempt`
- `job_attempts.oban_job_id + attempt`
- `rate_limit_buckets.identifier + bucket`

### Foreign keys

- `api_keys.organization_id -> organizations.id`
- `queues.organization_id -> organizations.id`
- `jobs.organization_id -> organizations.id`
- `jobs.queue_id -> queues.id`
- `job_attempts.job_id -> jobs.id`
- `job_events.job_id -> jobs.id`

### Operational indexes

- status and inserted-at indexes for job listing
- queue/status composite indexes for queue depth inspection
- scheduled-at index for job scheduling and replay
- per-job event and attempt indexes for audit retrieval
- `rate_limit_buckets.expires_at_ms` for cleanup

## Isolation assumptions

- PostgreSQL default `READ COMMITTED` isolation is assumed.
- The implementation relies on unique constraints, not on serializable
  transactions, to close races around idempotency and unique queue naming.
- Oban provides durable queue persistence through PostgreSQL rather than a
  separate broker.

## Optimistic locking

- No explicit optimistic locking column is used in this slice.
- Queue and job lifecycle updates are small and strongly constrained by tenant
  filters, current-state transition rules, and unique constraints.
- If concurrent operator edits become common, an explicit `lock_version` field is
  the next upgrade path.

## Migration strategy

- Core tables are created through additive Ecto migrations in `priv/repo/migrations`.
- Oban schema creation is delegated to `Oban.Migration`.
- New production migrations should remain forward-only and reversible where
  practical.

## Rollback strategy

- Application-level multi-step writes roll back through `Repo.transaction/1`.
- Schema rollback uses the matching Ecto migration `down` or `change` reversal.
- Operational rollback for a bad release should prefer redeploying the previous
  application version before destructive schema rollback.
