defmodule PulseOps.Jobs.Idempotency do
  @moduledoc false

  @fingerprint_fields ~w(
    queue_id
    external_ref
    worker
    priority
    payload
    max_attempts
    timeout_ms
    scheduled_at
  )a

  def fingerprint(attrs) do
    if blank?(field(attrs, :idempotency_key)) do
      nil
    else
      attrs
      |> fingerprint_payload()
      |> normalize_term()
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
    end
  end

  defp fingerprint_payload(attrs) do
    Map.new(@fingerprint_fields, fn field_name ->
      {field_name, attrs |> field(field_name) |> normalize_term()}
    end)
  end

  defp field(attrs, key) when is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(attrs, key) -> Map.fetch!(attrs, key)
      Map.has_key?(attrs, string_key) -> Map.fetch!(attrs, string_key)
      true -> nil
    end
  end

  defp field(attrs, key) when is_binary(key) do
    atom_key = String.to_existing_atom(key)

    cond do
      Map.has_key?(attrs, key) -> Map.fetch!(attrs, key)
      Map.has_key?(attrs, atom_key) -> Map.fetch!(attrs, atom_key)
      true -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp normalize_term(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp normalize_term(%{} = map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), normalize_term(value)} end)
    |> Enum.sort_by(fn {key, _value} -> key end)
  end

  defp normalize_term(list) when is_list(list) do
    Enum.map(list, &normalize_term/1)
  end

  defp normalize_term(value), do: value

  defp blank?(value), do: value in [nil, ""]
end
