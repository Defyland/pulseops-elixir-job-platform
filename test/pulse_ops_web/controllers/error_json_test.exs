defmodule PulseOpsWeb.ErrorJSONTest do
  use ExUnit.Case, async: true

  alias PulseOpsWeb.ErrorJSON

  test "renders JSON error payloads from status templates" do
    assert ErrorJSON.render("404.json", %{}) == %{
             error: %{
               code: "404",
               message: "Not Found"
             }
           }
  end
end
