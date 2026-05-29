# Incident Response

Purpose: provide a concrete operating model for PulseOps alerts and production
failures.

## Severity

- SEV1: API unavailable, data loss suspected, database down, or job execution
  stopped across all tenants.
- SEV2: one tenant materially impacted, dead-letter spike, queue depth growing,
  or sustained elevated 5xx.
- SEV3: degraded latency, isolated webhook destination failures, or noisy but
  non-customer-impacting alerts.

## First 10 Minutes

1. Assign incident commander and primary investigator.
2. Freeze unrelated deploys.
3. Check `/healthz`, `/readyz`, Prometheus alerts, and recent deploy SHA.
4. Inspect queue depth, dead-letter rate, HTTP 5xx rate, and database
   connection saturation.
5. Decide whether to roll back the app, pause traffic, or disable a problematic
   webhook destination.

## Investigation

- Use `correlation_id`, `organization_id`, `job_id`, and `queue` log metadata.
- Compare public job status with Oban state.
- Run `PulseOps.Jobs.reconcile_terminal_jobs/1` if terminal Oban jobs diverge
  from platform jobs.
- Use `docs/runbooks/timeout-and-dead-letter.md` for dead-letter triage.
- Validate whether the issue is app code, database, platform network, or a
  customer webhook destination.

## Communication

- SEV1: update stakeholders every 15 minutes.
- SEV2: update every 30 minutes.
- SEV3: update when state changes.

## Closure

- Confirm alerts are clear.
- Confirm new jobs reach terminal state.
- Document customer impact, root cause, timeline, remediation, and prevention.
- Add tests, runbook updates, or alerts for every preventable recurrence.
