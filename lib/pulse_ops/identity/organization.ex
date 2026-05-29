defmodule PulseOps.Identity.Organization do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PulseOps.Identity.ApiKey
  alias PulseOps.Jobs.Job
  alias PulseOps.Queues.Queue

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :retention_days, :integer, default: 30

    has_many :api_keys, ApiKey
    has_many :queues, Queue
    has_many :jobs, Job

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug, :retention_days])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 120)
    |> update_change(:slug, &normalize_slug/1)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> validate_number(:retention_days, greater_than: 0, less_than_or_equal_to: 365)
    |> unique_constraint(:slug)
  end

  defp normalize_slug(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp normalize_slug(value), do: value
end
