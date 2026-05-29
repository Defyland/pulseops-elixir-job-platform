defmodule PulseOps.RateLimiterTest do
  use ExUnit.Case, async: false

  alias PulseOps.RateLimiter

  setup do
    previous = Application.get_env(:pulse_ops, :api_rate_limit)
    Application.put_env(:pulse_ops, :api_rate_limit, %{limit: 2, window_ms: 60_000})
    :ets.delete_all_objects(:pulse_ops_rate_limits)

    on_exit(fn ->
      Application.put_env(:pulse_ops, :api_rate_limit, previous)
      :ets.delete_all_objects(:pulse_ops_rate_limits)
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
end
