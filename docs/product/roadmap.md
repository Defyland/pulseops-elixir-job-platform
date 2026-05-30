# Product Roadmap

## Now

- Tenant registration and API key bootstrap.
- Tenant-scoped queues.
- Idempotent job creation.
- Job attempts and lifecycle events.
- Retry, cancel, dead-letter, retention, metrics, logs, and runbooks.
- Webhook egress policy and circuit breaking.

## Next

- Tenant-scoped API key permissions.
- Queue pause and resume endpoints with explicit operator audit events.
- Manual replay workflow with dry-run validation, reason, operator identity,
  payload hash, and replay idempotency key.
- Payload encryption at rest for sensitive payload classes.
- Distributed webhook concurrency controls for large deployments.

## Later

- RabbitMQ or external publisher ingress adapter.
- Event export/outbox for external subscribers.
- Usage metering and tenant quotas.
- Admin UI for dead-letter triage and replay approval.
- Enterprise identity through OAuth/OIDC or SAML if the customer segment needs
  human admin sessions.

## Success Metrics

- Job creation p95 latency under the documented target for the chosen load
  profile.
- Low duplicate-job rate for idempotent clients.
- Dead-letter rate visible through alerts and dashboards.
- Mean time to identify affected tenant and job during an incident under five
  minutes in the local runbook workflow.
