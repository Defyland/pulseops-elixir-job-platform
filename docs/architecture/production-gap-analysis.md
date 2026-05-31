# 100% Production Readiness Gap Analysis

PulseOps is complete as a senior-level backend challenge and is intentionally
production-shaped. It is not claiming to be ready for real customer traffic
without platform decisions, compliance controls, and operational ownership.

This document defines the delta between the current repository and a fully
production-operated service.

## Current Readiness Level

- Challenge readiness: ready.
- Single-node internal pilot: plausible after managed PostgreSQL and secrets are
  configured for the target environment.
- Multi-tenant customer production: not yet ready.
- Regulated customer production: not yet ready.

## Already Production-Shaped

- OTP release build through Docker.
- Runtime configuration through environment variables.
- PostgreSQL-backed durable job execution through Oban.
- Tenant isolation by `organization_id` filters and foreign keys.
- API key hashing, request authentication, and request rate limiting.
- Idempotent job creation and append-only lifecycle events.
- Health, readiness, Prometheus metrics, structured logs, OpenTelemetry setup,
  Grafana dashboard JSON, and operational runbooks.
- Deployment target and infrastructure as code exists as a concrete Fly.io
  reference under `ops/deploy/fly`.
- Distributed rate limiting through PostgreSQL-backed buckets.
- Webhook egress hardening with HTTPS enforcement, allowlists, DNS validation,
  DNS pinning for validated addresses, private-network blocking, redirect
  blocking, and circuit breaking.
- Optional bearer-token protection for Prometheus scrape endpoints.
- Retention pruning for terminal job history by tenant policy.
- Prometheus alert rules for HTTP errors, queue depth, dead letters, and job
  duration.
- CI for formatting, compile warnings, Credo, Sobelow, dependency audit, tests
  with coverage, OpenAPI linting, Docker build, SBOM generation, and container
  vulnerability scan output with a blocking HIGH/CRITICAL policy.
- Dependabot coverage for Mix dependencies and GitHub Actions.

## P0 Before Real Customer Traffic

These are launch blockers for a real production service:

- Managed PostgreSQL operations. Define backups, point-in-time recovery,
  restore drills, connection limits, maintenance windows, and migration
  ownership.
- Secret management. Move from environment-variable examples to a concrete
  secret store such as AWS Secrets Manager, SSM, Doppler, Vault, or platform
  secrets with rotation procedures.
- Alert routing. Prometheus rules exist, but a real PagerDuty/Opsgenie route,
  ownership schedule, and notification policy must be configured.
- Container and supply-chain policy/provenance. CI generates SBOM and blocks
  HIGH/CRITICAL fixed vulnerabilities, but signed release provenance and
  attestation still need to be defined for production releases.
- Webhook egress scaling. Policy enforcement exists, but very large
  deployments should centralize circuit breaker and per-host concurrency limits.

## P1 Shortly After Launch

These are not launch blockers for a narrow pilot, but should be tracked before
the service scales:

- Tenant-scoped API key permissions and key rotation APIs.
- Payload encryption at rest for sensitive job payloads.
- Admin/operator tooling for replay, queue pause/resume, and dead-letter
  triage beyond raw API calls.
- Load testing in CI or scheduled performance jobs against an ephemeral
  environment.
- Zero-downtime migration playbook for large tables and Oban queue changes.
- Multi-region disaster recovery objectives and restore automation.
- Audit export pipeline for security reviews and customer compliance requests.
- Incident process integration with real paging ownership and customer
  communication channels.

## P2 Hardening

- Adaptive tenant fairness across queues.
- Usage metering and tenant-level quotas.
- Per-tenant data residency options.
- Schema-level partitioning or archival tables for high-volume tenants.
- SAML/OIDC or service-account federation if API keys are not sufficient for
  the customer segment.

## Go/No-Go Review

The current repository should be presented as:

- A complete backend challenge implementation.
- A production-minded architecture slice.
- A strong seniority signal for Elixir, Phoenix, Ecto, Oban, testing, CI,
  observability, and trade-off communication.

It should not be presented as:

- A fully hosted SaaS.
- A compliance-ready regulated platform.
- A multi-region production deployment.

## Next Implementation Order

1. Execute a managed PostgreSQL restore drill against the deployment target.
2. Add production secret manager wiring and rotation ownership.
3. Define blocking supply-chain policy and release provenance.
4. Add distributed webhook concurrency controls at gateway or shared-storage
   layer.
5. Add payload encryption at rest if job payloads can contain customer secrets.
