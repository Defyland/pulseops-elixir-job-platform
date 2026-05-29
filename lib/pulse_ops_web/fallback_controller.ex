defmodule PulseOpsWeb.FallbackController do
  use PulseOpsWeb, :controller

  alias PulseOpsWeb.ErrorResponse

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    ErrorResponse.send(
      conn,
      422,
      "validation_error",
      "Request validation failed",
      translate_errors(changeset)
    )
  end

  def call(conn, {:error, :not_found}) do
    ErrorResponse.send(conn, 404, "not_found", "Resource not found")
  end

  def call(conn, {:error, :unauthorized}) do
    ErrorResponse.send(conn, 401, "unauthorized", "Authentication failed")
  end

  def call(conn, {:error, {:bad_request, message}}) do
    ErrorResponse.send(conn, 400, "bad_request", message)
  end

  def call(conn, {:error, {:conflict, message}}) do
    ErrorResponse.send(conn, 409, "conflict", message)
  end

  def call(conn, {:error, message}) when is_binary(message) do
    ErrorResponse.send(conn, 400, "bad_request", message)
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
