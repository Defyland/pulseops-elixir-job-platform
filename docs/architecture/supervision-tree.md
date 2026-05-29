# Supervision Tree

```mermaid
graph TD
  A["PulseOps.Supervisor"] --> B["PulseOpsWeb.Telemetry"]
  A --> C["PulseOps.Repo"]
  A --> D["Oban"]
  A --> E["PulseOps.RateLimiter"]
  A --> F["DNSCluster"]
  A --> G["Phoenix.PubSub"]
  A --> H["PulseOps.Queues.Provisioner"]
  A --> I["PulseOpsWeb.Endpoint"]
```

## Notes

- `Oban` owns queue processes, schedulers, and the pruner plugin.
- `PulseOps.Queues.Provisioner` only coordinates queue runtime shape; it does not execute jobs itself.
- `PulseOpsWeb.Telemetry` publishes Prometheus-compatible metrics and periodic queue depth measurements.
