# PulseOps Engineering Baseline

This repository follows the initiative-wide standards below.

## Mandatory outcomes

- Product-grade `README.md` with product and engineering sections
- `openapi.yaml` once the HTTP surface exists
- `docs/adr/`, `docs/architecture/`, `docs/benchmarks/`, `docs/api/`, `docs/diagrams/`, and `docs/runbooks/`
- atomic Conventional Commit history
- GitHub Actions for lint, tests, security, build, coverage, and OpenAPI validation
- observability with structured logs, metrics, traces, request IDs, and readiness endpoints
- documented k6 performance baselines

## PulseOps-specific emphasis

- documented supervision tree
- explicit retry policy with backoff, jitter, timeouts, and dead-letter transitions
- idempotency keys and deduplication behavior
- metrics for job lifecycle and queue depth
- failure tests around worker crashes, timeout handling, and webhook delivery

## Phase 0 boundary

This repository intentionally stops before scaffolding the Phoenix application. The goal of this phase is only to lock scope and standards.
