defmodule PulseOps.Jobs.RetentionPrunerTest do
  use PulseOps.DataCase, async: false

  use Oban.Testing, repo: PulseOps.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias PulseOps.Fixtures
  alias PulseOps.Jobs
  alias PulseOps.Jobs.{Job, JobAttempt, JobEvent, RetentionPruner}

  test "prunes terminal job history after the organization retention window" do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    terminal_at = DateTime.add(now, -2 * 24 * 60 * 60, :second)
    %{organization: organization} = Fixtures.organization_fixture(%{"retention_days" => 1})
    job = Fixtures.job_fixture(organization)

    assert %{success: 1} = Oban.drain_queue(queue: "default")
    expire_terminal_job(job, terminal_at)

    assert %{jobs: 1, attempts: 1, events: events_count} = Jobs.prune_expired_jobs(now)
    assert events_count >= 2
    refute Repo.get(Job, job.id)

    assert Repo.aggregate(from(attempt in JobAttempt, where: attempt.job_id == ^job.id), :count) ==
             0

    assert Repo.aggregate(from(event in JobEvent, where: event.job_id == ^job.id), :count) == 0
  end

  test "keeps active jobs even when they are older than the retention window" do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    inserted_at = DateTime.add(now, -10 * 24 * 60 * 60, :second)
    %{organization: organization} = Fixtures.organization_fixture(%{"retention_days" => 1})
    job = Fixtures.job_fixture(organization)

    from(job in Job, where: job.id == ^job.id)
    |> Repo.update_all(set: [inserted_at: inserted_at, updated_at: inserted_at])

    assert %{jobs: 0} = Jobs.prune_expired_jobs(now)
    assert %Job{status: "queued"} = Repo.get(Job, job.id)
  end

  test "honors different retention windows per tenant" do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    terminal_at = DateTime.add(now, -2 * 24 * 60 * 60, :second)
    %{organization: short_retention} = Fixtures.organization_fixture(%{"retention_days" => 1})
    %{organization: long_retention} = Fixtures.organization_fixture(%{"retention_days" => 7})
    short_job = Fixtures.job_fixture(short_retention)
    long_job = Fixtures.job_fixture(long_retention)

    assert %{success: 2} = Oban.drain_queue(queue: "default")
    expire_terminal_job(short_job, terminal_at)
    expire_terminal_job(long_job, terminal_at)

    assert %{jobs: 1} = Jobs.prune_expired_jobs(now)
    refute Repo.get(Job, short_job.id)
    assert %Job{} = Repo.get(Job, long_job.id)
  end

  test "scheduled pruner delegates to retention deletion" do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    terminal_at = DateTime.add(now, -2 * 24 * 60 * 60, :second)
    %{organization: organization} = Fixtures.organization_fixture(%{"retention_days" => 1})
    job = Fixtures.job_fixture(organization)

    assert %{success: 1} = Oban.drain_queue(queue: "default")
    expire_terminal_job(job, terminal_at)

    pid = start_supervised!(RetentionPruner)
    Sandbox.allow(Repo, self(), pid)
    send(pid, :prune)

    assert_eventually(fn -> Repo.get(Job, job.id) == nil end)
  end

  defp expire_terminal_job(%Job{} = job, terminal_at) do
    from(job in Job, where: job.id == ^job.id)
    |> Repo.update_all(
      set: [
        status: "succeeded",
        completed_at: terminal_at,
        inserted_at: terminal_at,
        updated_at: terminal_at
      ]
    )
  end

  defp assert_eventually(fun) do
    assert Enum.any?(1..20, fn _attempt ->
             if fun.() do
               true
             else
               Process.sleep(10)
               false
             end
           end)
  end
end
