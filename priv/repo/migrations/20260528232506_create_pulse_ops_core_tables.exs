defmodule PulseOps.Repo.Migrations.CreatePulseOpsCoreTables do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :retention_days, :integer, null: false, default: 30

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organizations, [:slug])

    create constraint(:organizations, :organizations_retention_days_range,
             check: "retention_days BETWEEN 1 AND 365"
           )

    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :key_prefix, :string, null: false
      add :hashed_secret, :string, null: false
      add :last_used_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:api_keys, [:organization_id])
    create unique_index(:api_keys, [:key_prefix])
    create unique_index(:api_keys, [:organization_id, :name])

    create table(:queues, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :concurrency, :integer, null: false, default: 5
      add :max_attempts, :integer, null: false, default: 5
      add :execution_timeout_ms, :integer, null: false, default: 30_000
      add :paused_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:queues, [:organization_id, :name])
    create index(:queues, [:organization_id, :paused_at])

    create constraint(:queues, :queues_concurrency_range, check: "concurrency BETWEEN 1 AND 50")

    create constraint(:queues, :queues_max_attempts_range, check: "max_attempts BETWEEN 1 AND 20")

    create constraint(:queues, :queues_timeout_range,
             check: "execution_timeout_ms BETWEEN 100 AND 300000"
           )

    create table(:jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :queue_id, references(:queues, type: :binary_id, on_delete: :restrict), null: false
      add :oban_job_id, :bigint
      add :external_ref, :string
      add :worker, :string, null: false
      add :status, :string, null: false, default: "queued"
      add :priority, :integer, null: false, default: 0
      add :payload, :map, null: false, default: %{}
      add :result, :map
      add :idempotency_key, :string
      add :correlation_id, :string, null: false
      add :attempt_count, :integer, null: false, default: 0
      add :max_attempts, :integer, null: false
      add :timeout_ms, :integer, null: false
      add :scheduled_at, :utc_datetime_usec
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :discarded_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :last_error, :string
      add :last_error_kind, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:jobs, [:organization_id, :status])
    create index(:jobs, [:organization_id, :queue_id, :status])
    create index(:jobs, [:organization_id, :inserted_at])
    create index(:jobs, [:queue_id, :scheduled_at])

    create unique_index(:jobs, [:organization_id, :external_ref],
             where: "external_ref IS NOT NULL",
             name: :jobs_org_external_ref_index
           )

    create unique_index(:jobs, [:organization_id, :idempotency_key],
             where: "idempotency_key IS NOT NULL",
             name: :jobs_org_idempotency_key_index
           )

    create constraint(:jobs, :jobs_priority_range, check: "priority BETWEEN 0 AND 9")
    create constraint(:jobs, :jobs_attempt_count_positive, check: "attempt_count >= 0")
    create constraint(:jobs, :jobs_max_attempts_range, check: "max_attempts BETWEEN 1 AND 20")
    create constraint(:jobs, :jobs_timeout_range, check: "timeout_ms BETWEEN 100 AND 300000")

    create constraint(:jobs, :jobs_status_allowed,
             check:
               "status IN ('queued', 'running', 'retryable', 'succeeded', 'dead_lettered', 'cancelled')"
           )

    create table(:job_attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :job_id, references(:jobs, type: :binary_id, on_delete: :delete_all), null: false
      add :oban_job_id, :bigint, null: false
      add :attempt, :integer, null: false
      add :status, :string, null: false, default: "running"
      add :started_at, :utc_datetime_usec, null: false
      add :finished_at, :utc_datetime_usec
      add :duration_ms, :integer
      add :error_kind, :string
      add :error_message, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:job_attempts, [:job_id, :inserted_at])
    create unique_index(:job_attempts, [:job_id, :attempt])

    create unique_index(:job_attempts, [:oban_job_id, :attempt],
             name: :job_attempts_oban_attempt_index
           )

    create constraint(:job_attempts, :job_attempts_attempt_positive, check: "attempt > 0")

    create constraint(:job_attempts, :job_attempts_status_allowed,
             check: "status IN ('running', 'succeeded', 'failed', 'dead_lettered', 'cancelled')"
           )

    create table(:job_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :job_id, references(:jobs, type: :binary_id, on_delete: :delete_all), null: false
      add :attempt, :integer
      add :event_type, :string, null: false
      add :status, :string, null: false
      add :correlation_id, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:job_events, [:job_id, :inserted_at])

    create constraint(:job_events, :job_events_status_allowed,
             check:
               "status IN ('queued', 'running', 'retryable', 'succeeded', 'dead_lettered', 'cancelled')"
           )
  end
end
