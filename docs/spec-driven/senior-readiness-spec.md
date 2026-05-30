# Senior Readiness Spec

This spec applies the repository standards from:

- `specs/general-project-spec.md`
- `specs/senior-engineering-rubric.md`
- `specs/spec-driven-senior-quality.md`

Scope is limited to PulseOps as a backend challenge and portfolio case study.
The target is senior/tech-lead evidence, not a claim that the service is already
operated for real customer traffic.

## Product Bar

PulseOps must read as a product for platform teams that need tenant-safe job
execution, retry control, dead-letter review, and operational auditability.
Evidence must name target users, problem, core workflow, non-goals, and roadmap.

Acceptance criteria:

- `README.md` explains product, users, workflow, architecture, tests, operations,
  security, trade-offs, failures, and roadmap.
- `docs/product/` documents problem, personas, use cases, non-goals, roadmap,
  and packaging assumptions.
- `docs/evaluator-guide.md` provides a short review path for external reviewers.

## Domain Bar

The domain model must be explicit enough that an interviewer can reason about
jobs, queues, attempts, events, retries, and tenant boundaries without reading
all code first.

Acceptance criteria:

- `docs/domain/` defines glossary, bounded contexts, aggregates, invariants, and
  state machines.
- Domain nouns in docs match code modules and tests: organization, API key,
  queue, job, attempt, job event, retry, dead letter, retention, replay.
- Critical lifecycle and idempotency rules are protected by ExUnit tests.

## Architecture Bar

Architecture must justify Phoenix, PostgreSQL, Oban, transactional job tables,
audit events, and the choice to defer a full event store.

Acceptance criteria:

- Architecture docs include overview, C4 context, C4 container, module
  boundaries, sequence flows, deployment view, supervision tree, messaging, data
  consistency, and production gap analysis.
- ADRs describe why Oban is the executor and when an event store becomes
  justified.
- Operational boundaries are explicit: API, domain contexts, PostgreSQL, Oban,
  telemetry, webhooks, and future admin replay.

## API Bar

The public API must be documented as a versioned control plane with consistent
authentication, request examples, response examples, and errors.

Acceptance criteria:

- `openapi.yaml` describes `/api/v1` endpoints, API key auth, examples, and
  standardized error payloads.
- `docs/api/` documents examples, authorization matrix, and error format.
- Request tests cover authorization, validation, tenant isolation, and job
  lifecycle operations.

## Data and Consistency Bar

PulseOps must make the source of truth, transaction boundaries, indexes,
constraints, rollback assumptions, and reconciliation strategy explicit.

Acceptance criteria:

- `docs/architecture/data-consistency.md` documents transaction boundaries,
  unique constraints, foreign keys, indexes, isolation assumptions, migration
  strategy, rollback strategy, and terminal-state reconciliation.
- Idempotency is enforced by tenant-scoped database constraints.
- Job state and executor state are reconciled when Oban terminal state diverges
  from the public job record.

## Security Bar

Security evidence must cover multi-tenancy, API keys, rate limits, webhooks,
admin operations, replay, audit, and residual risk.

Acceptance criteria:

- `docs/security/threat-model.md` covers assets, actors, trust boundaries,
  abuse cases, controls, monitoring signals, and residual risks.
- `docs/api/authorization-matrix.md` defines tenant-scoped behavior.
- Tests cover tenant isolation, API key access, malformed payloads, webhook
  egress policy, and rate limiting behavior.

## Observability Bar

Observability must help an operator answer which tenant, queue, job, attempt,
and correlation ID were affected.

Acceptance criteria:

- Runtime exposes `/healthz`, `/readyz`, and `/metrics`.
- Logs carry request ID and correlation ID, with organization/job metadata where
  available.
- Metrics cover HTTP, queue depth, job lifecycle counts, job duration, and VM
  runtime signals.
- `docs/observability/evidence.md` includes captured demo output, metrics,
  structured logs, dashboard preview, and alert references.

## Performance Bar

Performance claims must be measured or clearly marked as planned. PulseOps must
include k6 scenarios and measured local baseline results for the portfolio.

Acceptance criteria:

- `benchmarks/` includes smoke, load, stress, and spike scripts.
- `benchmarks/results/local-baseline.md` reports p50, p95, p99, throughput,
  error rate, CPU notes, memory notes, bottleneck, and next optimization.
- Performance docs avoid claiming capacity beyond the measured local profile.

## Scalability Bar

Scalability evidence must name the hot path, growth tables, queues, bottlenecks,
and consistency boundaries.

Acceptance criteria:

- `docs/scalability.md` documents hot paths, read-heavy and write-heavy flows,
  fastest-growing tables, queue buildup modes, hot partitions, horizontal scale,
  sharding candidates, async candidates, and non-eventual flows.
- `docs/architecture/production-gap-analysis.md` separates challenge readiness
  from real production traffic.

## Operational Cost Bar

The repository must show that operational cost is part of the design, not an
afterthought.

Acceptance criteria:

- `docs/operational-cost.md` explains infrastructure components, non-financial
  costs, debugging complexity, deploy complexity, backup/retention cost,
  monitoring burden, vendor risk, and simpler alternatives rejected.
