defmodule PulseOps.Identity.ApiKey do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PulseOps.Identity.Organization

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @wildcard_scope "*"
  @allowed_scopes [
    @wildcard_scope,
    "organizations:read",
    "api_keys:read",
    "api_keys:write",
    "queues:read",
    "queues:write",
    "jobs:read",
    "jobs:write",
    "jobs:control"
  ]

  schema "api_keys" do
    field :name, :string
    field :scopes, {:array, :string}, default: [@wildcard_scope]
    field :key_prefix, :string
    field :hashed_secret, :string
    field :last_used_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :organization, Organization

    timestamps(type: :utc_datetime_usec)
  end

  def allowed_scopes, do: @allowed_scopes

  def has_scope?(%__MODULE__{scopes: scopes}, required_scope)
      when is_list(scopes) and is_binary(required_scope) do
    required_scope in @allowed_scopes and
      (@wildcard_scope in scopes or required_scope in scopes)
  end

  def has_scope?(_api_key, _required_scope), do: false

  def issue_changeset(api_key, organization, attrs, token_attrs) do
    api_key
    |> cast(attrs, [:name, :scopes])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 80)
    |> validate_scopes()
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

  defp validate_scopes(changeset) do
    changeset
    |> update_change(:scopes, &normalize_scopes/1)
    |> validate_required([:scopes])
    |> validate_change(:scopes, fn :scopes, scopes -> scope_errors(scopes) end)
  end

  defp normalize_scopes(scopes) when is_list(scopes) do
    scopes
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_scopes(scopes), do: scopes

  defp scope_errors(scopes) when not is_list(scopes), do: [scopes: "must be a list"]

  defp scope_errors([]), do: [scopes: "must include at least one scope"]

  defp scope_errors(scopes) do
    invalid_scopes = Enum.reject(scopes, &(&1 in @allowed_scopes))

    cond do
      invalid_scopes != [] ->
        [scopes: "contains unsupported scopes: #{Enum.join(invalid_scopes, ", ")}"]

      @wildcard_scope in scopes and length(scopes) > 1 ->
        [scopes: "cannot combine wildcard scope with other scopes"]

      true ->
        []
    end
  end
end
