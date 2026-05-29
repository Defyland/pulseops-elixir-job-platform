defmodule PulseOps.Jobs.Reconciler do
  @moduledoc false

  use GenServer

  require Logger

  alias PulseOps.Jobs

  @default_interval_ms 5_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    schedule_reconcile()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:reconcile, state) do
    reconciled = Jobs.reconcile_terminal_jobs()

    if reconciled > 0 do
      Logger.warning("reconciled #{reconciled} platform jobs from terminal oban states")
    end

    schedule_reconcile()
    {:noreply, state}
  rescue
    error ->
      Logger.warning("job reconciliation failed: #{Exception.message(error)}")
      schedule_reconcile()
      {:noreply, state}
  end

  defp schedule_reconcile do
    Process.send_after(
      self(),
      :reconcile,
      Application.get_env(:pulse_ops, :job_reconciliation_interval_ms, @default_interval_ms)
    )
  end
end
