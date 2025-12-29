import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, timeoutMs } from '../shared/env.js';

export const options = {
  vus: 1,
  duration: '1m',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
};

export default function () {
  const res = http.get(`${baseUrl()}/health`, { timeout: `${timeoutMs()}ms` });
  check(res, {
    'health status 2xx': (r) => r.status >= 200 && r.status < 300,
  });
  sleep(1);
}
