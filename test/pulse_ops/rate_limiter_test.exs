defmodule PulseOps.RateLimiterTest do
  use PulseOps.DataCase, async: false

  alias PulseOps.RateLimiter

  setup do
    previous = Application.get_env(:pulse_ops, :api_rate_limit)

    Application.put_env(:pulse_ops, :api_rate_limit, %{limit: 2, window_ms: 60_000, storage: :ets})

    RateLimiter.reset_local!()

    on_exit(fn ->
      Application.put_env(:pulse_ops, :api_rate_limit, previous)
      RateLimiter.reset_local!()
    end)

    :ok
  end

  test "honors the configured request budget" do
    assert {:ok, 1} = RateLimiter.allow?("api_key:test", 1_000)
    assert {:ok, 0} = RateLimiter.allow?("api_key:test", 1_000)

    assert {:error, %{remaining: 0, retry_after_ms: retry_after_ms}} =
             RateLimiter.allow?("api_key:test", 1_000)

    assert retry_after_ms > 0
  end

  test "can enforce the request budget with PostgreSQL-backed buckets" do
    Application.put_env(:pulse_ops, :api_rate_limit, %{
      limit: 2,
      window_ms: 60_000,
      storage: :postgres
    })

    assert {:ok, 1} = RateLimiter.allow?("api_key:distributed", 1_000)
    assert {:ok, 0} = RateLimiter.allow?("api_key:distributed", 1_000)

    assert {:error, %{remaining: 0, retry_after_ms: retry_after_ms}} =
             RateLimiter.allow?("api_key:distributed", 1_000)

    assert retry_after_ms == 59_000
  end

  test "cleans expired PostgreSQL buckets" do
    Application.put_env(:pulse_ops, :api_rate_limit, %{
      limit: 2,
      window_ms: 60_000,
      storage: :postgres
    })

    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.insert_all("rate_limit_buckets", [
      %{
        identifier: "api_key:expired",
        bucket: 1,
        count: 1,
        expires_at_ms: 999,
        inserted_at: now,
        updated_at: now
      }
    ])

    assert 1 = RateLimiter.cleanup_expired(1_000)
  end
end
