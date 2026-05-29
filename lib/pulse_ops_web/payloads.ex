defmodule PulseOpsWeb.Payloads do
  @moduledoc false

  alias PulseOps.Identity.{ApiKey, Organization}
  alias PulseOps.Jobs.{Job, JobAttempt, JobEvent}
  alias PulseOps.Queues.Queue

  def organization(%Organization{} = organization) do
    %{
      id: organization.id,
      name: organization.name,
      slug: organization.slug,
      retention_days: organization.retention_days,
      inserted_at: iso8601(organization.inserted_at),
      updated_at: iso8601(organization.updated_at)
    }
  end

  def api_key(%ApiKey{} = api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      key_prefix: api_key.key_prefix,
      revoked_at: iso8601(api_key.revoked_at),
      last_used_at: iso8601(api_key.last_used_at),
      inserted_at: iso8601(api_key.inserted_at)
    }
  end

  def queue(%Queue{} = queue) do
    %{
      id: queue.id,
      name: queue.name,
      concurrency: queue.concurrency,
      max_attempts: queue.max_attempts,
      execution_timeout_ms: queue.execution_timeout_ms,
      paused: not is_nil(queue.paused_at),
      paused_at: iso8601(queue.paused_at),
      inserted_at: iso8601(queue.inserted_at),
      updated_at: iso8601(queue.updated_at)
    }
  end

  def job(%Job{} = job) do
    base = %{
      id: job.id,
      queue_id: job.queue_id,
      queue_name: loaded_queue_name(job),
      external_ref: job.external_ref,
      worker: job.worker,
      status: job.status,
      priority: job.priority,
      payload: job.payload,
      result: job.result,
      idempotency_key: job.idempotency_key,
      correlation_id: job.correlation_id,
      attempt_count: job.attempt_count,
      max_attempts: job.max_attempts,
      timeout_ms: job.timeout_ms,
      scheduled_at: iso8601(job.scheduled_at),
      started_at: iso8601(job.started_at),
      completed_at: iso8601(job.completed_at),
      discarded_at: iso8601(job.discarded_at),
      cancelled_at: iso8601(job.cancelled_at),
      last_error: job.last_error,
      last_error_kind: job.last_error_kind,
      inserted_at: iso8601(job.inserted_at),
      updated_at: iso8601(job.updated_at)
    }

    base
    |> maybe_put(:attempts, job.attempts, fn attempts -> Enum.map(attempts, &attempt/1) end)
    |> maybe_put(:events, job.events, fn events -> Enum.map(events, &event/1) end)
  end

  def attempt(%JobAttempt{} = attempt) do
    %{
      id: attempt.id,
      oban_job_id: attempt.oban_job_id,
      attempt: attempt.attempt,
      status: attempt.status,
      started_at: iso8601(attempt.started_at),
      finished_at: iso8601(attempt.finished_at),
      duration_ms: attempt.duration_ms,
      error_kind: attempt.error_kind,
      error_message: attempt.error_message,
      metadata: attempt.metadata
    }
  end

  def event(%JobEvent{} = event) do
    %{
      id: event.id,
      attempt: event.attempt,
      event_type: event.event_type,
      status: event.status,
      correlation_id: event.correlation_id,
      metadata: event.metadata,
      inserted_at: iso8601(event.inserted_at)
    }
  end

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(value), do: value

  defp maybe_put(payload, _key, %Ecto.Association.NotLoaded{}, _mapper), do: payload
  defp maybe_put(payload, _key, nil, _mapper), do: payload
  defp maybe_put(payload, key, value, mapper), do: Map.put(payload, key, mapper.(value))

  defp loaded_queue_name(%Job{queue: %Queue{name: name}}), do: name
  defp loaded_queue_name(_job), do: nil
end
