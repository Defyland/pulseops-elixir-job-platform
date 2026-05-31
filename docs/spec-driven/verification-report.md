# Verification Report

## Summary

This report records the verification for the spec-driven senior-readiness pass.
The implementation adds missing portfolio evidence and compliance tests. It does
not change application runtime behavior.

Local verification date: 2026-05-30.

Techlead hardening verification date: 2026-05-31.

The hardening pass closes the concrete review gaps found after the senior
readiness evaluation: tenant-scoped Oban runtime queues, idempotency
fingerprints with concurrent duplicate handling, webhook address pinning and
redirect blocking, optional metrics bearer-token protection, explicit numeric
input validation, and blocking container vulnerability scanning.

Latest remote `main` CI checked before this commit:

- Run `26696681615`
- Commit `bb95222`
- Status: success
- Duration: 4m52s

The current commit still needs its own GitHub Actions run after push. Recording
that run ID inside this same commit would require a follow-up commit and would
trigger another run, so final remote status is reported in the delivery summary.

## Commands Run

Commands run from the project root:

| Command | Result | Notes |
| --- | --- | --- |
| `mix format` | Passed | Formatted the updated ExUnit compliance test. |
| `mix test test/spec_compliance/general_project_spec_test.exs` | Passed | 20 tests, 0 failures. An initial wording-only assertion failed and was corrected before this passing run. |
| `mix ci` | Passed | Credo found no issues, Sobelow found no vulnerabilities, 67 tests passed, total coverage 80.63%. |
| `git diff --check` | Passed | No whitespace errors. |
| `npx @redocly/cli lint openapi.yaml` | Passed | OpenAPI description validated successfully. |
| `gh run list --workflow ci.yml --branch main --limit 3` | Passed | Latest remote `main` CI was green before this commit. |

Additional commands run for the 2026-05-31 techlead hardening pass:

| Command | Result | Notes |
| --- | --- | --- |
| `mix test test/pulse_ops/jobs_test.exs test/pulse_ops/jobs/execution_worker_test.exs test/pulse_ops/jobs/webhook_security_test.exs` | Passed | 20 tests, 0 failures. Covers tenant-scoped queue execution, idempotency fingerprint conflicts, concurrent idempotency, webhook pinning, and redirect blocking. |
| `mix test test/pulse_ops_web/controllers/health_controller_test.exs test/spec_compliance/general_project_spec_test.exs` | Passed | 24 tests, 0 failures. Covers metrics bearer-token protection and hardening spec evidence. |
| `mix test` | Passed | 75 tests, 0 failures. |
| `mix ci` | Passed | Credo found no issues, Sobelow found no vulnerabilities, dependency audit passed, 75 tests passed, total coverage 81.75%. |
| `npx @redocly/cli lint openapi.yaml` | Passed | OpenAPI description validated successfully. |
| `git diff --check` | Passed | No whitespace errors. |
| `docker build -t pulseops-hardening-check .` | Passed | Production release image builds locally. |
| `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp aquasec/trivy:0.70.0 image --ignore-unfixed --severity CRITICAL,HIGH --format json --output /tmp/pulseops-trivy-results.json --exit-code 1 pulseops-hardening-check` | Passed | Blocking HIGH/CRITICAL scan completed with exit code 0. |

Additional commands run for the 2026-05-31 reference-quality pass:

| Command | Result | Notes |
| --- | --- | --- |
| `mix test test/pulse_ops/jobs_test.exs` | Passed | 10 tests, 0 failures. Covers idempotency fingerprint extraction, legacy fingerprint backfill, and legacy conflict behavior. |
| `mix test test/pulse_ops/queues/provisioner_test.exs test/spec_compliance/general_project_spec_test.exs` | Passed | 22 tests, 0 failures. Covers local queue resync evidence and documentation compliance. |
| `mix test test/pulse_ops/jobs/webhook_security_test.exs test/pulse_ops/jobs/execution_worker_test.exs test/spec_compliance/general_project_spec_test.exs` | Passed | 32 tests, 0 failures. Covers approved URL connection options and webhook timeout budget evidence. |
| `mix ci` | Passed | Credo found no issues, Sobelow found no vulnerabilities, dependency audit passed, 78 tests passed, total coverage 81.09%. |
| `npx @redocly/cli lint openapi.yaml` | Passed | OpenAPI description validated successfully. |
| `git diff --check` | Passed | No whitespace errors. |
| `docker build -t pulseops-quality-check .` | Passed | Production release image builds locally after the quality pass. |
| `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp aquasec/trivy:0.70.0 image --ignore-unfixed --severity CRITICAL,HIGH --format json --output /tmp/pulseops-quality-trivy-results.json --exit-code 1 pulseops-quality-check` | Passed | Blocking HIGH/CRITICAL scan completed with exit code 0. |

## Passing Criteria

- Spec-driven docs exist and reference the shared standards.
- Product, domain, architecture, scalability, cost, and case-study docs exist.
- README and evaluator guide point to the new evidence.
- Spec compliance tests protect the expanded evidence package.
- Local validation commands pass.
- OpenAPI validation still passes.

## Partial Criteria

- Real customer production readiness remains partial by design. Managed
  PostgreSQL, secret manager provisioning, alert routing, provenance policy, and
  real incident ownership are documented as P0 external platform work.
- Current commit remote CI is intentionally checked after push and reported in
  the final delivery summary.

## Failed or Blocked Criteria

- Initial local spec compliance run failed because the test expected the exact
  phrase `tenant-safe job execution` while the product document used
  `tenant-facing platform capability`. The test was corrected to assert the
  documented product language and the suite passed afterward.

## Remaining Risk

- Documentation quality depends on compliance tests and reviewer discipline; it
  cannot replace operating the service under real production load.
- CI must be checked after the final push because local validation cannot prove
  the remote Docker/SBOM/Trivy path by itself.
