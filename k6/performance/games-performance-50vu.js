import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, timeoutMs } from '../shared/env.js';

// User API routes (for authentication)
const USER_REGISTER_PATH = '/user/auth/register';
const USER_LOGIN_PATH = '/user/auth/login';

// Games API routes
const GAMES_BASE_PATH = '/games/api/game';
const GAMES_LIST_PATH = '/games/api/game';
const GAMES_PURCHASE_PATH = '/games/api/game/purchase';

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
  
  // Register new unique admin user for THIS test run
  const uniqueEmail = `k6admin${Date.now()}@test.com`;
  const adminRegPayload = JSON.stringify({
    name: 'Admin Performance Games',
    email: uniqueEmail,
    username: `k6admin${Date.now()}`,
    password: 'Admin@123',
    role: 'Admin',
  });
  
  console.log(`🔄 Tentando registrar admin: ${uniqueEmail}`);
  const regRes = http.post(`${base}${USER_REGISTER_PATH}`, adminRegPayload, { headers, timeout: `${timeoutMs()}ms` });
  console.log(`📊 Register Status: ${regRes.status} ${regRes.body.substring(0, 100)}`);
  
  if (regRes.status === 201) {
    console.log(`✅ Admin criado: ${uniqueEmail}`);
    const loginPayload = JSON.stringify({
      email: uniqueEmail,
      password: 'Admin@123',
    });
    
    console.log(`🔄 Tentando fazer login com: ${uniqueEmail}`);
    const loginRes = http.post(`${base}${USER_LOGIN_PATH}`, loginPayload, { headers, timeout: `${timeoutMs()}ms` });
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
  
  console.error('❌ Falha ao obter token - testes vão falhar!');
  return { token: null };
}

export default function (data) {
  const base = baseUrl();
  const timeout = `${timeoutMs()}ms`;

  // GET game list (requires token) - NO Content-Type for GET
  const headers = {
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };
  const listRes = http.get(`${base}${GAMES_LIST_PATH}?PageNumber=1&PageSize=10&SortBy=&SortDirection=ASC&Filter=`, { headers, timeout });
  check(listRes, { 
    'game list status ok': (r) => [200, 403, 503].includes(r.status),
    'game list success': (r) => r.status === 200,
  });

  sleep(0.5);
}
