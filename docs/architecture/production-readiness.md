# Production Readiness Review

PulseOps is ready as a senior-level backend challenge implementation. This
review defines what is already production-shaped, what should be monitored, and
which items remain deliberate follow-ups before a real customer rollout.

For the full delta between this challenge implementation and a real customer
production launch, see
[production-gap-analysis.md](production-gap-analysis.md).

## Operational Contract

- API availability target: 99.9% monthly for authenticated job control routes.
- Job enqueue latency target: p95 under 250 ms at the documented local load
  profile.
- Job execution freshness target: queued `noop` jobs should normally reach a
  terminal state within seconds.
- Error budget indicators: elevated `5xx`, rate-limit spikes, queue depth
  growth, and jobs stuck in `running`.

## Deployment Readiness

- The app builds as an OTP release through the Dockerfile.
- Runtime secrets are read from environment variables in `config/runtime.exs`.
- PostgreSQL migrations live in `priv/repo/migrations`.
- Health and readiness endpoints are split as `/healthz` and `/readyz`.
- A concrete Fly.io deployment reference lives in `ops/deploy/fly`.
- The CI workflow validates formatting, compilation, static analysis, security,
  dependency audit, tests with coverage, OpenAPI linting, Docker build, SBOM
  generation, and container vulnerability scan output.
- Dependabot is configured for Mix dependencies and GitHub Actions.

## Observability Readiness

- Structured logs include request, correlation, organization, job, and queue
  metadata.
- Phoenix, Ecto, Bandit, and Oban are wired for OpenTelemetry.
- Prometheus metrics expose request, query, job lifecycle, queue depth, and VM
  memory signals. Production scrape paths can require a bearer token.
- Grafana dashboard JSON is checked in under `ops/grafana`.
- Prometheus alert rules are checked in under `ops/prometheus/alerts.yml`.
- Runbooks document timeout, dead-letter, restore drills, secret rotation,
  incident response, and disaster recovery.

## Data Readiness

- Tenant data is separated by `organization_id` filters and foreign keys.
- Idempotency is enforced with database constraints.
- Job lifecycle writes append audit events.
- Oban terminal state is reconciled back into the public job model if telemetry
  persistence is missed.
- Terminal job history is pruned by tenant retention policy.
- Rate limiting can be backed by PostgreSQL for multi-node deployments.
- Rollback strategy favors application redeploy before destructive schema
  rollback.

## Scaling Limits

- PostgreSQL-backed rate limiting is sufficient for moderate multi-node
  deployments. Extremely high request volume should move this concern to Redis
  or an API gateway.
- Queue concurrency is synchronized into Oban queues, but per-tenant fairness
  beyond queue configuration is not yet adaptive. Each node periodically
  reconciles domain queues into local Oban queue processes so multi-node
  convergence does not depend on process restarts.
- Webhook egress has allowlisting, private-network blocking, DNS validation,
  address pinning, redirect blocking, and a node-local circuit breaker.
  Per-host distributed concurrency limits are still a follow-up.
- Payload encryption at rest is not implemented.
- DR is documented, but multi-region restore automation is not implemented.

## Rollback Plan

1. Stop routing new traffic to the failing release.
2. Redeploy the previous known-good image.
3. Leave already-enqueued Oban jobs in PostgreSQL; workers can resume from the
   durable queue.
4. Run `PulseOps.Jobs.reconcile_terminal_jobs/1` if public job state diverged
   from terminal Oban state during the incident.
5. Only roll back schema changes when the migration is known to be reversible
   and the previous app version requires it.

## Release Checklist

- `mix ci`
- `npx @redocly/cli lint openapi.yaml`
- `docker build .`
- `make demo`
- If host port 5432 is already allocated, run local dependencies with
  `POSTGRES_PORT=55432`.
- Confirm the GitHub Actions badge points to a green `main` workflow run.
- Publish the release tag, for example `git tag -a v0.1.0 -m "PulseOps v0.1.0"`.
- Review `benchmarks/results/local-baseline.md`
- Confirm `DATABASE_URL`, `SECRET_KEY_BASE`, and optional
  `OTEL_EXPORTER_OTLP_ENDPOINT` are present in the target environment
- Confirm `WEBHOOK_ALLOWED_HOSTS` is set before enabling webhook jobs for real
  tenants.
- Confirm PostgreSQL backup/PITR and restore drill evidence exists.

## Next Production Investments

- Add tenant-scoped API key permissions.
- Add payload encryption at rest.
- Add distributed webhook circuit breaker/concurrency enforcement.
- Add automated restore drills and release provenance attestation.
