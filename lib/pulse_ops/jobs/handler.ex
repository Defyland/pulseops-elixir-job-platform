defmodule PulseOps.Jobs.Handler do
  @moduledoc false

  alias PulseOps.Jobs.{Job, WebhookCircuitBreaker, WebhookSecurity}

  def execute(%Job{} = job, attempt) do
    case job.worker do
      "noop" ->
        {:ok, %{"acknowledged" => true, "attempt" => attempt, "payload" => job.payload}}

      "flaky" ->
        fail_until_attempt = Map.get(job.payload, "fail_until_attempt", 1)

        if attempt <= fail_until_attempt do
          {:error, "simulated transient failure on attempt #{attempt}"}
        else
          {:ok, %{"recovered_on_attempt" => attempt}}
        end

      "crash" ->
        raise "simulated worker crash for job #{job.id}"

      "sleep" ->
        duration_ms = Map.get(job.payload, "duration_ms", 0)

        if duration_ms > job.timeout_ms do
          {:error, "execution exceeded timeout budget of #{job.timeout_ms}ms"}
        else
          Process.sleep(duration_ms)
          {:ok, %{"slept_ms" => duration_ms}}
        end

      "webhook" ->
        execute_webhook(job)
    end
  end

  defp execute_webhook(%Job{} = job) do
    with url when is_binary(url) <- Map.get(job.payload, "url"),
         body <- Map.get(job.payload, "body", %{}),
         {:ok, uri} <- WebhookSecurity.validate_url(url),
         :ok <- WebhookCircuitBreaker.allow?(uri.host) do
      post_webhook(job, uri, body)
    else
      nil -> {:discard, "webhook jobs require payload.url"}
      {:error, {:policy, reason}} -> {:discard, reason}
      {:error, {:circuit_open, reason, _retry_after_ms}} -> {:error, reason}
    end
  end

  defp post_webhook(%Job{} = job, %URI{} = uri, body) do
    case Req.post(
           url: URI.to_string(uri),
           json: body,
           headers: [
             {"x-correlation-id", job.correlation_id},
             {"x-pulseops-job-id", job.id}
           ],
           receive_timeout: job.timeout_ms
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        WebhookCircuitBreaker.record_success(uri.host)
        {:ok, %{"status" => status}}

      {:ok, %{status: status}} ->
        WebhookCircuitBreaker.record_failure(uri.host)
        {:error, "webhook returned HTTP #{status}"}

      {:error, error} ->
        WebhookCircuitBreaker.record_failure(uri.host)
        {:error, Exception.message(error)}
    end
  end
end
