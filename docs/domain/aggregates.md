# Aggregates

## Organization Aggregate

Root: `Organization`

Entities:

- API keys
- Queues
- Jobs

Key rules:

- Organization slug is globally unique.
- API keys belong to exactly one organization.
- Queues and jobs are always queried through `organization_id`.
- Retention policy is defined at the organization level.

Why this boundary exists:

- Tenant isolation is the highest-value invariant in the system.
- Cross-tenant reads should fail closed before any job or queue rule is applied.

## Queue Aggregate

Root: `Queue`

Entities:

- Queue configuration
- Runtime provisioning state in Oban

Key rules:

- Queue name is unique per organization.
- Concurrency and timeout budgets are bounded.
- Paused queues should prevent uncontrolled execution without deleting history.
- Queue updates must synchronize with Oban queue configuration.

Why this boundary exists:

- Queue policy is a tenant-facing contract and must not be hidden inside worker
  options.

## Job Aggregate

Root: `Job`

Entities:

- Job attempts
- Job events
- Oban executor row

Key rules:

- `organization_id + idempotency_key` is unique when present.
- `organization_id + external_ref` is unique when present.
- Job lifecycle transitions must follow the state machine.
- Attempts are append-only execution evidence.
- Events are append-only audit evidence.
- Terminal jobs can be pruned only after tenant retention expires.

Why this boundary exists:

- Job state is the primary product surface. Oban is the executor, not the public
  domain model.
