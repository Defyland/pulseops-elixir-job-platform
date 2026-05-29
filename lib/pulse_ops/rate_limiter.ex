defmodule PulseOps.RateLimiter do
  @moduledoc false

  use GenServer

  @table :pulse_ops_rate_limits

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allow?(identifier, now_ms \\ System.system_time(:millisecond)) do
    %{limit: limit, window_ms: window_ms} = config()
    bucket = div(now_ms, window_ms)
    expires_at = (bucket + 1) * window_ms
    key = {identifier, bucket}

    count = :ets.update_counter(@table, key, {2, 1}, {key, 0, expires_at})

    if count <= limit do
      {:ok, limit - count}
    else
      {:error, %{retry_after_ms: expires_at - now_ms, remaining: 0}}
    end
  end

  @impl true
  def init(state) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now_ms = System.system_time(:millisecond)

    :ets.select_delete(@table, [{{:"$1", :"$2", :"$3"}, [{:<, :"$3", now_ms}], [true]}])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 60_000)
  end

  defp config do
    Application.get_env(:pulse_ops, :api_rate_limit, %{limit: 240, window_ms: 60_000})
  end
end
