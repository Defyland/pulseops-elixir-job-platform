defmodule PulseOps.IdentityTest do
  use PulseOps.DataCase, async: true

  alias PulseOps.Fixtures
  alias PulseOps.Identity
  alias PulseOps.Queues

  test "register_organization provisions the bootstrap queue and authenticates the returned API key" do
    {:ok, result} =
      Identity.register_organization(%{
        "name" => "PulseOps Labs",
        "slug" => "pulseops-labs",
        "retention_days" => 14
      })

    assert result.organization.slug == "pulseops-labs"
    assert result.default_queue.name == "default"

    assert {:ok, organization, api_key} = Identity.authenticate_api_key(result.bootstrap_api_key)
    assert organization.id == result.organization.id
    assert api_key.key_prefix

    assert [%{name: "default"}] = Queues.list_queues(organization)
  end

  test "issue_api_key creates a second usable token" do
    %{organization: organization} = Fixtures.organization_fixture()

    assert {:ok, %{api_key: api_key, token: token}} =
             Identity.issue_api_key(organization, %{"name" => "ci-runner"})

    assert api_key.name == "ci-runner"
    assert {:ok, authed_org, _record} = Identity.authenticate_api_key(token)
    assert authed_org.id == organization.id
  end
end
