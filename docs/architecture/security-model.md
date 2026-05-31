# Security Model

PulseOps is a multi-tenant control plane. The primary security objective is to
prevent one tenant from reading, mutating, or replaying another tenant's work
while preserving a small operational surface for the platform team.

## Threat model

### Assets

- tenant identity and API credentials
- queued and running job payloads
- execution audit trail and retry controls
- queue policy configuration

### Trust boundaries

1. Public HTTP callers to Phoenix.
2. Phoenix controllers to domain modules.
3. Domain writes to PostgreSQL.
4. Oban worker execution back into the domain model.
5. Outbound webhook execution to third-party services.

### Main threats

- credential theft or misuse of `x-api-key`
- horizontal privilege escalation between tenants
- replay of duplicate enqueue requests
- abuse of retry and cancel endpoints
- request flooding on public or authenticated endpoints
- sensitive payload leakage through logs or errors
- partial writes leaving `jobs` and `oban_jobs` out of sync

## Controls

### Authentication

- Every authenticated API route requires `x-api-key`.
- API tokens are generated as high-entropy random values with the format
  `po_live_<prefix>_<secret>`.
- Only the prefix and SHA-256 digest are stored in PostgreSQL.

### Tenant isolation and authorization

- Every tenant-scoped query filters by `organization_id`.
- Cross-tenant access returns `404`, not `403`, to avoid resource discovery.
- Retry, cancel, queue mutation, and API key revocation all run through the same
  tenant boundary check.

### Rate limiting

- `PulseOpsWeb.Plugs.ApiRateLimit` enforces a configurable request budget.
- Public routes are rate-limited by caller IP.
- Authenticated routes are rate-limited by API key identifier.
- Local development can use ETS-backed counters.
- Production can set `API_RATE_LIMIT_STORAGE=postgres` to share rate-limit
  buckets across application nodes through the `rate_limit_buckets` table.

### Input validation and execution safety

- Ecto changesets validate queue names, attempt ceilings, timeout budgets, and
  worker allowlists.
- Job creation rejects malformed ISO8601 timestamps and malformed numeric
  controls instead of silently defaulting client errors.
- The worker layer only executes supported handlers (`noop`, `flaky`, `crash`,
  `sleep`, `webhook`).
- Webhook workers reject non-HTTPS destinations by default, block private
  network targets, support explicit host allowlists, resolve DNS before egress,
  pin the approved connection URI to a validated address, disable automatic
  redirects, and use a per-host circuit breaker for repeated failures.

### Audit logging

- Every lifecycle mutation writes immutable `job_events`.
- Request and correlation IDs are emitted in structured logs and error payloads.
- Outbound webhook delivery propagates `x-correlation-id`.
- Policy-discarded webhook jobs persist the discard reason in public job error
  metadata for operator audit.

### Secret management

- Runtime secrets come from environment variables such as `DATABASE_URL`,
  `SECRET_KEY_BASE`, and `OTEL_EXPORTER_OTLP_ENDPOINT`.
- Example values are documented in [.env.example](../../.env.example).
- No plaintext API key secret is persisted after issuance.
- Rotation procedure is documented in
  [docs/runbooks/secret-rotation.md](../runbooks/secret-rotation.md).

## Residual risk and follow-up

- API keys are bearer credentials with no scoped permissions yet.
- Payload encryption at rest is not implemented in this slice.
- Key rotation is manual through create-and-revoke instead of scheduled rotation.
- The webhook circuit breaker is node-local; a very large deployment should
  centralize it in Redis, PostgreSQL, or the egress gateway.
