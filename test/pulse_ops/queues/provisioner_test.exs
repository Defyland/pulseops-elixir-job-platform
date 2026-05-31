defmodule PulseOps.Queues.ProvisionerTest do
  use PulseOps.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias PulseOps.Fixtures
  alias PulseOps.Queues.Provisioner
  alias PulseOps.Queues.Queue

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

  test "scheduled resync provisions queues that were created without direct sync" do
    %{organization: organization} = Fixtures.organization_fixture()
    pid = start_supervised!(Provisioner)
    Sandbox.allow(Repo, self(), pid)

    queue =
      %Queue{}
      |> Queue.changeset(%{
        "organization_id" => organization.id,
        "name" => "direct_sync",
        "concurrency" => 2,
        "max_attempts" => 4,
        "execution_timeout_ms" => 5_000
      })
      |> Repo.insert!()

    runtime_queue = Queue.runtime_name(queue)

    send(pid, :sync_all)
    state = :sys.get_state(pid)

    assert runtime_queue in state.last_runtime_queues
    assert state.last_sync_count >= 1
    assert %DateTime{} = state.last_synced_at
  end
end
