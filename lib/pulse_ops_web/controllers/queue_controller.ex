defmodule PulseOpsWeb.QueueController do
  use PulseOpsWeb, :controller

  alias PulseOps.Queues
  alias PulseOpsWeb.Payloads

  action_fallback PulseOpsWeb.FallbackController

  plug PulseOpsWeb.Plugs.ApiScopeAuth, [scope: "queues:read"] when action in [:index]
  plug PulseOpsWeb.Plugs.ApiScopeAuth, [scope: "queues:write"] when action in [:create, :update]

  def index(conn, _params) do
    queues = Queues.list_queues(conn.assigns.current_organization)
    json(conn, %{data: Enum.map(queues, &Payloads.queue/1)})
  end

  def create(conn, %{"queue" => queue_params}) do
    with {:ok, queue} <- Queues.create_queue(conn.assigns.current_organization, queue_params) do
      conn
      |> put_status(:created)
      |> json(%{data: Payloads.queue(queue)})
    end
  end

  def update(conn, %{"id" => id, "queue" => queue_params}) do
    with {:ok, queue} <- Queues.update_queue(conn.assigns.current_organization, id, queue_params) do
      json(conn, %{data: Payloads.queue(queue)})
    end
  end
end
