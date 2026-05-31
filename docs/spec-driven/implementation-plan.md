# Implementation Plan

This plan originally applied the senior-readiness spec with the smallest
complete documentation change: add the missing evidence layer, wire it into
evaluator entrypoints, and protect it with executable compliance tests.
Application behavior is not changed in this original evidence pass because the
code already implemented the documented job lifecycle, retry, dead-letter,
webhook, retention, rate-limit, and observability behavior. Runtime hardening
changes after that pass are tracked in
[techlead-hardening-spec.md](techlead-hardening-spec.md).

## Scope

In scope:

- Add spec-driven artifacts under `docs/spec-driven/`.
- Add missing product and domain documentation required by the shared standards.
- Add the central senior case study, scalability analysis, operational cost
  analysis, and C4-style architecture views.
- Update README, evaluator guide, engineering baseline, and changelog so an
  evaluator can find the evidence quickly.
- Extend spec compliance tests to fail when the new evidence package regresses.
- Run relevant local validations and record results in the verification report.

Out of scope:

- New application features.
- Generic refactors.
- Edits outside `pulseops-elixir-job-platform/`, except reading shared specs.
- Production cloud provisioning or managed service configuration.

## Files to Create or Update

Create:

- `docs/spec-driven/senior-readiness-spec.md`
- `docs/spec-driven/implementation-plan.md`
- `docs/spec-driven/verification-report.md`
- `docs/engineering-case-study.md`
- `docs/product/problem.md`
- `docs/product/personas.md`
- `docs/product/use-cases.md`
- `docs/product/non-goals.md`
- `docs/product/roadmap.md`
- `docs/product/pricing-or-plans.md`
- `docs/domain/glossary.md`
- `docs/domain/bounded-contexts.md`
- `docs/domain/aggregates.md`
- `docs/domain/invariants.md`
- `docs/domain/state-machines.md`
- `docs/architecture/c4-context.md`
- `docs/architecture/c4-container.md`
- `docs/architecture/module-boundaries.md`
- `docs/architecture/sequence-diagrams.md`
- `docs/architecture/deployment-view.md`
- `docs/scalability.md`
- `docs/operational-cost.md`

Update:

- `README.md`
- `docs/evaluator-guide.md`
- `docs/engineering-baseline.md`
- `CHANGELOG.md`
- `test/spec_compliance/general_project_spec_test.exs`

## Acceptance Criteria Mapping

| Acceptance criterion | Planned evidence | Verification |
| --- | --- | --- |
| Shared specs were read and applied | `docs/spec-driven/senior-readiness-spec.md` names all three shared specs | Spec compliance test checks required spec references. |
| Product narrative is explicit | `README.md`, `docs/product/*.md`, `docs/engineering-case-study.md` | Spec compliance test checks product docs and README links. |
| Domain model is explicit | `docs/domain/*.md` | Spec compliance test checks glossary, contexts, aggregates, invariants, and state machines. |
| Architecture is justified | `docs/architecture/*.md`, ADRs, case study | Spec compliance test checks C4 docs, module boundaries, sequence diagrams, ADR references. |
| Operational evidence is visible | `docs/observability/evidence.md`, `docs/runbooks/*.md`, `docs/operational-cost.md` | Existing and new compliance tests check evidence docs. |
| Security and replay risks are explicit | `docs/security/threat-model.md`, `docs/events/README.md`, ADR 002 | Existing compliance tests check replay, webhook, and job execution threat coverage. |
| Test and CI evidence is executable | `test/spec_compliance/general_project_spec_test.exs`, `.github/workflows/ci.yml` | `mix test test/spec_compliance/general_project_spec_test.exs` and `mix ci`. |
| Verification is auditable | `docs/spec-driven/verification-report.md` | Report records commands, results, partial criteria, and remaining risk. |

## Verification Commands

Run locally from the project root:

```bash
mix format
mix test test/spec_compliance/general_project_spec_test.exs
mix ci
git diff --check
```

Run or verify remotely after push:

```bash
gh run list --workflow ci.yml --branch main --limit 3
gh run watch --exit-status
```

## Risks

- Documentation can drift from the code. Mitigation: add spec compliance tests
  that require evidence files and high-signal phrases tied to implemented
  behavior.
- New docs can overclaim maturity. Mitigation: keep production readiness honest
  by marking real customer production gaps as partial or out of scope.
- Too many docs can make evaluation slower. Mitigation: README and evaluator
  guide point to a curated path instead of forcing reviewers through every file.

## Deferred Work

- Add payload encryption at rest if job payloads can contain sensitive customer
  secrets.
- Add production secret manager integration for a concrete platform.
- Add release provenance attestation and a blocking image policy.
- Add distributed webhook concurrency/circuit state for high-volume tenants.
