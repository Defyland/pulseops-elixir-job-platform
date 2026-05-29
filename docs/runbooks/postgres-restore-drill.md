# PostgreSQL Restore Drill

Purpose: prove that PulseOps can recover tenant data, Oban state, API keys, and
job history from managed PostgreSQL backups before a real production launch.

## Scope

- Database: managed PostgreSQL primary backing `DATABASE_URL`.
- Data: `organizations`, `api_keys`, `queues`, `jobs`, `job_attempts`,
  `job_events`, `oban_jobs`, and `rate_limit_buckets`.
- Objective: restore into an isolated environment, verify integrity, then
  document elapsed restore time and data loss window.

## Drill Steps

1. Create an isolated restore target database or temporary managed instance.
2. Restore the latest backup or point-in-time recovery target into that
   instance.
3. Start the app against the restored `DATABASE_URL` with no public traffic.
4. Run migrations with `PulseOps.Release.migrate()`.
5. Verify `/readyz` returns `200`.
6. Query counts for the core tables and compare against the source snapshot.
7. Fetch a known tenant job through the API and confirm attempts/events match.
8. Drain one safe `noop` job to prove Oban can resume from restored state.
9. Record restore duration, recovery point, missing data if any, and operator.

## Acceptance Criteria

- Restore completes within the declared RTO.
- Backup timestamp satisfies the declared RPO.
- Core table counts are explainable.
- At least one restored job can be read through the API.
- Oban starts without schema or queue errors.

## Frequency

- Run before production launch.
- Repeat quarterly.
- Repeat after changing database provider, backup policy, Oban version, or
  migration strategy.
