import { localEnv } from './dotenv.js';

function pick(name) {
  // Prefer localEnv (.env file) first, then __ENV (CLI args)
  return localEnv[name] || __ENV[name];
}

export function baseUrl() {
  const val = pick('BASE_URL');
  if (!val) {
    throw new Error('BASE_URL is required (set in __ENV or k6/.env)');
  }
  return val;
}

export function timeoutMs() {
  const val = pick('TIMEOUT_MS');
  return val ? Number(val) : 2000;
}

export function credentials() {
  return {
    username: pick('USERNAME'),
    password: pick('PASSWORD'),
  };
}

export function authTokenPath() {
  return pick('AUTH_TOKEN_PATH') || '/api/auth/token';
}

export function authHeaderOverride() {
  return pick('AUTH_HEADER');
}
