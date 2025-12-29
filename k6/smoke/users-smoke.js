import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, timeoutMs, credentials } from '../shared/env.js';

export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    'checks': ['rate>0.95'],
    http_req_duration: ['p(95)<1500'],
  },
};

export default function () {
  const base = baseUrl();
  const timeout = `${timeoutMs()}ms`;
  const headers = { 'Content-Type': 'application/json' };

  // 1. Check health endpoint
  const healthRes = http.get(`${base}/user/health`, { timeout });
  check(healthRes, {
    'health reachable': (r) => r.status === 200 || r.status === 404,
  });

  // 2. Attempt login with existing credentials
  const creds = credentials();
  const loginPayload = JSON.stringify({
    email: creds.username,
    password: creds.password,
  });
  const loginRes = http.post(`${base}/user/auth/login`, loginPayload, { 
    headers, 
    timeout,
  });
  
  check(loginRes, {
    'login succeeds': (r) => r.status === 200,
    'login endpoint exists': (r) => r.status !== 404,
  });

  sleep(1);
}
