# Use Cases

## UC1: Register a Tenant

An operator creates an organization and receives a bootstrap API key. The
registration flow also provisions the default queue so the tenant can enqueue
work immediately.

## UC2: Enqueue an Idempotent Job

A tenant submits a job with `idempotency_key`. If the request is retried by the
client, PulseOps returns the existing job instead of creating duplicate work.

## UC3: Execute and Observe a Job

PulseOps schedules the job through Oban. The worker records attempts, lifecycle
events, metrics, and logs with correlation metadata.

## UC4: Handle a Transient Failure

A worker failure moves the job to `retryable` while attempts remain. Oban owns
retry scheduling and PulseOps mirrors the public lifecycle state.

## UC5: Triage a Dead-Lettered Job

When attempts are exhausted, the job becomes `dead_lettered`. Operators inspect
the final error, attempts, events, queue policy, and webhook policy before
retrying or creating a corrected new job.

## UC6: Protect Webhook Egress

Webhook jobs are checked against HTTPS, host allowlists, private-network
blocking, DNS validation, timeout budgets, and circuit breaker state before
outbound delivery.

## UC7: Prune Terminal History

Terminal jobs are pruned according to tenant retention policy. Active jobs are
preserved even when older than the retention window.
