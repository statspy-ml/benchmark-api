import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Trend } from "k6/metrics";
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";

// Métricas customizadas
const errorCounter = new Counter("errors");
const responseTime = new Trend("response_time");

export const options = {
  stages: [
    { duration: "30s", target: 100 },
    { duration: "2m", target: 500 },
    { duration: "5m", target: 1000 },
    { duration: "10m", target: 1000 },
    { duration: "1m", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<500", "p(99)<1000"],
    http_req_failed: ["rate<0.01"],
  },
  summaryTrendStats: ["min", "avg", "med", "max", "p(90)", "p(95)", "p(99)"],
};

const APIS = {
  fastapi: "http://fastapi:8000",
  litestar: "http://litestar:8000",
  go: "http://go:8000",
  "go-fiber": "http://go-fiber:8000",
  "go-gin": "http://go-gin:8000",
};

const API_TO_TEST = __ENV.API || "fastapi";

export default function () {
  const url = `${APIS[API_TO_TEST]}/calculate`;

  const payload = JSON.stringify({
    a: Math.floor(Math.random() * 1000),
    b: Math.floor(Math.random() * 1000),
  });

  const params = {
    headers: { "Content-Type": "application/json" },
  };

  const res = http.post(url, payload, params);

  const success = check(res, {
    "status is 200": (r) => r.status === 200,
    "has result": (r) => {
      try {
        return JSON.parse(r.body).result !== undefined;
      } catch {
        return false;
      }
    },
  });

  if (!success) {
    errorCounter.add(1);
  }

  responseTime.add(res.timings.duration);
  sleep(0.1);
}

export function handleSummary(data) {
  const api = __ENV.API || "fastapi";
  const timestamp =
    __ENV.TIMESTAMP || new Date().toISOString().replace(/[:.]/g, "-");

  return {
    [`/results/${api}_report_${timestamp}.html`]: htmlReport(data),
    stdout: textSummary(data, { indent: " ", enableColors: false }),
  };
}
