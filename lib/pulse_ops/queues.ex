defmodule PulseOps.Queues do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PulseOps.Identity.Organization
  alias PulseOps.Queues.{Provisioner, Queue}
  alias PulseOps.Repo

  def list_queues(%Organization{id: organization_id}) do
    Queue
    |> where([queue], queue.organization_id == ^organization_id)
    |> order_by([queue], asc: queue.inserted_at)
    |> Repo.all()
  end

  def list_runtime_queues do
    Queue
    |> order_by([queue], asc: queue.inserted_at)
    |> Repo.all()
  end

  def get_queue(%Organization{id: organization_id}, id) do
    case Repo.get_by(Queue, id: id, organization_id: organization_id) do
      nil -> {:error, :not_found}
      queue -> {:ok, queue}
    end
  end

  def find_queue(%Organization{id: organization_id}, attrs) do
    queue_name = Map.get(attrs, "queue_name") || Map.get(attrs, :queue_name)
    queue_id = Map.get(attrs, "queue_id") || Map.get(attrs, :queue_id)

    cond do
      is_binary(queue_id) ->
        Repo.get_by(Queue, id: queue_id, organization_id: organization_id)

      is_binary(queue_name) ->
        Repo.get_by(Queue, name: queue_name, organization_id: organization_id)

      true ->
        Repo.get_by(Queue, name: "default", organization_id: organization_id)
    end
  end

  def create_queue(%Organization{} = organization, attrs) do
    attrs = Map.put(attrs, "organization_id", organization.id)

    with {:ok, queue} <- %Queue{} |> Queue.changeset(attrs) |> Repo.insert() do
      :ok = Provisioner.sync_queue(queue)
      {:ok, queue}
    end
  end

  def update_queue(%Organization{} = organization, queue_id, attrs) do
    with {:ok, queue} <- get_queue(organization, queue_id),
         {:ok, updated_queue} <- queue |> Queue.changeset(attrs) |> Repo.update() do
      :ok = Provisioner.sync_queue(updated_queue)
      {:ok, updated_queue}
    end
  end
end
