defmodule PulseOps.Jobs.WebhookSecurity.ApprovedUrl do
  @moduledoc false

  defstruct [:original_uri, :connect_uri, :host, :addresses]

  def url(%__MODULE__{connect_uri: connect_uri}), do: URI.to_string(connect_uri)

  def connect_options(%__MODULE__{} = approved_url, timeout_ms) when is_integer(timeout_ms) do
    approved_url
    |> connect_options()
    |> Keyword.put(:timeout, timeout_ms)
  end

  def connect_options(%__MODULE__{host: host, addresses: [_address | _addresses]}) do
    [hostname: host]
  end

  def connect_options(%__MODULE__{}), do: []
end
