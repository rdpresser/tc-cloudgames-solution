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
  
  // Try to register new unique admin user for THIS test run
  const uniqueEmail = `k6admin${Date.now()}@test.com`;
  const adminRegPayload = JSON.stringify({
    name: 'Admin Test User',
    email: uniqueEmail,
    username: `k6admin${Date.now()}`,
    password: 'Admin@123',
    role: 'Admin',
  });
  
  console.log(`🔄 Tentando registrar admin: ${uniqueEmail}`);
  const regRes = http.post(`${base}${REGISTER_PATH}`, adminRegPayload, { headers, timeout: `${timeoutMs()}ms` });
  console.log(`📊 Register Status: ${regRes.status} ${regRes.body.substring(0, 100)}`);
  
  // If registration succeeds (201), login with the new user to get token
  if (regRes.status === 201) {
    console.log(`✅ Admin criado: ${uniqueEmail}`);
    const loginPayload = JSON.stringify({
      email: uniqueEmail,
      password: 'Admin@123',
    });
    
    console.log(`🔄 Tentando fazer login com: ${uniqueEmail}`);
    const loginRes = http.post(`${base}${LOGIN_PATH}`, loginPayload, { headers, timeout: `${timeoutMs()}ms` });
    console.log(`📊 Login Status: ${loginRes.status}`);
    
    if (loginRes.status === 200) {
      const body = JSON.parse(loginRes.body);
      console.log('✅ Token obtido com sucesso!');
      return { token: body.jwtToken };
    } else {
      console.error(`❌ Login falhou com status ${loginRes.status}: ${loginRes.body.substring(0, 200)}`);
    }
  } else {
    console.error(`❌ Registro falhou com status ${regRes.status}: ${regRes.body.substring(0, 200)}`);
  }
  
  console.error('❌ Falha ao obter token - testes LIST vão falhar!');
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
    const listRes = http.get(`${base}${USERS_PATH}?PageNumber=1&PageSize=100&SortBy=&SortDirection=ASC&Filter=`, { headers, timeout });
    check(listRes, { 'list status ok': (r) => [200, 403].includes(r.status) });
  } else if (operation === 1) {
    // Register and login new user (stress test auth endpoint)
    const uniqueId = `${__VU}${__ITER}${Date.now()}${Math.random().toString(36).substring(7)}`;
    const authEmail = `k6auth${uniqueId}@test.com`;
    const authPassword = 'Auth@123';
    
    // First register a new user
    const authRegPayload = JSON.stringify({
      name: 'Auth Test User',
      email: authEmail,
      username: `k6auth${uniqueId}`,
      password: authPassword,
      role: 'User',
    });
    const authRegRes = http.post(`${base}${REGISTER_PATH}`, authRegPayload, { headers: { 'Content-Type': 'application/json' }, timeout });
    check(authRegRes, { 'auth register ok': (r) => [201, 400].includes(r.status) });
    
    // Then login with new credentials
    if (authRegRes.status === 201 || authRegRes.status === 400) {
      const loginPayload = JSON.stringify({
        email: authEmail,
        password: authPassword,
      });
      const loginRes = http.post(`${base}${LOGIN_PATH}`, loginPayload, { headers: { 'Content-Type': 'application/json' }, timeout });
      check(loginRes, { 'login status ok': (r) => [200, 401].includes(r.status) });
    }
  } else {
    // Register new User account
    const uniqueId = `${__VU}${__ITER}${Date.now()}${Math.random().toString(36).substring(7)}`;
    const regPayload = JSON.stringify({
      name: 'Load Test User',
      email: `k6user${uniqueId}@test.com`,
      username: `k6user${uniqueId}`,
      password: 'LoadTest@123',
      role: 'User',
    });
    const regRes = http.post(`${base}${REGISTER_PATH}`, regPayload, { headers: { 'Content-Type': 'application/json' }, timeout });
    check(regRes, { 'register status ok': (r) => [201, 400].includes(r.status) });
  }

  sleep(0.5);
}
