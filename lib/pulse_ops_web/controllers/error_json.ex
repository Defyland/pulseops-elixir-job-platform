defmodule PulseOpsWeb.ErrorJSON do
  @moduledoc false

  def render(template, _assigns) do
    %{
      error: %{
        code: String.trim_trailing(template, ".json"),
        message: Phoenix.Controller.status_message_from_template(template)
      }
    }
  end
end
