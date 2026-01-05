# k6 Performance Testing Harness

Comprehensive performance testing suite for TC Cloud Games microservices running on AKS. Includes smoke, load, and performance tests for Users, Games, and Payments services.

---

## 📁 Folder Structure

```
k6/
├── config/              # Environment and auth configuration files
│   ├── auth.sample.json
│   └── env.prod.json
├── shared/              # Common utilities and helpers
│   ├── env.js          # Environment variable parser
│   ├── auth.js         # Authentication utilities
│   └── dotenv.js       # .env file loader
├── smoke/               # Smoke tests - 1 VU, 30s duration
│   ├── users-smoke.js
│   ├── games-smoke.js
│   └── games-smoke-debug.js
├── load/                # Load tests - 25 VUs sustained
│   ├── users-load.js
│   └── games-load.js
├── performance/         # Performance tests - 50-100 VUs
│   ├── users-performance.js
│   ├── users-performance-50vu.js
│   └── games-performance-50vu.js
├── data/                # Optional test data (CSV/JSON)
├── output/              # Test results and reports (gitignored)
└── .env                 # Local environment variables (not committed)
```

---

## 🎯 Test Types

### 1️⃣ **Smoke Tests** (1 VU)
- **Purpose**: Verify basic availability and functionality
- **Duration**: 30 seconds
- **Virtual Users**: 1 VU
- **Thresholds**: 
  - Error rate < 5%
  - P95 latency < 1500ms
- **Use Cases**: Quick sanity checks, pre-deployment validation

### 2️⃣ **Load Tests** (25 VUs)
- **Purpose**: Test sustained load with realistic traffic
- **Duration**: 9 minutes (ramp-up → sustained → ramp-down)
- **Virtual Users**: Ramps from 10 → 25 → 0 VUs
- **Stages**:
  - 2 min: Ramp up to 10 VUs
  - 5 min: Sustain 25 VUs
  - 2 min: Ramp down to 0 VUs
- **Thresholds**:
  - Error rate < 10%
  - P95 latency < 1500ms
- **Use Cases**: Capacity planning, SLO validation

### 3️⃣ **Performance Tests** (50-100 VUs)
- **Purpose**: Identify performance bottlenecks and breaking points
- **Duration**: 15 minutes
- **Virtual Users**: 50 VUs (or 100 VUs for stress tests)
- **Stages**:
  - 2 min: Ramp up to 10 VUs
  - 5 min: Sustain 30 VUs
  - 5 min: Sustain 50 VUs (or 100 VUs)
  - 3 min: Ramp down to 0 VUs
- **Thresholds**:
  - Error rate < 10%
  - P95 latency < 1500ms
- **Use Cases**: Stress testing, scalability limits, resource optimization

---

## 🚀 Prerequisites (Windows)

1. **Install k6**:
   ```powershell
   choco install k6
   ```
   Or download from: https://k6.io/docs/get-started/installation/

2. **Verify installation**:
   ```powershell
   k6 version
   ```

3. **No npm required** - the .env loader is included in `k6/shared/dotenv.js`

---

## ⚙️ Environment Configuration

### Local .env file
Create `k6/.env` with your environment variables:

```env
BASE_URL=http://YOUR_LOAD_BALANCER_IP
USERNAME=your-test-user@example.com
PASSWORD=YourPassword@123
AUTH_TOKEN_PATH=/user/auth/login
AUTH_HEADER=
TIMEOUT_MS=5000
```

**Priority order**: `.env` file → CLI arguments (`-e VAR=...`) → script defaults

**Variables**:
- `BASE_URL`: Target API endpoint (required)
- `USERNAME`: Test user email (used for auto-registration)
- `PASSWORD`: Test user password (used for auto-registration)
- `AUTH_TOKEN_PATH`: Login endpoint path (default: `/user/auth/login`)
- `AUTH_HEADER`: Pre-authenticated token (optional, skips login)
- `TIMEOUT_MS`: Request timeout in milliseconds (default: 5000)

---

## 📝 Running Tests

### Basic Execution

```powershell
# Smoke test (1 VU)
k6 run k6/smoke/users-smoke.js

# Load test (25 VUs)
k6 run k6/load/users-load.js

# Performance test (50 VUs)
k6 run k6/performance/users-performance-50vu.js
```

