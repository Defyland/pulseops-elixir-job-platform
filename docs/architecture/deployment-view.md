# Deployment View

## Local Development

```text
Developer shell
  -> Phoenix app
  -> PostgreSQL through docker compose
  -> Optional Prometheus and Grafana through docker compose
```

Primary commands:

```bash
docker compose up -d postgres
mix ecto.setup
mix phx.server
make demo
```

## CI

GitHub Actions validates:

- formatting
- compilation with warnings as errors
- Credo
- Sobelow
- dependency audit
- tests with coverage
- OpenAPI linting
- Docker release build
- SBOM generation
- Trivy image scan artifact

## Reference Production Shape

```text
Load balancer / platform router
  -> PulseOps OTP release containers
  -> Managed PostgreSQL
  -> Prometheus scrape
  -> Grafana dashboard
  -> Alert routing
  -> Secret manager
```

The checked-in Fly.io reference under `ops/deploy/fly` is a concrete deployment
example. It is not a claim that managed database backups, secret rotation,
on-call ownership, or compliance controls are already operated.

## Runtime Configuration

Runtime configuration comes from environment variables, including:

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `PHX_HOST`
- `API_RATE_LIMIT_STORAGE`
- `WEBHOOK_ALLOWED_HOSTS`
- `WEBHOOK_ALLOW_PRIVATE_NETWORKS`
- `OTEL_EXPORTER_OTLP_ENDPOINT`

## Rollback

Rollback should first redeploy the previous known-good image. Destructive schema
rollback should be avoided unless the migration is known to be reversible and
the previous application version requires it.

See [production readiness](production-readiness.md) and
[production gap analysis](production-gap-analysis.md).
