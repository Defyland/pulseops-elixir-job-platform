defmodule PulseOps.Queues.Queue do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PulseOps.Identity.Organization
  alias PulseOps.Jobs.Job

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "queues" do
    field :name, :string
    field :concurrency, :integer, default: 5
    field :max_attempts, :integer, default: 5
    field :execution_timeout_ms, :integer, default: 30_000
    field :paused_at, :utc_datetime_usec

    belongs_to :organization, Organization
    has_many :jobs, Job

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(queue, attrs) do
    queue
    |> cast(attrs, [
      :organization_id,
      :name,
      :concurrency,
      :max_attempts,
      :execution_timeout_ms,
      :paused_at
    ])
    |> validate_required([
      :organization_id,
      :name,
      :concurrency,
      :max_attempts,
      :execution_timeout_ms
    ])
    |> validate_length(:name, min: 2, max: 32)
    |> validate_format(:name, ~r/^[a-z][a-z0-9_-]+$/)
    |> validate_number(:concurrency, greater_than: 0, less_than_or_equal_to: 50)
    |> validate_number(:max_attempts, greater_than: 0, less_than_or_equal_to: 20)
    |> validate_number(:execution_timeout_ms,
      greater_than_or_equal_to: 100,
      less_than_or_equal_to: 300_000
    )
    |> unique_constraint(:name)
    |> foreign_key_constraint(:organization_id)
  end

  def paused?(%__MODULE__{paused_at: paused_at}), do: not is_nil(paused_at)
end
