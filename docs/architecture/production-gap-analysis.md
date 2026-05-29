# 100% Production Readiness Gap Analysis

PulseOps is complete as a senior-level backend challenge and is intentionally
production-shaped. It is not claiming to be ready for real customer traffic
without platform decisions, compliance controls, and operational ownership.

This document defines the delta between the current repository and a fully
production-operated service.

## Current Readiness Level

- Challenge readiness: ready.
- Single-node internal pilot: plausible after deployment manifests and managed
  PostgreSQL are added.
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
- CI for formatting, compile warnings, Credo, Sobelow, dependency audit, tests
  with coverage, OpenAPI linting, and Docker build.
- Dependabot coverage for Mix dependencies, GitHub Actions, and Docker base
  images.

## P0 Before Real Customer Traffic

These are launch blockers for a real production service:

- Deployment target and infrastructure as code. The repository needs explicit
  Fly.io, ECS, Kubernetes, or similar manifests, including app, worker,
  networking, secrets, logs, metrics, and database connectivity.
- Managed PostgreSQL operations. Define backups, point-in-time recovery,
  restore drills, connection limits, maintenance windows, and migration
  ownership.
- Secret management. Move from environment-variable examples to a concrete
  secret store such as AWS Secrets Manager, SSM, Doppler, Vault, or platform
  secrets with rotation procedures.
- Distributed rate limiting. The current ETS limiter is correct for a single
  node; multi-node deployments need Redis, database-backed counters, or gateway
  enforcement.
- Webhook egress hardening. Add allowlists, DNS rebinding protection, SSRF
  protection, per-host concurrency, circuit breakers, and destination-level
  backoff.
- Retention pruning. Implement scheduled deletion/archival for job history
  based on tenant retention policy.
- Alerting. Convert SLO indicators into concrete alerts for 5xx rate, queue
  depth, job age, dead-letter volume, database saturation, and worker crashes.
- Container and supply-chain scanning. Add image vulnerability scanning, SBOM
  generation, and release artifact provenance.

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
- Concrete incident process: severity levels, paging ownership, postmortem
  template, and customer communication workflow.

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

1. Add deployment manifests for one target platform.
2. Add managed PostgreSQL backup/restore documentation and drills.
3. Replace ETS rate limiting with a distributed limiter.
4. Implement retention pruning.
5. Add container scanning and SBOM generation to CI.
6. Add alert rules and dashboard provisioning for a real metrics backend.
