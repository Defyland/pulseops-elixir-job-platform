defmodule PulseOps.Repo.Migrations.AddJobIdempotencyFingerprint do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :idempotency_fingerprint, :string
    end
  end
end
