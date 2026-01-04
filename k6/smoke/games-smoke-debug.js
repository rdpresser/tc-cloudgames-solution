import http from 'k6/http';
import { check } from 'k6';
import { baseUrl, timeoutMs } from '../shared/env.js';

const USER_REGISTER_PATH = '/user/auth/register';
const USER_LOGIN_PATH = '/user/auth/login';
const GAMES_BASE_PATH = '/games/api/game';

export const options = {
  vus: 1,
  duration: '30s',
};

export function setup() {
  const base = baseUrl();
  const timeout = `${timeoutMs()}ms`;

  const headers = { 'Content-Type': 'application/json' };
  const uniqueEmail = `k6admin${Date.now()}@test.com`;

  const adminRegPayload = JSON.stringify({
    name: 'Admin Smoke Games',
    email: uniqueEmail,
    username: `k6admin${Date.now()}`,
    password: 'Admin@123',
    role: 'Admin',
  });

  const regRes = http.post(`${base}${USER_REGISTER_PATH}`, adminRegPayload, { headers, timeout });
  
  const loginPayload = JSON.stringify({
    email: uniqueEmail,
    password: 'Admin@123',
  });

  const loginRes = http.post(`${base}${USER_LOGIN_PATH}`, loginPayload, { headers, timeout });

  const body = JSON.parse(loginRes.body || '{}');
  return { token: body.jwtToken };
}

export default function (data) {
  const base = baseUrl();
  const timeout = `${timeoutMs()}ms`;
  
  const postHeaders = {
    'Content-Type': 'application/json',
    'Authorization': data.token ? `Bearer ${data.token}` : '',
  };

  // Test simple game payload
  const gamePayload = JSON.stringify({
    name: `Test Game ${Date.now()}`,
    releaseDate: '2025-06-01',
    ageRating: 'T',
    description: 'Test Game Description',
    developerInfo: {
      developer: 'Test Developer',
      publisher: 'Test Publisher',
    },
    diskSize: 50,
    price: 59.99,
    playtime: {
      hours: 10,
      playerCount: 1,
    },
    gameDetails: {
      genre: 'Action',
      platforms: ['PC'],
      tags: 'test',
      gameMode: 'Singleplayer',
      distributionFormat: 'Digital',
      availableLanguages: 'EN-US',
      supportsDlcs: true,
    },
    systemRequirements: {
      minimum: 'Minimum Requirements',
      recommended: 'Recommended Requirements',
    },
    rating: 4.5,
    officialLink: 'https://example.com',
    gameStatus: 'Available',
  });

  console.log(`📝 Payload: ${gamePayload}`);
  
  const createRes = http.post(`${base}${GAMES_BASE_PATH}`, gamePayload, { headers: postHeaders, timeout });
  
  console.log(`📊 Response Status: ${createRes.status}`);
  console.log(`📊 Response Body: ${createRes.body.substring(0, 500)}`);
  
  check(createRes, {
    'game create': (r) => r.status === 201,
  });
}
