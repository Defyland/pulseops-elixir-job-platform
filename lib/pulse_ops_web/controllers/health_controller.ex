defmodule PulseOpsWeb.HealthController do
  use PulseOpsWeb, :controller

  alias PulseOps.Repo

  def health(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def readiness(conn, _params) do
    case Repo.query("SELECT 1") do
      {:ok, _result} ->
        json(conn, %{status: "ready"})

      {:error, _error} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "degraded"})
    end
  end
end
