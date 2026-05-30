# Operational Cost

Operational cost is part of the PulseOps architecture. The design intentionally
uses PostgreSQL and Oban before adding RabbitMQ, Redis, an event store, or
microservices.

## Infrastructure Components

Required:

- Phoenix/Elixir OTP release
- PostgreSQL
- Oban tables inside PostgreSQL
- Prometheus-compatible metrics scraping
- Grafana or another dashboard viewer
- CI runner

Optional or production-specific:

- managed PostgreSQL backups and PITR
- secret manager
- alert routing service
- container registry and image scanner
- egress proxy for high-risk webhook deployments

## Non-Financial Cost

- On-call engineers need to understand both public job state and Oban executor
  state.
- Operators need runbooks for dead letters, restore drills, secret rotation,
  incident response, and disaster recovery.
- Security reviewers need to validate tenant isolation, bearer-token handling,
  webhook egress, and replay controls.
- Product teams need clear limits for retention, queue concurrency, retry
  policy, and API rate limits.

## Debugging Complexity

Main debugging surfaces:

- HTTP request logs
- correlation IDs
- `jobs`
- `job_attempts`
- `job_events`
- `oban_jobs`
- Prometheus metrics
- Grafana dashboard
- runbooks

The cost is acceptable because each surface answers a different operational
question. The public job model answers customer-facing status. Oban answers
executor state. Events and attempts answer why the state changed.

## Deployment Complexity

The current deploy model is a single OTP release connected to PostgreSQL. This
keeps deploy complexity lower than a split API service, worker service, broker,
event store, and projection service.

Required production deploy checks:

- migrations run once per release
- readiness checks pass before routing traffic
- workers are started with correct queue configuration
- old release can be redeployed if the new release fails
- no destructive migration is required for rollback

## Backup And Retention Cost

Cost drivers:

- retained job payloads
- attempts per job
- event history volume
- Oban job retention
- PostgreSQL WAL and backup storage

Mitigations:

- tenant-level retention days
- pruning terminal jobs only
- future archival or partitioning for high-volume tenants
- managed PostgreSQL PITR for real production

## Monitoring Burden

Minimum production signals:

- HTTP 5xx rate
- queue depth
- dead-letter rate
- p95 job execution duration
- database connection pressure
- jobs stuck in `running`
- rate-limit spikes
- webhook policy discards and circuit-open counts

Alert rules exist in `ops/prometheus/alerts.yml`, but real production still
needs routing, ownership, escalation policy, and incident review discipline.

## Vendor Lock-In Risk

PostgreSQL and Oban are portable across most hosting platforms. The Fly.io
deployment reference is intentionally a reference, not a hard dependency.

Potential lock-in appears when choosing:

- managed PostgreSQL provider
- secret manager
- alerting platform
- container provenance and registry policy
- observability backend

## Simpler Alternatives Rejected

In-memory queue:

- rejected because jobs would be lost on restart and retry/dead-letter behavior
  would be weak.

RabbitMQ from day one:

- rejected because Oban already provides durable execution and fewer local/CI
  dependencies for this product slice.

Full event store:

- rejected because current requirements need queryable job state plus audit
  logs, not projection rebuilds or external ordered streams.

Microservices:

- rejected because module boundaries inside a Phoenix application are enough
  until team scale or independent deployment requirements justify the cost.
