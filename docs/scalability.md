# Scalability

PulseOps scales first by keeping the architecture small, stateful where it must
be, and explicit about the limits that appear before more infrastructure is
justified.

## Hot Path

The hottest path is job creation:

```text
POST /api/v1/jobs
  -> API key lookup
  -> rate-limit check
  -> queue lookup
  -> idempotency constraint
  -> jobs insert
  -> oban_jobs insert
  -> job_events insert
```

The next hottest path is worker completion, which updates attempts, jobs, and
events while emitting telemetry.

## Read-Heavy Paths

- list jobs by tenant/status/queue
- get job details
- inspect attempts and lifecycle events
- scrape `/metrics`
- readiness checks during deploys

## Write-Heavy Paths

- create jobs
- record worker attempts
- append job events
- increment PostgreSQL-backed rate-limit buckets
- retention pruning for terminal history

## Fastest-Growing Tables

- `jobs`
- `job_attempts`
- `job_events`
- `oban_jobs`
- `rate_limit_buckets` under high request volume

Retention pruning reduces long-term growth for terminal job history, but active
jobs and high-volume tenants still need monitoring.

## Queue Buildup Modes

- dependency outage causes retries to accumulate
- webhook destination becomes slow or unavailable
- queue concurrency is too low for tenant volume
- PostgreSQL contention slows enqueue or completion writes
- worker deployment is down while clients continue enqueueing

## Hot Partitions

Potential hot keys:

- one organization with much higher traffic than others
- one queue receiving most jobs
- one API key hitting rate-limit buckets continuously
- one webhook host causing repeated retries or circuit-breaker checks

## Horizontal Scale

The Phoenix application and Oban workers can run on multiple nodes against the
same PostgreSQL database. PostgreSQL remains the central scaling boundary.

Works well:

- more API nodes for HTTP throughput
- more worker nodes for execution throughput
- queue concurrency tuning per tenant
- PostgreSQL-backed rate limits for multi-node correctness

Needs care:

- database connection pool sizing
- Oban queue concurrency versus database write capacity
- rate-limit bucket cleanup under high cardinality
- node-local webhook circuit breaker state

## Sharding or Partitioning Candidates

Do not shard early. Consider partitioning when measured data shows one of these
limits:

- `jobs` and `job_events` retention volume creates slow pruning or index bloat
- a few tenants dominate database writes
- audit retention requirements differ sharply by tenant
- Oban table growth requires tighter archival strategy

Likely first step:

- time-based partitioning for terminal job history
- tenant-level archival tables for high-volume tenants
- Redis or gateway rate limiting if PostgreSQL buckets become too hot

## Async Candidates

Already async:

- job execution
- retries
- webhook delivery
- retention pruning
- terminal reconciliation

Potential future async work:

- audit export
- usage metering
- external event publication through outbox
- replay approval workflow

## Non-Eventual Flows

These must not become eventually consistent without a stronger design:

- tenant authentication and authorization
- idempotent job creation
- queue ownership checks
- public job creation plus Oban scheduling
- retry/cancel tenant boundary checks
- webhook egress policy enforcement

## Scale Strategy

1. Tune queues, database indexes, and connection pools while keeping the modular
   monolith.
2. Add measured load testing against the target deployment environment.
3. Move hot ephemeral coordination, such as rate limiting or webhook circuit
   state, to Redis or gateway infrastructure only when PostgreSQL becomes the
   bottleneck.
4. Add outbox/event export only when external consumers require ordered streams.
5. Partition or archive job history once retention volume justifies it.
