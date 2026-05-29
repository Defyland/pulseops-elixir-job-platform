# Local Benchmark Baseline

Date: 2026-05-28

## Machine profile

- Host: macOS 15.6 (`Darwin 24.6.0`) on Apple M1 Max
- Memory: 32 GiB RAM

## Preconditions

- `mix ecto.setup`
- server started with `API_RATE_LIMIT=100000 mix phx.server`
- `PULSEOPS_API_KEY` exported from the seed output

## Exact commands

```bash
BASE_URL=http://localhost:4000 \
  k6 run --summary-trend-stats 'avg,min,med,max,p(50),p(95),p(99)' \
  benchmarks/smoke.js

BASE_URL=http://localhost:4000 \
PULSEOPS_API_KEY=<seeded-key> \
  k6 run --vus 5 --duration 15s \
  --summary-trend-stats 'avg,min,med,max,p(50),p(95),p(99)' \
  benchmarks/load.js

BASE_URL=http://localhost:4000 \
PULSEOPS_API_KEY=<seeded-key> \
  k6 run --summary-trend-stats 'avg,min,med,max,p(50),p(95),p(99)' \
  benchmarks/stress.js

BASE_URL=http://localhost:4000 \
PULSEOPS_API_KEY=<seeded-key> \
  k6 run --summary-trend-stats 'avg,min,med,max,p(50),p(95),p(99)' \
  benchmarks/spike.js
```

## Results

### Smoke

- p50: 90.45 ms
- p95: 118.49 ms
- p99: 120.09 ms
- throughput: 0.91 req/s
- error rate: 0%

### Load

- profile: 5 VUs for 15s
- total requests: 780
- p50: 79.98 ms
- p95: 145.65 ms
- p99: 280.24 ms
- throughput: 51.74 req/s
- error rate: 0%

### Stress

- profile: `20 -> 50 -> 0` VUs over `2m`
- total requests: 26,002
- p50: 114.88 ms
- p95: 179.41 ms
- p99: 276.61 ms
- throughput: 216.62 req/s
- error rate: 0%

### Spike

- profile: `5 -> 80 -> 5 -> 0` VUs over `50s`
- total requests: 8,821
- p50: 140.32 ms
- p95: 268.53 ms
- p99: 408.04 ms
- throughput: 176.25 req/s
- error rate: 0%

## Operational notes

- The first stress attempt exposed a request-path bug: synchronizing queues during
  every enqueue saturated `PulseOps.Queues.Provisioner`, causing `39.48%` request
  failures, `15.15 req/s`, `p95=10.09s`, and `p99=13.13s`. Final published stress
  and spike numbers above were captured after removing that hot-path dependency.
- The pre-fix overload also left one platform job stuck in `running` even though
  its `oban_jobs` row had already reached `completed`. `PulseOps.Jobs.reconcile_terminal_jobs/1`
  now repairs that divergence and recovered the stale row during validation.
- Job table state after the full benchmark pass and reconciliation:
  `[{"succeeded", 35603}]`
- `vm_memory_total` from `/metrics` after the final stress/spike run was
  `122326.888` KiB (about `119.5 MiB`).
- Beam process snapshot after the spike run settled back to about `34 MiB` RSS
  (`ps`), while the earlier load snapshot peaked near `136 MiB` RSS and `54%`
  CPU.
- This benchmark pass validated three fixes discovered under load: runtime
  `API_RATE_LIMIT` applies in `dev`, queue provisioning no longer sits on the
  enqueue hot path, and terminal Oban state is now reconciled if telemetry
  persistence is missed.
