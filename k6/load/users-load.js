import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import { URL } from 'https://jslib.k6.io/url/1.0.0/index.js';
import { baseUrl, credentials, timeoutMs } from '../shared/env.js';

const USERS_PATH = '/user/api/user';
const LOGIN_PATH = '/user/auth/login';

export const options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 25 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<800'],
  },
};

export function setup() {
  const base = baseUrl();
  const headers = { 'Content-Type': 'application/json' };
  const loginPayload = JSON.stringify({
    email: credentials().username,
    password: credentials().password,
  });
  
  const res = http.post(`${base}${LOGIN_PATH}`, loginPayload, { headers, timeout: `${timeoutMs()}ms` });
  if (res.status !== 200) {
    fail(`Login failed with status ${res.status}`);
  }

  const body = JSON.parse(res.body);
  if (!body?.jwtToken) {
    fail('Login succeeded but jwtToken was not returned');
  }

  return { token: body.jwtToken };
}

export default function (data) {
  const base = baseUrl();
  if (!data?.token) {
    fail('Missing bearer token from setup');
  }

  const headers = {
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };

  const url = new URL(USERS_PATH, base);
  url.searchParams.set('pageNumber', '1');
  url.searchParams.set('pageSize', '10');
  url.searchParams.set('sortBy', '');
  url.searchParams.set('sortDirection', 'ASC');
  url.searchParams.set('filter', '');

  // GET user list (paginated, requires Admin role)
  const listRes = http.get(url.toString(), {
    headers,
    timeout: `${timeoutMs()}ms`,
  });
  check(listRes, {
    'user list status 200/401/403': (r) => [200, 401, 403].includes(r.status),
  });

  sleep(1);
}
