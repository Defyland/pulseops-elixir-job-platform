defmodule PulseOps.Jobs.RetentionPruner do
  @moduledoc false

  use GenServer

  require Logger

  alias PulseOps.Jobs

  @default_interval_ms 86_400_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    schedule_prune()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:prune, state) do
    %{jobs: jobs_count} = summary = Jobs.prune_expired_jobs()

    if jobs_count > 0 do
      Logger.info("pruned expired job history: #{inspect(summary)}")
    end

    schedule_prune()
    {:noreply, state}
  rescue
    error ->
      Logger.warning("job retention pruning failed: #{Exception.message(error)}")
      schedule_prune()
      {:noreply, state}
  end

  defp schedule_prune do
    Process.send_after(
      self(),
      :prune,
      Application.get_env(
        :pulse_ops,
        :job_retention_pruning_interval_ms,
        @default_interval_ms
      )
    )
  end
end
