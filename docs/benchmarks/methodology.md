# Benchmark Methodology

PulseOps uses k6 for all benchmark scenarios.

## Profiles

- `smoke.js`: validates liveness, auth, and a small enqueue burst
- `load.js`: steady-state enqueue traffic
- `stress.js`: saturation test to surface latency cliffs and error-rate growth
- `spike.js`: abrupt burst to inspect queue depth and recovery time

## Metrics captured

- p50 latency
- p95 latency
- p99 latency
- throughput
- error rate
- queue depth observations from `/metrics`
- CPU and memory notes collected from the host or container runtime

## Preconditions

- PostgreSQL running locally
- seeded organization and API key
- API running with `/metrics` enabled
- k6 installed locally

## Commands

```bash
k6 run benchmarks/smoke.js
k6 run benchmarks/load.js
k6 run benchmarks/stress.js
k6 run benchmarks/spike.js
```

## Published results

- latest local capture: [docs/benchmarks/latest-results.md](/Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/pulseops-elixir-job-platform/docs/benchmarks/latest-results.md)
