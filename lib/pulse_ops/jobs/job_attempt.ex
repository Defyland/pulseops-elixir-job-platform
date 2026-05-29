defmodule PulseOps.Jobs.JobAttempt do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PulseOps.Jobs.Job

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(running succeeded failed dead_lettered cancelled)

  schema "job_attempts" do
    field :oban_job_id, :integer
    field :attempt, :integer
    field :status, :string, default: "running"
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :duration_ms, :integer
    field :error_kind, :string
    field :error_message, :string
    field :metadata, :map, default: %{}

    belongs_to :job, Job

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(job_attempt, attrs) do
    job_attempt
    |> cast(attrs, [
      :job_id,
      :oban_job_id,
      :attempt,
      :status,
      :started_at,
      :finished_at,
      :duration_ms,
      :error_kind,
      :error_message,
      :metadata
    ])
    |> validate_required([:job_id, :oban_job_id, :attempt, :status, :started_at])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:attempt, greater_than: 0)
    |> unique_constraint(:attempt)
    |> foreign_key_constraint(:job_id)
  end
end
