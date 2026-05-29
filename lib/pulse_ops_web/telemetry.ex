defmodule PulseOpsWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {TelemetryMetricsPrometheus.Core, metrics: metrics(), start_async: false}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      distribution("phoenix.endpoint.stop.duration",
        reporter_options: [buckets: duration_buckets()],
        unit: {:native, :millisecond}
      ),
      counter("phoenix.router_dispatch.stop.count",
        tags: [:route, :status],
        tag_values: &route_tag_values/1
      ),
      distribution("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        tag_values: &route_tag_values/1,
        reporter_options: [buckets: duration_buckets()],
        unit: {:native, :millisecond}
      ),
      distribution("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        tag_values: &route_tag_values/1,
        reporter_options: [buckets: duration_buckets()],
        unit: {:native, :millisecond}
      ),
      distribution("pulse_ops.repo.query.total_time",
        reporter_options: [buckets: duration_buckets()],
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      distribution("pulse_ops.repo.query.query_time",
        reporter_options: [buckets: duration_buckets()],
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      distribution("pulse_ops.repo.query.queue_time",
        reporter_options: [buckets: duration_buckets()],
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      counter("pulse_ops.job.created.count", tags: [:queue, :worker]),
      counter("pulse_ops.job.stop.count", tags: [:queue, :worker, :status]),
      distribution("pulse_ops.job.stop.duration",
        tags: [:queue, :worker, :status],
        reporter_options: [buckets: duration_buckets()],
        unit: {:native, :millisecond},
        description: "End-to-end execution time for background jobs"
      ),
      last_value("pulse_ops.queue.depth",
        tags: [:queue, :status],
        description: "Queue depth grouped by queue identifier and job status"
      ),
      last_value("vm.memory.total", unit: {:byte, :kilobyte}),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      {PulseOps.Observability, :emit_queue_depth, []}
    ]
  end

  defp route_tag_values(%{conn: conn}) do
    %{route: conn.request_path, status: Integer.to_string(conn.status || 0)}
  end

  defp duration_buckets do
    [1, 5, 10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000]
  end
end
