# k6 performance harness

Root for smoke, load, and performance (breakpoint) tests against the AKS production endpoint.

## Structure
- k6/config/: environment and auth placeholders (no secrets committed)
- k6/shared/: common helpers (env parsing, auth)
- k6/smoke/: lightweight availability checks
- k6/load/: sustained concurrency tests
- k6/performance/: breakpoint/stress-style tests
- k6/data/: optional CSV/JSON payloads
- k6/output/: local artifacts (gitignored)

## Local prerequisites (Windows)
1) Install k6: `choco install k6` (or download MSI from https://k6.io/docs/get-started/installation/).
2) Verify: `k6 version`.
3) No npm install needed—the small .env loader is included in `k6/shared/dotenv.js`.

## Local env file (.env)
- File: `k6/.env` (placeholders, no secrets). Variables:
  - BASE_URL=https://REPLACE_ME
  - USERNAME=REPLACE_ME
  - PASSWORD=REPLACE_ME
  - AUTH_TOKEN_PATH=/api/auth/token
  - AUTH_HEADER=
  - TIMEOUT_MS=2000
- Usage:
  - The scripts read `__ENV` first, then fall back to k6/.env automatically (no CLI flag needed).
  - Override any var explicitly via `-e VAR=...` if you need to change a single value.

## Configuring auth
- Scripts can fetch a token via POST to AUTH_TOKEN_PATH (default `/api/auth/token`) using USERNAME/PASSWORD env vars.
- Override token path if needed: `-e AUTH_TOKEN_PATH=/identity/connect/token`.
- If you already have a token, pass `-e AUTH_HEADER="Bearer <token>"` to skip login.

## Environment variables (examples)
- BASE_URL: required host for the prod API (https://host or https://ip)
- USERNAME, PASSWORD: credentials used to obtain a token
- AUTH_TOKEN_PATH: optional token endpoint path (default /api/auth/token)
- TIMEOUT_MS: request timeout in ms (default 2000)

## Running locally
- Smoke (uses k6/.env fallback): `k6 run k6/smoke/users-smoke.js`
- Load: `k6 run k6/load/users-load.js`
- Performance: `k6 run k6/performance/users-performance.js`
- To override inline: `k6 run -e BASE_URL=https://host -e USERNAME=u -e PASSWORD=p k6/smoke/users-smoke.js`
- Export summary: add `--summary-export=k6/output/summary.json`

## GitHub Actions (prod only)
- Workflow: `.github/workflows/perf-k6.yml` (manual trigger, optional schedule)
- Uses dockerized k6 for reproducibility
- Expects environment-scoped secrets (`prod`):
  - PERF_BASE_URL, PERF_USERNAME, PERF_PASSWORD
  - Optional: PERF_AUTH_TOKEN_PATH, PERF_AUTH_HEADER
- Artifacts: smoke/load/performance summaries uploaded for inspection

## Next tweaks
- Point endpoints in scripts to real API routes.
- Add service-specific scripts (games/payments) following the same pattern.
- Tune stages/thresholds to your SLOs and expected traffic.
