defmodule PulseOps.Fixtures do
  @moduledoc false

  import Plug.Conn

  alias PulseOps.{Identity, Jobs, Queues}
  alias PulseOps.Queues.Queue

  def organization_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    params =
      Map.merge(
        %{
          "name" => "Acme #{unique}",
          "slug" => "acme-#{unique}",
          "retention_days" => 30
        },
        attrs
      )

    {:ok, result} = Identity.register_organization(params)
    result
  end

  def queue_fixture(organization, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    params =
      Map.merge(
        %{
          "name" => "queue_#{unique}",
          "concurrency" => 3,
          "max_attempts" => 4,
          "execution_timeout_ms" => 5_000
        },
        attrs
      )

    {:ok, queue} = Queues.create_queue(organization, params)
    queue
  end

  def api_key_fixture(%{organization: organization}, attrs) do
    api_key_fixture(organization, attrs)
  end

  def api_key_fixture(organization, attrs) do
    unique = System.unique_integer([:positive])

    params =
      Map.merge(
        %{
          "name" => "api-key-#{unique}",
          "scopes" => ["*"]
        },
        attrs
      )

    {:ok, result} = Identity.issue_api_key(organization, params)
    result
  end

  def job_fixture(organization, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    params =
      Map.merge(
        %{
          "queue_name" => "default",
          "worker" => "noop",
          "external_ref" => "job-#{unique}",
          "payload" => %{"value" => unique}
        },
        attrs
      )

    {:ok, %{job: job}} = Jobs.create_job(organization, params)
    job
  end

  def runtime_queue(%{queue: %Queue{} = queue}), do: Queue.runtime_name(queue)
  def runtime_queue(%Queue{} = queue), do: Queue.runtime_name(queue)

  def authenticate(conn, token) do
    put_req_header(conn, "x-api-key", token)
  end
end
