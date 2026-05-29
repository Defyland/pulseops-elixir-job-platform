defmodule PulseOps.Jobs.StateMachineTest do
  use ExUnit.Case, async: true

  alias PulseOps.Jobs.StateMachine

  test "allows queued jobs to start and then succeed" do
    assert {:ok, "running"} = StateMachine.transition("queued", :start)
    assert {:ok, "succeeded"} = StateMachine.transition("running", :succeed)
  end

  test "allows dead-lettered jobs to re-enter the queue" do
    assert {:ok, "queued"} = StateMachine.transition("dead_lettered", :retry)
  end

  test "rejects invalid transitions" do
    assert :error = StateMachine.transition("succeeded", :retry)
    assert :error = StateMachine.transition("cancelled", :start)
  end
end
