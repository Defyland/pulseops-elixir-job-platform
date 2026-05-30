# Domain Glossary

| Term | Meaning |
| --- | --- |
| Organization | Tenant boundary for API keys, queues, jobs, attempts, and events. |
| API key | High-entropy bearer credential scoped to one organization. |
| Queue | Tenant-owned execution lane with concurrency, retry, timeout, and pause policy. |
| Job | Public async work request created through the API and executed through Oban. |
| Worker | Execution implementation selected by the job payload, currently constrained by an allowlist. |
| Attempt | One execution try for a job, including start time, finish time, status, and error metadata. |
| Job event | Append-only lifecycle audit row describing how a job changed state. |
| Idempotency key | Tenant-scoped key that prevents duplicate job creation for retried client requests. |
| External reference | Optional tenant-scoped business reference supplied by the caller. |
| Retryable | Non-terminal state meaning automatic or explicit retry can still occur. |
| Dead-lettered | Terminal failure state after retry budget is exhausted or execution cannot continue safely. |
| Replay | Privileged administrative decision to run intent again after reviewing prior failure evidence. |
| Reconciliation | Repair process that mirrors terminal Oban state back into the public job model if telemetry persistence was missed. |
| Retention pruning | Deletion of old terminal job history according to tenant retention policy. |
| Correlation ID | Request/job identifier propagated through logs, events, metrics, and webhook calls. |
