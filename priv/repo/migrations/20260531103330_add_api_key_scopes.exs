defmodule PulseOps.Repo.Migrations.AddApiKeyScopes do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :scopes, {:array, :string}, null: false, default: ["*"]
    end

    create constraint(:api_keys, :api_keys_scopes_not_empty, check: "cardinality(scopes) > 0")

    create constraint(:api_keys, :api_keys_scopes_wildcard_exclusive,
             check: "array_position(scopes, '*') IS NULL OR cardinality(scopes) = 1"
           )

    create constraint(:api_keys, :api_keys_scopes_allowed,
             check:
               "scopes <@ ARRAY['*', 'organizations:read', 'api_keys:read', 'api_keys:write', 'queues:read', 'queues:write', 'jobs:read', 'jobs:write', 'jobs:control']::varchar[]"
           )
  end
end
