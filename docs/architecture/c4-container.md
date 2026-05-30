# C4 Container

## Containers

| Container | Responsibility | Technology |
| --- | --- | --- |
| Phoenix API | Versioned JSON API, auth, rate limit, validation, errors, health, metrics | Phoenix, Bandit |
| Domain contexts | Identity, queue, and job business rules | Elixir modules, Ecto |
| PostgreSQL | Source of truth for tenants, queues, jobs, attempts, events, rate buckets, Oban jobs | PostgreSQL |
| Oban executor | Durable scheduling, retries, queue execution, telemetry | Oban |
| Worker handlers | Execute supported job types such as noop, flaky, crash, sleep, and webhook | Elixir |
| Prometheus | Scrape metrics from `/metrics` | Prometheus |
| Grafana | Render operational dashboards | Grafana |

## Container Responsibilities

Phoenix owns HTTP concerns only. Domain contexts own product rules. PostgreSQL
owns durable state. Oban owns executor scheduling. The public job state remains
in PulseOps tables so the API is not coupled directly to Oban internals.

## Container Trade-Off

The design uses a modular monolith plus PostgreSQL-backed execution instead of
separate services and a broker. This keeps local setup, CI, and operational cost
small while still proving durable async execution and clear boundaries.
