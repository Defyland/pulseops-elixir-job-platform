#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BASE_URL="${BASE_URL:-http://localhost:4000}"
PORT="${PORT:-4000}"
POSTGRES_PORT="${POSTGRES_PORT:-55432}"
export POSTGRES_PORT
SERVER_PID=""
SERVER_LOG="${TMPDIR:-/tmp}/pulseops-demo-server.log"

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID"
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

json_get() {
  python3 -c 'import json,sys; data=json.load(sys.stdin); path=sys.argv[1].split(".");
cur=data
for part in path:
    cur=cur[int(part)] if isinstance(cur, list) else cur[part]
print(cur)' "$1"
}

wait_for_health() {
  for _ in $(seq 1 60); do
    if curl -fsS "$BASE_URL/healthz" >/dev/null 2>&1; then
      return 0
    fi

    sleep 1
  done

  echo "PulseOps did not become healthy. Server log: $SERVER_LOG" >&2
  exit 1
}

require_command docker
require_command curl
require_command mix
require_command python3

echo "Starting PostgreSQL on local port $POSTGRES_PORT..."
docker compose up -d postgres >/dev/null

echo "Preparing database..."
mix deps.get >/dev/null
mix ecto.create --quiet >/dev/null 2>&1 || true
mix ecto.migrate --quiet

if curl -fsS "$BASE_URL/healthz" >/dev/null 2>&1; then
  echo "Using existing PulseOps server at $BASE_URL"
else
  echo "Starting PulseOps server at $BASE_URL"
  PORT="$PORT" API_RATE_LIMIT=100000 mix phx.server >"$SERVER_LOG" 2>&1 &
  SERVER_PID="$!"
  trap cleanup EXIT
  wait_for_health
fi

SLUG="demo-$(date +%s)"

echo "Creating tenant: $SLUG"
ORG_RESPONSE="$(
  curl -fsS -X POST "$BASE_URL/api/v1/organizations" \
    -H "content-type: application/json" \
    -d "{\"organization\":{\"name\":\"PulseOps Demo\",\"slug\":\"$SLUG\",\"retention_days\":7}}"
)"

API_KEY="$(printf '%s' "$ORG_RESPONSE" | json_get "data.bootstrap_api_key")"

echo "Enqueueing job..."
JOB_RESPONSE="$(
  curl -fsS -X POST "$BASE_URL/api/v1/jobs" \
    -H "content-type: application/json" \
    -H "x-api-key: $API_KEY" \
    -d "{\"job\":{\"queue_name\":\"default\",\"worker\":\"noop\",\"idempotency_key\":\"demo-$SLUG\",\"payload\":{\"source\":\"demo\"}}}"
)"

JOB_ID="$(printf '%s' "$JOB_RESPONSE" | json_get "data.id")"

echo "Waiting for job completion: $JOB_ID"
STATUS="unknown"

for _ in $(seq 1 30); do
  JOB_DETAIL="$(curl -fsS -H "x-api-key: $API_KEY" "$BASE_URL/api/v1/jobs/$JOB_ID")"
  STATUS="$(printf '%s' "$JOB_DETAIL" | json_get "data.status")"

  if [[ "$STATUS" == "succeeded" || "$STATUS" == "dead_lettered" || "$STATUS" == "cancelled" ]]; then
    break
  fi

  sleep 1
done

echo "Final job status: $STATUS"

if [[ "$STATUS" != "succeeded" ]]; then
  echo "Expected demo job to succeed." >&2
  exit 1
fi

echo "Lifecycle events:"
curl -fsS -H "x-api-key: $API_KEY" "$BASE_URL/api/v1/jobs/$JOB_ID/events" |
  python3 -c 'import json,sys
events=json.load(sys.stdin)["data"]
for event in events:
    print("- {}: {}".format(event["event_type"], event["status"]))'

echo "Metric sample:"
curl -fsS "$BASE_URL/metrics" |
  grep -E "pulse_ops_job_(created|stop)_count" |
  head -n 5

echo "Demo completed successfully."
