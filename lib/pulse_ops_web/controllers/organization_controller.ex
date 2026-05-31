defmodule PulseOpsWeb.OrganizationController do
  use PulseOpsWeb, :controller

  alias PulseOps.Identity
  alias PulseOpsWeb.Payloads

  action_fallback PulseOpsWeb.FallbackController

  plug PulseOpsWeb.Plugs.ApiScopeAuth, [scope: "organizations:read"] when action in [:show]

  def create(conn, %{"organization" => organization_params}) do
    with {:ok, result} <- Identity.register_organization(organization_params) do
      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          organization: Payloads.organization(result.organization),
          default_queue: Payloads.queue(result.default_queue),
          bootstrap_api_key: result.bootstrap_api_key
        }
      })
    end
  end

  def show(conn, _params) do
    json(conn, %{data: Payloads.organization(conn.assigns.current_organization)})
  end
end
