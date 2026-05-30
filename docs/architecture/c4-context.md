# C4 Context

## System Context

PulseOps is a job execution control plane for platform and product teams. It
accepts authenticated API calls, persists tenant-scoped jobs, executes them
asynchronously, and exposes operational evidence.

```text
API Client
  -> PulseOps HTTP API
  -> PostgreSQL
  -> Oban Executor
  -> Worker Handler
  -> Optional Webhook Destination

Operator
  -> PulseOps HTTP API
  -> Job attempts, events, metrics, logs, runbooks

Prometheus
  -> PulseOps /metrics

Grafana
  -> Prometheus
```

## External Actors

- API client: creates tenants, API keys, queues, and jobs.
- Operator: retries, cancels, investigates dead letters, and follows runbooks.
- Webhook destination: receives outbound delivery for webhook jobs.
- Observability stack: scrapes metrics and renders dashboards.

## Trust Boundaries

- Public HTTP caller to Phoenix endpoint.
- Authenticated API to tenant-scoped domain contexts.
- Domain contexts to PostgreSQL.
- Oban worker to job handler.
- Webhook handler to untrusted third-party network.

Security details live in [threat model](../security/threat-model.md).
