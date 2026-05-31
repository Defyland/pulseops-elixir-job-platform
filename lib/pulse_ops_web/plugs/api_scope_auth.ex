defmodule PulseOpsWeb.Plugs.ApiScopeAuth do
  @moduledoc false

  alias PulseOps.Identity.ApiKey
  alias PulseOpsWeb.ErrorResponse

  def init(opts) do
    scope = Keyword.fetch!(opts, :scope)

    if scope in ApiKey.allowed_scopes() and scope != "*" do
      scope
    else
      raise ArgumentError, "unsupported API key scope: #{inspect(scope)}"
    end
  end

  def call(%Plug.Conn{assigns: %{current_api_key: api_key}} = conn, required_scope) do
    if ApiKey.has_scope?(api_key, required_scope) do
      conn
    else
      forbidden(conn, required_scope)
    end
  end

  def call(conn, required_scope), do: forbidden(conn, required_scope)

  defp forbidden(conn, required_scope) do
    ErrorResponse.send(
      conn,
      403,
      "forbidden",
      "API key scope is not allowed for this endpoint",
      %{required_scope: required_scope}
    )
  end
end
