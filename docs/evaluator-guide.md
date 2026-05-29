# Evaluator Guide

This repository is designed to be evaluated as a product-minded backend system,
not as a framework scaffold. The fastest review path is to inspect the product
surface first, then verify the engineering evidence.

## What to Look For

- Product narrative: `README.md` explains the user, problem, workflows, domain,
  and roadmap.
- API contract: `openapi.yaml` documents versioned endpoints, auth, examples,
  and standardized errors.
- Multi-tenancy: API keys, queues, jobs, attempts, and events are tenant-scoped.
- Async execution: Oban persists durable jobs while PulseOps keeps a public
  domain model for job lifecycle and audit history.
- Observability: health, readiness, Prometheus metrics, structured log metadata,
  OpenTelemetry setup, and a Grafana dashboard are included.
- Security: threat model, authorization matrix, rate limiting, validation,
  secret handling, tenant isolation, and audit logging are explicit.
- Production thinking: performance baselines, runbooks, data consistency notes,
  CI gates, Docker build, and operational trade-offs are documented.

## Five-Minute Review

```bash
make ci
make docker-build
make demo
```

On GitHub, the README CI badge links directly to the workflow run history for
the same checks.

`make demo` starts the local dependencies, creates a tenant through the API,
enqueues a job, waits for execution, prints lifecycle events, and samples
Prometheus metrics.

The demo uses `POSTGRES_PORT=55432` by default to avoid clashing with a local
PostgreSQL already bound to 5432. Override `POSTGRES_PORT` when needed.

## Evidence Map

- Architecture: `docs/architecture/overview.md`
- Data consistency: `docs/architecture/data-consistency.md`
- Messaging: `docs/architecture/messaging.md`
- Security: `docs/architecture/security-model.md`
- Authorization matrix: `docs/api/authorization-matrix.md`
- Runbook: `docs/runbooks/timeout-and-dead-letter.md`
- Production readiness: `docs/architecture/production-readiness.md`
- 100% production gap analysis:
  `docs/architecture/production-gap-analysis.md`
- Observability evidence: `docs/observability/evidence.md`
- Benchmark results: `benchmarks/results/local-baseline.md`
- Spec compliance tests: `test/spec_compliance/general_project_spec_test.exs`
- Release notes: `CHANGELOG.md` and the `v0.1.0` tag

## Senior-Level Signals

- The implementation distinguishes public domain state from executor-specific
  Oban state.
- Idempotency, tenant isolation, and terminal-state reconciliation are enforced
  with tests instead of being described only in prose.
- CI validates formatting, compilation, Credo, Sobelow, dependency audit,
  coverage, OpenAPI linting, and Docker build.
- Performance work includes smoke, load, stress, and spike profiles with
  measured latency, throughput, error rate, and runtime notes.
- The docs name trade-offs and residual risk directly instead of implying the
  project is production-complete in every dimension.
- The production gap analysis distinguishes challenge completeness from real
  customer-production requirements.

## Known Non-Goals

- No browser UI is included; the API is the product surface.
- RabbitMQ is not required for this slice because Oban provides durable
  PostgreSQL-backed execution.
- OAuth/JWT support is deferred; high-entropy API keys are enough for this
  backend challenge.
- Payload encryption at rest and webhook egress allowlisting are documented
  follow-ups.
