defmodule PulseOps.Jobs.WebhookSecurityTest do
  use ExUnit.Case, async: false

  alias PulseOps.Jobs.{WebhookCircuitBreaker, WebhookSecurity}
  alias PulseOps.Jobs.WebhookSecurity.ApprovedUrl

  setup do
    previous = Application.get_env(:pulse_ops, :webhook_security)

    on_exit(fn ->
      Application.put_env(:pulse_ops, :webhook_security, previous)
      WebhookCircuitBreaker.reset!()
    end)

    WebhookCircuitBreaker.reset!()
    :ok
  end

  test "rejects private network destinations unless explicitly allowed" do
    put_webhook_config(%{
      allow_http: true,
      allow_private_networks: false,
      resolve_dns: false
    })

    assert {:error, {:policy, reason}} = WebhookSecurity.validate_url("http://127.0.0.1/hooks")
    assert reason =~ "private network"

    assert {:error, {:policy, ipv6_reason}} = WebhookSecurity.validate_url("https://[::1]/hooks")
    assert ipv6_reason =~ "private network"
  end

  test "enforces exact and wildcard host allowlists" do
    put_webhook_config(%{
      allowed_hosts: ["hooks.example.com", "*.tenant.example.com"],
      resolve_dns: false
    })

    assert {:ok, _uri} = WebhookSecurity.validate_url("https://hooks.example.com/jobs")
    assert {:ok, _uri} = WebhookSecurity.validate_url("https://acme.tenant.example.com/jobs")

    assert {:error, {:policy, reason}} =
             WebhookSecurity.validate_url("https://evil.example.com/jobs")

    assert reason =~ "not allowlisted"
  end

  test "approves webhooks with pinned connect uri after deterministic DNS validation" do
    put_webhook_config(%{
      allowed_hosts: ["hooks.example.com"],
      resolve_dns: true,
      resolved_hosts: %{"hooks.example.com" => ["93.184.216.34"]}
    })

    assert {:ok, approved_url} =
             WebhookSecurity.approve_url("https://hooks.example.com/jobs")

    assert approved_url.host == "hooks.example.com"
    assert URI.to_string(approved_url.connect_uri) == "https://93.184.216.34/jobs"
    assert approved_url.addresses == [{93, 184, 216, 34}]

    connect_options = ApprovedUrl.connect_options(approved_url, 1_500)
    assert connect_options[:hostname] == "hooks.example.com"
    assert connect_options[:timeout] == 1_500
  end

  test "rejects hosts that resolve to configured private addresses" do
    put_webhook_config(%{
      allowed_hosts: ["hooks.example.com"],
      resolve_dns: true,
      resolved_hosts: %{"hooks.example.com" => ["10.0.0.10"]}
    })

    assert {:error, {:policy, reason}} =
             WebhookSecurity.approve_url("https://hooks.example.com/jobs")

    assert reason =~ "private network"
  end

  test "opens webhook circuit after the configured failure threshold" do
    put_webhook_config(%{
      circuit_breaker: %{failure_threshold: 2, reset_after_ms: 100}
    })

    assert :ok = WebhookCircuitBreaker.allow?("hooks.example.com", 1_000)
    assert :ok = WebhookCircuitBreaker.record_failure("hooks.example.com", 1_000)
    assert :ok = WebhookCircuitBreaker.allow?("hooks.example.com", 1_001)
    assert :ok = WebhookCircuitBreaker.record_failure("hooks.example.com", 1_002)

    assert {:error, {:circuit_open, reason, retry_after_ms}} =
             WebhookCircuitBreaker.allow?("hooks.example.com", 1_003)

    assert reason =~ "webhook circuit open"
    assert retry_after_ms > 0
    assert :ok = WebhookCircuitBreaker.allow?("hooks.example.com", 1_200)
  end

  defp put_webhook_config(overrides) do
    Application.put_env(
      :pulse_ops,
      :webhook_security,
      Map.merge(
        %{
          allowed_hosts: [],
          allow_http: false,
          allow_private_networks: false,
          resolve_dns: false,
          circuit_breaker: %{failure_threshold: 5, reset_after_ms: 60_000}
        },
        overrides
      )
    )
  end
end
