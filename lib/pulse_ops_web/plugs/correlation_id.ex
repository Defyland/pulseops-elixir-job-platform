defmodule PulseOpsWeb.Plugs.CorrelationId do
  @moduledoc false

  import Plug.Conn

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    correlation_id =
      conn
      |> get_req_header("x-correlation-id")
      |> List.first()
      |> case do
        nil -> get_resp_header(conn, "x-request-id") |> List.first() || Ecto.UUID.generate()
        value -> value
      end

    Logger.metadata(correlation_id: correlation_id)

    conn
    |> assign(:correlation_id, correlation_id)
    |> put_resp_header("x-correlation-id", correlation_id)
  end
end