- Production readiness docs identify P0/P1/P2 investments before customer
  production.

## Maintainability Bar

Maintainers must know where to add a worker, queue policy, lifecycle event,
webhook control, runbook, or benchmark.

Acceptance criteria:

- Module boundaries are documented in `docs/architecture/module-boundaries.md`.
- Test strategy is documented through README, compliance tests, and targeted
  ExUnit suites.
- Scripts exist for CI, Docker build, OpenAPI lint, and demo flows.

## Readability Bar

Docs, tests, and code must use domain language rather than vague process names.

Acceptance criteria:

- Public docs consistently use organization, queue, job, attempt, event, retry,
  dead letter, replay, reconciler, retention, and webhook.
- Tests describe business rules such as tenant isolation, idempotency, terminal
  reconciliation, and webhook egress blocking.

## Test and CI Bar

The repo must have local and remote verification for formatting, lint, security,
tests, coverage, OpenAPI, Docker, SBOM, and image scanning.

Acceptance criteria:

- `mix ci` runs local formatting, compile, Credo, Sobelow, dependency audit, and
  tests with coverage.
- GitHub Actions runs local checks plus OpenAPI linting, Docker build, SBOM
  generation, and Trivy scan artifact publishing.
- `test/spec_compliance/general_project_spec_test.exs` protects senior evidence
  so missing docs or downgraded CI fail the suite.

## Evidence Matrix

| Criterion | Evidence | Status | Notes |
| --- | --- | --- | --- |
| Product problem, users, workflow, and non-goals are explicit | `README.md`, `docs/product/problem.md`, `docs/product/personas.md`, `docs/product/non-goals.md` | Done | Product is framed as a tenant-safe job execution control plane. |
| Senior case study exists | `docs/engineering-case-study.md` | Done | Covers product, domain, architecture, failure, security, scale, cost, and next steps. |
| Domain model is explicit | `docs/domain/glossary.md`, `docs/domain/aggregates.md`, `docs/domain/invariants.md`, `docs/domain/state-machines.md` | Done | Mirrors code modules and lifecycle tests. |
| Architecture has boundaries and deployment views | `docs/architecture/overview.md`, `docs/architecture/c4-context.md`, `docs/architecture/c4-container.md`, `docs/architecture/module-boundaries.md`, `docs/architecture/deployment-view.md` | Done | Keeps modular monolith and executor boundaries visible. |
| Event/retry/DLQ/replay contract is documented | `docs/events/README.md`, `docs/events/job_lifecycle_event.v1.json` | Done | Defines lifecycle events, worker events, idempotency, replay, and future export envelope. |
| Event-store trade-off is explicit | `docs/adr/002-job-events-before-event-store.md` | Done | Keeps transactional tables until stream requirements justify event-store cost. |
| API contract is documented | `openapi.yaml`, `docs/api/examples.md`, `docs/api/errors.md`, `docs/api/authorization-matrix.md` | Done | Versioned endpoints, auth, examples, and standard errors are present. |
| Data consistency is documented and tested | `docs/architecture/data-consistency.md`, `test/pulse_ops/jobs/reconciler_test.exs`, `test/pulse_ops/jobs_test.exs` | Done | Transaction boundaries, constraints, idempotency, and reconciliation are covered. |
| Security model covers abuse cases | `docs/security/threat-model.md`, `docs/architecture/security-model.md`, `test/pulse_ops/jobs/webhook_security_test.exs` | Done | Includes tenant isolation, replay risk, webhooks, job execution, and residual risks. |
| Observability has runtime evidence | `docs/observability/evidence.md`, `ops/grafana/dashboards/pulseops-dashboard.json`, `ops/prometheus/alerts.yml` | Done | Captured logs, metrics, dashboard preview, and alerts are documented. |
| Performance has measured baseline | `benchmarks/results/local-baseline.md`, `docs/benchmarks/latest-results.md` | Done | Smoke, load, stress, and spike results are documented with metrics. |
| Scalability and cost are explicit | `docs/scalability.md`, `docs/operational-cost.md`, `docs/architecture/production-gap-analysis.md` | Done | Names bottlenecks, cost drivers, and real production gaps. |
| CI and verification are reproducible | `.github/workflows/ci.yml`, `Makefile`, `docs/spec-driven/verification-report.md` | Done | Local commands and remote CI are recorded. |
| Real customer production readiness is honest | `docs/architecture/production-gap-analysis.md` | Partial | Challenge is portfolio-ready; managed DB, secret manager, alert routing, provenance policy, and production operations remain external P0 items. |

## Out of Scope

- Hosted SaaS operations with customer traffic.
- Managed PostgreSQL procurement, PITR configuration, and recurring restore
  drills outside the checked-in runbooks.
- Production secret manager provisioning and automatic key rotation.
- OAuth/OIDC, SAML, or fine-grained API key scopes.
- Payload encryption at rest.
- Distributed webhook concurrency enforcement beyond the current node-local
  circuit breaker and policy controls.
- Full event store or event-sourced job reconstruction.
