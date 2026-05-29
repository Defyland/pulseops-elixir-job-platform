import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = __ENV.BASE_URL || "http://localhost:4000";

export const options = {
  vus: 1,
  iterations: 5
};

export default function () {
  const response = http.get(`${baseUrl}/healthz`);
  check(response, { "healthz is 200": (r) => r.status === 200 });
  sleep(1);
}
