defmodule PulseOps.Jobs.StateMachine do
  @moduledoc false

  @transitions %{
    "queued" => %{start: "running", cancel: "cancelled"},
    "running" => %{
      succeed: "succeeded",
      fail: "retryable",
      discard: "dead_lettered",
      cancel: "cancelled"
    },
    "retryable" => %{
      retry: "queued",
      start: "running",
      discard: "dead_lettered",
      cancel: "cancelled"
    },
    "dead_lettered" => %{retry: "queued"},
    "cancelled" => %{},
    "succeeded" => %{}
  }

  def transition(current_status, action) when is_atom(action) do
    @transitions
    |> Map.get(current_status, %{})
    |> Map.fetch(action)
  end
end
