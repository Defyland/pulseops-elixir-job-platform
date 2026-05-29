# PulseOps

[![CI](https://github.com/Defyland/pulseops-elixir-job-platform/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Defyland/pulseops-elixir-job-platform/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/Defyland/pulseops-elixir-job-platform?label=release)](https://github.com/Defyland/pulseops-elixir-job-platform/releases)

## What is this product?

PulseOps is a multi-tenant job execution platform built with Elixir, Phoenix, PostgreSQL, and Oban. It is designed for teams that need a reliable API for enqueueing, tracking, retrying, and auditing critical background jobs such as webhooks, reconciliation tasks, or tenant-specific automation.

Evaluator entrypoints:

- [docs/evaluator-guide.md](docs/evaluator-guide.md)
- [docs/architecture/production-readiness.md](docs/architecture/production-readiness.md)
- [docs/architecture/production-gap-analysis.md](docs/architecture/production-gap-analysis.md)
- [docs/observability/evidence.md](docs/observability/evidence.md)
- [ops/deploy/fly/README.md](ops/deploy/fly/README.md)
- [ops/prometheus/alerts.yml](ops/prometheus/alerts.yml)
- [CHANGELOG.md](CHANGELOG.md)
- `make ci`
- `make docker-build`
- `make demo`

## Problem it solves

Teams usually start background processing with generic workers and little product structure. That breaks down when they need tenant isolation, API key authentication, idempotent job creation, retry policies, dead-letter handling, or operational visibility. PulseOps packages those concerns behind a dedicated API instead of forcing them into ad hoc application code.

## Target users

- Platform engineers building internal automation APIs
- B2B SaaS teams running customer-specific background workloads
- Operations teams that need audit trails and replay controls
- Product engineers who need a safe webhook and async execution backend

## Main features

- Tenant registration with bootstrap API keys
- Per-tenant queues with configurable concurrency, timeout budget, and retry policy
- Idempotent job creation through `idempotency_key`
- Job lifecycle tracking across `queued`, `running`, `retryable`, `succeeded`, `dead_lettered`, and `cancelled`
- Attempt history and immutable event log per job
- Retry and cancel endpoints
- Health, readiness, and Prometheus metrics endpoints
- OpenTelemetry instrumentation for Phoenix, Ecto, Bandit, and Oban
- PostgreSQL-backed distributed rate limiting for multi-node deployments
- Tenant retention pruning for terminal job history
- Webhook egress policy with allowlists, private-network blocking, DNS checks,
  and circuit breaking

## Architecture overview

PulseOps is a Phoenix JSON API backed by PostgreSQL. The HTTP layer authenticates API keys, writes job requests into the relational model, and enqueues execution into Oban. Oban workers load the platform job record, execute a constrained handler, and emit lifecycle telemetry. Prometheus scrapes `/metrics`, and Grafana dashboards consume those metrics.

More detail:

- [docs/architecture/overview.md](docs/architecture/overview.md)
- [docs/architecture/supervision-tree.md](docs/architecture/supervision-tree.md)
- [docs/architecture/data-consistency.md](docs/architecture/data-consistency.md)
- [docs/architecture/messaging.md](docs/architecture/messaging.md)
- [docs/architecture/production-readiness.md](docs/architecture/production-readiness.md)
- [docs/architecture/production-gap-analysis.md](docs/architecture/production-gap-analysis.md)
- [docs/architecture/security-model.md](docs/architecture/security-model.md)
- [docs/diagrams/request-and-worker-flows.md](docs/diagrams/request-and-worker-flows.md)

## Tech stack

- Elixir 1.19 / Erlang OTP 28+ (CI validates OTP 29; Docker release uses OTP 28)
- Phoenix 1.8 JSON API over Bandit
- Ecto + PostgreSQL
- Oban for persistent background execution
- Req for outbound webhook delivery
- OpenTelemetry for tracing instrumentation
- Telemetry Metrics + Prometheus exporter
- Grafana dashboard definition in `ops/grafana`
- k6 scripts in `benchmarks/`

## Domain model

- `Organization`: tenant boundary, slug, retention policy
- `ApiKey`: scoped credential for a single organization
- `Queue`: execution lane with concurrency, timeout budget, retry ceiling, and pause state
- `Job`: public-facing async task with payload, idempotency key, status, and execution metadata
- `JobAttempt`: one execution attempt with timing and failure metadata
- `JobEvent`: append-only audit event stream for lifecycle transitions

## API documentation

- OpenAPI contract: [openapi.yaml](openapi.yaml)
- Request/response examples: [docs/api/examples.md](docs/api/examples.md)
- Error contract: [docs/api/errors.md](docs/api/errors.md)
- Authorization matrix: [docs/api/authorization-matrix.md](docs/api/authorization-matrix.md)

## Async or event architecture

The HTTP API persists the public `jobs` record first, then inserts a matching Oban job that carries the `job_id`, `correlation_id`, and timeout budget. Execution happens asynchronously inside `PulseOps.Jobs.ExecutionWorker`.

Lifecycle behavior:

- creation emits `job.created`
- worker start emits `job.started`
- worker success emits `job.succeeded`
- transient failure emits `job.failed` and sets the job to `retryable`
- final failure emits `job.dead_lettered`
- operator actions emit `job.retried` and `job.cancelled`

## Database design

Tables:

- `organizations`
- `api_keys`
- `queues`
- `jobs`
- `job_attempts`
- `rate_limit_buckets`
- Oban-managed `oban_jobs`
- `job_events`

Important constraints:

- unique `organizations.slug`
- unique `api_keys.key_prefix`
- unique queue name per organization
- unique `jobs.idempotency_key` per organization when present
- unique `jobs.external_ref` per organization when present
- unique attempt number per job
- unique rate-limit bucket per identifier/window

More detail:

- [docs/architecture/data-consistency.md](docs/architecture/data-consistency.md)

## Testing strategy

The repository includes:

- unit tests for the state machine
- database-backed integration tests for tenant creation and idempotency
- request tests for organization and job endpoints
- authorization tests for tenant isolation
- async worker tests for success, crash, dead-letter, webhook delivery, and timeout budget failures
- production-readiness tests for retention pruning, PostgreSQL rate limiting,
  webhook egress policy, and webhook circuit breaking

Run `mix test` to execute the suite.

## Performance benchmarks

Benchmark assets live in:

- [benchmarks/baseline.md](benchmarks/baseline.md)
- [benchmarks/results/local-baseline.md](benchmarks/results/local-baseline.md)
- [docs/benchmarks/methodology.md](docs/benchmarks/methodology.md)
- [docs/benchmarks/latest-results.md](docs/benchmarks/latest-results.md)

The scripts cover smoke, load, stress, and spike scenarios using k6.

## Observability

PulseOps exposes:

- structured logs with `request_id`, `correlation_id`, `organization_id`, `job_id`, and queue metadata
- traces instrumented for Phoenix, Ecto, Bandit, and Oban
- `/healthz`
- `/readyz`
- `/metrics`
- queue depth and job lifecycle metrics
- Grafana dashboard definition at [ops/grafana/dashboards/pulseops-dashboard.json](ops/grafana/dashboards/pulseops-dashboard.json)
- Captured demo metrics, structured log examples, and dashboard preview in
  [docs/observability/evidence.md](docs/observability/evidence.md)
- Prometheus alert rules at [ops/prometheus/alerts.yml](ops/prometheus/alerts.yml)

## Security considerations

- API key authentication through `x-api-key`
- tenant isolation enforced on every organization-scoped query
- request rate limiting through ETS locally or PostgreSQL-backed buckets in
  multi-node production
- no secret values persisted in plaintext; API keys are stored as SHA-256 digests
- explicit validation for queue names, retry ceilings, time budgets, and job payload structure
- correlation IDs propagated into webhook requests for auditability
- webhook execution defaults to HTTPS, allowlists, private-network blocking,
  DNS checks, and circuit breaking
- Sobelow and dependency audit checks in CI

Supporting docs:

- [docs/architecture/security-model.md](docs/architecture/security-model.md)
- [docs/api/authorization-matrix.md](docs/api/authorization-matrix.md)

## Trade-offs and decisions

- Domain queues are modeled explicitly, but this slice keeps execution on top of Oban instead of introducing RabbitMQ. That reduces infrastructure while still demonstrating persistent retries and dead letters.
- API key hashing uses SHA-256 because the tokens are high-entropy random secrets. A password-style adaptive hash was not necessary for this slice.
- Timeout failure tests simulate budget overruns at the domain layer to keep deterministic coverage in manual Oban test mode.
- PostgreSQL-backed rate limiting was chosen over Redis for this challenge
  because PostgreSQL is already required, keeps the local platform smaller, and
  still proves shared limiter semantics across app nodes.
- Webhook egress is deliberately policy-first: unsafe destinations are
  discarded instead of retried because SSRF violations are not transient
  delivery failures.

See ADRs:

- [docs/adr/001-oban-as-persistent-execution-engine.md](docs/adr/001-oban-as-persistent-execution-engine.md)

## How to run locally

1. Copy `.env.example` to `.env` if you want custom settings.
2. Start PostgreSQL and optional observability services:

```bash
docker compose up -d postgres
```

If local port 5432 is already in use, run PostgreSQL on a different host port:

```bash
POSTGRES_PORT=55432 docker compose up -d postgres
export POSTGRES_PORT=55432
```

3. Install dependencies and prepare the database:

```bash
mix deps.get
mix ecto.setup
```

4. Start the API:

```bash
mix phx.server
```

5. Create a tenant:

```bash
curl -X POST http://localhost:4000/api/v1/organizations \
  -H "content-type: application/json" \
  -d '{"organization":{"name":"Northwind Ops","slug":"northwind-ops","retention_days":21}}'
```

Or run the full API demo:

```bash
make demo
```

## How to run tests

```bash
mix test
mix ci
make ci
```

## Failure scenarios

- worker crash: job moves to `retryable` until retry budget is exhausted
- timeout budget exceeded: job records a retryable failure with the timeout message
- final retry exhausted: job moves to `dead_lettered`
- webhook target returns a non-2xx status: job remains retryable or dead-lettered based on retry budget
- tenant accesses another tenant's job id: API returns `404`
- readiness check fails: `/readyz` returns `503`

## Roadmap

- add queue pause/resume endpoints instead of requiring a generic patch
- add bulk replay of dead-lettered jobs
- add JWT or workload-identity auth for internal service-to-service traffic
- add RabbitMQ ingress adapter for external publishers
- add tenant-scoped dashboard pages on top of the JSON API
