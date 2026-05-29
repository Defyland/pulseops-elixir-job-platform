defmodule PulseOps.Jobs.WebhookCircuitBreaker do
  @moduledoc false

  use GenServer

  @table :pulse_ops_webhook_circuit_breakers
  @default_config %{failure_threshold: 5, reset_after_ms: 60_000}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def allow?(host, now_ms \\ System.monotonic_time(:millisecond)) do
    host = normalize_host(host)

    case :ets.lookup(table!(), host) do
      [{^host, :open, _failure_count, opened_at_ms}] ->
        maybe_allow_open_circuit(host, opened_at_ms, now_ms)

      _ ->
        :ok
    end
  end

  def record_success(host) do
    :ets.delete(table!(), normalize_host(host))
    :ok
  end

  def record_failure(host, now_ms \\ System.monotonic_time(:millisecond)) do
    host = normalize_host(host)
    failure_count = current_failure_count(host) + 1

    state =
      if failure_count >= circuit_config().failure_threshold do
        :open
      else
        :closed
      end

    :ets.insert(table!(), {host, state, failure_count, now_ms})
    :ok
  end

  def reset! do
    :ets.delete_all_objects(table!())
    :ok
  end

  @impl GenServer
  def init(state) do
    table!()
    {:ok, state}
  end

  defp maybe_allow_open_circuit(host, opened_at_ms, now_ms) do
    retry_after_ms = circuit_config().reset_after_ms - (now_ms - opened_at_ms)

    if retry_after_ms <= 0 do
      :ets.insert(table!(), {host, :half_open, 0, opened_at_ms})
      :ok
    else
      {:error, {:circuit_open, "webhook circuit open for #{host}", retry_after_ms}}
    end
  end

  defp current_failure_count(host) do
    case :ets.lookup(table!(), host) do
      [{^host, :closed, failure_count, _opened_at_ms}] -> failure_count
      [{^host, :half_open, failure_count, _opened_at_ms}] -> failure_count
      [{^host, :open, failure_count, _opened_at_ms}] -> failure_count
      [] -> 0
    end
  end

  defp circuit_config do
    security_config =
      Application.get_env(:pulse_ops, :webhook_security, %{})
      |> Map.get(:circuit_breaker, %{})

    %{
      failure_threshold:
        integer_config(
          security_config,
          :failure_threshold,
          Map.fetch!(@default_config, :failure_threshold)
        ),
      reset_after_ms:
        integer_config(
          security_config,
          :reset_after_ms,
          Map.fetch!(@default_config, :reset_after_ms)
        )
    }
  end

  defp integer_config(config, key, default) do
    value = Map.get(config, key) || Map.get(config, Atom.to_string(key)) || default

    if is_binary(value), do: String.to_integer(value), else: value
  end

  defp normalize_host(host) do
    host
    |> to_string()
    |> String.downcase()
  end

  defp table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _table ->
        @table
    end
  rescue
    ArgumentError -> @table
  end
end
