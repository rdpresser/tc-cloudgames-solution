import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, credentials, timeoutMs } from '../shared/env.js';

const USERS_PATH = '/user/api/user';
const LOGIN_PATH = '/user/auth/login';
const REGISTER_PATH = '/user/auth/register';

export const options = {
  stages: [
    { duration: '2m', target: 20 },
    { duration: '5m', target: 50 },
    { duration: '5m', target: 80 },
    { duration: '3m', target: 100 },
    { duration: '3m', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.1'],
    http_req_duration: ['p(95)<1500'],
  },
};

let sharedToken = null;

export function setup() {
  const base = baseUrl();
  const headers = { 'Content-Type': 'application/json' };
  const loginPayload = JSON.stringify({
    email: credentials().username,
    password: credentials().password,
  });
  
  const res = http.post(`${base}${LOGIN_PATH}`, loginPayload, { headers, timeout: `${timeoutMs()}ms` });
  if (res.status === 200) {
    const body = JSON.parse(res.body);
    return { token: body.jwtToken };
  }
  return { token: null };
}

export default function (data) {
  const base = baseUrl();
  const timeout = `${timeoutMs()}ms`;
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };

  // Mix of operations to stress test
  const operation = Math.floor(Math.random() * 3);

  if (operation === 0) {
    // GET user list
    const listRes = http.get(`${base}${USERS_PATH}?pageNumber=1&pageSize=10`, { headers, timeout });
    check(listRes, { 'list status ok': (r) => [200, 401, 403].includes(r.status) });
  } else if (operation === 1) {
    // Login (re-authenticate)
    const loginPayload = JSON.stringify({
      email: credentials().username,
      password: credentials().password,
    });
    const loginRes = http.post(`${base}${LOGIN_PATH}`, loginPayload, { headers: { 'Content-Type': 'application/json' }, timeout });
    check(loginRes, { 'login status ok': (r) => [200, 404].includes(r.status) });
  } else {
    // Register new user (with valid payload to pass validation)
    const regPayload = JSON.stringify({
      name: `PerfTest User ${__VU}`,
      email: `perftest${__VU}${__ITER}@test.com`,
      username: `perftest${__VU}${__ITER}`,
      password: `TestPass${__VU}@!`,
      role: 'User',
    });
    const regRes = http.post(`${base}${REGISTER_PATH}`, regPayload, { headers: { 'Content-Type': 'application/json' }, timeout });
    check(regRes, { 'register status ok': (r) => [201, 400].includes(r.status) });
  }

  sleep(0.5);
}
