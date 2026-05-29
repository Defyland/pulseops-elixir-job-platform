import http from "k6/http";

const baseUrl = __ENV.BASE_URL || "http://localhost:4000";
const apiKey = __ENV.PULSEOPS_API_KEY;

export const options = {
  stages: [
    { duration: "30s", target: 20 },
    { duration: "1m", target: 50 },
    { duration: "30s", target: 0 }
  ]
};

export default function () {
  http.post(
    `${baseUrl}/api/v1/jobs`,
    JSON.stringify({
      job: {
        queue_name: "default",
        worker: "noop",
        idempotency_key: `stress-${__VU}-${__ITER}`,
        payload: { source: "k6-stress" }
      }
    }),
    {
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey
      }
    }
  );
}
