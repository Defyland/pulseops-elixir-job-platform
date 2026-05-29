import http from "k6/http";
import { check } from "k6";

const baseUrl = __ENV.BASE_URL || "http://localhost:4000";
const apiKey = __ENV.PULSEOPS_API_KEY;

export const options = {
  vus: 10,
  duration: "1m",
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<300"]
  }
};

export default function () {
  const payload = JSON.stringify({
    job: {
      queue_name: "default",
      worker: "noop",
      idempotency_key: `${__VU}-${__ITER}`,
      payload: { source: "k6-load", vu: __VU, iter: __ITER }
    }
  });

  const response = http.post(`${baseUrl}/api/v1/jobs`, payload, {
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey
    }
  });

  check(response, {
    "job enqueue is 201 or 200": (r) => r.status === 201 || r.status === 200
  });
}
