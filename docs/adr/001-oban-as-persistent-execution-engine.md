# ADR 001: Use Oban as the Persistent Execution Engine

## Status

Accepted

## Context

PulseOps needs durable retries, dead-letter behavior, scheduling, attempt metadata, and operational introspection. The product could have used a custom GenServer-based queue or introduced RabbitMQ from the first slice.

## Decision

Use Oban on top of PostgreSQL as the execution engine for this slice.

## Rationale

- durable jobs backed by the relational database
- native retry, scheduling, cancellation, pruning, and queue management
- good fit for OTP supervision and telemetry
- lets the project demonstrate product-grade async behavior without adding a second infrastructure dependency on day one

## Consequences

Positive:

- simpler local setup
- fewer moving parts in CI
- strong operational story for job persistence and retries

Negative:

- queue semantics are constrained by Oban’s execution model
- broker-style routing keys and exchange topologies are postponed
- horizontal partitioning beyond PostgreSQL requires future design work

## Follow-up

RabbitMQ can be added later as an ingress adapter while keeping Oban as the
execution backend or by replacing the execution path if broker-native routing
becomes the primary requirement.
