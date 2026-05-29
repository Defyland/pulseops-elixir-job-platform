defmodule PulseOps.Repo.Migrations.CreateRateLimitBuckets do
  use Ecto.Migration

  def change do
    create table(:rate_limit_buckets) do
      add :identifier, :string, null: false
      add :bucket, :bigint, null: false
      add :count, :integer, null: false, default: 0
      add :expires_at_ms, :bigint, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:rate_limit_buckets, [:identifier, :bucket])
    create index(:rate_limit_buckets, [:expires_at_ms])
  end
end
