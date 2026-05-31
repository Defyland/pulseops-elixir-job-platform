# PulseOps Threat Model

This threat model focuses on privileged operations, manual replay, webhook
egress, and job execution. It complements
[docs/architecture/security-model.md](../architecture/security-model.md).

## Assets

- organization-scoped jobs, attempts, events, queues, and payloads
- API keys and future operator credentials
- retry, cancel, dead-letter, and replay controls
- webhook destinations, request bodies, headers, and delivery evidence
- Oban execution state and worker telemetry
- audit records used for incident review and customer support

## Trust Boundaries

| Boundary | Risk |
| --- | --- |
| External API client to Phoenix | Untrusted caller can attempt cross-tenant access, flooding, malformed payloads, or replay abuse. |
| Phoenix controllers to domain contexts | Authorization or validation bypass could mutate tenant state incorrectly. |
| Domain contexts to PostgreSQL | Transaction gaps can split public job state from executor state. |
| Oban worker to job handler | Payload-driven execution can fail, timeout, or trigger unsafe egress. |
| Webhook handler to third-party network | Destination can be malicious, private, slow, or unstable. |
| Operator/admin workflow to retry/replay | Privileged action can duplicate work or bypass customer intent. |

## Administrative Operations

Administrative operations include retry, cancel, future replay, queue pause,
queue resume, retention pruning, and incident repair.

| Threat | Control |
| --- | --- |
| Operator retries another tenant's job | Every admin action must resolve tenant context and filter by `organization_id`. |
| Operator replays a destructive job without reason | Replay must require operator identity, reason, original job ID, and audit event. |
| Admin endpoint becomes a bulk execution vector | Rate limit admin actions and require bounded batch size. |
| Queue pause/resume disrupts unrelated tenants | Scope queue operations by tenant and queue ID/name. |
| Retention pruning deletes active work | Prune only terminal `succeeded`, `dead_lettered`, and `cancelled` jobs. |
| Incident repair hides history | Repair should append reconciliation/audit metadata rather than rewriting prior events. |

## Manual Replay

Replay is higher risk than retry because it can duplicate side effects.

Required controls before adding a replay endpoint:

- authenticated operator identity
- tenant-scoped authorization
- explicit replay reason
- original job ID and original correlation ID
- payload hash or payload version
- replay idempotency key
- dry-run validation for worker type, queue policy, timeout, and webhook policy
- audit event linking original job and replay action

Replay must not:

- bypass `organization_id`
- reuse a stale idempotency key unintentionally
- bypass webhook SSRF controls
- bypass queue concurrency and timeout policy
- mutate historical `job_events`
- erase the original failure

## Webhooks

Webhook jobs cross from PulseOps into untrusted third-party infrastructure.

| Threat | Control |
| --- | --- |
| SSRF to localhost/private network | HTTPS default, private-network blocking, loopback blocking, DNS validation, and disabled redirects. |
| DNS rebinding | Resolve destination before egress, pin the approved connection URI to the validated address, and prefer an egress proxy for high-risk production deployments. |
| Credential leakage through URL userinfo | Reject URLs containing userinfo. |
| Retry storm against failing destination | Use bounded attempts, backoff, circuit breaker, and dead-letter state. |
| Tenant config sends data to wrong host | Use `WEBHOOK_ALLOWED_HOSTS` and tenant/operator review before production enablement. |
| Slow destination exhausts workers | Enforce job timeout budget and per-host circuit breaker. |

Residual risk:

- The current circuit breaker is node-local.
- Large production deployments should centralize egress policy and concurrency in
  a gateway, Redis, or PostgreSQL-backed coordination layer.

## Job Execution

| Threat | Control |
| --- | --- |
| Worker crash leaves public state stale | Oban telemetry plus `PulseOps.Jobs.Reconciler` repair terminal mismatches. |
| Timeout consumes worker capacity | Per-job timeout budget and terminal attempt recording. |
| Retry storm increases database load | Max attempts, Oban backoff, queue depth alerts, and dead-lettering. |
| Payload leaks secrets into logs | Structured logging should prefer IDs, correlation, and summaries over full payloads. |
| Unsupported worker gets executed | Worker allowlist in job changeset. |
| Duplicate enqueue creates duplicate side effects | `organization_id + idempotency_key` unique constraint. |

## Abuse Cases To Test

- Tenant A attempts to fetch, retry, or cancel Tenant B's job.
- Same idempotency key is submitted concurrently.
- Dead-lettered job is retried with no Oban job ID.
- Webhook points to `127.0.0.1`, `localhost`, RFC1918 IP, or IPv6 loopback.
- Webhook destination fails repeatedly until circuit opens.
- Reconciler sees Oban terminal but public job still `running`.
- Retention pruner sees an old active job and must not delete it.

## Monitoring Signals

- elevated `pulse_ops_job_stop_count{status="dead_lettered"}`
- high `pulse_ops_queue_depth{status="queued"}`
- repeated webhook policy discards
- frequent manual retry/replay actions
- API `429` spikes by API key
- public jobs stuck in `running`
- database connection queue time

## Residual Risks

- API keys are bearer credentials and do not yet have fine-grained scopes.
- Payload encryption at rest is not implemented.
- Replay endpoint is intentionally deferred.
- Audit export for compliance review is not implemented.
- Egress circuit breaking is node-local.
- A full event store is deferred until event-stream requirements justify the
  operational cost.
