defmodule PulseOps.Jobs.ExecutionWorkerTest do
  use PulseOps.DataCase, async: false

  use Oban.Testing, repo: PulseOps.Repo

  alias PulseOps.Fixtures
  alias PulseOps.Jobs
  alias PulseOps.Jobs.WebhookCircuitBreaker

  test "executes noop jobs and records attempts and events" do
    %{organization: organization} = Fixtures.organization_fixture()
    job = Fixtures.job_fixture(organization)

    assert %{success: 1, failure: 0} = Oban.drain_queue(queue: Fixtures.runtime_queue(job))
    assert {:ok, job} = Jobs.get_job(organization, job.id)

    assert job.status == "succeeded"
    assert [%{status: "succeeded"}] = job.attempts
    assert Enum.any?(job.events, &(&1.event_type == "job.succeeded"))
  end

  test "marks crashing jobs as retryable while attempts remain" do
    %{organization: organization} = Fixtures.organization_fixture()

    job =
      Fixtures.job_fixture(organization, %{
        "worker" => "crash",
        "payload" => %{},
        "max_attempts" => 3
      })

    assert %{success: 0, failure: 1} = Oban.drain_queue(queue: Fixtures.runtime_queue(job))
    assert {:ok, job} = Jobs.get_job(organization, job.id)

    assert job.status == "retryable"
    assert job.last_error_kind == "error"
    assert Enum.any?(job.events, &(&1.event_type == "job.failed"))
  end

  test "dead-letters jobs that exhaust retries immediately" do
    %{organization: organization} = Fixtures.organization_fixture()

    job =
      Fixtures.job_fixture(organization, %{
        "worker" => "crash",
        "max_attempts" => 1,
        "payload" => %{}
      })

    assert %{success: 0, failure: 0, discard: 1} =
             Oban.drain_queue(queue: Fixtures.runtime_queue(job))

    assert {:ok, job} = Jobs.get_job(organization, job.id)
    assert job.status == "dead_lettered"
  end

  test "propagates correlation ids to webhook handlers" do
    %{organization: organization} = Fixtures.organization_fixture()
    bypass = Bypass.open()
    test_pid = self()

    Bypass.expect_once(bypass, "POST", "/hooks/jobs", fn conn ->
      send(test_pid, {:webhook_headers, Plug.Conn.get_req_header(conn, "x-correlation-id")})
      Plug.Conn.resp(conn, 202, ~s({"accepted":true}))
    end)

    job =
      Fixtures.job_fixture(organization, %{
        "worker" => "webhook",
        "correlation_id" => "corr-webhook-123",
        "payload" => %{
          "url" => "http://localhost:#{bypass.port}/hooks/jobs",
          "body" => %{"job" => "payload"}
        }
      })

    assert %{success: 1} = Oban.drain_queue(queue: Fixtures.runtime_queue(job))
    assert_receive {:webhook_headers, ["corr-webhook-123"]}

    assert {:ok, job} = Jobs.get_job(organization, job.id)
    assert job.status == "succeeded"
  end

  test "dead-letters webhook jobs that violate egress policy" do
    previous = Application.get_env(:pulse_ops, :webhook_security)

    Application.put_env(:pulse_ops, :webhook_security, %{
      allowed_hosts: [],
      allow_http: true,
      allow_private_networks: false,
      resolve_dns: false,
      circuit_breaker: %{failure_threshold: 2, reset_after_ms: 250}
    })

    on_exit(fn ->
      Application.put_env(:pulse_ops, :webhook_security, previous)
      WebhookCircuitBreaker.reset!()
    end)

    %{organization: organization} = Fixtures.organization_fixture()

    job =
      Fixtures.job_fixture(organization, %{
        "worker" => "webhook",
        "payload" => %{
          "url" => "http://127.0.0.1:4000/hooks/jobs",
          "body" => %{"job" => "payload"}
        }
      })

    assert %{discard: 1} = Oban.drain_queue(queue: Fixtures.runtime_queue(job))
    assert {:ok, job} = Jobs.get_job(organization, job.id)
    assert job.status == "dead_lettered"
    assert job.last_error =~ "private network"
  end

  test "dead-letters webhook redirects instead of following them" do
    previous = Application.get_env(:pulse_ops, :webhook_security)

    Application.put_env(:pulse_ops, :webhook_security, %{
      allowed_hosts: [],
      allow_http: true,
      allow_private_networks: true,
      resolve_dns: false,
      circuit_breaker: %{failure_threshold: 2, reset_after_ms: 250}
    })

    on_exit(fn ->
      Application.put_env(:pulse_ops, :webhook_security, previous)
      WebhookCircuitBreaker.reset!()
    end)

    %{organization: organization} = Fixtures.organization_fixture()
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/hooks/jobs", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("location", "http://127.0.0.1/admin")
      |> Plug.Conn.resp(302, "")
    end)

    job =
      Fixtures.job_fixture(organization, %{
        "worker" => "webhook",
        "payload" => %{
          "url" => "http://localhost:#{bypass.port}/hooks/jobs",
          "body" => %{"job" => "payload"}
        }
      })

    assert %{discard: 1} = Oban.drain_queue(queue: Fixtures.runtime_queue(job))
    assert {:ok, job} = Jobs.get_job(organization, job.id)
    assert job.status == "dead_lettered"
    assert job.last_error =~ "redirects are disabled"
  end

  test "captures timeouts as retryable failures" do
    %{organization: organization} = Fixtures.organization_fixture()

    job =
      Fixtures.job_fixture(organization, %{
        "worker" => "sleep",
        "timeout_ms" => 100,
        "payload" => %{"duration_ms" => 250}
      })

    assert %{failure: 1} = Oban.drain_queue(queue: Fixtures.runtime_queue(job))
    assert {:ok, job} = Jobs.get_job(organization, job.id)
    assert job.status == "retryable"
    assert job.last_error =~ "timeout budget"
  end
end
