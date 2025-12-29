import { sleep } from 'k6';
import { baseUrl, credentials, timeoutMs } from '../shared/env.js';
import { buildAuthHeaders } from '../shared/auth.js';
import { getWithChecks } from '../shared/httpClient.js';

const USERS_PATH = '/api/users';

export const options = {
  stages: [
    { duration: '2m', target: 20 },
    { duration: '5m', target: 50 },
    { duration: '5m', target: 80 },
    { duration: '3m', target: 100 },
    { duration: '3m', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<1200'],
  },
};

export default function () {
  const headers = buildAuthHeaders(baseUrl(), credentials().username, credentials().password, timeoutMs());
  getWithChecks('users list', `${baseUrl()}${USERS_PATH}`, headers, timeoutMs());
  sleep(0.5);
}
