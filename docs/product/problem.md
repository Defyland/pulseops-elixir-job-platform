# Product Problem

PulseOps solves the operational gap between "we have background jobs" and "we
can safely expose job execution as a tenant-facing platform capability."

Teams often start with ad hoc workers embedded inside an application. That is
fine until they need tenant isolation, idempotency, retries, dead-letter review,
replay discipline, webhook safety, and audit evidence. At that point the queue
becomes a product surface, not just an implementation detail.

## Users

- Platform engineers who need a reliable internal job execution API.
- B2B SaaS product teams that run customer-specific asynchronous workloads.
- Operations teams that need to inspect failures and retry work safely.
- Backend engineers who need webhook delivery without rebuilding reliability
  primitives in every service.

## Core Workflow

1. A tenant is registered as an organization.
2. The tenant receives an API key.
3. The tenant creates or configures a queue.
4. The tenant enqueues a job with an optional idempotency key.
5. PulseOps persists the job, schedules execution through Oban, and records
   lifecycle events.
6. Operators inspect attempts, events, metrics, and logs when a job fails.
7. Retry or replay decisions are made explicitly instead of being hidden in
   worker code.

## Business Value

- Fewer duplicate side effects through idempotent job creation.
- Faster incident triage through job attempts and lifecycle events.
- Better tenant isolation than shared worker code with ad hoc filters.
- Lower operational cost than introducing a broker, event store, and separate
  job control service before the product needs them.
