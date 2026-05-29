# Job Replay Contract Drift

Use this runbook when replayed jobs fail because lifecycle metadata or payload shape changed.

## Triage

- Confirm the job lifecycle event follows `docs/events/README.md`.
- Check whether the replay uses the original `job_id` and a new attempt record.
- Inspect dead-letter reason, retry count, queue name, and correlation ID.
- Verify operator identity and replay reason were recorded.

## Recovery

- Stop batch replay if failures repeat.
- Add a compatibility adapter for old payload metadata when safe.
- Replay a single job first, then resume batch replay.
- Document the incompatibility in the next ADR or migration note.
