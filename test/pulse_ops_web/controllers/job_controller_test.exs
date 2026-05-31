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

    assert %{success: 2} = Oban.drain_queue(queue: Fixtures.runtime_queue(first_job))

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

    assert %{discard: 1} = Oban.drain_queue(queue: Fixtures.runtime_queue(dead_lettered_job))

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

    assert %{success: 1} = Oban.drain_queue(queue: Fixtures.runtime_queue(job))

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> get("/api/v1/jobs/#{job.id}/events")

    assert %{"data" => events} = json_response(conn, 200)
    assert Enum.any?(events, &(&1["event_type"] == "job.succeeded"))
  end

  test "enforces read, write, and control scopes for job endpoints", %{conn: conn} do
    tenant = Fixtures.organization_fixture()
    job = Fixtures.job_fixture(tenant.organization)

    %{token: read_token} = Fixtures.api_key_fixture(tenant, %{"scopes" => ["jobs:read"]})
    %{token: write_token} = Fixtures.api_key_fixture(tenant, %{"scopes" => ["jobs:write"]})
    %{token: control_token} = Fixtures.api_key_fixture(tenant, %{"scopes" => ["jobs:control"]})

    conn =
      conn
      |> Fixtures.authenticate(read_token)
      |> get("/api/v1/jobs/#{job.id}")

    assert %{"data" => %{"id" => job_id}} = json_response(conn, 200)
    assert job_id == job.id

    conn =
      build_conn()
      |> Fixtures.authenticate(read_token)
      |> post("/api/v1/jobs", %{
        job: %{queue_name: "default", worker: "noop", payload: %{"blocked" => true}}
      })

    assert %{
             "error" => %{
               "code" => "forbidden",
               "details" => %{"required_scope" => "jobs:write"}
             }
           } = json_response(conn, 403)

    conn =
      build_conn()
      |> Fixtures.authenticate(write_token)
      |> post("/api/v1/jobs", %{
        job: %{queue_name: "default", worker: "noop", payload: %{"allowed" => true}}
      })

    assert %{"data" => %{"worker" => "noop"}} = json_response(conn, 201)

    conn =
      build_conn()
      |> Fixtures.authenticate(write_token)
      |> get("/api/v1/jobs/#{job.id}")

    assert %{
             "error" => %{
               "code" => "forbidden",
               "details" => %{"required_scope" => "jobs:read"}
             }
           } = json_response(conn, 403)

    conn =
      build_conn()
      |> Fixtures.authenticate(control_token)
      |> post("/api/v1/jobs/#{job.id}/cancel")

    assert %{"data" => %{"id" => ^job_id, "status" => "cancelled"}} = json_response(conn, 200)

    conn =
      build_conn()
      |> Fixtures.authenticate(write_token)
      |> post("/api/v1/jobs/#{job.id}/retry")

    assert %{
             "error" => %{
               "code" => "forbidden",
               "details" => %{"required_scope" => "jobs:control"}
             }
           } = json_response(conn, 403)
  end
end
