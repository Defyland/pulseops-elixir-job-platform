# Changelog

## Unreleased

### Added

- PostgreSQL-backed distributed rate limiting with cleanup of expired buckets.
- Tenant retention pruning for terminal jobs, attempts, events, and matching
  Oban rows.
- Webhook egress hardening with HTTPS enforcement, host allowlists,
  private-network blocking, DNS validation, and circuit breaking.
- Fly.io deployment reference, Prometheus alert rules, restore drill, secret
  rotation, incident response, and disaster recovery runbooks.
- CI SBOM generation and container vulnerability scan evidence.
- Release migration helper for production deploys.
- Job lifecycle event contracts, replay/idempotency policy, event-store ADR,
  and threat model for admin operations, webhooks, and job execution.

### Fixed

- Persisted Oban discard results as `dead_lettered` platform jobs instead of
  incorrectly treating them as success.

## 0.1.0 - 2026-05-29

### Added

- Multi-tenant Phoenix API for organizations, API keys, queues, and jobs.
- Durable asynchronous execution through Oban.
- Job attempts, audit events, retry, cancel, dead-letter, and reconciliation
  flows.
- API key authentication, tenant isolation, rate limiting, validation, and
  structured error responses.
- OpenAPI contract and request/response examples.
- Structured logs, request and correlation IDs, Prometheus metrics,
  OpenTelemetry setup, health/readiness probes, and Grafana dashboard.
- k6 smoke, load, stress, and spike benchmarks with measured local results.
- CI validation for formatting, compilation, Credo, Sobelow, dependency audit,
  tests with coverage, OpenAPI linting, and Docker build.
- Spec compliance tests that enforce the repository baseline as executable
  evidence.
- Evaluator guide, production readiness review, `Makefile` shortcuts, and a
  reproducible API demo.
- `.dockerignore` for smaller and less noisy release build contexts.
- README CI and release badges for public evaluator signal.
- Observability evidence with captured demo output, Prometheus samples,
  structured log examples, and a dashboard preview.
- Production gap analysis that separates challenge completeness from real
  customer-production requirements.
- Dependabot maintenance for Mix dependencies and GitHub Actions.

### Fixed

- Removed queue synchronization from the enqueue hot path after stress testing
  exposed Provisioner saturation.
- Synchronized newly provisioned default queues after organization registration
  so fresh tenants can execute jobs immediately in the runtime demo.
- Added terminal Oban state reconciliation for platform jobs that remain
  `running` after executor completion.
- Replaced a missing Docker base image with a resolvable Elixir release image.
- Made local PostgreSQL port binding configurable with `POSTGRES_PORT` and
  removed obsolete Docker Compose metadata.
- Replaced local absolute filesystem links in public documentation with
  portable repository-relative links.
- Corrected the Grafana success-rate PromQL query to match the metric emitted by
  the running `/metrics` endpoint.

### Known Follow-Ups

- Tenant-scoped API key permissions.
- Payload encryption at rest for sensitive job payloads.
- Distributed webhook concurrency controls for high-volume deployments.
