# Engineering Case Study

## 1. Product Context

PulseOps is a multi-tenant job execution platform for teams that need to expose
background work through an API. It solves the point where a normal worker queue
becomes a product surface: tenants need isolation, idempotency, status,
attempts, retries, dead-letter review, webhook controls, and audit history.

The product is intentionally API-first. A browser UI is out of scope because the
backend challenge is about execution correctness, operability, and architecture.

## 2. Domain Model

The core domain nouns are organization, API key, queue, job, attempt, job event,
retry, dead letter, reconciliation, retention, and replay.

The organization is the tenant boundary. Queues define tenant-owned execution
policy. Jobs are public work requests. Attempts are execution evidence. Events
are append-only lifecycle audit records.

Domain details:

- [glossary](domain/glossary.md)
- [bounded contexts](domain/bounded-contexts.md)
- [aggregates](domain/aggregates.md)
- [invariants](domain/invariants.md)
- [state machines](domain/state-machines.md)

## 3. Architecture

PulseOps uses a modular Phoenix application with PostgreSQL and Oban. Phoenix
handles the JSON API. Domain contexts own identity, queues, and jobs. PostgreSQL
stores public state and Oban executor state. Oban owns durable scheduling,
retries, and worker execution.

The important split is between the public job model and executor state. The API
does not expose Oban internals as the product model. PulseOps stores `jobs`,
`job_attempts`, and `job_events` as the stable domain surface while Oban handles
execution mechanics.

Architecture evidence:

- [overview](architecture/overview.md)
- [C4 context](architecture/c4-context.md)
- [C4 container](architecture/c4-container.md)
- [module boundaries](architecture/module-boundaries.md)
- [sequence diagrams](architecture/sequence-diagrams.md)
- [deployment view](architecture/deployment-view.md)
- [supervision tree](architecture/supervision-tree.md)

## 4. Key Trade-offs

Oban over RabbitMQ:

- chosen because the project needs durable execution, retries, scheduling, and
  operational introspection without adding a broker on day one
- rejected broker-first design because it increases local setup, CI, deploy, and
  failure modes before broker-native routing is required

Transactional tables plus audit events over event sourcing:

- chosen because operators need current job state and per-job history
- rejected full event sourcing because projection rebuilds, snapshots, upcasters,
  and replay tooling are not justified yet

API keys over OAuth/OIDC:

- chosen because high-entropy service credentials fit this machine-to-machine
  challenge
- rejected OAuth/OIDC until delegated identity, human admin sessions, or
  enterprise SSO becomes a requirement

## 5. Data Model

Core tables:

- `organizations`
- `api_keys`
- `queues`
- `jobs`
- `job_attempts`
- `job_events`
- `rate_limit_buckets`
- Oban-managed `oban_jobs`

The data model uses tenant-scoped foreign keys, unique constraints for
idempotency, and indexes for job lookup, queue depth, attempts, events, and rate
limit cleanup.

Details live in [data consistency](architecture/data-consistency.md).

## 6. Consistency Model

PulseOps uses PostgreSQL transactions and unique constraints instead of
serializable transactions for the main race-prone operations.

Important consistency points:

- organization bootstrap creates organization, default queue, and API key in one
  transaction
- job creation writes public job state, Oban executor state, and `job.created`
  audit evidence in one transaction
- idempotency is enforced by `organization_id + idempotency_key`
- terminal Oban state is reconciled into public job state if telemetry
  persistence is missed
- retention pruning deletes terminal history in one transaction

## 7. Failure Scenarios

Covered failure modes:

- worker crash
- timeout budget exceeded
- retry exhaustion
- dead-letter triage
- webhook target failure
- webhook policy discard
- tenant attempts cross-tenant access
- job remains `running` after Oban reached terminal state
- old active jobs must not be pruned

Runbooks cover timeout/dead-letter triage, contract drift replay, restore drill,
secret rotation, incident response, and disaster recovery.

## 8. Performance Strategy

Performance is measured with k6 smoke, load, stress, and spike scripts. The goal
is method and bottleneck visibility, not inflated numbers.

Current strategy:

- keep queue provisioning out of the enqueue hot path
- index tenant/status/queue lookup paths
- use Oban for durable execution
- publish measured local p50, p95, p99, throughput, error rate, CPU, and memory
  notes

Evidence:

- [benchmark baseline](../benchmarks/baseline.md)
- [local results](../benchmarks/results/local-baseline.md)
- [benchmark methodology](benchmarks/methodology.md)

## 9. Scalability Strategy

The first scaling boundary is PostgreSQL. API nodes and workers can scale
horizontally, but public job writes, Oban scheduling, rate-limit buckets, and
event history all converge on the database.

The strategy is to tune the modular monolith first, then move only proven hot
coordination paths to dedicated infrastructure.

Details: [scalability](scalability.md).

## 10. Security Model

PulseOps protects tenant data with scoped API key authentication,
tenant-scoped queries, rate limits, validation, structured errors, audit events,
and webhook egress controls.

Security evidence:

- [security model](architecture/security-model.md)
- [threat model](security/threat-model.md)
- [authorization matrix](api/authorization-matrix.md)
- webhook security tests
- request tests for API keys, scope enforcement, and tenant isolation

Residual risks are explicit: payload encryption at rest is not implemented,
replay endpoint is deferred, key rotation is manual, and node-local webhook
circuit state is not enough for very large deployments.

## 11. Observability

The system exposes health, readiness, Prometheus metrics, structured logs, and
OpenTelemetry instrumentation. Domain signals include job lifecycle counts,
execution duration, queue depth, request/correlation IDs, organization ID, job
ID, and queue metadata.

Evidence:

- [observability evidence](observability/evidence.md)
- `ops/grafana/dashboards/pulseops-dashboard.json`
- `ops/prometheus/alerts.yml`

## 12. Operational Cost

PulseOps deliberately avoids a broker, Redis, event store, and microservices in
the first slice. The cost is a heavier PostgreSQL dependency. The benefit is a
smaller operating surface for a portfolio system and early production pilot.

Details: [operational cost](operational-cost.md).

## 13. Maintainability

The code is organized around Phoenix contexts and domain language. A maintainer
can find tenant identity in `PulseOps.Identity`, queue policy in
`PulseOps.Queues`, job lifecycle in `PulseOps.Jobs`, and HTTP behavior in
`PulseOpsWeb`.

Compliance tests keep documentation and evidence from regressing. Runbooks,
OpenAPI examples, ADRs, and benchmark scripts provide operational context.

## 14. Product Decisions

Product decisions that shape the architecture:

- API-first surface because the target user is another service or platform team.
- Tenant-level retention because storage cost and audit expectations vary by
  customer.
- Explicit queue model because concurrency and timeout policy are product
  concerns.
- Manual replay is deferred because replay can duplicate side effects and needs
  operator identity, reason, dry-run validation, and idempotency controls.

## 15. What I Would Do Next

For the portfolio:

- keep CI green and tagged releases visible
- add more captured benchmark runs from a hosted environment
- add screenshots from a real Grafana instance if the service is deployed

Before real customer production:

- provision managed PostgreSQL with backup, PITR, and restore drills
- add production secret manager and rotation ownership
- add alert routing and incident ownership
- add scheduled API key rotation and operator identity integration
- add payload encryption at rest when payload sensitivity requires it
- add release provenance and blocking image policy
