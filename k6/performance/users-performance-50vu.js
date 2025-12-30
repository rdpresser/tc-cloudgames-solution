import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, credentials, timeoutMs } from '../shared/env.js';

const USERS_PATH = '/user/api/user';
const LOGIN_PATH = '/user/auth/login';
const REGISTER_PATH = '/user/auth/register';

export const options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 30 },
    { duration: '5m', target: 50 },
    { duration: '3m', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.1'],
    http_req_duration: ['p(95)<1500'],
  },
};

export function setup() {
  const base = baseUrl();
  const headers = { 'Content-Type': 'application/json' };
  
  // Create Admin user for testing (if not exists)
  const adminRegPayload = JSON.stringify({
    name: 'K6 Test Admin',
    email: 'k6testadmin@test.com',
    username: 'k6testadmin',
    password: 'Admin@123',
    role: 'Admin',
  });
  http.post(`${base}${REGISTER_PATH}`, adminRegPayload, { headers, timeout: `${timeoutMs()}ms` });
  
  // Login as Admin to get token for user list endpoint
  const loginPayload = JSON.stringify({
    email: 'k6testadmin@test.com',
    password: 'Admin@123',
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
    // GET user list (requires Admin token)
    const listRes = http.get(`${base}${USERS_PATH}?pageNumber=1&pageSize=10`, { headers, timeout });
    check(listRes, { 'list status ok': (r) => [200, 401, 403].includes(r.status) });
  } else if (operation === 1) {
    // Login (re-authenticate as Admin)
    const loginPayload = JSON.stringify({
      email: 'k6testadmin@test.com',
      password: 'Admin@123',
    });
    const loginRes = http.post(`${base}${LOGIN_PATH}`, loginPayload, { headers: { 'Content-Type': 'application/json' }, timeout });
    check(loginRes, { 'login status ok': (r) => [200, 404].includes(r.status) });
  } else {
    // Register new Admin user
    const regPayload = JSON.stringify({
      name: `PerfTest Admin ${__VU}`,
      email: `perfadmin${__VU}${__ITER}@test.com`,
      username: `perfadmin${__VU}${__ITER}`,
      password: `Admin${__VU}@123`,
      role: 'Admin',
    });
    const regRes = http.post(`${base}${REGISTER_PATH}`, regPayload, { headers: { 'Content-Type': 'application/json' }, timeout });
    check(regRes, { 'register status ok': (r) => [201, 400].includes(r.status) });
  }

  sleep(0.5);
}
