defmodule PulseOpsWeb.ApiKeyController do
  use PulseOpsWeb, :controller

  alias PulseOps.Identity
  alias PulseOpsWeb.Payloads

  action_fallback PulseOpsWeb.FallbackController

  def index(conn, _params) do
    api_keys = Identity.list_api_keys(conn.assigns.current_organization)
    json(conn, %{data: Enum.map(api_keys, &Payloads.api_key/1)})
  end

  def create(conn, %{"api_key" => api_key_params}) do
    with {:ok, %{api_key: api_key, token: token}} <-
           Identity.issue_api_key(conn.assigns.current_organization, api_key_params) do
      conn
      |> put_status(:created)
      |> json(%{data: %{api_key: Payloads.api_key(api_key), token: token}})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, _api_key} <- Identity.revoke_api_key(conn.assigns.current_organization, id) do
      send_resp(conn, :no_content, "")
    end
  end
end
