import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import { baseUrl, timeoutMs } from '../shared/env.js';

const HEALTH_PATH = '/user/health';
const LOGIN_PATH = '/user/auth/login';
const REGISTER_PATH = '/user/auth/register';
const USERS_PATH = '/user/api/user';

export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<1500'],
  },
};

export function setup() {
  const base = baseUrl();
  const timeout = `${timeoutMs()}ms`;

  // Health check before running steps
  const healthRes = http.get(`${base}${HEALTH_PATH}`, { timeout });
  check(healthRes, {
    'health reachable': (r) => r.status === 200 || r.status === 404,
  });

  // Register + login admin on-the-fly (same pattern as performance tests)
  const headers = { 'Content-Type': 'application/json' };
  const uniqueEmail = `k6admin${Date.now()}@test.com`;
  const uniqueUser = `k6admin${Date.now()}`;

  const adminRegPayload = JSON.stringify({
    name: 'Admin Smoke User',
    email: uniqueEmail,
    username: uniqueUser,
    password: 'Admin@123',
    role: 'Admin',
  });

  const regRes = http.post(`${base}${REGISTER_PATH}`, adminRegPayload, { headers, timeout });
  check(regRes, {
    'admin register ok (201/400)': (r) => [201, 400].includes(r.status),
  });

  // If already exists (400), still try login
  const loginPayload = JSON.stringify({
    email: uniqueEmail,
    password: 'Admin@123',
  });

  const loginRes = http.post(`${base}${LOGIN_PATH}`, loginPayload, { headers, timeout });
  check(loginRes, {
    'login endpoint exists': (r) => r.status !== 404,
    'login succeeds': (r) => r.status === 200,
  });

  if (loginRes.status !== 200) {
    fail(`Login failed with status ${loginRes.status}`);
  }

  const body = JSON.parse(loginRes.body || '{}');
  if (!body?.jwtToken) {
    fail('Login succeeded but jwtToken was not returned');
  }

  return { token: body.jwtToken };
}

export default function (data) {
  const base = baseUrl();
  const timeout = `${timeoutMs()}ms`;
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };

  // GET list with same route/query pattern used in performance tests
  const listRes = http.get(
    `${base}${USERS_PATH}?PageNumber=1&PageSize=100&SortBy=&SortDirection=ASC&Filter=`,
    { headers, timeout },
  );

  check(listRes, {
    'user list reachable (200/403)': (r) => [200, 403].includes(r.status),
  });

  if (listRes.status >= 400 && __ITER === 0) {
    console.log(`User list failed: status=${listRes.status} body=${(listRes.body || '').substring(0, 300)}`);
  }

  sleep(1);
}
