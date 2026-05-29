defmodule PulseOps.Identity.ApiKey do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PulseOps.Identity.Organization

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_keys" do
    field :name, :string
    field :key_prefix, :string
    field :hashed_secret, :string
    field :last_used_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :organization, Organization

    timestamps(type: :utc_datetime_usec)
  end

  def issue_changeset(api_key, organization, attrs, token_attrs) do
    api_key
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 80)
    |> put_change(:organization_id, organization.id)
    |> put_change(:key_prefix, token_attrs.key_prefix)
    |> put_change(:hashed_secret, token_attrs.hashed_secret)
    |> unique_constraint(:key_prefix)
    |> unique_constraint(:name)
    |> foreign_key_constraint(:organization_id)
  end

  def revoke_changeset(api_key) do
    change(api_key, revoked_at: DateTime.utc_now())
  end
end
