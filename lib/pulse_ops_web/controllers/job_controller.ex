defmodule PulseOpsWeb.JobController do
  use PulseOpsWeb, :controller

  alias PulseOps.Jobs
  alias PulseOpsWeb.Payloads

  action_fallback PulseOpsWeb.FallbackController

  def index(conn, params) do
    jobs = Jobs.list_jobs(conn.assigns.current_organization, params)
    json(conn, %{data: Enum.map(jobs, &Payloads.job/1)})
  end

  def create(conn, %{"job" => job_params}) do
    with {:ok, %{job: job, deduplicated?: deduplicated?}} <-
           Jobs.create_job(conn.assigns.current_organization, job_params) do
      conn
      |> put_status(if(deduplicated?, do: :ok, else: :created))
      |> json(%{data: Payloads.job(job), meta: %{deduplicated: deduplicated?}})
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, job} <- Jobs.get_job(conn.assigns.current_organization, id) do
      json(conn, %{data: Payloads.job(job)})
    end
  end

  def retry(conn, %{"id" => id}) do
    with {:ok, job} <- Jobs.retry_job(conn.assigns.current_organization, id) do
      json(conn, %{data: Payloads.job(job)})
    end
  end

  def cancel(conn, %{"id" => id}) do
    with {:ok, job} <- Jobs.cancel_job(conn.assigns.current_organization, id) do
      json(conn, %{data: Payloads.job(job)})
    end
  end

  def events(conn, %{"id" => id}) do
    with {:ok, events} <- Jobs.list_job_events(conn.assigns.current_organization, id) do
      json(conn, %{data: Enum.map(events, &Payloads.event/1)})
    end
  end
end
