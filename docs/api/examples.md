# API Examples

## Create an organization

```http
POST /api/v1/organizations
Content-Type: application/json

{
  "organization": {
    "name": "Northwind Ops",
    "slug": "northwind-ops",
    "retention_days": 21
  }
}
```

```json
{
  "data": {
    "organization": {
      "id": "688e8d07-4df4-4895-aea4-82b89fbd3c91",
      "name": "Northwind Ops",
      "slug": "northwind-ops",
      "retention_days": 21,
      "inserted_at": "2026-05-28T23:00:00Z",
      "updated_at": "2026-05-28T23:00:00Z"
    },
    "default_queue": {
      "id": "0cb748f1-4e89-4bfa-a1ba-c1178ec6ed4e",
      "name": "default",
      "concurrency": 5,
      "max_attempts": 5,
      "execution_timeout_ms": 30000,
      "paused": false,
      "paused_at": null,
      "inserted_at": "2026-05-28T23:00:00Z",
      "updated_at": "2026-05-28T23:00:00Z"
    },
    "bootstrap_api_key": "po_live_590cf7e88c_0d1f4f3d27a4954aa56d0c41f0893d21"
  }
}
```

## Create a queue

```http
POST /api/v1/queues
x-api-key: po_live_...
Content-Type: application/json

{
  "queue": {
    "name": "critical_webhooks",
    "concurrency": 10,
    "max_attempts": 7,
    "execution_timeout_ms": 45000
  }
}
```

## Create a webhook job

```http
POST /api/v1/jobs
x-api-key: po_live_...
x-correlation-id: corr-order-100200
Content-Type: application/json

{
  "job": {
    "queue_name": "critical_webhooks",
    "worker": "webhook",
    "external_ref": "order-100200-webhook",
    "idempotency_key": "order-100200-paid",
    "payload": {
      "url": "https://example.com/hooks/orders",
      "body": {
        "order_id": 100200,
        "event": "order.paid"
      }
    }
  }
}
```

## Retry a dead-lettered job

```http
POST /api/v1/jobs/17b1e34a-416a-4038-b4a4-c72a81106c06/retry
x-api-key: po_live_...
```

## Cancel a queued job

```http
POST /api/v1/jobs/17b1e34a-416a-4038-b4a4-c72a81106c06/cancel
x-api-key: po_live_...
```

## Validation error when `worker` is missing

```http
POST /api/v1/jobs
x-api-key: po_live_...
Content-Type: application/json

{
  "job": {
    "queue_name": "default"
  }
}
```

## Rate limited response

```http
GET /healthz
x-correlation-id: corr-rate-limit
```
