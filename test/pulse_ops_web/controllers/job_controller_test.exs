defmodule PulseOpsWeb.JobControllerTest do
  use PulseOpsWeb.ConnCase, async: true

  alias PulseOps.Fixtures

  test "rejects authenticated job endpoints without an API key", %{conn: conn} do
    conn = post(conn, "/api/v1/jobs", %{job: %{worker: "noop"}})
    assert %{"error" => %{"code" => "unauthorized"}} = json_response(conn, 401)
  end

  test "creates a job and deduplicates repeated idempotency keys", %{conn: conn} do
    %{bootstrap_api_key: token} = Fixtures.organization_fixture()
    conn = Fixtures.authenticate(conn, token)

    payload = %{
      job: %{
        queue_name: "default",
        worker: "noop",
        idempotency_key: "idemp-1000",
        payload: %{"step" => "dispatch"}
      }
    }

    conn = post(conn, "/api/v1/jobs", payload)

    assert %{"data" => %{"id" => job_id}, "meta" => %{"deduplicated" => false}} =
             json_response(conn, 201)

    conn = post(build_conn() |> Fixtures.authenticate(token), "/api/v1/jobs", payload)

    assert %{"data" => %{"id" => ^job_id}, "meta" => %{"deduplicated" => true}} =
             json_response(conn, 200)
  end

  test "returns validation errors for malformed job payloads", %{conn: conn} do
    %{bootstrap_api_key: token} = Fixtures.organization_fixture()

    conn =
      conn
      |> Fixtures.authenticate(token)
      |> post("/api/v1/jobs", %{job: %{queue_name: "default"}})

    assert %{
             "error" => %{
               "code" => "validation_error",
               "details" => %{"worker" => [_ | _]}
             }
           } = json_response(conn, 422)
  end

  test "lists and filters jobs for the current tenant", %{conn: conn} do
    tenant = Fixtures.organization_fixture()
    first_job = Fixtures.job_fixture(tenant.organization, %{"worker" => "noop"})
    second_job = Fixtures.job_fixture(tenant.organization, %{"worker" => "noop"})

    assert %{success: 2} = Oban.drain_queue(queue: "default")

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> get("/api/v1/jobs", %{status: "succeeded"})

    assert %{"data" => jobs} = json_response(conn, 200)
    returned_ids = Enum.map(jobs, & &1["id"])

    assert first_job.id in returned_ids
    assert second_job.id in returned_ids
    assert Enum.all?(jobs, &(&1["status"] == "succeeded"))
  end

  test "cancels queued jobs and retries dead-lettered jobs", %{conn: conn} do
    tenant = Fixtures.organization_fixture()
    queued_job = Fixtures.job_fixture(tenant.organization)

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> post("/api/v1/jobs/#{queued_job.id}/cancel")

    assert %{"data" => %{"id" => queued_job_id, "status" => "cancelled"}} =
             json_response(conn, 200)

    assert queued_job_id == queued_job.id

    retry_tenant = Fixtures.organization_fixture()

    dead_lettered_job =
      Fixtures.job_fixture(retry_tenant.organization, %{
        "worker" => "crash",
        "max_attempts" => 1,
        "payload" => %{}
      })

    assert %{discard: 1} = Oban.drain_queue(queue: "default")

    conn =
      build_conn()
      |> Fixtures.authenticate(retry_tenant.bootstrap_api_key)
      |> post("/api/v1/jobs/#{dead_lettered_job.id}/retry")

    assert %{"data" => %{"id" => retried_job_id, "status" => "queued"}} =
             json_response(conn, 200)

    assert retried_job_id == dead_lettered_job.id
  end

  test "hides jobs from other tenants", %{conn: conn} do
    first_tenant = Fixtures.organization_fixture()
    second_tenant = Fixtures.organization_fixture()
    job = Fixtures.job_fixture(first_tenant.organization)

    conn =
      conn
      |> Fixtures.authenticate(second_tenant.bootstrap_api_key)
      |> get("/api/v1/jobs/#{job.id}")

    assert %{"error" => %{"code" => "not_found"}} = json_response(conn, 404)
  end

  test "lists job events for the owning tenant", %{conn: conn} do
    tenant = Fixtures.organization_fixture()
    job = Fixtures.job_fixture(tenant.organization)

    assert %{success: 1} = Oban.drain_queue(queue: "default")

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> get("/api/v1/jobs/#{job.id}/events")

    assert %{"data" => events} = json_response(conn, 200)
    assert Enum.any?(events, &(&1["event_type"] == "job.succeeded"))
  end
end
