defmodule PulseOpsWeb.Plugs.ApiRateLimit do
  @moduledoc false

  import Plug.Conn

  alias PulseOps.RateLimiter
  alias PulseOpsWeb.ErrorResponse

  def init(opts), do: opts

  def call(conn, _opts) do
    identifier =
      case conn.assigns[:current_api_key] do
        %{id: api_key_id} -> "api_key:#{api_key_id}"
        _ -> "ip:#{remote_ip(conn)}"
      end

    case RateLimiter.allow?(identifier) do
      {:ok, remaining} ->
        put_resp_header(conn, "x-ratelimit-remaining", Integer.to_string(remaining))

      {:error, %{retry_after_ms: retry_after_ms}} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(max(div(retry_after_ms, 1000), 1)))
        |> ErrorResponse.send(429, "rate_limited", "Too many requests", %{
          retry_after_ms: retry_after_ms
        })
    end
  end

  defp remote_ip(conn) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  end
end