### With Datetime Output Files

```powershell
# Generate timestamped output files
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Smoke test with JSON output
k6 run k6/smoke/users-smoke.js --summary-export="k6/output/users-smoke-results_$timestamp.json"

# Load test with JSON output
k6 run k6/load/users-load.js --summary-export="k6/output/users-load-results_$timestamp.json"

# Performance test with JSON output
k6 run k6/performance/users-performance-50vu.js --summary-export="k6/output/users-perf-results_$timestamp.json"

# Games service load test
k6 run k6/load/games-load.js --summary-export="k6/output/games-load-results_$timestamp.json"
```

### Override Environment Variables

```powershell
# Override BASE_URL and credentials
k6 run -e BASE_URL=https://your-api-endpoint.com -e USERNAME=testuser@example.com -e PASSWORD=Test@123 k6/smoke/users-smoke.js

# Use pre-authenticated token
k6 run -e AUTH_HEADER="Bearer YOUR_TOKEN_HERE" k6/load/users-load.js

# Change timeout
k6 run -e TIMEOUT_MS=10000 k6/performance/users-performance-50vu.js
```

### Advanced Output Options

```powershell
# Export multiple output formats
k6 run k6/load/users-load.js `
  --summary-export="k6/output/summary_$timestamp.json" `
  --out json="k6/output/metrics_$timestamp.json" `
  --out csv="k6/output/metrics_$timestamp.csv"

# Export HTML report (requires k6-reporter extension)
k6 run k6/load/users-load.js `
  --summary-export="k6/output/report_$timestamp.json" `
  --out json="k6/output/raw_$timestamp.json"

# Verbose output for debugging
k6 run --verbose k6/smoke/users-smoke.js
```

---

## 🔧 Command-Line Parameters

### Core k6 Options

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--vus <n>` | Override VUs (for simple scripts) | `k6 run --vus 10 script.js` |
| `--duration <time>` | Override duration | `k6 run --duration 2m script.js` |
| `--iterations <n>` | Run N iterations per VU | `k6 run --iterations 100 script.js` |
| `--stage <time>:<vus>` | Add custom stage | `k6 run --stage 2m:10 --stage 5m:25 script.js` |
| `-e VAR=value` | Set environment variable | `k6 run -e BASE_URL=https://api.com script.js` |
| `--summary-export <file>` | Export JSON summary | `k6 run --summary-export=output/summary.json script.js` |
| `--out <format>=<file>` | Export metrics | `k6 run --out json=metrics.json script.js` |
| `--verbose` | Verbose logging | `k6 run --verbose script.js` |
| `--quiet` | Minimal output | `k6 run --quiet script.js` |
| `--no-color` | Disable colored output | `k6 run --no-color script.js` |
| `--http-debug` | Full HTTP request/response logs | `k6 run --http-debug script.js` |

### Script-Specific Environment Variables

| Variable | Used By | Description | Default |
|----------|---------|-------------|---------|
| `BASE_URL` | All scripts | Target API base URL | (required) |
| `USERNAME` | All scripts | Test user email | `your-test-user@example.com` |
| `PASSWORD` | All scripts | Test user password | `YourPassword@123` |
| `AUTH_TOKEN_PATH` | All scripts | Login endpoint path | `/user/auth/login` |
| `AUTH_HEADER` | All scripts | Pre-authenticated token | (empty) |
| `TIMEOUT_MS` | All scripts | Request timeout (ms) | `5000` |

---

## 📊 Example Test Scenarios

### Scenario 1: Quick Smoke Test
```powershell
# Run smoke test and save results with timestamp
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
k6 run k6/smoke/users-smoke.js --summary-export="k6/output/smoke_$ts.json"
```

### Scenario 2: Load Test with Custom Parameters
```powershell
# Run load test with custom stages
k6 run k6/load/users-load.js `
  -e BASE_URL=https://your-api-endpoint.com `
  -e TIMEOUT_MS=10000 `
  --summary-export="k6/output/load_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
```

