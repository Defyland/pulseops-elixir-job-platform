defmodule PulseOpsWeb.Plugs.ApiKeyAuth do
  @moduledoc false

  import Plug.Conn

  require Logger

  alias PulseOps.Identity
  alias PulseOpsWeb.ErrorResponse

  def init(opts), do: opts

  def call(conn, _opts) do
    with [token | _] <- get_req_header(conn, "x-api-key"),
         {:ok, organization, api_key} <- Identity.authenticate_api_key(token) do
      Logger.metadata(organization_id: organization.id)

      conn
      |> assign(:current_organization, organization)
      |> assign(:current_api_key, api_key)
    else
      _ ->
        ErrorResponse.send(conn, 401, "unauthorized", "A valid x-api-key header is required")
    end
  end
end
