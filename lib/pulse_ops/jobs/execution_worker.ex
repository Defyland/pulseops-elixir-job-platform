defmodule PulseOps.Jobs.ExecutionWorker do
  @moduledoc false

  use Oban.Worker, queue: :control, max_attempts: 5

  require Logger

  alias PulseOps.Jobs
  alias PulseOps.Jobs.Handler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_id" => platform_job_id}} = oban_job) do
    case Jobs.get_job_for_execution(platform_job_id) do
      nil ->
        :ok

      job ->
        Logger.metadata(
          correlation_id: job.correlation_id,
          organization_id: job.organization_id,
          job_id: job.id,
          queue: job.queue.name
        )

        case job.status do
          status when status in ["succeeded", "dead_lettered", "cancelled"] ->
            :ok

          _ ->
            Handler.execute(job, oban_job.attempt)
        end
    end
  end

  @impl Oban.Worker
  def timeout(%Oban.Job{args: %{"timeout_ms" => timeout_ms}}) when is_integer(timeout_ms) do
    timeout_ms
  end

  def timeout(_job), do: 30_000

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    trunc(:math.pow(attempt, 4) + :rand.uniform(30))
  end
end
