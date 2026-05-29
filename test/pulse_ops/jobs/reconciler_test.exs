defmodule PulseOps.Jobs.ReconcilerTest do
  use PulseOps.DataCase, async: false

  alias PulseOps.Jobs.Reconciler

  setup do
    original_interval = Application.get_env(:pulse_ops, :job_reconciliation_interval_ms)
    Application.put_env(:pulse_ops, :job_reconciliation_interval_ms, 60_000)

    on_exit(fn ->
      if is_nil(original_interval) do
        Application.delete_env(:pulse_ops, :job_reconciliation_interval_ms)
      else
        Application.put_env(:pulse_ops, :job_reconciliation_interval_ms, original_interval)
      end
    end)

    :ok
  end

  test "runs reconciliation without crashing when there are no terminal state drifts" do
    pid = start_supervised!(Reconciler)

    send(pid, :reconcile)

    assert :sys.get_state(pid) == %{}
    assert Process.alive?(pid)
  end
end
