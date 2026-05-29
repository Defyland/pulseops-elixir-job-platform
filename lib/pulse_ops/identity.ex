defmodule PulseOps.Identity do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PulseOps.Identity.{ApiKey, ApiToken, Organization}
  alias PulseOps.Queues.{Provisioner, Queue}
  alias PulseOps.Repo

  def register_organization(attrs) do
    case persist_organization(attrs) do
      {:ok, %{default_queue: queue} = result} ->
        :ok = Provisioner.sync_queue(queue)
        {:ok, result}

      {:error, _reason} = error ->
        error
    end
  end

  def authenticate_api_key(token) do
    with {:ok, parsed} <- ApiToken.parse(token),
         %ApiKey{} = api_key <-
           Repo.one(
             from key in ApiKey,
               where: key.key_prefix == ^parsed.key_prefix and is_nil(key.revoked_at),
               preload: [:organization]
           ),
         true <- ApiToken.secure_compare(parsed.secret, api_key.hashed_secret) do
      touch_api_key(api_key)
      {:ok, api_key.organization, api_key}
    else
      nil -> {:error, :unauthorized}
      false -> {:error, :unauthorized}
      {:error, _} = error -> error
    end
  end

  def issue_api_key(%Organization{} = organization, attrs) do
    Repo.transaction(fn ->
      case create_api_key_record(organization, attrs) do
        {:ok, api_key, token} -> %{api_key: api_key, token: token}
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def list_api_keys(%Organization{id: organization_id}) do
    ApiKey
    |> where([key], key.organization_id == ^organization_id)
    |> order_by([key], desc: key.inserted_at)
    |> Repo.all()
  end

  def revoke_api_key(%Organization{id: organization_id}, api_key_id) do
    case Repo.get_by(ApiKey, id: api_key_id, organization_id: organization_id) do
      nil ->
        {:error, :not_found}

      %ApiKey{} = api_key ->
        api_key
        |> ApiKey.revoke_changeset()
        |> Repo.update()
    end
  end

  defp create_api_key_record(%Organization{} = organization, attrs) do
    token_attrs = ApiToken.generate()

    case %ApiKey{}
         |> ApiKey.issue_changeset(organization, attrs, token_attrs)
         |> Repo.insert() do
      {:ok, api_key} -> {:ok, api_key, token_attrs.token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp touch_api_key(%ApiKey{id: api_key_id}) do
    now = DateTime.utc_now()

    from(key in ApiKey, where: key.id == ^api_key_id)
    |> Repo.update_all(set: [last_used_at: now, updated_at: now])

    :ok
  end

  defp persist_organization(attrs) do
    Repo.transaction(fn ->
      with {:ok, organization} <-
             %Organization{}
             |> Organization.changeset(attrs)
             |> Repo.insert(),
           {:ok, queue} <-
             %Queue{}
             |> Queue.changeset(%{
               "organization_id" => organization.id,
               "name" => "default",
               "concurrency" => 5,
               "max_attempts" => 5,
               "execution_timeout_ms" => 30_000
             })
             |> Repo.insert(),
           {:ok, api_key, token} <- create_api_key_record(organization, %{"name" => "bootstrap"}) do
        %{
          organization: organization,
          bootstrap_api_key: token,
          default_queue: queue,
          api_key: api_key
        }
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end
