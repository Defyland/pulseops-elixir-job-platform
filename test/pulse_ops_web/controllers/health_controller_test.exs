defmodule PulseOpsWeb.HealthControllerTest do
  use PulseOpsWeb.ConnCase, async: false

  setup do
    previous = Application.get_env(:pulse_ops, :api_rate_limit)
    Application.put_env(:pulse_ops, :api_rate_limit, %{limit: 240, window_ms: 60_000})
    :ets.delete_all_objects(:pulse_ops_rate_limits)

    on_exit(fn ->
      Application.put_env(:pulse_ops, :api_rate_limit, previous)
      :ets.delete_all_objects(:pulse_ops_rate_limits)
    end)

    :ok
  end

  test "returns liveness and readiness responses with correlation ids", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-correlation-id", "corr-health-check")
      |> get("/healthz")

    assert %{"status" => "ok"} = json_response(conn, 200)
    assert get_resp_header(conn, "x-correlation-id") == ["corr-health-check"]

    conn = build_conn() |> get("/readyz")
    assert %{"status" => "ready"} = json_response(conn, 200)
  end

  test "serves prometheus metrics without authentication", %{conn: conn} do
    conn = get(conn, "/metrics")

    assert response(conn, 200) =~ "# TYPE"
    assert [content_type | _] = get_resp_header(conn, "content-type")
    assert String.starts_with?(content_type, "text/plain")
  end

  test "returns a structured 429 response when the rate limit is exceeded", %{conn: conn} do
    Application.put_env(:pulse_ops, :api_rate_limit, %{limit: 1, window_ms: 60_000})
    :ets.delete_all_objects(:pulse_ops_rate_limits)

    conn = get(conn, "/healthz")
    assert %{"status" => "ok"} = json_response(conn, 200)

    conn =
      build_conn()
      |> put_req_header("x-correlation-id", "corr-rate-limit")
      |> get("/healthz")

    assert %{
             "error" => %{
               "code" => "rate_limited",
               "details" => %{"retry_after_ms" => retry_after_ms},
               "request_id" => request_id,
               "correlation_id" => "corr-rate-limit"
             }
           } = json_response(conn, 429)

    assert is_integer(retry_after_ms)
    assert is_binary(request_id)
    assert get_resp_header(conn, "retry-after") != []
  end
end
