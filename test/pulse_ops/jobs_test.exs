defmodule PulseOps.JobsTest do
  use PulseOps.DataCase, async: false

  alias PulseOps.Fixtures
  alias PulseOps.Jobs
  alias PulseOps.Jobs.{Job, JobAttempt, JobEvent}
  alias PulseOps.Queues.Provisioner

  test "create_job deduplicates requests by organization and idempotency key" do
    %{organization: organization} = Fixtures.organization_fixture()

    attrs = %{
      "queue_name" => "default",
      "worker" => "noop",
      "idempotency_key" => "same-order",
      "payload" => %{"kind" => "order"}
    }

    assert {:ok, %{job: job, deduplicated?: false}} = Jobs.create_job(organization, attrs)
    assert {:ok, %{job: same_job, deduplicated?: true}} = Jobs.create_job(organization, attrs)
    assert same_job.id == job.id
  end

  test "create_job rejects malformed schedule timestamps" do
    %{organization: organization} = Fixtures.organization_fixture()

    assert {:error, {:bad_request, _message}} =
             Jobs.create_job(organization, %{
               "queue_name" => "default",
               "worker" => "noop",
               "scheduled_at" => "tomorrow please"
             })
  end

  test "create_job does not depend on queue resynchronization during enqueue" do
    %{organization: organization} = Fixtures.organization_fixture()
    original_oban_config = Application.get_env(:pulse_ops, Oban, [])
    Application.put_env(:pulse_ops, Oban, Keyword.put(original_oban_config, :testing, :inline))
    start_supervised!(Provisioner)
    :sys.suspend(Provisioner)

    on_exit(fn ->
      if Process.whereis(Provisioner) do
        :sys.resume(Provisioner)
      end

      Application.put_env(:pulse_ops, Oban, original_oban_config)
    end)

    task =
      Task.async(fn ->
        Jobs.create_job(organization, %{
          "queue_name" => "default",
          "worker" => "noop",
          "idempotency_key" => "provisioner-independent",
          "payload" => %{"kind" => "order"}
        })
      end)

    assert {:ok, %{deduplicated?: false}} = Task.await(task, 500)
  end

  test "reconcile_terminal_jobs repairs running jobs whose oban execution already completed" do
    %{organization: organization} = Fixtures.organization_fixture()

    {:ok, %{job: created_job}} =
      Jobs.create_job(organization, %{"queue_name" => "default", "worker" => "noop"})

    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {:ok, running_job} =
      created_job
      |> Job.lifecycle_changeset(%{
        status: "running",
        started_at: now,
        attempt_count: 1
      })
      |> Repo.update()

    %JobAttempt{}
    |> JobAttempt.changeset(%{
      job_id: running_job.id,
      oban_job_id: running_job.oban_job_id,
      attempt: 1,
      status: "running",
      started_at: now,
      metadata: %{"queue" => "default", "worker" => "PulseOps.Jobs.ExecutionWorker"}
    })
    |> Repo.insert!()

    %JobEvent{}
    |> JobEvent.changeset(%{
      job_id: running_job.id,
      attempt: 1,
      event_type: "job.started",
      status: "running",
      correlation_id: running_job.correlation_id,
      metadata: %{"queue" => "default", "worker" => "PulseOps.Jobs.ExecutionWorker"}
    })
    |> Repo.insert!()

    completed_at = DateTime.add(now, 25, :millisecond)

    Repo.query!(
      """
      UPDATE oban_jobs
      SET state = 'completed',
          attempt = 1,
          attempted_at = $2,
          completed_at = $3
      WHERE id = $1
      """,
      [running_job.oban_job_id, now, completed_at]
    )

    assert 1 == Jobs.reconcile_terminal_jobs()

    repaired_job = Repo.get!(Job, running_job.id)

    assert repaired_job.status == "succeeded"
    assert repaired_job.completed_at == completed_at
    assert repaired_job.attempt_count == 1

    attempt =
      Repo.one!(
        from attempt in JobAttempt,
          where: attempt.job_id == ^running_job.id and attempt.attempt == 1
      )

    assert attempt.status == "succeeded"
    assert attempt.finished_at == completed_at
    assert attempt.duration_ms == 25
    assert attempt.metadata["reconciled"] == true
    assert attempt.metadata["oban_state"] == "completed"

    event =
      Repo.one!(
        from event in JobEvent,
          where:
            event.job_id == ^running_job.id and event.event_type == "job.succeeded" and
              event.attempt == 1
      )

    assert event.status == "succeeded"
    assert event.metadata["reconciled"] == true
    assert event.metadata["oban_state"] == "completed"
    assert event.metadata["duration_ms"] == 25
  end
end
