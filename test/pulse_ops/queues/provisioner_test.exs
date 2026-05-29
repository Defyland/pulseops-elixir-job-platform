defmodule PulseOps.Queues.ProvisionerTest do
  use PulseOps.DataCase, async: false

  alias PulseOps.Fixtures
  alias PulseOps.Queues.Provisioner

  setup do
    original_oban_config = Application.get_env(:pulse_ops, Oban, [])
    Application.put_env(:pulse_ops, Oban, Keyword.put(original_oban_config, :testing, :inline))

    on_exit(fn ->
      Application.put_env(:pulse_ops, Oban, original_oban_config)

      if pid = Process.whereis(Provisioner) do
        GenServer.stop(pid)
      end
    end)

    :ok
  end

  test "sync_queue works when the provisioner is running" do
    %{organization: organization} = Fixtures.organization_fixture()
    queue = Fixtures.queue_fixture(organization)
    start_supervised!(Provisioner)

    assert :ok = Provisioner.sync_queue(queue)
  end
end
