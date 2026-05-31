# Techlead Hardening Spec

## Scope

This spec closes the concrete senior/techlead review gaps identified after the
previous readiness pass. It does not require external production services; it
requires local, executable evidence that the repository is shaped as closely as
possible to production within a self-contained challenge.

## Acceptance Criteria

### Tenant-Scoped Runtime Queues

- Public queue names remain tenant-local API concepts.
- Oban runtime queue names include the tenant boundary so two organizations can
  both have a `default` queue without sharing pause, scale, or drain behavior.
- Each node periodically resynchronizes database-backed queues into local Oban
  queue processes so queue creation on one node does not require restarts on
  the others.
- Tests prove that draining one tenant's default runtime queue does not execute
  another tenant's default queue.

### Idempotency Under Concurrency

- Idempotency keys are backed by a request fingerprint.
- Reusing the same key with the same semantic request returns the original job.
- Reusing the same key with a different semantic request returns conflict.
- Concurrent identical requests converge on one persisted job even when the
  database unique constraint wins the race.

### Webhook Egress Hardening

- Webhook validation rejects private networks by default.
- When DNS validation is enabled, the approved connection URI is pinned to a
  vetted resolved address while preserving the original hostname for the HTTP
  client connection options.
- Automatic redirects are disabled; webhook redirects become terminal policy
  failures instead of being followed into an unvalidated destination.
- Webhook connect and receive waits both use the job timeout budget.

### Metrics Boundary

- `/metrics` remains easy to run locally without credentials.
- A configured metrics bearer token makes `/metrics` return `401` unless the
  matching `Authorization: Bearer ...` header is supplied.

### Supply-Chain Gate

- Container vulnerability scanning is a blocking CI policy for HIGH and
  CRITICAL findings after unfixed vulnerabilities are ignored.
- Scan output remains uploaded as evidence.

### API Validation

- Malformed numeric job inputs return explicit `400` errors instead of silently
  falling back to defaults.

## Non-Goals

- Running PagerDuty, a managed secret store, or a managed PostgreSQL service in
  the repository.
- Claiming customer production readiness without operational ownership.
- Implementing a bespoke event store before the transactional audit log needs
  it.

## Verification Commands

- `mix test`
- `mix ci`
- `npx @redocly/cli lint openapi.yaml`
