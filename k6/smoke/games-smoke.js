import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import { baseUrl, timeoutMs } from '../shared/env.js';

// User API routes (for authentication)
const USER_REGISTER_PATH = '/user/auth/register';
const USER_LOGIN_PATH = '/user/auth/login';

// Games API routes
const GAMES_BASE_PATH = '/games/api/game';
const GAMES_LIST_PATH = '/games/api/game';
const GAMES_PURCHASE_PATH = '/games/api/game/purchase';

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

  // Register + login admin to get token
  const headers = { 'Content-Type': 'application/json' };
  const uniqueEmail = `k6admin${Date.now()}@test.com`;
  const uniqueUser = `k6admin${Date.now()}`;

  const adminRegPayload = JSON.stringify({
    name: 'Admin Smoke Games',
    email: uniqueEmail,
    username: uniqueUser,
    password: 'Admin@123',
    role: 'Admin',
  });

  console.log(`🔄 Tentando registrar admin: ${uniqueEmail}`);
  const regRes = http.post(`${base}${USER_REGISTER_PATH}`, adminRegPayload, { headers, timeout });
  console.log(`📊 Register Status: ${regRes.status} ${regRes.body.substring(0, 100)}`);
  
  check(regRes, {
    'admin register ok (201/400)': (r) => [201, 400].includes(r.status),
  });

  const loginPayload = JSON.stringify({
    email: uniqueEmail,
    password: 'Admin@123',
  });

  console.log(`🔄 Tentando fazer login com: ${uniqueEmail}`);
  const loginRes = http.post(`${base}${USER_LOGIN_PATH}`, loginPayload, { headers, timeout });
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
  
  // Headers for authenticated requests - NO Content-Type for GET
  const authHeaders = {
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };

  const postHeaders = {
    'Content-Type': 'application/json',
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };

  // 1. List games (GET - requires token)
  const listRes = http.get(
    `${base}${GAMES_LIST_PATH}?PageNumber=1&PageSize=10&SortBy=&SortDirection=ASC&Filter=`,
    { headers: authHeaders, timeout },
  );

  check(listRes, {
    'game list reachable': (r) => [200, 403, 503].includes(r.status),
    'game list success': (r) => r.status === 200,
  });

  if (listRes.status >= 400 && __ITER === 0) {
    console.log(`⚠️ Game list check: status=${listRes.status} body=${(listRes.body || '').substring(0, 300)}`);
  }

  // Skip create/purchase if service is unavailable
  if (listRes.status === 503) {
    console.log('⚠️ Games API is unavailable (503) - skipping create and purchase tests');
    sleep(1);
    return;
  }

  // 2. Create a game (POST - requires token and Admin role)
  const gamePayload = JSON.stringify({
    name: `Smoke Test Game ${Date.now()}`,
    releaseDate: '2025-06-01',
    ageRating: 'T',
    description: 'Game Description',
    developerInfo: {
      developer: 'Developer Name',
      publisher: 'Publisher Name',
    },
    diskSize: 50,
    price: 59.99,
    playtime: {
      hours: 10,
      playerCount: 1,
    },
    gameDetails: {
      genre: 'Action',
      platforms: [
        'Xbox One',
        'Android',
        'VR (HTC Vive)',
        'Wii U',
        'Stadia',
        'iOS',
        'PlayStation Vita',
        'Nintendo Switch',
        'PC',
        'VR (Oculus Quest)',
        'Browser',
        'PlayStation 5',
        'PlayStation 4',
        'Xbox Series X|S',
        'Linux',
        'Steam Deck',
        'VR (PlayStation VR)',
        'Nintendo 3DS',
        'macOS',
      ],
      tags: 'Tags',
      gameMode: 'Casual',
      distributionFormat: 'Physical',
      availableLanguages: 'EN-US',
      supportsDlcs: true,
    },
    systemRequirements: {
      minimum: 'Minimum Requirements',
      recommended: 'Recommended Requirements',
    },
    rating: 4.5,
    officialLink: 'https://example.com',
    gameStatus: 'In Development',
  });

  const createRes = http.post(`${base}${GAMES_BASE_PATH}`, gamePayload, { headers: postHeaders, timeout });
  
  check(createRes, {
    'game create reachable': (r) => [201, 400, 403].includes(r.status),
    'game create success': (r) => r.status === 201,
  });

  if (createRes.status === 400 && __ITER === 0) {
    console.log(`❌ CREATE GAME ERROR: ${createRes.body}`);
  } else if (createRes.status >= 400 && __ITER === 0) {
    console.log(`⚠️ Game create check: status=${createRes.status} body=${(createRes.body || '').substring(0, 300)}`);
  }

  // If game was created, try to get it by ID and purchase it
  let gameId = null;
  if (createRes.status === 201) {
    const gameData = JSON.parse(createRes.body);
    gameId = gameData.id;
    console.log(`✅ Game created with ID: ${gameId}`);

    // 3. Get game by ID (GET - requires token)
    const getRes = http.get(`${base}${GAMES_BASE_PATH}/${gameId}`, { headers: authHeaders, timeout });
    
    check(getRes, {
      'game get by id reachable': (r) => [200, 403, 404].includes(r.status),
      'game get by id success': (r) => r.status === 200,
    });

    if (getRes.status >= 400 && __ITER === 0) {
      console.log(`⚠️ Game get by ID: status=${getRes.status} body=${(getRes.body || '').substring(0, 300)}`);
    }

    // 4. Purchase game (POST - requires token)
    const purchasePayload = JSON.stringify({
      gameId: gameId,
      paymentMethod: {
        method: 'credit_card',
        cardLast4Digits: '9246',
      },
    });

    const purchaseRes = http.post(`${base}${GAMES_PURCHASE_PATH}`, purchasePayload, { headers: postHeaders, timeout });
    
    check(purchaseRes, {
      'game purchase reachable': (r) => [201, 400, 403].includes(r.status),
      'game purchase success': (r) => r.status === 201,
    });

    if (purchaseRes.status === 400 && __ITER === 0) {
      console.log(`❌ PURCHASE GAME ERROR: ${purchaseRes.body}`);
    } else if (purchaseRes.status >= 400 && __ITER === 0) {
      console.log(`⚠️ Game purchase: status=${purchaseRes.status} body=${(purchaseRes.body || '').substring(0, 300)}`);
    }
  }

  sleep(1);
}
