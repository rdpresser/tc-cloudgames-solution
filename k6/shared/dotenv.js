// Minimal .env parser for k6 (no external deps). Reads ../.env relative to this file.
const rawEnv = open('../.env');

function parseEnv(content) {
  const result = {};
  if (!content) return result;
  const lines = content.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIndex = trimmed.indexOf('=');
    if (eqIndex === -1) continue;
    const key = trimmed.slice(0, eqIndex).trim();
    const value = trimmed.slice(eqIndex + 1).trim();
    result[key] = value;
  }
  return result;
}

export const localEnv = parseEnv(rawEnv);