### Scenario 3: Performance Test with Full Debugging
```powershell
# Run performance test with HTTP debugging and verbose output
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
k6 run k6/performance/users-performance-50vu.js `
  --http-debug `
  --verbose `
  --summary-export="k6/output/perf_debug_$timestamp.json" `
  --out json="k6/output/perf_metrics_$timestamp.json"
```

### Scenario 4: Multi-Service Load Test
```powershell
# Run all service load tests sequentially with timestamped outputs
$ts = Get-Date -Format "yyyyMMdd_HHmmss"

k6 run k6/load/users-load.js --summary-export="k6/output/users-load_$ts.json"
k6 run k6/load/games-load.js --summary-export="k6/output/games-load_$ts.json"
```

### Scenario 5: Pre-Deployment Validation
```powershell
# Run all smoke tests before deployment
$date = Get-Date -Format "yyyyMMdd_HHmmss"

k6 run k6/smoke/users-smoke.js --summary-export="k6/output/pre-deploy-users_$date.json"
k6 run k6/smoke/games-smoke.js --summary-export="k6/output/pre-deploy-games_$date.json"
```

---

## 🎯 Thresholds & Success Criteria

All tests include built-in thresholds that automatically fail if not met:

```javascript
// Smoke tests (stricter)
thresholds: {
  http_req_failed: ['rate<0.05'],      // < 5% error rate
  http_req_duration: ['p(95)<1500'],    // 95th percentile < 1500ms
}

// Load & Performance tests
thresholds: {
  http_req_failed: ['rate<0.1'],       // < 10% error rate
  http_req_duration: ['p(95)<1500'],    // 95th percentile < 1500ms
}
```

---

## 🔥 Warmup & Retries

- All scripts perform health check warmup in `setup()` phase
- Warmup requests are tagged with `warmup:true`
- Thresholds filter out warmup traffic: `http_req_failed{warmup:false}`
- Default timeout: 5000ms (configurable via `TIMEOUT_MS`)
- Automatic admin user registration with unique timestamps

---

## 🤖 GitHub Actions (CI/CD)

**Workflow**: `.github/workflows/perf-k6.yml`

**Triggers**: Manual dispatch or scheduled runs

**Secrets** (environment-scoped to `prod`):
- `PERF_BASE_URL`
- `PERF_USERNAME`
- `PERF_PASSWORD`
- `PERF_AUTH_TOKEN_PATH` (optional)
- `PERF_AUTH_HEADER` (optional)

**Artifacts**: Automatically uploaded test summaries and metrics

---

## 📈 Output Files

All test results are saved to `k6/output/` (gitignored):

```
k6/output/
├── users-smoke-results_20260105_143022.json
├── users-load-results_20260105_150045.json
├── games-load-results_20260105_152130.json
└── perf-metrics_20260105_154500.csv
```

**File formats**:
- `.json`: Detailed summary with metrics, checks, and thresholds
- `.csv`: Time-series metrics for trend analysis
- `.txt`: Human-readable logs and analysis

---

## 🛠️ Troubleshooting

**Connection refused**:
```powershell
# Verify BASE_URL is reachable
k6 run -e BASE_URL=http://YOUR_IP_ADDRESS k6/smoke/users-smoke.js
```

**Authentication failures**:
```powershell
# Use verbose logging to debug
k6 run --verbose k6/smoke/users-smoke.js
```

**Timeout errors**:
```powershell
# Increase timeout
k6 run -e TIMEOUT_MS=15000 k6/load/users-load.js
```

**High error rates**:
```powershell
# Run with HTTP debugging
k6 run --http-debug k6/smoke/users-smoke.js
```

---

## 📚 Additional Resources

- [k6 Documentation](https://k6.io/docs/)
- [k6 Test Lifecycle](https://k6.io/docs/using-k6/test-lifecycle/)
- [k6 Thresholds](https://k6.io/docs/using-k6/thresholds/)
- [k6 Options Reference](https://k6.io/docs/using-k6/k6-options/reference/)

---

## 🔮 Next Steps

- Tune stages/thresholds based on your SLOs
- Add custom scenarios for specific user flows
- Integrate with monitoring (Prometheus, Grafana)
- Set up automated performance regression testing
- Create service-specific dashboards for results analysis
