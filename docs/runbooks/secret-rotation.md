# Secret Rotation

Purpose: rotate operational secrets without losing job processing, tenant
isolation, or API availability.

## Secrets

- `SECRET_KEY_BASE`: Phoenix signing/encryption secret.
- `DATABASE_URL`: managed PostgreSQL credential.
- `PULSEOPS_API_KEY`: local demo/operator token only.
- `WEBHOOK_ALLOWED_HOSTS`: destination policy, not a secret, but security
  sensitive.
- `OTEL_EXPORTER_OTLP_ENDPOINT`: observability backend endpoint.

## Rotation Procedure

1. Open an incident or change record with owner, start time, and rollback owner.
2. Create the replacement secret in the platform secret manager.
3. Deploy the application with both old and new database credentials valid when
   the provider supports dual credentials.
4. Run `/readyz` and a tenant-authenticated smoke request.
5. Drain a `noop` job to confirm worker access to PostgreSQL and Oban.
6. Revoke the old secret only after the new release is serving traffic.
7. Store the rotation timestamp, operator, and validation evidence in the
   change record.

## Rollback

- If readiness fails, restore the previous platform secret value and redeploy.
- If database auth fails, re-enable the previous database credential from the
  provider console and restart machines.
- If API clients fail after an API key rotation, issue a new tenant API key and
  revoke the compromised one after client confirmation.

## Controls

- Never commit secret values to Git.
- Prefer provider secrets, AWS Secrets Manager, Vault, Doppler, or SSM over raw
  `.env` files outside local development.
- Review secret access logs during and after rotation.
