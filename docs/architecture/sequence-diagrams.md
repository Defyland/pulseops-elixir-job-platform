# Sequence Diagrams

## Create Job

```text
Client
  -> PulseOpsWeb.JobController
  -> ApiKeyAuth plug
  -> ApiRateLimit plug
  -> PulseOps.Jobs.create_job
  -> PostgreSQL transaction
      -> insert jobs
      -> insert oban_jobs
      -> insert job_events job.created
  <- 201 Created
```

Why this order matters:

- Authentication and rate limiting happen before domain writes.
- Public job state and executor scheduling are created in one transaction.
- `job.created` is emitted as audit evidence for the accepted request.

## Execute Job Successfully

```text
Oban
  -> PulseOps.Jobs.ExecutionWorker
  -> PulseOps.Jobs.Handler
  -> PostgreSQL
      -> insert/update job_attempts
      -> update jobs to succeeded
      -> insert job_events job.succeeded
  -> Telemetry
  -> Prometheus metrics
```

Why this order matters:

- Oban owns execution scheduling.
- PulseOps owns public state and audit history.
- Metrics and logs carry queue, job, organization, and correlation context.

## Dead-Letter Job

```text
Oban attempt fails
  -> ExecutionWorker records failed attempt
  -> retry budget remains?
      yes -> jobs.status = retryable, job.failed event
      no  -> jobs.status = dead_lettered, job.dead_lettered event
  -> alert evaluates dead-letter rate
```

Why this order matters:

- Transient failures and final failures have different operational responses.
- Dead-lettered jobs require operator review instead of silent replay.

## Reconcile Terminal State

```text
Reconciler tick
  -> find public jobs stuck running
  -> inspect terminal oban_jobs rows
  -> lock public job row
  -> update terminal status
  -> upsert attempt evidence
  -> append reconciled terminal event
```

Why this order matters:

- The reconciler repairs divergence without deleting historical evidence.
- The lock prevents concurrent repair from duplicating terminal events.

## Webhook Job

```text
ExecutionWorker
  -> WebhookSecurity validates URL and host
  -> WebhookCircuitBreaker checks host state
  -> Req outbound request with x-correlation-id
  -> success: job.succeeded
  -> non-2xx/transient: retryable or dead_lettered
  -> policy violation: discarded/dead_lettered with reason
```

Why this order matters:

- SSRF and private-network controls run before egress.
- Circuit breaking protects workers from repeated slow or failing destinations.
