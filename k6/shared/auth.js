import http from 'k6/http';
import { check } from 'k6';
import { authHeaderOverride, authTokenPath } from './env.js';

export function buildAuthHeaders(base, username, password, timeoutMs) {
  if (authHeaderOverride()) {
    return { Authorization: authHeaderOverride() };
  }
  if (!username || !password) {
    return {};
  }

  const res = http.post(
    `${base}${authTokenPath()}`,
    JSON.stringify({ username, password }),
    {
      headers: { 'Content-Type': 'application/json' },
      timeout: `${timeoutMs}ms`,
    }
  );

  check(res, {
    'auth status is 200': (r) => r.status === 200,
    'auth has access token': (r) => Boolean(r.json('access_token')),
  });

  const token = res.json('access_token');
  if (!token) {
    throw new Error('No access_token returned by auth endpoint');
  }

  return { Authorization: `Bearer ${token}` };
}
