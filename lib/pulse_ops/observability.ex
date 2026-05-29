defmodule PulseOps.Observability do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PulseOps.Jobs.Job
  alias PulseOps.Repo

  def emit_queue_depth do
    Job
    |> group_by([job], [job.queue_id, job.status])
    |> select([job], %{queue_id: job.queue_id, status: job.status, depth: count(job.id)})
    |> Repo.all()
    |> Enum.each(fn row ->
      :telemetry.execute(
        [:pulse_ops, :queue, :depth],
        %{depth: row.depth},
        %{queue: row.queue_id, status: row.status}
      )
    end)
  rescue
    _ -> :ok
  end
end
