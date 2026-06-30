# ADR 003: Publish the Repository Under the MIT License

## Status

Accepted.

## Context

PulseOps is already shaped as a public Elixir execution-platform asset with API
docs, retry/dead-letter behavior, auditability guidance, and evaluator notes.
Without an explicit license, the repository is publicly visible but not clearly
reusable by the engineers it is meant to teach.

## Decision

Publish the repository under the MIT License and mention that explicitly in the
README.

## Consequences

Positive:

- Learners can reuse the Oban-centered execution model and supporting docs with
  a clear legal boundary.
- The public portfolio signal becomes consistent with the repo's instructional
  intent.

Negative:

- Downstream forks may copy only the app surface and skip the operator caveats.
- Dependency and asset licensing still need separate attention.
