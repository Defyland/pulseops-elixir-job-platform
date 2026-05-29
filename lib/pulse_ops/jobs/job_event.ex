defmodule PulseOps.Jobs.JobEvent do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PulseOps.Jobs.Job

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(queued running retryable succeeded dead_lettered cancelled)

  schema "job_events" do
    field :attempt, :integer
    field :event_type, :string
    field :status, :string
    field :correlation_id, :string
    field :metadata, :map, default: %{}

    belongs_to :job, Job

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(job_event, attrs) do
    job_event
    |> cast(attrs, [:job_id, :attempt, :event_type, :status, :correlation_id, :metadata])
    |> validate_required([:job_id, :event_type, :status, :correlation_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:job_id)
  end
end
