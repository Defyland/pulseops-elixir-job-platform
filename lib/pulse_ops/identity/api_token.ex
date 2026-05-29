defmodule PulseOps.Identity.ApiToken do
  @moduledoc false

  @token_prefix ["po", "live"]

  def generate do
    prefix = random_fragment(10)
    secret = random_fragment(32)

    %{
      token: Enum.join(@token_prefix ++ [prefix, secret], "_"),
      key_prefix: prefix,
      hashed_secret: hash_secret(secret)
    }
  end

  def parse(token) when is_binary(token) do
    case String.split(token, "_", parts: 4) do
      [prefix_a, prefix_b, key_prefix, secret]
      when [prefix_a, prefix_b] == @token_prefix and byte_size(secret) > 10 ->
        {:ok, %{key_prefix: key_prefix, secret: secret}}

      _ ->
        {:error, :invalid_token}
    end
  end

  def parse(_token), do: {:error, :invalid_token}

  def hash_secret(secret) when is_binary(secret) do
    :sha256
    |> :crypto.hash(secret)
    |> Base.encode16(case: :lower)
  end

  def secure_compare(secret, hashed_secret) when is_binary(secret) and is_binary(hashed_secret) do
    Plug.Crypto.secure_compare(hash_secret(secret), hashed_secret)
  end

  def secure_compare(_, _), do: false

  defp random_fragment(size) do
    size
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
    |> binary_part(0, size)
  end
end
