defmodule PulseOpsWeb.ApiKeyControllerTest do
  use PulseOpsWeb.ConnCase, async: true

  alias PulseOps.Fixtures

  test "lists, creates, and revokes API keys for the current tenant", %{conn: conn} do
    tenant = Fixtures.organization_fixture()

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> get("/api/v1/api-keys")

    assert %{"data" => [%{"name" => "bootstrap", "scopes" => ["*"]}]} =
             json_response(conn, 200)

    conn =
      build_conn()
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> post("/api/v1/api-keys", %{
        api_key: %{name: "ci-runner", scopes: ["jobs:read", "jobs:write"]}
      })

    assert %{
             "data" => %{
               "api_key" => %{
                 "id" => api_key_id,
                 "name" => "ci-runner",
                 "scopes" => ["jobs:read", "jobs:write"]
               },
               "token" => token
             }
           } = json_response(conn, 201)

    assert String.starts_with?(token, "po_live_")

    conn =
      build_conn()
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> delete("/api/v1/api-keys/#{api_key_id}")

    response(conn, 204)
  end

  test "hides API keys from other tenants", %{} do
    first_tenant = Fixtures.organization_fixture()
    second_tenant = Fixtures.organization_fixture()

    conn =
      build_conn()
      |> Fixtures.authenticate(first_tenant.bootstrap_api_key)
      |> post("/api/v1/api-keys", %{api_key: %{name: "ops-rotation"}})

    assert %{"data" => %{"api_key" => %{"id" => api_key_id}}} = json_response(conn, 201)

    conn =
      conn
      |> recycle()
      |> Fixtures.authenticate(second_tenant.bootstrap_api_key)
      |> delete("/api/v1/api-keys/#{api_key_id}")

    assert %{"error" => %{"code" => "not_found"}} = json_response(conn, 404)
  end

  test "returns validation errors for invalid API key payloads", %{conn: conn} do
    tenant = Fixtures.organization_fixture()

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> post("/api/v1/api-keys", %{api_key: %{name: "x"}})

    assert %{
             "error" => %{
               "code" => "validation_error",
               "details" => %{"name" => [_ | _]}
             }
           } = json_response(conn, 422)
  end

  test "enforces read and write scopes for API key management", %{conn: conn} do
    tenant = Fixtures.organization_fixture()
    %{token: read_token} = Fixtures.api_key_fixture(tenant, %{"scopes" => ["api_keys:read"]})
    %{token: write_token} = Fixtures.api_key_fixture(tenant, %{"scopes" => ["api_keys:write"]})

    conn =
      conn
      |> Fixtures.authenticate(read_token)
      |> get("/api/v1/api-keys")

    assert %{"data" => [_ | _]} = json_response(conn, 200)

    conn =
      build_conn()
      |> Fixtures.authenticate(read_token)
      |> post("/api/v1/api-keys", %{api_key: %{name: "blocked-writer"}})

    assert %{
             "error" => %{
               "code" => "forbidden",
               "details" => %{"required_scope" => "api_keys:write"}
             }
           } = json_response(conn, 403)

    conn =
      build_conn()
      |> Fixtures.authenticate(write_token)
      |> post("/api/v1/api-keys", %{api_key: %{name: "allowed-writer"}})

    assert %{"data" => %{"api_key" => %{"name" => "allowed-writer"}}} =
             json_response(conn, 201)

    conn =
      build_conn()
      |> Fixtures.authenticate(write_token)
      |> get("/api/v1/api-keys")

    assert %{
             "error" => %{
               "code" => "forbidden",
               "details" => %{"required_scope" => "api_keys:read"}
             }
           } = json_response(conn, 403)
  end
end
