defmodule PulseOpsWeb.MetricsController do
  use PulseOpsWeb, :controller

  alias PulseOpsWeb.ErrorResponse

  def index(conn, _params) do
    if authorized?(conn) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, TelemetryMetricsPrometheus.Core.scrape())
    else
      ErrorResponse.send(conn, 401, "unauthorized", "A valid metrics bearer token is required")
    end
  end

  defp authorized?(conn) do
    case metrics_token() do
      nil ->
        true

      token ->
        conn
        |> get_req_header("authorization")
        |> List.first()
        |> valid_bearer_token?(token)
    end
  end

  defp metrics_token do
    :pulse_ops
    |> Application.get_env(:metrics_auth, %{})
    |> Map.get(:bearer_token)
    |> blank_to_nil()
  end

  defp valid_bearer_token?("Bearer " <> supplied, token) do
    byte_size(supplied) == byte_size(token) and Plug.Crypto.secure_compare(supplied, token)
  end

  defp valid_bearer_token?(_header, _token), do: false

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
