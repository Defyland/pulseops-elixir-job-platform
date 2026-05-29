# Authorization Matrix

## Public endpoints

| Endpoint | Method | Authentication | Notes |
| --- | --- | --- | --- |
| `/healthz` | `GET` | none | liveness probe |
| `/readyz` | `GET` | none | readiness probe |
| `/metrics` | `GET` | none | Prometheus scrape endpoint |
| `/api/v1/organizations` | `POST` | none | tenant bootstrap only |

## Tenant-scoped endpoints

| Endpoint | Method | Authentication | Tenant isolation rule |
| --- | --- | --- | --- |
| `/api/v1/organizations/me` | `GET` | `x-api-key` | resolves current tenant only |
| `/api/v1/api-keys` | `GET` | `x-api-key` | only keys for the current tenant |
| `/api/v1/api-keys` | `POST` | `x-api-key` | new key belongs to current tenant |
| `/api/v1/api-keys/:id` | `DELETE` | `x-api-key` | other-tenant ids return `404` |
| `/api/v1/queues` | `GET` | `x-api-key` | only queues for the current tenant |
| `/api/v1/queues` | `POST` | `x-api-key` | queue is created under current tenant |
| `/api/v1/queues/:id` | `PATCH` | `x-api-key` | other-tenant ids return `404` |
| `/api/v1/jobs` | `GET` | `x-api-key` | only jobs for the current tenant |
| `/api/v1/jobs` | `POST` | `x-api-key` | queue selection is restricted to current tenant |
| `/api/v1/jobs/:id` | `GET` | `x-api-key` | other-tenant ids return `404` |
| `/api/v1/jobs/:id/retry` | `POST` | `x-api-key` | only current tenant may requeue |
| `/api/v1/jobs/:id/cancel` | `POST` | `x-api-key` | only current tenant may cancel |
| `/api/v1/jobs/:id/events` | `GET` | `x-api-key` | only current tenant may inspect audit events |

## Security behavior notes

- Missing or invalid API keys return `401`.
- Cross-tenant resource access returns `404`.
- Authenticated and unauthenticated routes both pass through the rate limiter.
- Correlation IDs are echoed in responses and error envelopes for traceability.
