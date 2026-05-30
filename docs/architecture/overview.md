# Architecture Overview

PulseOps is intentionally split into a small number of coarse-grained modules:

- `PulseOps.Identity`: tenant registration, API key issuance, and authentication
- `PulseOps.Queues`: per-tenant queue definitions and runtime synchronization with Oban
- `PulseOps.Jobs`: job creation, retries, cancellation, attempt history, and audit events
- `PulseOpsWeb`: Phoenix controllers, plugs, health probes, and metrics endpoint

## Runtime flow

1. A caller authenticates with `x-api-key`.
2. The API resolves the organization and checks rate limits.
3. `Jobs.create_job/2` validates the request, checks idempotency, and writes the public `jobs` record.
4. The matching Oban job is inserted with the platform `job_id`.
5. `PulseOps.Jobs.ExecutionWorker` executes the handler.
6. Oban telemetry updates attempts, events, and terminal job state.

## Storage strategy

The public domain state is stored in `jobs`, `job_attempts`, and `job_events`.
Oban owns the executor-specific scheduling table `oban_jobs`. The split keeps the
API stable even if the execution backend changes later.

## Lifecycle and replay guidance

Job lifecycle events, retry semantics, dead-letter policy, replay rules, and the
event-store trade-off are documented separately:

- [docs/events/README.md](../events/README.md)
- [docs/adr/002-job-events-before-event-store.md](../adr/002-job-events-before-event-store.md)
- [docs/security/threat-model.md](../security/threat-model.md)
