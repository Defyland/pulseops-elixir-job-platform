defmodule PulseOps.SpecCompliance.GeneralProjectSpecTest do
  use ExUnit.Case, async: true

  @moduledoc false

  @repo Path.expand("../..", __DIR__)
  @external_spec Path.expand("../specs/general-project-spec.md", @repo)

  @readme_sections [
    "What is this product?",
    "Problem it solves",
    "Target users",
    "Main features",
    "Architecture overview",
    "Tech stack",
    "Domain model",
    "API documentation",
    "Async or event architecture",
    "Database design",
    "Testing strategy",
    "Performance benchmarks",
    "Observability",
    "Security considerations",
    "Trade-offs and decisions",
    "How to run locally",
    "How to run tests",
    "Failure scenarios",
    "Roadmap"
  ]

  @documentation_dirs ~w(
    docs/adr
    docs/architecture
    docs/benchmarks
    docs/api
    docs/diagrams
    docs/events
    docs/observability
    docs/runbooks
    docs/security
  )

  @documentation_files ~w(
    CHANGELOG.md
    README.md
    openapi.yaml
    docs/evaluator-guide.md
    docs/api/examples.md
    docs/api/errors.md
    docs/api/authorization-matrix.md
    docs/adr/001-oban-as-persistent-execution-engine.md
    docs/adr/002-job-events-before-event-store.md
    docs/architecture/overview.md
    docs/architecture/supervision-tree.md
    docs/architecture/data-consistency.md
    docs/architecture/messaging.md
    docs/architecture/deployment-readiness.md
    docs/architecture/production-gap-analysis.md
    docs/architecture/production-readiness.md
    docs/architecture/security-model.md
    docs/benchmarks/methodology.md
    docs/benchmarks/latest-results.md
    docs/diagrams/request-and-worker-flows.md
    docs/events/README.md
    docs/events/job_lifecycle_event.v1.json
    docs/observability/dashboard-preview.svg
    docs/observability/evidence.md
    docs/runbooks/timeout-and-dead-letter.md
    docs/runbooks/job-replay-contract-drift.md
    docs/runbooks/postgres-restore-drill.md
    docs/runbooks/secret-rotation.md
    docs/runbooks/incident-response.md
    docs/runbooks/disaster-recovery.md
    docs/security/threat-model.md
    ops/prometheus/alerts.yml
    ops/deploy/fly/fly.toml
    ops/deploy/fly/README.md
  )

  test "general project spec is represented by executable compliance tests" do
    baseline = read!("docs/engineering-baseline.md")

    assert baseline =~ "specs/general-project-spec.md"
    assert baseline =~ "Repository-controlled requirements closed"

    if File.exists?(@external_spec) do
      assert File.read!(@external_spec) =~ "# General Project Spec"
      assert File.read!(@external_spec) =~ "Repository Definition of Done"
    end
  end

  test "mandatory documentation structure and entrypoints exist" do
    Enum.each(@documentation_dirs, &assert_dir!/1)
    Enum.each(@documentation_files, &assert_file!/1)
  end

  test "README contains every product and engineering section from the spec" do
    readme = read!("README.md")

    Enum.each(@readme_sections, fn section ->
      assert readme =~ "## #{section}"
    end)
  end

  test "external evaluator experience is explicit and reproducible" do
    readme = read!("README.md")
    evaluator = read!("docs/evaluator-guide.md")
    readiness = read!("docs/architecture/production-readiness.md")
    makefile = read!("Makefile")
    demo = read!("scripts/demo.sh")
    dockerignore = read!(".dockerignore")

    Enum.each(
      [
        "actions/workflows/ci.yml/badge.svg?branch=main",
        "github/v/tag/Defyland/pulseops-elixir-job-platform",
        "docs/evaluator-guide.md",
        "docs/architecture/production-readiness.md",
        "docs/architecture/production-gap-analysis.md",
        "docs/observability/evidence.md",
        "docs/events/README.md",
        "docs/security/threat-model.md",
        "docs/adr/002-job-events-before-event-store.md",
        "make demo"
      ],
      &assert_contains!(readme, &1)
    )

    Enum.each(
      [
        "Five-Minute Review",
        "Evidence Map",
        "Senior-Level Signals",
        "Known Non-Goals",
        "Event contracts and replay policy",
        "Threat model",
        "Event-store decision"
      ],
      &assert_contains!(evaluator, &1)
    )

    Enum.each(
      [
        "Operational Contract",
        "Deployment Readiness",
        "Scaling Limits",
        "Rollback Plan",
        "PostgreSQL-backed rate limiting",
        "Terminal job history is pruned"
      ],
      &assert_contains!(readiness, &1)
    )

    Enum.each(["ci:", "docker-build:", "demo:"], &assert_contains!(makefile, &1))

    Enum.each(
      [
        "#!/usr/bin/env bash",
        "POSTGRES_PORT=\"${POSTGRES_PORT:-55432}\"",
        "docker compose up -d postgres",
        "Demo completed successfully"
      ],
      &assert_contains!(demo, &1)
    )

    assert executable?("scripts/demo.sh")
    assert_contains!(read!("docker-compose.yml"), "${POSTGRES_PORT:-5432}:5432")
    assert_contains!(read!("config/dev.exs"), "System.get_env(\"POSTGRES_PORT\", \"5432\")")
    assert_contains!(dockerignore, "_build")
    assert_contains!(dockerignore, "deps")
  end

  test "documentation is portable and does not expose local filesystem paths" do
    files =
      ["README.md", "CHANGELOG.md", "openapi.yaml"]
      |> Enum.map(&Path.join(@repo, &1))
      |> Enum.concat(Path.wildcard(Path.join(@repo, "docs/**/*.md")))
      |> Enum.concat(Path.wildcard(Path.join(@repo, "benchmarks/**/*.md")))
      |> Enum.concat(Path.wildcard(Path.join(@repo, "benchmarks/*.md")))
      |> Enum.uniq()

    assert files != []

    Enum.each(files, fn file ->
      content = File.read!(file)

      refute content =~ "/Users/",
             "expected #{Path.relative_to(file, @repo)} to avoid local absolute paths"
    end)
  end

  test "local markdown links resolve from their source documents" do
    files =
      ["README.md", "CHANGELOG.md"]
      |> Enum.map(&Path.join(@repo, &1))
      |> Enum.concat(Path.wildcard(Path.join(@repo, "docs/**/*.md")))
      |> Enum.concat(Path.wildcard(Path.join(@repo, "benchmarks/**/*.md")))
      |> Enum.concat(Path.wildcard(Path.join(@repo, "benchmarks/*.md")))
      |> Enum.uniq()

    Enum.each(files, fn file ->
      file
      |> File.read!()
      |> local_markdown_links()
      |> Enum.each(fn target ->
        path =
          target
          |> String.split("#", parts: 2)
          |> hd()
          |> then(&Path.expand(&1, Path.dirname(file)))

        assert File.exists?(path),
               "expected #{Path.relative_to(file, @repo)} link #{inspect(target)} to resolve"
      end)
    end)
  end

  test "OpenAPI contract proves versioned endpoints, auth, examples, and error payloads" do
    openapi = read!("openapi.yaml")

    Enum.each(
      [
        "openapi: 3.1.0",
        "/api/v1/organizations",
        "/api/v1/jobs",
        "ApiKeyAuth",
        "ValidationError",
        "Unauthorized",
        "RateLimited",
        "NotFound",
        "Conflict",
        "application/json",
        "example:"
      ],
      &assert_contains!(openapi, &1)
    )
  end

  test "testing baseline covers critical layers and async failure paths" do
    Enum.each(
      [
        "test/pulse_ops/jobs/state_machine_test.exs",
        "test/pulse_ops/identity_test.exs",
        "test/pulse_ops/jobs_test.exs",
        "test/pulse_ops_web/controllers/job_controller_test.exs",
        "test/pulse_ops_web/controllers/api_key_controller_test.exs",
        "test/pulse_ops_web/controllers/queue_controller_test.exs",
        "test/pulse_ops/jobs/execution_worker_test.exs",
        "test/pulse_ops/jobs/reconciler_test.exs",
        "test/pulse_ops/jobs/retention_pruner_test.exs",
        "test/pulse_ops/jobs/webhook_security_test.exs",
        "test/pulse_ops_web/controllers/error_json_test.exs",
        "test/pulse_ops/rate_limiter_test.exs",
        "test/pulse_ops/queues/provisioner_test.exs"
      ],
      &assert_file!/1
    )

    worker_tests = read!("test/pulse_ops/jobs/execution_worker_test.exs")

    Enum.each(
      ["dead-letters", "correlation ids", "timeouts", "retryable", "egress policy"],
      &assert_contains!(worker_tests, &1)
    )

    rate_limiter_tests = read!("test/pulse_ops/rate_limiter_test.exs")
    retention_tests = read!("test/pulse_ops/jobs/retention_pruner_test.exs")
    webhook_tests = read!("test/pulse_ops/jobs/webhook_security_test.exs")

    assert_contains!(rate_limiter_tests, "PostgreSQL-backed buckets")
    assert_contains!(retention_tests, "retention window")
    assert_contains!(webhook_tests, "private network")
  end

  test "CI workflow validates formatting, lint, security, tests, OpenAPI, coverage, and Docker" do
    ci = read!(".github/workflows/ci.yml")
    dependabot = read!(".github/dependabot.yml")
    readme = read!("README.md")

    Enum.each(
      [
        "mix format --check-formatted",
        "mix compile --warnings-as-errors",
        "mix credo --strict",
        "mix sobelow --skip --exit",
        "mix deps.audit",
        "mix test --cover",
        "actions/checkout@v6",
        "actions/setup-node@v6",
        "actions/upload-artifact@v7",
        "anchore/sbom-action@v0.24.0",
        "aquasec/trivy:0.70.0",
        "otp-version: \"29.0\"",
        "npx @redocly/cli lint openapi.yaml",
        "docker build -t pulseops-ci:${{ github.sha }} .",
        "fetch-depth: 0",
        "pulseops-sbom.spdx.json",
        "trivy-results.json",
        "pulseops-trivy",
        "--exit-code 0"
      ],
      &assert_contains!(ci, &1)
    )

    assert_contains!(readme, "actions/workflows/ci.yml/badge.svg?branch=main")
    assert_contains!(readme, "github/v/tag/Defyland/pulseops-elixir-job-platform")

    Enum.each(
      [
        "package-ecosystem: \"mix\"",
        "package-ecosystem: \"github-actions\"",
        "interval: \"weekly\""
      ],
      &assert_contains!(dependabot, &1)
    )
  end

  test "100 percent production readiness gaps are explicit and prioritized" do
    gap_analysis = read!("docs/architecture/production-gap-analysis.md")

    Enum.each(
      [
        "100% Production Readiness Gap Analysis",
        "Current Readiness Level",
        "Already Production-Shaped",
        "P0 Before Real Customer Traffic",
        "P1 Shortly After Launch",
        "P2 Hardening",
        "Go/No-Go Review",
        "Deployment target and infrastructure as code",
        "Managed PostgreSQL operations",
        "Distributed rate limiting",
        "Webhook egress hardening",
        "Retention pruning",
        "Container and supply-chain policy"
      ],
      &assert_contains!(gap_analysis, &1)
    )
  end

  test "observability baseline is implemented and documented" do
    dashboard = read!("ops/grafana/dashboards/pulseops-dashboard.json")
    alerts = read!("ops/prometheus/alerts.yml")
    evidence = read!("docs/observability/evidence.md")
    preview = read!("docs/observability/dashboard-preview.svg")
    telemetry = read!("lib/pulse_ops_web/telemetry.ex")
    router = read!("lib/pulse_ops_web/router.ex")
    config = read!("config/config.exs") <> read!("config/dev.exs")

    Enum.each(["/healthz", "/readyz", "/metrics"], &assert_contains!(router, &1))
    Enum.each(["request_id", "correlation_id"], &assert_contains!(config, &1))

    Enum.each(
      ["pulse_ops.job.created.count", "pulse_ops.queue.depth", "vm.memory.total"],
      &assert_contains!(telemetry, &1)
    )

    assert_file!("ops/grafana/dashboards/pulseops-dashboard.json")
    assert read!("mix.exs") =~ "opentelemetry"

    Enum.each(
      [
        "Demo Evidence",
        "Metrics Evidence",
        "Structured Log Evidence",
        "Dashboard Evidence",
        "pulse_ops_job_stop_count",
        "pulse_ops_job_stop_duration_bucket",
        "job.succeeded"
      ],
      &assert_contains!(evidence, &1)
    )

    assert_contains!(dashboard, "pulse_ops_job_stop_count{status=\\\"succeeded\\\"}[5m]")
    assert_contains!(alerts, "PulseOpsHighHttp5xxRate")
    assert_contains!(alerts, "PulseOpsDeadLetterRateHigh")
    assert_contains!(evidence, "Alert Evidence")
    refute dashboard =~ "pulse_ops_job_stop_count_total"
    assert_contains!(preview, "PulseOps Operational Dashboard")
  end

  test "performance baseline publishes k6 scenarios and measured results" do
    Enum.each(
      ~w(benchmarks/baseline.md benchmarks/smoke.js benchmarks/load.js benchmarks/stress.js benchmarks/spike.js benchmarks/results/local-baseline.md),
      &assert_file!/1
    )

    results = read!("benchmarks/results/local-baseline.md")

    Enum.each(
      [
        "Smoke",
        "Load",
        "Stress",
        "Spike",
        "p50",
        "p95",
        "p99",
        "throughput",
        "error rate",
        "CPU",
        "memory"
      ],
      &assert_contains!(results, &1)
    )
  end

  test "security baseline is documented and backed by request tests" do
    security = read!("docs/architecture/security-model.md")
    authz = read!("docs/api/authorization-matrix.md")
    api_key_tests = read!("test/pulse_ops_web/controllers/api_key_controller_test.exs")
    job_tests = read!("test/pulse_ops_web/controllers/job_controller_test.exs")

    Enum.each(
      [
        "Threat model",
        "API key",
        "Rate limiting",
        "Input validation",
        "Secret management",
        "Tenant isolation",
        "Audit logging",
        "PostgreSQL",
        "Webhook"
      ],
      &assert_contains!(security, &1)
    )

    assert authz =~ "Tenant isolation"
    assert api_key_tests =~ "other tenants"
    assert job_tests =~ "validation errors"
    assert job_tests =~ "json_response(conn, 422)"
  end

  test "messaging and transaction baselines are explicit for the Oban-backed design" do
    messaging = read!("docs/architecture/messaging.md")
    data = read!("docs/architecture/data-consistency.md")
    events = read!("docs/events/README.md")
    adr = read!("docs/adr/002-job-events-before-event-store.md")
    identity = read!("lib/pulse_ops/identity.ex")
    provisioner = read!("lib/pulse_ops/queues/provisioner.ex")

    Enum.each(
      [
        "Queues",
        "Routing keys",
        "Retry queues",
        "Dead-letter queue",
        "Message idempotency",
        "Consumer acknowledgement",
        "Correlation IDs",
        "Replay should be treated as a privileged administrative operation"
      ],
      &assert_contains!(messaging, &1)
    )

    Enum.each(
      [
        "Transaction boundaries",
        "Unique constraints",
        "Foreign keys",
        "Operational indexes",
        "Optimistic locking",
        "Isolation assumptions",
        "Migration strategy",
        "Rollback strategy"
      ],
      &assert_contains!(data, &1)
    )

    Enum.each(
      [
        "Persisted Job Lifecycle Events",
        "Worker Operational Events",
        "Retry Policy",
        "Dead-Letter Policy",
        "Idempotency Policy",
        "Replay Decision Matrix",
        "Supervision Direction"
      ],
      &assert_contains!(events, &1)
    )

    Enum.each(
      [
        "Use Transactional Job Tables and Audit Logs Before a Full Event Store",
        "When To Keep Transactional Tables + Audit Logs",
        "When To Introduce An Event Store",
        "Replay Guidance"
      ],
      &assert_contains!(adr, &1)
    )

    assert_contains!(identity, "Provisioner.sync_queue(queue)")
    assert_contains!(provisioner, "Oban.start_queue")
  end

  test "threat model covers admin replay webhooks and job execution risks" do
    threat_model = read!("docs/security/threat-model.md")
    replay_runbook = read!("docs/runbooks/job-replay-contract-drift.md")
    overview = read!("docs/architecture/overview.md")

    Enum.each(
      [
        "Administrative Operations",
        "Manual Replay",
        "Webhooks",
        "Job Execution",
        "Abuse Cases To Test",
        "Monitoring Signals",
        "tenant-scoped authorization",
        "replay idempotency key",
        "Webhook jobs cross from PulseOps into untrusted third-party infrastructure"
      ],
      &assert_contains!(threat_model, &1)
    )

    assert_contains!(replay_runbook, "Job Replay Contract Drift")
    assert_contains!(replay_runbook, "operator identity")
    assert_contains!(overview, "Lifecycle and replay guidance")
    assert_contains!(overview, "docs/events/README.md")
  end

  test "production readiness pack has deploy, retention, webhook, and release evidence" do
    fly = read!("ops/deploy/fly/fly.toml")
    fly_readme = read!("ops/deploy/fly/README.md")
    jobs = read!("lib/pulse_ops/jobs.ex")
    rate_limiter = read!("lib/pulse_ops/rate_limiter.ex")
    webhook_security = read!("lib/pulse_ops/jobs/webhook_security.ex")
    webhook_circuit = read!("lib/pulse_ops/jobs/webhook_circuit_breaker.ex")
    release = read!("lib/pulse_ops/release.ex")
    compose = read!("docker-compose.yml")

    Enum.each(
      ["API_RATE_LIMIT_STORAGE = \"postgres\"", "WEBHOOK_ALLOW_PRIVATE_NETWORKS = \"false\""],
      &assert_contains!(fly, &1)
    )

    Enum.each(
      ["fly deploy --config ops/deploy/fly/fly.toml", "PulseOps.Release.migrate()"],
      &assert_contains!(fly_readme, &1)
    )

    assert_contains!(jobs, "prune_expired_jobs")
    assert_contains!(rate_limiter, "allow_postgres")
    assert_contains!(webhook_security, "private_address?")
    assert_contains!(webhook_circuit, "circuit_open")
    assert_contains!(release, "Ecto.Migrator.with_repo")
    assert_contains!(compose, "./ops/prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro")
  end

  test "Dockerfile uses a resolvable Elixir base image and builds a release" do
    dockerfile = read!("Dockerfile")

    assert dockerfile =~ "FROM elixir:1.19.5-otp-28-slim AS build"
    assert dockerfile =~ "FROM debian:trixie-slim AS runtime"
    assert dockerfile =~ "RUN mix release"
    assert dockerfile =~ ~s(CMD ["/app/bin/pulse_ops", "start"])
  end

  test "git history follows Conventional Commits with atomic implementation steps" do
    {log, 0} = System.cmd("git", ["log", "--format=%s", "-n", "10"], cd: @repo)
    subjects = String.split(log, "\n", trim: true)

    assert length(subjects) >= 5

    Enum.each(subjects, fn subject ->
      assert subject =~ ~r/^(build|chore|ci|docs|feat|fix|perf|refactor|test)(\([^)]+\))?: .+/
      refute subject in ["update project", "fixes", "final version", "stuff"]
    end)
  end

  defp read!(relative_path) do
    @repo
    |> Path.join(relative_path)
    |> File.read!()
  end

  defp assert_file!(relative_path) do
    assert File.regular?(Path.join(@repo, relative_path)), "expected #{relative_path} to exist"
  end

  defp assert_dir!(relative_path) do
    assert File.dir?(Path.join(@repo, relative_path)), "expected #{relative_path} to exist"
  end

  defp assert_contains!(content, expected) do
    assert content =~ expected, "expected content to include #{inspect(expected)}"
  end

  defp executable?(relative_path) do
    mode =
      @repo
      |> Path.join(relative_path)
      |> File.stat!()
      |> Map.fetch!(:mode)

    Bitwise.band(mode, 0o111) != 0
  end

  defp local_markdown_links(content) do
    Regex.scan(~r/\[[^\]]+\]\(([^)]+)\)/, content)
    |> Enum.map(fn [_full, target] -> target end)
    |> Enum.reject(&external_or_anchor_link?/1)
  end

  defp external_or_anchor_link?(target) do
    String.starts_with?(target, ["http://", "https://", "mailto:", "#"])
  end
end
