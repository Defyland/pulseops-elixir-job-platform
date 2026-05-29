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
    docs/runbooks
  )

  @documentation_files ~w(
    README.md
    openapi.yaml
    docs/api/examples.md
    docs/api/errors.md
    docs/api/authorization-matrix.md
    docs/adr/001-oban-as-persistent-execution-engine.md
    docs/architecture/overview.md
    docs/architecture/supervision-tree.md
    docs/architecture/data-consistency.md
    docs/architecture/messaging.md
    docs/architecture/security-model.md
    docs/benchmarks/methodology.md
    docs/benchmarks/latest-results.md
    docs/diagrams/request-and-worker-flows.md
    docs/runbooks/timeout-and-dead-letter.md
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
        "test/pulse_ops/rate_limiter_test.exs",
        "test/pulse_ops/queues/provisioner_test.exs"
      ],
      &assert_file!/1
    )

    worker_tests = read!("test/pulse_ops/jobs/execution_worker_test.exs")

    Enum.each(
      ["dead-letters", "correlation ids", "timeouts", "retryable"],
      &assert_contains!(worker_tests, &1)
    )
  end

  test "CI workflow validates formatting, lint, security, tests, OpenAPI, coverage, and Docker" do
    ci = read!(".github/workflows/ci.yml")

    Enum.each(
      [
        "mix format --check-formatted",
        "mix compile --warnings-as-errors",
        "mix credo --strict",
        "mix sobelow --skip --exit",
        "mix deps.audit",
        "mix test --cover",
        "actions/upload-artifact",
        "npx @redocly/cli lint openapi.yaml",
        "docker build .",
        "fetch-depth: 0"
      ],
      &assert_contains!(ci, &1)
    )
  end

  test "observability baseline is implemented and documented" do
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
        "Audit logging"
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

    Enum.each(
      [
        "Queues",
        "Routing keys",
        "Retry queues",
        "Dead-letter queue",
        "Message idempotency",
        "Consumer acknowledgement",
        "Correlation IDs"
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
end
