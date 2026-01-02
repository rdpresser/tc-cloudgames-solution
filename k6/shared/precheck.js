import http from 'k6/http';
import { check, sleep } from 'k6';

// Prewarm health endpoint with retries and tagging so thresholds can exclude warmup.
export function prewarmHealth(base, timeoutMs, attempts = 10, intervalSec = 3) {
  for (let i = 1; i <= attempts; i++) {
    const res = http.get(`${base}/health`, { timeout: `${timeoutMs}ms`, tags: { warmup: 'true' } });
    const ok = res.status >= 200 && res.status < 300;
    check(res, { 'warmup health 2xx': () => ok });
    if (ok) return true;
    sleep(intervalSec);
  }
  return false;
}
