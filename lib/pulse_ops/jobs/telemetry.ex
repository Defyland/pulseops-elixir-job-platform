defmodule PulseOps.Jobs.Telemetry do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PulseOps.Jobs.{Job, JobAttempt, JobEvent}
  alias PulseOps.Repo

  require Logger

  @handler_id "pulse-ops-oban-handler"

  def attach do
    :telemetry.attach_many(
      @handler_id,
      [[:oban, :job, :start], [:oban, :job, :stop], [:oban, :job, :exception]],
      &__MODULE__.handle_event/4,
      nil
    )
  rescue
    ArgumentError -> :ok
  end

  def handle_event([:oban, :job, :start], _measurements, metadata, _config) do
    oban_job = metadata.job
    now = DateTime.utc_now()

    with platform_job_id when is_binary(platform_job_id) <- oban_job.args["job_id"],
         %Job{} = platform_job <- Repo.get(Job, platform_job_id) do
      Repo.transaction(fn ->
        platform_job
        |> Job.lifecycle_changeset(%{
          status: "running",
          started_at: platform_job.started_at || now,
          attempt_count: max(platform_job.attempt_count, oban_job.attempt)
        })
        |> Repo.update!()

        %JobAttempt{}
        |> JobAttempt.changeset(%{
          job_id: platform_job.id,
          oban_job_id: oban_job.id,
          attempt: oban_job.attempt,
          status: "running",
          started_at: now,
          metadata: %{
            "queue" => oban_job.queue,
            "worker" => oban_job.worker
          }
        })
        |> Repo.insert(
          on_conflict: [
            set: [
              status: "running",
              started_at: now,
              updated_at: now,
              metadata: %{"queue" => oban_job.queue, "worker" => oban_job.worker}
            ]
          ],
          conflict_target: [:job_id, :attempt]
        )

        insert_event(platform_job, %{
          attempt: oban_job.attempt,
          event_type: "job.started",
          status: "running",
          metadata: %{"queue" => oban_job.queue, "worker" => oban_job.worker}
        })
      end)
    end
  rescue
    error ->
      Logger.warning("failed to persist oban start telemetry: #{Exception.message(error)}")
  end

  def handle_event([:oban, :job, :stop], measurements, metadata, _config) do
    persist_terminal_event(
      measurements,
      metadata,
      terminal_state(metadata.state),
      metadata.result,
      nil
    )
  end

  def handle_event([:oban, :job, :exception], measurements, metadata, _config) do
    persist_terminal_event(
      measurements,
      metadata,
      exception_state(metadata.state),
      nil,
      %{kind: metadata.kind, reason: metadata.reason}
    )
  end

  defp persist_terminal_event(measurements, metadata, status, result, error_details) do
    oban_job = metadata.job
    now = DateTime.utc_now()
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    with platform_job_id when is_binary(platform_job_id) <- oban_job.args["job_id"],
         %Job{} = platform_job <- Repo.get(Job, platform_job_id) do
      Repo.transaction(fn ->
        platform_job
        |> Job.lifecycle_changeset(
          job_terminal_attrs(platform_job, status, now, oban_job.attempt, result, error_details)
        )
        |> Repo.update!()

        from(attempt in JobAttempt,
          where: attempt.job_id == ^platform_job.id and attempt.attempt == ^oban_job.attempt
        )
        |> Repo.update_all(
          set: [
            status: attempt_status(status),
            finished_at: now,
            duration_ms: duration_ms,
            error_kind: format_error_kind(error_details),
            error_message: format_error_message(error_details),
            updated_at: now
          ]
        )

        insert_event(platform_job, %{
          attempt: oban_job.attempt,
          event_type: event_type_for(status),
          status: status,
          metadata: %{
            "duration_ms" => duration_ms,
            "result" => sanitize_term(result),
            "error_kind" => format_error_kind(error_details),
            "error_message" => format_error_message(error_details)
          }
        })
      end)

      :telemetry.execute(
        [:pulse_ops, :job, :stop],
        %{duration: measurements.duration},
        %{queue: oban_job.queue, worker: oban_job.worker, status: status}
      )
    end
  rescue
    error ->
      Logger.warning("failed to persist oban terminal telemetry: #{Exception.message(error)}")
  end

  defp insert_event(%Job{} = job, attrs) do
    %JobEvent{}
    |> JobEvent.changeset(Map.merge(attrs, %{job_id: job.id, correlation_id: job.correlation_id}))
    |> Repo.insert!()
  end

  defp job_terminal_attrs(job, status, now, attempt, result, error_details) do
    base = %{
      status: status,
      attempt_count: max(job.attempt_count, attempt),
      result: normalize_result(result),
      last_error_kind: format_error_kind(error_details),
      last_error: format_error_message(error_details)
    }

    case status do
      "succeeded" -> Map.merge(base, %{completed_at: now, discarded_at: nil, cancelled_at: nil})
      "retryable" -> Map.merge(base, %{completed_at: nil, discarded_at: nil, cancelled_at: nil})
      "dead_lettered" -> Map.merge(base, %{discarded_at: now})
      "cancelled" -> Map.merge(base, %{cancelled_at: now})
    end
  end

  defp terminal_state(:success), do: "succeeded"
  defp terminal_state(:cancelled), do: "cancelled"
  defp terminal_state(:snoozed), do: "retryable"
  defp terminal_state(_), do: "succeeded"

  defp exception_state(:discard), do: "dead_lettered"
  defp exception_state(:cancelled), do: "cancelled"
  defp exception_state(_), do: "retryable"

  defp attempt_status("dead_lettered"), do: "dead_lettered"
  defp attempt_status("cancelled"), do: "cancelled"
  defp attempt_status("succeeded"), do: "succeeded"
  defp attempt_status(_), do: "failed"

  defp event_type_for("succeeded"), do: "job.succeeded"
  defp event_type_for("dead_lettered"), do: "job.dead_lettered"
  defp event_type_for("cancelled"), do: "job.cancelled"
  defp event_type_for(_), do: "job.failed"

  defp format_error_kind(nil), do: nil
  defp format_error_kind(%{kind: kind}), do: to_string(kind)

  defp format_error_message(nil), do: nil

  defp format_error_message(%{reason: reason}) do
    Exception.message(reason)
  rescue
    _ -> inspect(reason)
  end

  defp sanitize_term(nil), do: nil
  defp sanitize_term(term) when is_map(term) or is_list(term) or is_binary(term), do: term
  defp sanitize_term(term) when is_number(term) or is_boolean(term), do: term
  defp sanitize_term(term), do: inspect(term)

  defp normalize_result(nil), do: nil
  defp normalize_result(%{} = result), do: result
  defp normalize_result({:ok, %{} = result}), do: result
  defp normalize_result({:ok, result}), do: %{"value" => sanitize_term(result)}
  defp normalize_result(result), do: %{"value" => sanitize_term(result)}
end
