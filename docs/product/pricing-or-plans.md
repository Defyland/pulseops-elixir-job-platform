# Pricing Or Plans

PulseOps is a portfolio backend challenge, not a commercial SaaS. This document
still describes packaging assumptions because they influence architecture.

## Internal Platform Plan

For an internal platform, PulseOps is operated as shared infrastructure.

- Cost driver: PostgreSQL storage, worker CPU, observability retention, and
  operational ownership.
- Fairness driver: per-tenant queues, concurrency limits, and rate limits.
- Support driver: job events, attempts, correlation IDs, and runbooks.

## SaaS Packaging Hypothesis

If sold as a hosted service, plans would likely map to operational limits:

- number of tenants or workspaces
- monthly jobs
- queue concurrency
- retention days
- webhook destinations
- audit export period
- support and SLO tier

## Architectural Impact

- Retention days are modeled per organization because storage cost is a product
  lever.
- Queue concurrency belongs to the domain model because fairness is a product
  promise.
- API keys and rate limits are tenant scoped because usage isolation is required
  before pricing is meaningful.
- Usage metering is deferred because the portfolio slice focuses on job
  lifecycle correctness first.
