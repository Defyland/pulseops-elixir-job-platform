# PulseOps

Multi-tenant job and workflow platform built in Elixir to showcase resilient background execution.

## Status

Phase 0 bootstrap only. This repository currently establishes naming, scope, documentation structure, and engineering expectations. It does not yet contain a Phoenix application or worker engine.

## Product intent

PulseOps is planned as a platform for creating, executing, monitoring, retrying, auditing, and replaying critical jobs across tenant projects and queues.

## Planned stack

- Elixir
- Phoenix API
- PostgreSQL
- Oban or a custom job engine
- RabbitMQ for optional external ingestion
- Redis for optional rate limiting
- OpenTelemetry
- Prometheus and Grafana
- Docker Compose
- k6

## Engineering focus

This project is meant to demonstrate:

- OTP supervision strategies
- persistent job execution semantics
- retry and dead-letter handling
- idempotent job creation
- operational dashboards and observability
- failure simulation around workers and webhooks

## Bootstrap contents

- repository initialized and synchronized with GitHub
- mandatory documentation folders created
- baseline engineering spec captured in `docs/engineering-baseline.md`

## Next phase

The first implementation slice should prioritize organizations, API keys, queues, jobs, lifecycle states, retry policy, and idempotency.
