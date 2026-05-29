# Runbook: Timeout and Dead-Letter Handling

## Symptoms

- job remains in `retryable`
- repeated `job.failed` events with timeout-related messages
- job eventually lands in `dead_lettered`
- job remains in `running` long after the underlying worker should have finished

## Triage steps

1. Fetch the job details and inspect `attempts` and `events`.
2. Confirm whether the queue timeout budget is too low for the handler payload.
3. Check `/metrics` for queue depth and failure spikes.
4. If the worker is a webhook, confirm upstream latency and response codes.
5. If the platform row is stuck in `running`, compare it with the corresponding
   `oban_jobs` state in PostgreSQL.

## Immediate mitigations

- increase `execution_timeout_ms` on the queue if the workload is legitimately longer
- reduce payload size or split the workload into smaller jobs
- retry a dead-lettered job after the upstream dependency is stable again
- restart the application if the reconciler is not running; on boot it will
  resume periodic repair of stale terminal Oban rows

## Commands

```bash
curl -H "x-api-key: $PULSEOPS_API_KEY" \
  http://localhost:4000/api/v1/jobs/$JOB_ID

curl -X POST -H "x-api-key: $PULSEOPS_API_KEY" \
  http://localhost:4000/api/v1/jobs/$JOB_ID/retry

mix run -e 'IO.inspect(PulseOps.Jobs.reconcile_terminal_jobs())'
```

## Escalation notes

- If many tenants are affected simultaneously, inspect PostgreSQL health and the host running Oban.
- If only one tenant is affected, compare queue policy and downstream dependency latency for that tenant.
- If `oban_jobs` is terminal but the public `jobs` row is not, treat it as a
  state-mirroring incident and preserve the offending job id for follow-up.
