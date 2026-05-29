defmodule PulseOpsWeb.ErrorResponse do
  @moduledoc false

  import Plug.Conn

  def send(conn, status, code, message, details \\ %{}) do
    body = %{
      error: %{
        code: code,
        message: message,
        details: details,
        request_id: List.first(get_resp_header(conn, "x-request-id")),
        correlation_id: conn.assigns[:correlation_id]
      }
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
    |> halt()
  end
end
