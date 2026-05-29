defmodule PulseOpsWeb.Router do
  use PulseOpsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :rate_limited_api do
    plug PulseOpsWeb.Plugs.ApiRateLimit
  end

  pipeline :authenticated_api do
    plug PulseOpsWeb.Plugs.ApiKeyAuth
  end

  scope "/", PulseOpsWeb do
    pipe_through [:api, :rate_limited_api]

    get "/healthz", HealthController, :health
    get "/readyz", HealthController, :readiness
    get "/metrics", MetricsController, :index
  end

  scope "/api/v1", PulseOpsWeb do
    pipe_through [:api, :rate_limited_api]

    post "/organizations", OrganizationController, :create
  end

  scope "/api/v1", PulseOpsWeb do
    pipe_through [:api, :authenticated_api, :rate_limited_api]

    get "/organizations/me", OrganizationController, :show

    get "/api-keys", ApiKeyController, :index
    post "/api-keys", ApiKeyController, :create
    delete "/api-keys/:id", ApiKeyController, :delete

    get "/queues", QueueController, :index
    post "/queues", QueueController, :create
    patch "/queues/:id", QueueController, :update

    get "/jobs", JobController, :index
    post "/jobs", JobController, :create
    get "/jobs/:id", JobController, :show
    post "/jobs/:id/retry", JobController, :retry
    post "/jobs/:id/cancel", JobController, :cancel
    get "/jobs/:id/events", JobController, :events
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:pulse_ops, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: PulseOpsWeb.Telemetry
    end
  end
end
