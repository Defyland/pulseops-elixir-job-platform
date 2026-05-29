# Disaster Recovery

Purpose: define how PulseOps should be recovered after regional, database, or
platform-level failure.

## Targets

- Initial portfolio target: documented DR process, not automated multi-region.
- Pilot RTO: 4 hours.
- Pilot RPO: 15 minutes, assuming managed PostgreSQL point-in-time recovery.
- Production target before customer launch: provider-backed restore automation
  and quarterly drills.

## Failure Modes

- App machines unavailable: redeploy the last known-good image.
- PostgreSQL primary unavailable: fail over through the managed provider.
- Data corruption or bad migration: restore to a point-in-time target and
  replay only verified safe traffic.
- Secret compromise: follow `secret-rotation.md`.
- Region unavailable: restore database into the standby region and deploy the
  release image with the same runtime configuration.

## Recovery Sequence

1. Freeze deploys and declare the incident severity.
2. Identify whether data loss, corruption, or only compute unavailability is in
   scope.
3. Restore PostgreSQL or fail over using the provider control plane.
4. Deploy the previous known-good image if the current image is suspect.
5. Run migrations only after confirming the target app version expects them.
6. Verify `/readyz`, tenant auth, job creation, Oban drain, metrics, and logs.
7. Re-enable traffic gradually.

## Evidence To Keep

- Backup identifier or PITR timestamp.
- Release image SHA.
- Restore command/operator.
- Integrity checks.
- Job execution smoke result.
- Follow-up remediation items.
