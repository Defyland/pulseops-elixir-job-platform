# State Machines

## Job Lifecycle

```text
queued
  -> running
  -> succeeded

queued
  -> running
  -> retryable
  -> running
  -> dead_lettered

queued | retryable | running
  -> cancelled

dead_lettered
  -> retryable
  -> running
```

Terminal states:

- `succeeded`
- `dead_lettered`
- `cancelled`

Rules:

- `queued` means the API accepted the job and scheduled execution.
- `running` means a worker attempt started.
- `retryable` means execution failed but the retry budget may continue.
- `succeeded` means the job completed successfully.
- `dead_lettered` means automatic execution is exhausted or unsafe.
- `cancelled` means an authorized operation stopped future execution.
- Retrying a terminal failure must create audit evidence.

## Attempt Lifecycle

```text
started
  -> succeeded
  -> failed
  -> dead_lettered
  -> cancelled
```

Rules:

- Attempts are execution evidence for a single worker try.
- Attempt number is unique per job.
- Attempt errors must preserve failure kind and message.

## Webhook Delivery Lifecycle

```text
validated
  -> delivered
  -> retryable_failure
  -> policy_discard
  -> circuit_open
```

Rules:

- Policy failures are not retried as transient network failures.
- Circuit-open failures protect workers from repeated slow or failing hosts.
- Correlation ID is propagated to outbound webhook requests.

## Replay Lifecycle

Replay is intentionally not a public endpoint in the current slice.

Required future states:

```text
requested
  -> dry_run_validated
  -> approved
  -> enqueued
  -> rejected
```

Replay must preserve original job history and add a new audit trail for the
operator action.
