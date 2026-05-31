defmodule PulseOps.Jobs.WebhookSecurity.ApprovedUrl do
  @moduledoc false

  defstruct [:original_uri, :connect_uri, :host, :addresses]

  def url(%__MODULE__{connect_uri: connect_uri}), do: URI.to_string(connect_uri)

  def connect_options(%__MODULE__{host: host, addresses: [_address | _addresses]}) do
    [hostname: host]
  end

  def connect_options(%__MODULE__{}), do: []
end
