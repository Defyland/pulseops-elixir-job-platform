defmodule PulseOpsWeb.QueueControllerTest do
  use PulseOpsWeb.ConnCase, async: true

  alias PulseOps.Fixtures

  test "lists the default queue and allows queue updates", %{conn: conn} do
    tenant = Fixtures.organization_fixture()

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> get("/api/v1/queues")

    assert %{"data" => [%{"id" => queue_id, "name" => "default", "paused" => false}]} =
             json_response(conn, 200)

    paused_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    conn =
      build_conn()
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> patch("/api/v1/queues/#{queue_id}", %{
        queue: %{concurrency: 8, paused_at: paused_at}
      })

    assert %{
             "data" => %{
               "id" => ^queue_id,
               "concurrency" => 8,
               "paused" => true,
               "paused_at" => returned_paused_at
             }
           } = json_response(conn, 200)

    assert String.starts_with?(returned_paused_at, String.trim_trailing(paused_at, "Z"))
  end

  test "creates queues and rejects invalid names", %{conn: conn} do
    tenant = Fixtures.organization_fixture()

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> post("/api/v1/queues", %{
        queue: %{
          name: "critical_webhooks",
          concurrency: 6,
          max_attempts: 7,
          execution_timeout_ms: 45_000
        }
      })

    assert %{"data" => %{"name" => "critical_webhooks", "concurrency" => 6}} =
             json_response(conn, 201)

    conn =
      build_conn()
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> post("/api/v1/queues", %{
        queue: %{
          name: "Bad Queue",
          concurrency: 6,
          max_attempts: 7,
          execution_timeout_ms: 45_000
        }
      })

    assert %{
             "error" => %{
               "code" => "validation_error",
               "details" => %{"name" => [_ | _]}
             }
           } = json_response(conn, 422)
  end

  test "hides queues from other tenants", %{conn: conn} do
    first_tenant = Fixtures.organization_fixture()
    second_tenant = Fixtures.organization_fixture()
    queue = Fixtures.queue_fixture(first_tenant.organization)

    conn =
      conn
      |> Fixtures.authenticate(second_tenant.bootstrap_api_key)
      |> patch("/api/v1/queues/#{queue.id}", %{queue: %{concurrency: 9}})

    assert %{"error" => %{"code" => "not_found"}} = json_response(conn, 404)
  end

  test "enforces read and write scopes for queue endpoints", %{conn: conn} do
    tenant = Fixtures.organization_fixture()
    %{token: read_token} = Fixtures.api_key_fixture(tenant, %{"scopes" => ["queues:read"]})
    %{token: write_token} = Fixtures.api_key_fixture(tenant, %{"scopes" => ["queues:write"]})

    conn =
      conn
      |> Fixtures.authenticate(read_token)
      |> get("/api/v1/queues")

    assert %{"data" => [%{"name" => "default"}]} = json_response(conn, 200)

    conn =
      build_conn()
      |> Fixtures.authenticate(read_token)
      |> post("/api/v1/queues", %{
        queue: %{
          name: "blocked_queue",
          concurrency: 3,
          max_attempts: 4,
          execution_timeout_ms: 5_000
        }
      })

    assert %{
             "error" => %{
               "code" => "forbidden",
               "details" => %{"required_scope" => "queues:write"}
             }
           } = json_response(conn, 403)

    conn =
      build_conn()
      |> Fixtures.authenticate(write_token)
      |> post("/api/v1/queues", %{
        queue: %{
          name: "allowed_queue",
          concurrency: 3,
          max_attempts: 4,
          execution_timeout_ms: 5_000
        }
      })

    assert %{"data" => %{"name" => "allowed_queue"}} = json_response(conn, 201)

    conn =
      build_conn()
      |> Fixtures.authenticate(write_token)
      |> get("/api/v1/queues")

    assert %{
             "error" => %{
               "code" => "forbidden",
               "details" => %{"required_scope" => "queues:read"}
             }
           } = json_response(conn, 403)
  end
end
