# Personas

## Platform Engineer

Needs to provide an internal API for reliable job execution across product
teams. Cares about predictable retries, queue depth, observability, deployment
controls, and clear ownership when jobs fail.

## SaaS Product Engineer

Needs to enqueue tenant-specific work from application features without leaking
one tenant's jobs, payloads, or retry actions into another tenant's boundary.
Cares about API ergonomics, idempotency, and request examples.

## Operations Engineer

Needs to inspect dead-lettered jobs, identify which customer was affected,
understand why execution failed, and decide whether retry is safe. Cares about
events, attempts, logs, runbooks, and alert signals.

## Security Reviewer

Needs evidence that API keys, tenant filters, webhook egress, admin actions,
replay, and audit records are handled deliberately. Cares about threat models,
authorization matrices, abuse cases, and residual risk.

## Technical Evaluator

Needs to decide whether the repository demonstrates senior backend engineering.
Cares about product framing, domain modeling, trade-offs, test depth,
observability, CI, and honest production gaps.
