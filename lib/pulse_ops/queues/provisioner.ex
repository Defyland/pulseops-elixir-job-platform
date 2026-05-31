defmodule PulseOps.Queues.Provisioner do
  @moduledoc false

  use GenServer

  require Logger

  alias PulseOps.Queues
  alias PulseOps.Queues.Queue

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def sync_queue(%Queue{} = queue) do
    if testing_manual?() or is_nil(Process.whereis(__MODULE__)) do
      :ok
    else
      GenServer.call(__MODULE__, {:sync, queue})
    end
  end

  @impl true
  def init(state) do
    send(self(), :bootstrap)
    {:ok, state}
  end

  @impl true
  def handle_info(:bootstrap, state) do
    unless testing_manual?() do
      try do
        Queues.list_runtime_queues()
        |> Enum.each(&ensure_queue/1)
      rescue
        error ->
          Logger.warning("queue bootstrap skipped: #{Exception.message(error)}")
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:sync, queue}, _from, state) do
    reply = if testing_manual?(), do: :ok, else: ensure_queue(queue)
    {:reply, reply, state}
  end

  defp ensure_queue(%Queue{} = queue) do
    name = Queue.runtime_name(queue)
    paused? = Queue.paused?(queue)

    _ =
      Oban.start_queue(
        queue: name,
        limit: queue.concurrency,
        local_only: true,
        paused: paused?
      )

    _ = maybe_scale_queue(name, queue.concurrency)

    if paused? do
      _ = maybe_pause_queue(name)
    else
      _ = maybe_resume_queue(name)
    end

    :ok
  end

  defp maybe_scale_queue(name, concurrency) do
    Oban.scale_queue(queue: name, limit: concurrency, local_only: true)
  rescue
    ArgumentError -> :ok
  end

  defp maybe_pause_queue(name) do
    Oban.pause_queue(queue: name, local_only: true)
  rescue
    ArgumentError -> :ok
  end

  defp maybe_resume_queue(name) do
    Oban.resume_queue(queue: name, local_only: true)
  rescue
    ArgumentError -> :ok
  end

  defp testing_manual? do
    Application.get_env(:pulse_ops, Oban, [])[:testing] == :manual
  end
end
