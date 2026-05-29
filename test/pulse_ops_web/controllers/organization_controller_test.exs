defmodule PulseOpsWeb.OrganizationControllerTest do
  use PulseOpsWeb.ConnCase, async: true

  alias PulseOps.Fixtures

  test "POST /api/v1/organizations creates a tenant and returns a bootstrap key", %{conn: conn} do
    conn =
      post(conn, "/api/v1/organizations", %{
        organization: %{
          name: "Northwind Ops",
          slug: "northwind-ops",
          retention_days: 21
        }
      })

    assert %{
             "data" => %{
               "organization" => %{"slug" => "northwind-ops"},
               "default_queue" => %{"name" => "default"},
               "bootstrap_api_key" => bootstrap_api_key
             }
           } = json_response(conn, 201)

    assert is_binary(bootstrap_api_key)
    assert String.starts_with?(bootstrap_api_key, "po_live_")
  end

  test "GET /api/v1/organizations/me resolves the current tenant", %{conn: conn} do
    tenant = Fixtures.organization_fixture()

    conn =
      conn
      |> Fixtures.authenticate(tenant.bootstrap_api_key)
      |> get("/api/v1/organizations/me")

    assert %{"data" => %{"id" => id, "slug" => slug}} = json_response(conn, 200)
    assert id == tenant.organization.id
    assert slug == tenant.organization.slug
  end
end
