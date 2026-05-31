# Error Format

Every non-2xx response follows the same envelope:

```json
{
  "error": {
    "code": "validation_error",
    "message": "Request validation failed",
    "details": {
      "worker": ["can't be blank"]
    },
    "request_id": "F5kPqF0A0E4FGQAAABeB",
    "correlation_id": "corr-order-100200"
  }
}
```

## Error codes

- `unauthorized`: missing or invalid `x-api-key`
- `forbidden`: valid API key without the endpoint's required scope
- `validation_error`: schema validation failed
- `bad_request`: malformed scheduling or queue selection input
- `conflict`: invalid lifecycle transition such as retrying a succeeded job
- `not_found`: resource does not exist or belongs to another tenant
- `rate_limited`: the caller exceeded the configured request budget

## Authorization failure example

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found",
    "details": {},
    "request_id": "F5kPqF0A0E4FGQAAABhC",
    "correlation_id": "corr-tenant-check"
  }
}
```

The API intentionally returns `404` for cross-tenant resource access so callers
cannot distinguish between “unknown id” and “known id in another tenant”.

Valid API keys that belong to the tenant but lack the endpoint's required scope
return `403` with the missing scope in `details.required_scope`.

```json
{
  "error": {
    "code": "forbidden",
    "message": "API key scope is not allowed for this endpoint",
    "details": {
      "required_scope": "jobs:write"
    },
    "request_id": "F5kPqF0A0E4FGQAAABhD",
    "correlation_id": "corr-scope-check"
  }
}
```

## Validation failure example

```json
{
  "error": {
    "code": "validation_error",
    "message": "Request validation failed",
    "details": {
      "worker": ["can't be blank"]
    },
    "request_id": "F5kPqF0A0E4FGQAAABeB",
    "correlation_id": "corr-order-100200"
  }
}
```

## Rate limit failure example

```json
{
  "error": {
    "code": "rate_limited",
    "message": "Too many requests",
    "details": {
      "retry_after_ms": 54823
    },
    "request_id": "F5kPqF0A0E4FGQAAABeB",
    "correlation_id": "corr-rate-limit"
  }
}
```
