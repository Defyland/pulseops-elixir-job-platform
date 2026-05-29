defmodule PulseOps.Jobs.WebhookSecurity do
  @moduledoc false

  import Bitwise

  @default_config %{
    allowed_hosts: [],
    allow_http: false,
    allow_private_networks: false,
    resolve_dns: true
  }

  def validate_url(url) when is_binary(url) do
    url
    |> URI.parse()
    |> validate_uri()
  end

  def validate_url(_url), do: {:error, {:policy, "webhook url must be a string"}}

  defp validate_uri(%URI{host: nil}) do
    {:error, {:policy, "webhook url must include a host"}}
  end

  defp validate_uri(%URI{userinfo: userinfo}) when is_binary(userinfo) do
    {:error, {:policy, "webhook url must not include userinfo"}}
  end

  defp validate_uri(%URI{} = uri) do
    uri = %{uri | host: String.downcase(uri.host)}

    with :ok <- validate_scheme(uri.scheme),
         :ok <- validate_allowlist(uri.host),
         :ok <- validate_network_boundary(uri.host) do
      {:ok, uri}
    end
  end

  defp validate_scheme("https"), do: :ok

  defp validate_scheme("http") do
    if config().allow_http do
      :ok
    else
      {:error, {:policy, "webhook url must use https"}}
    end
  end

  defp validate_scheme(_scheme), do: {:error, {:policy, "webhook url must use http or https"}}

  defp validate_allowlist(host) do
    allowed_hosts = config().allowed_hosts

    if allowed_hosts == [] or Enum.any?(allowed_hosts, &host_allowed?(host, &1)) do
      :ok
    else
      {:error, {:policy, "webhook host #{host} is not allowlisted"}}
    end
  end

  defp validate_network_boundary(host) do
    if config().allow_private_networks do
      :ok
    else
      host
      |> addresses_for_host()
      |> reject_private_addresses(host)
    end
  end

  defp addresses_for_host(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} -> {:ok, [address]}
      {:error, _reason} -> resolve_host(host)
    end
  end

  defp resolve_host("localhost"), do: {:ok, [{127, 0, 0, 1}]}

  defp resolve_host(host) do
    if config().resolve_dns do
      case lookup_addresses(host) do
        [] -> {:error, {:policy, "webhook host #{host} could not be resolved"}}
        addresses -> {:ok, addresses}
      end
    else
      {:ok, []}
    end
  end

  defp lookup_addresses(host) do
    Enum.flat_map([:inet, :inet6], fn family ->
      case :inet.getaddrs(String.to_charlist(host), family) do
        {:ok, addresses} -> addresses
        {:error, _reason} -> []
      end
    end)
  end

  defp reject_private_addresses({:ok, addresses}, host) do
    if Enum.any?(addresses, &private_address?/1) do
      {:error, {:policy, "webhook host #{host} resolves to a private network"}}
    else
      :ok
    end
  end

  defp reject_private_addresses({:error, reason}, _host), do: {:error, reason}

  defp private_address?({10, _, _, _}), do: true
  defp private_address?({127, _, _, _}), do: true
  defp private_address?({169, 254, _, _}), do: true
  defp private_address?({172, second, _, _}) when second in 16..31, do: true
  defp private_address?({192, 0, 0, _}), do: true
  defp private_address?({192, 168, _, _}), do: true
  defp private_address?({198, second, _, _}) when second in 18..19, do: true
  defp private_address?({198, 51, 100, _}), do: true
  defp private_address?({203, 0, 113, _}), do: true
  defp private_address?({first, _, _, _}) when first == 0 or first >= 224, do: true
  defp private_address?({100, second, _, _}) when second in 64..127, do: true
  defp private_address?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp private_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp private_address?({first, _, _, _, _, _, _, _}) when (first &&& 0xFE00) == 0xFC00, do: true
  defp private_address?({first, _, _, _, _, _, _, _}) when (first &&& 0xFFC0) == 0xFE80, do: true
  defp private_address?(_address), do: false

  defp host_allowed?(host, "*." <> suffix), do: String.ends_with?(host, "." <> suffix)
  defp host_allowed?(host, allowed_host), do: host == allowed_host

  defp config do
    raw = Application.get_env(:pulse_ops, :webhook_security, %{})

    %{
      allowed_hosts:
        raw
        |> config_value(:allowed_hosts, Map.fetch!(@default_config, :allowed_hosts))
        |> normalize_allowed_hosts(),
      allow_http: boolean_config(raw, :allow_http),
      allow_private_networks: boolean_config(raw, :allow_private_networks),
      resolve_dns: boolean_config(raw, :resolve_dns)
    }
  end

  defp normalize_allowed_hosts(hosts) when is_binary(hosts) do
    hosts
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> normalize_allowed_hosts()
  end

  defp normalize_allowed_hosts(hosts) when is_list(hosts) do
    hosts
    |> Enum.map(&String.downcase(to_string(&1)))
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_allowed_hosts(_hosts), do: []

  defp boolean_config(raw, key) do
    value = config_value(raw, key, Map.fetch!(@default_config, key))

    value in [true, "true", "1", 1]
  end

  defp config_value(raw, key, default) do
    cond do
      Map.has_key?(raw, key) -> Map.fetch!(raw, key)
      Map.has_key?(raw, Atom.to_string(key)) -> Map.fetch!(raw, Atom.to_string(key))
      true -> default
    end
  end
end
