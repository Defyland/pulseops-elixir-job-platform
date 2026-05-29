defmodule PulseOps.Jobs.Job do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PulseOps.Identity.Organization
  alias PulseOps.Jobs.{JobAttempt, JobEvent}
  alias PulseOps.Queues.Queue

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(queued running retryable succeeded dead_lettered cancelled)
  @supported_workers ~w(noop flaky crash sleep webhook)

  schema "jobs" do
    field :external_ref, :string
    field :oban_job_id, :integer
    field :worker, :string
    field :status, :string, default: "queued"
    field :priority, :integer, default: 0
    field :payload, :map, default: %{}
    field :result, :map
    field :idempotency_key, :string
    field :correlation_id, :string
    field :attempt_count, :integer, default: 0
    field :max_attempts, :integer
    field :timeout_ms, :integer
    field :scheduled_at, :utc_datetime_usec
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :discarded_at, :utc_datetime_usec
    field :cancelled_at, :utc_datetime_usec
    field :last_error, :string
    field :last_error_kind, :string

    belongs_to :organization, Organization
    belongs_to :queue, Queue
    has_many :attempts, JobAttempt
    has_many :events, JobEvent

    timestamps(type: :utc_datetime_usec)
  end

  def supported_workers, do: @supported_workers
  def statuses, do: @statuses

  def create_changeset(job, attrs) do
    job
    |> cast(attrs, [
      :organization_id,
      :queue_id,
      :external_ref,
      :worker,
      :status,
      :priority,
      :payload,
      :idempotency_key,
      :correlation_id,
      :max_attempts,
      :timeout_ms,
      :scheduled_at
    ])
    |> validate_required([
      :organization_id,
      :queue_id,
      :worker,
      :status,
      :priority,
      :payload,
      :correlation_id,
      :max_attempts,
      :timeout_ms
    ])
    |> validate_inclusion(:worker, @supported_workers)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:priority, greater_than_or_equal_to: 0, less_than_or_equal_to: 9)
    |> validate_number(:max_attempts, greater_than: 0, less_than_or_equal_to: 20)
    |> validate_number(:timeout_ms, greater_than_or_equal_to: 100, less_than_or_equal_to: 300_000)
    |> unique_constraint(:external_ref, name: :jobs_org_external_ref_index)
    |> unique_constraint(:idempotency_key, name: :jobs_org_idempotency_key_index)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:queue_id)
  end

  def lifecycle_changeset(job, attrs) do
    job
    |> cast(attrs, [
      :oban_job_id,
      :status,
      :result,
      :attempt_count,
      :started_at,
      :completed_at,
      :discarded_at,
      :cancelled_at,
      :last_error,
      :last_error_kind
    ])
    |> validate_inclusion(:status, @statuses)
  end
end
