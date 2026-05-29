# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     PulseOps.Repo.insert!(%PulseOps.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias PulseOps.Identity
alias PulseOps.Repo

if Repo.aggregate(PulseOps.Identity.Organization, :count, :id) == 0 do
  {:ok, result} =
    Identity.register_organization(%{
      "name" => "Demo Tenant",
      "slug" => "demo-tenant",
      "retention_days" => 14
    })

  IO.puts("""
  Seeded Demo Tenant
  bootstrap_api_key=#{result.bootstrap_api_key}
  """)
else
  IO.puts("Seed data already exists, skipping.")
end
