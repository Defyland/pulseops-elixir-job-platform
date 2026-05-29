defmodule PulseOps.RateLimiter do
  @moduledoc false

  use GenServer

  import Ecto.Query, warn: false

  alias PulseOps.Repo

  @table :pulse_ops_rate_limits
  @default_config %{limit: 240, window_ms: 60_000, storage: :ets}
  @cleanup_interval_ms 60_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allow?(identifier, now_ms \\ System.system_time(:millisecond)) do
    %{limit: limit, window_ms: window_ms, storage: storage} = config()
    bucket = div(now_ms, window_ms)
    expires_at = (bucket + 1) * window_ms

    case storage do
      :postgres -> allow_postgres(identifier, bucket, limit, expires_at, now_ms)
      :ets -> allow_ets(identifier, bucket, limit, expires_at, now_ms)
    end
  end

  def cleanup_expired(now_ms \\ System.system_time(:millisecond)) do
    cleanup_ets(now_ms)

    if config().storage == :postgres do
      cleanup_postgres(now_ms)
    else
      0
    end
  end

  def reset_local! do
    ensure_table!()
    :ets.delete_all_objects(@table)
  end

  @impl true
  def init(state) do
    ensure_table!()
    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  defp allow_ets(identifier, bucket, limit, expires_at, now_ms) do
    key = {identifier, bucket}

    ensure_table!()
    count = :ets.update_counter(@table, key, {2, 1}, {key, 0, expires_at})

    limit_result(count, limit, expires_at, now_ms)
  end

  defp allow_postgres(identifier, bucket, limit, expires_at, now_ms) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {_count, rows} =
      Repo.insert_all(
        "rate_limit_buckets",
        [
          %{
            identifier: identifier,
            bucket: bucket,
            count: 1,
            expires_at_ms: expires_at,
            inserted_at: now,
            updated_at: now
          }
        ],
        on_conflict: [inc: [count: 1], set: [expires_at_ms: expires_at, updated_at: now]],
        conflict_target: [:identifier, :bucket],
        returning: [:count]
      )

    rows
    |> returned_count()
    |> limit_result(limit, expires_at, now_ms)
  end

  defp cleanup_ets(now_ms) do
    ensure_table!()
    :ets.select_delete(@table, [{{:"$1", :"$2", :"$3"}, [{:<, :"$3", now_ms}], [true]}])
  end

  defp cleanup_postgres(now_ms) do
    {deleted, _} =
      from(bucket in "rate_limit_buckets", where: field(bucket, :expires_at_ms) < ^now_ms)
      |> Repo.delete_all()

    deleted
  end

  defp limit_result(count, limit, _expires_at, _now_ms) when count <= limit do
    {:ok, limit - count}
  end

  defp limit_result(_count, _limit, expires_at, now_ms) do
    {:error, %{retry_after_ms: max(expires_at - now_ms, 0), remaining: 0}}
  end

  defp returned_count([%{count: count}]), do: count
  defp returned_count([[count: count]]), do: count

  defp returned_count(rows) do
    raise "unexpected rate limit insert_all returning payload: #{inspect(rows)}"
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _table ->
        @table
    end
  rescue
    ArgumentError -> @table
  end

  defp config do
    raw = Application.get_env(:pulse_ops, :api_rate_limit, %{})

    %{
      limit: integer_config(raw, :limit),
      window_ms: integer_config(raw, :window_ms),
      storage: storage_config(raw)
    }
  end

  defp integer_config(raw, key) do
    value =
      Map.get(raw, key) || Map.get(raw, Atom.to_string(key)) || Map.fetch!(@default_config, key)

    if is_binary(value), do: String.to_integer(value), else: value
  end

  defp storage_config(raw) do
    raw
    |> Map.get(:storage, Map.get(raw, "storage", Map.fetch!(@default_config, :storage)))
    |> case do
      value when value in [:postgres, "postgres", "pg"] -> :postgres
      _ -> :ets
    end
  end
end
