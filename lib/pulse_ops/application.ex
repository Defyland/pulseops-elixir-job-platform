defmodule PulseOps.Application do
  @moduledoc false

  use Application

  alias PulseOps.Jobs.Telemetry, as: JobsTelemetry

  @impl true
  def start(_type, _args) do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:pulse_ops, :repo], db_statement: :enabled)
    OpentelemetryOban.setup()
    JobsTelemetry.attach()

    children =
      [
        PulseOpsWeb.Telemetry,
        PulseOps.Repo,
        {Oban, Application.fetch_env!(:pulse_ops, Oban)},
        PulseOps.RateLimiter,
        PulseOps.Jobs.WebhookCircuitBreaker,
        {DNSCluster, query: Application.get_env(:pulse_ops, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: PulseOps.PubSub}
      ] ++
        runtime_children() ++
        [
          PulseOpsWeb.Endpoint
        ]

    opts = [strategy: :one_for_one, name: PulseOps.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PulseOpsWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp runtime_children do
    if Application.get_env(:pulse_ops, Oban, [])[:testing] == :manual do
      []
    else
      [PulseOps.Queues.Provisioner, PulseOps.Jobs.Reconciler, PulseOps.Jobs.RetentionPruner]
    end
  end
end
