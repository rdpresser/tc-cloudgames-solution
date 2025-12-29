import http from 'k6/http';
import { check } from 'k6';

export function getWithChecks(name, url, headers, timeoutMs) {
  const res = http.get(url, { headers, timeout: `${timeoutMs}ms` });
  check(res, {
    [`${name} status 2xx`]: (r) => r.status >= 200 && r.status < 300,
    [`${name} body exists`]: (r) => Boolean(r.body),
  });
  return res;
}
