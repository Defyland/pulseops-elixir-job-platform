defmodule PulseOps.Jobs do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Oban.Job, as: ObanJob
  alias PulseOps.Identity.Organization
  alias PulseOps.Jobs.{ExecutionWorker, Job, JobAttempt, JobEvent, StateMachine}
  alias PulseOps.Queues
  alias PulseOps.Repo

  @terminal_oban_states ~w(completed cancelled discarded)
  @retention_prunable_statuses ~w(succeeded dead_lettered cancelled)

  def list_jobs(%Organization{id: organization_id}, filters \\ %{}) do
    Job
    |> where([job], job.organization_id == ^organization_id)
    |> maybe_filter_by_status(filters)
    |> maybe_filter_by_queue(filters)
    |> order_by([job], desc: job.inserted_at)
    |> preload(:queue)
    |> Repo.all()
  end

  def get_job(%Organization{id: organization_id}, job_id) do
    case fetch_job_query(organization_id, job_id)
         |> preload([:queue, :attempts, :events])
         |> Repo.one() do
      nil -> {:error, :not_found}
      job -> {:ok, job}
    end
  end

  def list_job_events(%Organization{id: organization_id}, job_id) do
    with {:ok, _job} <- get_job(%Organization{id: organization_id}, job_id) do
      events =
        JobEvent
        |> join(:inner, [event], job in assoc(event, :job))
        |> where(
          [event, job],
          job.organization_id == ^organization_id and event.job_id == ^job_id
        )
        |> order_by([event], asc: event.inserted_at)
        |> Repo.all()

      {:ok, events}
    end
  end

  def get_job_for_execution(job_id) do
    Job
    |> where([job], job.id == ^job_id)
    |> preload(:queue)
    |> Repo.one()
  end

  def create_job(%Organization{} = organization, attrs) do
    idempotency_key = Map.get(attrs, "idempotency_key") || Map.get(attrs, :idempotency_key)

    case find_deduplicated_job(organization.id, idempotency_key) do
      %Job{} = deduplicated_job ->
        {:ok, %{job: Repo.preload(deduplicated_job, :queue), deduplicated?: true}}

      nil ->
        do_create_job(organization, attrs)
    end
  end

  def retry_job(%Organization{id: organization_id}, job_id) do
    with %Job{} = job <- Repo.one(fetch_job_query(organization_id, job_id)),
         {:ok, next_status} <- StateMachine.transition(job.status, :retry),
         true <- is_integer(job.oban_job_id) do
      now = DateTime.utc_now()

      Repo.transaction(fn ->
        job
        |> Job.lifecycle_changeset(%{
          status: next_status,
          completed_at: nil,
          discarded_at: nil,
          cancelled_at: nil,
          last_error: nil,
          last_error_kind: nil
        })
        |> Repo.update!()

        Oban.retry_job(job.oban_job_id)

        %JobEvent{}
        |> JobEvent.changeset(%{
          job_id: job.id,
          event_type: "job.retried",
          status: next_status,
          correlation_id: job.correlation_id,
          metadata: %{"requested_at" => now}
        })
        |> Repo.insert!()
      end)

      get_job(%Organization{id: organization_id}, job_id)
    else
      nil -> {:error, :not_found}
      false -> {:error, {:conflict, "job has not been dispatched yet"}}
      :error -> {:error, {:conflict, "job cannot be retried from its current state"}}
      {:error, _} = error -> error
    end
  end

  def cancel_job(%Organization{id: organization_id}, job_id) do
    with %Job{} = job <- Repo.one(fetch_job_query(organization_id, job_id)),
         {:ok, next_status} <- StateMachine.transition(job.status, :cancel) do
      now = DateTime.utc_now()

      Repo.transaction(fn ->
        job
        |> Job.lifecycle_changeset(%{status: next_status, cancelled_at: now})
        |> Repo.update!()

        if is_integer(job.oban_job_id), do: Oban.cancel_job(job.oban_job_id)

        %JobEvent{}
        |> JobEvent.changeset(%{
          job_id: job.id,
          event_type: "job.cancelled",
          status: next_status,
          correlation_id: job.correlation_id,
          metadata: %{"requested_at" => now}
        })
        |> Repo.insert!()
      end)

      get_job(%Organization{id: organization_id}, job_id)
    else
      nil -> {:error, :not_found}
      :error -> {:error, {:conflict, "job cannot be cancelled from its current state"}}
      {:error, _} = error -> error
    end
  end

  def reconcile_terminal_jobs(limit \\ 100) when is_integer(limit) and limit > 0 do
    terminal_reconciliation_candidates(limit)
    |> Enum.reduce(0, fn {job_id, oban_job_id}, reconciled ->
      case reconcile_terminal_job(job_id, oban_job_id) do
        :ok -> reconciled + 1
        :noop -> reconciled
      end
    end)
  end

  def prune_expired_jobs(now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :microsecond)

    Repo.transaction(fn ->
      expired_job_ids = expired_job_ids_query(now)

      {events_count, _} =
        from(event in JobEvent, where: event.job_id in subquery(expired_job_ids))
        |> Repo.delete_all()

      {attempts_count, _} =
        from(attempt in JobAttempt, where: attempt.job_id in subquery(expired_job_ids))
        |> Repo.delete_all()

      {oban_jobs_count, _} =
        from(oban_job in ObanJob,
          join: job in Job,
          on: job.oban_job_id == oban_job.id,
          where: job.id in subquery(expired_job_ids)
        )
        |> Repo.delete_all()

      {jobs_count, _} =
        from(job in Job, where: job.id in subquery(expired_job_ids))
        |> Repo.delete_all()

      summary = %{
        jobs: jobs_count,
        attempts: attempts_count,
        events: events_count,
        oban_jobs: oban_jobs_count
      }

      :telemetry.execute([:pulse_ops, :jobs, :retention, :pruned], summary, %{})

      summary
    end)
    |> case do
      {:ok, summary} -> summary
      {:error, reason} -> raise "failed to prune expired jobs: #{inspect(reason)}"
    end
  end

  defp do_create_job(%Organization{} = organization, attrs) do
    organization
    |> Queues.find_queue(attrs)
    |> create_job_for_queue(organization, attrs)
  end

  defp enqueue_job(%Job{} = job, queue) do
    args = %{
      "job_id" => job.id,
      "correlation_id" => job.correlation_id,
      "timeout_ms" => job.timeout_ms
    }

    args
    |> ExecutionWorker.new(
      queue: queue.name,
      max_attempts: job.max_attempts,
      priority: job.priority,
      scheduled_at: job.scheduled_at
    )
    |> Oban.insert()
  end

  defp normalize_create_attrs(%Organization{} = organization, queue, attrs) do
    with {:ok, scheduled_at} <- parse_datetime(attr(attrs, :scheduled_at)) do
      {:ok,
       %{
         organization_id: organization.id,
         queue_id: queue.id,
         external_ref: attr(attrs, :external_ref),
         worker: attr(attrs, :worker),
         status: "queued",
         priority: coerce_integer(attr(attrs, :priority), 0),
         payload: attr(attrs, :payload) || %{},
         idempotency_key: attr(attrs, :idempotency_key),
         correlation_id: attr(attrs, :correlation_id) || Ecto.UUID.generate(),
         max_attempts: coerce_integer(attr(attrs, :max_attempts), queue.max_attempts),
         timeout_ms: coerce_integer(attr(attrs, :timeout_ms), queue.execution_timeout_ms),
         scheduled_at: scheduled_at
       }}
    end
  end

  defp persist_created_job(queue, normalized_attrs) do
    with {:ok, job} <- %Job{} |> Job.create_changeset(normalized_attrs) |> Repo.insert(),
         {:ok, oban_job} <- enqueue_job(job, queue) do
      finalize_created_job(job, oban_job, queue)
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp create_job_for_queue(nil, _organization, _attrs) do
    {:error, {:bad_request, "queue was not found for this organization"}}
  end

  defp create_job_for_queue(queue, organization, attrs) do
    with {:ok, normalized_attrs} <- normalize_create_attrs(organization, queue, attrs) do
      Repo.transaction(fn -> persist_created_job(queue, normalized_attrs) end)
    end
  end

  defp terminal_reconciliation_candidates(limit) do
    from(job in Job,
      join: oban_job in ObanJob,
      on: oban_job.id == job.oban_job_id,
      where: job.status == "running" and oban_job.state in ^@terminal_oban_states,
      order_by: [asc: job.updated_at],
      limit: ^limit,
      select: {job.id, oban_job.id}
    )
    |> Repo.all()
  end

  defp expired_job_ids_query(now) do
    from(job in Job,
      join: organization in Organization,
      on: organization.id == job.organization_id,
      where: job.status in ^@retention_prunable_statuses,
      where:
        fragment(
          "COALESCE(?, ?, ?) < (?::timestamp without time zone - (? * interval '1 day'))",
          job.completed_at,
          job.discarded_at,
          job.cancelled_at,
          ^now,
          organization.retention_days
        ),
      select: job.id
    )
  end

  defp reconcile_terminal_job(job_id, oban_job_id) do
    Repo.transaction(fn ->
      platform_job =
        Job
        |> where([job], job.id == ^job_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      oban_job = Repo.get(ObanJob, oban_job_id)

      case {platform_job, oban_job} do
        {%Job{} = job, %ObanJob{} = oban_job}
        when job.status == "running" and oban_job.state in @terminal_oban_states ->
          persist_reconciled_terminal_state(job, oban_job)
          :ok

        _ ->
          :noop
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, _reason} -> :noop
    end
  end

  defp persist_reconciled_terminal_state(job, oban_job) do
    snapshot = reconciled_terminal_snapshot(job, oban_job)

    job
    |> Job.lifecycle_changeset(
      reconciled_terminal_attrs(
        job,
        snapshot.status,
        snapshot.attempt,
        snapshot.started_at,
        snapshot.finished_at,
        snapshot.last_error_kind,
        snapshot.last_error
      )
    )
    |> Repo.update!()

    upsert_reconciled_attempt(job, oban_job, snapshot)

    insert_reconciled_terminal_event(job, oban_job, snapshot)
  end

  defp finalize_created_job(job, oban_job, queue) do
    {:ok, updated_job} =
      job
      |> Job.lifecycle_changeset(%{oban_job_id: oban_job.id})
      |> Repo.update()

    %JobEvent{}
    |> JobEvent.changeset(%{
      job_id: updated_job.id,
      event_type: "job.created",
      status: updated_job.status,
      correlation_id: updated_job.correlation_id,
      metadata: %{
        "queue" => queue.name,
        "worker" => updated_job.worker,
        "scheduled_at" => updated_job.scheduled_at
      }
    })
    |> Repo.insert!()

    :telemetry.execute(
      [:pulse_ops, :job, :created],
      %{count: 1},
      %{queue: queue.name, worker: updated_job.worker}
    )

    %{job: Repo.preload(updated_job, :queue), deduplicated?: false}
  end

  defp parse_datetime(nil), do: {:ok, nil}

  defp parse_datetime(datetime) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, parsed, _offset} -> {:ok, parsed}
      _ -> {:error, {:bad_request, "scheduled_at must be an ISO8601 datetime"}}
    end
  end

  defp parse_datetime(%DateTime{} = datetime), do: {:ok, datetime}
  defp parse_datetime(_), do: {:error, {:bad_request, "scheduled_at must be an ISO8601 datetime"}}

  defp coerce_integer(nil, default), do: default
  defp coerce_integer(value, _default) when is_integer(value), do: value

  defp coerce_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> default
    end
  end

  defp attr(attrs, key), do: Map.get(attrs, Atom.to_string(key)) || Map.get(attrs, key)

  defp maybe_filter_by_status(query, %{"status" => status}) when is_binary(status) do
    where(query, [job], job.status == ^status)
  end

  defp maybe_filter_by_status(query, %{status: status}) when is_binary(status) do
    where(query, [job], job.status == ^status)
  end

  defp maybe_filter_by_status(query, _filters), do: query

  defp maybe_filter_by_queue(query, %{"queue_id" => queue_id}) when is_binary(queue_id) do
    where(query, [job], job.queue_id == ^queue_id)
  end

  defp maybe_filter_by_queue(query, %{queue_id: queue_id}) when is_binary(queue_id) do
    where(query, [job], job.queue_id == ^queue_id)
  end

  defp maybe_filter_by_queue(query, _filters), do: query

  defp upsert_reconciled_attempt(job, oban_job, snapshot) do
    metadata = %{
      "queue" => oban_job.queue,
      "worker" => oban_job.worker,
      "reconciled" => true,
      "oban_state" => oban_job.state
    }

    %JobAttempt{}
    |> JobAttempt.changeset(%{
      job_id: job.id,
      oban_job_id: oban_job.id,
      attempt: snapshot.attempt,
      status: attempt_status_for(snapshot.status),
      started_at: snapshot.started_at,
      finished_at: snapshot.finished_at,
      duration_ms: snapshot.duration_ms,
      error_kind: snapshot.last_error_kind,
      error_message: snapshot.last_error,
      metadata: metadata
    })
    |> Repo.insert!(
      on_conflict: [
        set: [
          status: attempt_status_for(snapshot.status),
          started_at: snapshot.started_at,
          finished_at: snapshot.finished_at,
          duration_ms: snapshot.duration_ms,
          error_kind: snapshot.last_error_kind,
          error_message: snapshot.last_error,
          metadata: metadata,
          updated_at: snapshot.finished_at
        ]
      ],
      conflict_target: [:job_id, :attempt]
    )
  end

  defp insert_reconciled_terminal_event(job, oban_job, snapshot) do
    %JobEvent{}
    |> JobEvent.changeset(%{
      job_id: job.id,
      attempt: snapshot.attempt,
      event_type: event_type_for(snapshot.status),
      status: snapshot.status,
      correlation_id: job.correlation_id,
      metadata: %{
        "queue" => oban_job.queue,
        "worker" => oban_job.worker,
        "oban_state" => oban_job.state,
        "reconciled" => true,
        "duration_ms" => snapshot.duration_ms
      }
    })
    |> Repo.insert!()
  end

  defp reconciled_terminal_snapshot(job, oban_job) do
    status = platform_status_for(oban_job.state)
    attempt = max(oban_job.attempt || 1, 1)
    finished_at = terminal_finished_at(oban_job) || DateTime.utc_now()
    started_at = job.started_at || utc_datetime(oban_job.attempted_at) || finished_at
    duration_ms = max(DateTime.diff(finished_at, started_at, :millisecond), 0)
    {last_error_kind, last_error} = oban_error(oban_job)

    %{
      status: status,
      attempt: attempt,
      started_at: started_at,
      finished_at: finished_at,
      duration_ms: duration_ms,
      last_error_kind: last_error_kind,
      last_error: last_error
    }
  end

  defp platform_status_for("completed"), do: "succeeded"
  defp platform_status_for("discarded"), do: "dead_lettered"
  defp platform_status_for("cancelled"), do: "cancelled"

  defp event_type_for("succeeded"), do: "job.succeeded"
  defp event_type_for("dead_lettered"), do: "job.dead_lettered"
  defp event_type_for("cancelled"), do: "job.cancelled"

  defp attempt_status_for("succeeded"), do: "succeeded"
  defp attempt_status_for("dead_lettered"), do: "dead_lettered"
  defp attempt_status_for("cancelled"), do: "cancelled"

  defp reconciled_terminal_attrs(
         job,
         status,
         attempt,
         started_at,
         finished_at,
         last_error_kind,
         last_error
       ) do
    base = %{
      status: status,
      attempt_count: max(job.attempt_count, attempt),
      started_at: job.started_at || started_at,
      last_error_kind: last_error_kind,
      last_error: last_error
    }

    case status do
      "succeeded" ->
        Map.merge(base, %{
          completed_at: finished_at,
          discarded_at: nil,
          cancelled_at: nil,
          last_error_kind: nil,
          last_error: nil
        })

      "dead_lettered" ->
        Map.merge(base, %{completed_at: nil, discarded_at: finished_at, cancelled_at: nil})

      "cancelled" ->
        Map.merge(base, %{completed_at: nil, discarded_at: nil, cancelled_at: finished_at})
    end
  end

  defp terminal_finished_at(%ObanJob{state: "completed", completed_at: completed_at}),
    do: utc_datetime(completed_at)

  defp terminal_finished_at(%ObanJob{state: "discarded", discarded_at: discarded_at}),
    do: utc_datetime(discarded_at)

  defp terminal_finished_at(%ObanJob{state: "cancelled", cancelled_at: cancelled_at}),
    do: utc_datetime(cancelled_at)

  defp oban_error(%ObanJob{errors: []}), do: {nil, nil}
  defp oban_error(%ObanJob{errors: nil}), do: {nil, nil}

  defp oban_error(%ObanJob{errors: errors}) when is_list(errors) do
    errors
    |> List.last()
    |> oban_error_entry()
  end

  defp oban_error_entry(%{"kind" => kind, "error" => error}) do
    {kind, error}
  end

  defp oban_error_entry(%{"kind" => kind, "reason" => reason}) do
    {kind, inspect(reason)}
  end

  defp oban_error_entry(%{kind: kind, error: error}) do
    {to_string(kind), error}
  end

  defp oban_error_entry(%{kind: kind, reason: reason}) do
    {to_string(kind), inspect(reason)}
  end

  defp oban_error_entry(_entry), do: {nil, nil}

  defp utc_datetime(nil), do: nil
  defp utc_datetime(%DateTime{} = datetime), do: datetime
  defp utc_datetime(%NaiveDateTime{} = datetime), do: DateTime.from_naive!(datetime, "Etc/UTC")

  defp fetch_job_query(organization_id, job_id) do
    from(job in Job, where: job.organization_id == ^organization_id and job.id == ^job_id)
  end

  defp find_by_idempotency(organization_id, idempotency_key) do
    Repo.get_by(Job, organization_id: organization_id, idempotency_key: idempotency_key)
  end

  defp find_deduplicated_job(_organization_id, nil), do: nil
  defp find_deduplicated_job(_organization_id, ""), do: nil

  defp find_deduplicated_job(organization_id, idempotency_key),
    do: find_by_idempotency(organization_id, idempotency_key)
end
