# Fly.io Deployment Reference

This is the concrete deployment target for the portfolio version of PulseOps.
It is intentionally small, but it documents the production controls that must
exist around the app before real customer traffic.

## Provisioning

1. Create the app and managed PostgreSQL instance.

```bash
fly apps create pulseops-elixir-job-platform
fly postgres create --name pulseops-postgres --region gru
fly postgres attach --app pulseops-elixir-job-platform pulseops-postgres
```

2. Set runtime secrets through the platform secret store.

```bash
fly secrets set \
  SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  WEBHOOK_ALLOWED_HOSTS="hooks.example.com,*.trusted.example.com"
```

3. Deploy from the repository root.

```bash
fly deploy --config ops/deploy/fly/fly.toml --dockerfile Dockerfile
```

4. Run migrations before shifting traffic to a new image.

```bash
fly ssh console --app pulseops-elixir-job-platform \
  -C "/app/bin/pulse_ops eval 'PulseOps.Release.migrate()'"
```

## Production Controls

- PostgreSQL must have backups and a tested restore path before launch.
- `DATABASE_URL` and `SECRET_KEY_BASE` must stay in Fly secrets, never in Git.
- `API_RATE_LIMIT_STORAGE=postgres` makes rate limiting shared across machines.
- Webhook egress defaults to HTTPS, DNS validation, private-network blocking,
  and an explicit `WEBHOOK_ALLOWED_HOSTS` allowlist.
- `/readyz` is used as the deployment health check.
- Run at least two machines to avoid single-machine maintenance downtime.

## Launch Gate

Use this target for a demo or pilot only after these commands pass:

```bash
make ci
make demo
docker build -t pulseops-release-candidate .
```
