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
- The CI workflow validates formatting, compilation, static analysis, security,
  dependency audit, tests with coverage, OpenAPI linting, and Docker build.
- Dependabot is configured for Mix dependencies, GitHub Actions, and Docker
  base images.

## Observability Readiness

- Structured logs include request, correlation, organization, job, and queue
  metadata.
- Phoenix, Ecto, Bandit, and Oban are wired for OpenTelemetry.
- Prometheus metrics expose request, query, job lifecycle, queue depth, and VM
  memory signals.
- Grafana dashboard JSON is checked in under `ops/grafana`.
- Runbooks document timeout, dead-letter, and stale `running` job triage.

## Data Readiness

- Tenant data is separated by `organization_id` filters and foreign keys.
- Idempotency is enforced with database constraints.
- Job lifecycle writes append audit events.
- Oban terminal state is reconciled back into the public job model if telemetry
  persistence is missed.
- Rollback strategy favors application redeploy before destructive schema
  rollback.

## Scaling Limits

- The current rate limiter is node-local ETS. Multi-node deployments need a
  shared limiter or sticky routing.
- Queue concurrency is synchronized into Oban queues, but per-tenant fairness
  beyond queue configuration is not yet adaptive.
- Webhook execution lacks egress allowlisting, circuit breaking, and per-host
  concurrency limits.
- Payload encryption at rest is not implemented.
- Retention pruning is documented in the roadmap but not implemented.

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

## Next Production Investments

- Add distributed rate limiting.
- Add retention pruning jobs.
- Add webhook egress allowlist and retry backoff policy per destination.
- Add tenant-scoped API key permissions.
- Add deployment manifests for a concrete platform such as Fly.io, ECS, or
  Kubernetes.
