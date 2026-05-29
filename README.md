# PulseOps

## What is this product?

PulseOps is a multi-tenant job execution platform built with Elixir, Phoenix, PostgreSQL, and Oban. It is designed for teams that need a reliable API for enqueueing, tracking, retrying, and auditing critical background jobs such as webhooks, reconciliation tasks, or tenant-specific automation.

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

## Architecture overview

PulseOps is a Phoenix JSON API backed by PostgreSQL. The HTTP layer authenticates API keys, writes job requests into the relational model, and enqueues execution into Oban. Oban workers load the platform job record, execute a constrained handler, and emit lifecycle telemetry. Prometheus scrapes `/metrics`, and Grafana dashboards consume those metrics.

More detail:

- [docs/architecture/overview.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/architecture/overview.md)
- [docs/architecture/supervision-tree.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/architecture/supervision-tree.md)
- [docs/architecture/data-consistency.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/architecture/data-consistency.md)
- [docs/architecture/messaging.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/architecture/messaging.md)
- [docs/architecture/security-model.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/architecture/security-model.md)
- [docs/diagrams/request-and-worker-flows.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/diagrams/request-and-worker-flows.md)

## Tech stack

- Elixir 1.19 / Erlang OTP 29
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

- OpenAPI contract: [openapi.yaml](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/openapi.yaml)
- Request/response examples: [docs/api/examples.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/api/examples.md)
- Error contract: [docs/api/errors.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/api/errors.md)
- Authorization matrix: [docs/api/authorization-matrix.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/api/authorization-matrix.md)

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
- Oban-managed `oban_jobs`
- `job_events`

Important constraints:

- unique `organizations.slug`
- unique `api_keys.key_prefix`
- unique queue name per organization
- unique `jobs.idempotency_key` per organization when present
- unique `jobs.external_ref` per organization when present
- unique attempt number per job

More detail:

- [docs/architecture/data-consistency.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/architecture/data-consistency.md)

## Testing strategy

The repository includes:

- unit tests for the state machine
- database-backed integration tests for tenant creation and idempotency
- request tests for organization and job endpoints
- authorization tests for tenant isolation
- async worker tests for success, crash, dead-letter, webhook delivery, and timeout budget failures

Run `mix test` to execute the suite.

## Performance benchmarks

Benchmark assets live in:

- [benchmarks/baseline.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/benchmarks/baseline.md)
- [benchmarks/results/local-baseline.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/benchmarks/results/local-baseline.md)
- [docs/benchmarks/methodology.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/benchmarks/methodology.md)
- [docs/benchmarks/latest-results.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/benchmarks/latest-results.md)

The scripts cover smoke, load, stress, and spike scenarios using k6.

## Observability

PulseOps exposes:

- structured logs with `request_id`, `correlation_id`, `organization_id`, `job_id`, and queue metadata
- traces instrumented for Phoenix, Ecto, Bandit, and Oban
- `/healthz`
- `/readyz`
- `/metrics`
- queue depth and job lifecycle metrics
- Grafana dashboard definition at [ops/grafana/dashboards/pulseops-dashboard.json](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/ops/grafana/dashboards/pulseops-dashboard.json)

## Security considerations

- API key authentication through `x-api-key`
- tenant isolation enforced on every organization-scoped query
- request rate limiting through an ETS-backed limiter
- no secret values persisted in plaintext; API keys are stored as SHA-256 digests
- explicit validation for queue names, retry ceilings, time budgets, and job payload structure
- correlation IDs propagated into webhook requests for auditability
- Sobelow and dependency audit checks in CI

Supporting docs:

- [docs/architecture/security-model.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/architecture/security-model.md)
- [docs/api/authorization-matrix.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/api/authorization-matrix.md)

## Trade-offs and decisions

- Domain queues are modeled explicitly, but this slice keeps execution on top of Oban instead of introducing RabbitMQ. That reduces infrastructure while still demonstrating persistent retries and dead letters.
- API key hashing uses SHA-256 because the tokens are high-entropy random secrets. A password-style adaptive hash was not necessary for this slice.
- Timeout failure tests simulate budget overruns at the domain layer to keep deterministic coverage in manual Oban test mode.

See ADRs:

- [docs/adr/001-oban-as-persistent-execution-engine.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/adr/001-oban-as-persistent-execution-engine.md)

## How to run locally

1. Copy `.env.example` to `.env` if you want custom settings.
2. Start PostgreSQL and optional observability services:

```bash
docker compose up -d postgres
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

## How to run tests

```bash
mix test
mix ci
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
- add retention pruning for `jobs`, `job_attempts`, and `job_events`
- add bulk replay of dead-lettered jobs
- add JWT or workload-identity auth for internal service-to-service traffic
- add RabbitMQ ingress adapter for external publishers
- add tenant-scoped dashboard pages on top of the JSON API
