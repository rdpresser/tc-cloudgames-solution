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

  // Health check before running steps (no token required)
  console.log('🔄 Verificando health endpoint...');
  const healthRes = http.get(`${base}${HEALTH_PATH}`, { timeout });
  console.log(`📊 Health Status: ${healthRes.status}`);
  check(healthRes, {
    'health reachable': (r) => r.status === 200 || r.status === 404,
  });

  // Register + login admin on-the-fly (same pattern as performance tests)
  const headers = { 'Content-Type': 'application/json' };
  const uniqueEmail = `k6admin${Date.now()}@test.com`;
  const uniqueUser = `k6admin${Date.now()}`;

  // Nome não pode conter números conforme requisito
  const adminRegPayload = JSON.stringify({
    name: 'Admin Smoke User',
    email: uniqueEmail,
    username: uniqueUser,
    password: 'Admin@123',
    role: 'Admin',
  });

  console.log(`🔄 Tentando registrar admin: ${uniqueEmail}`);
  const regRes = http.post(`${base}${REGISTER_PATH}`, adminRegPayload, { headers, timeout });
  console.log(`📊 Register Status: ${regRes.status} ${regRes.body.substring(0, 100)}`);
  
  check(regRes, {
    'admin register ok (201/400)': (r) => [201, 400].includes(r.status),
  });

  // If already exists (400) or created (201), login to get token
  const loginPayload = JSON.stringify({
    email: uniqueEmail,
    password: 'Admin@123',
  });

  console.log(`🔄 Tentando fazer login com: ${uniqueEmail}`);
  const loginRes = http.post(`${base}${LOGIN_PATH}`, loginPayload, { headers, timeout });
  console.log(`📊 Login Status: ${loginRes.status}`);
  
  check(loginRes, {
    'login endpoint exists': (r) => r.status !== 404,
    'login succeeds': (r) => r.status === 200,
  });

  if (loginRes.status !== 200) {
    console.error(`❌ Login falhou com status ${loginRes.status}: ${loginRes.body.substring(0, 200)}`);
    fail(`Login failed with status ${loginRes.status}`);
  }

  const body = JSON.parse(loginRes.body || '{}');
  if (!body?.jwtToken) {
    console.error('❌ Token não retornado no login');
    fail('Login succeeded but jwtToken was not returned');
  }

  console.log('✅ Token obtido com sucesso!');
  return { token: body.jwtToken };
}

export default function (data) {
  const base = baseUrl();
  const timeout = `${timeoutMs()}ms`;
  
  // GET request - only needs Authorization header, no Content-Type for GET
  const headers = {
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };

  // GET list with same route/query pattern used in performance tests
  // This endpoint requires token (reuses the same token from setup)
  const listRes = http.get(
    `${base}${USERS_PATH}?PageNumber=1&PageSize=100&SortBy=&SortDirection=ASC&Filter=`,
    { headers, timeout },
  );

  check(listRes, {
    'user list reachable': (r) => r.status === 200 || r.status === 403,
    'user list success': (r) => r.status === 200,
  });

  if (listRes.status >= 400 && __ITER === 0) {
    console.log(`⚠️ User list check: status=${listRes.status} body=${(listRes.body || '').substring(0, 300)}`);
  }

  sleep(1);
}
