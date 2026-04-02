# Round 6 — Security Deep Dive

10 security dimensions for comprehensive vulnerability assessment. Use `--preset security-deep` to run only this round, or include in `--preset full`.

**Tools (install if available):**
- `pip install bandit pip-audit safety detect-secrets`
- `brew install gitleaks trivy` (Mac) / `choco install gitleaks trivy` (Windows)

---

### Dimension 6.1: Authentication & Authorization
**Search for:** API endpoints without auth, missing RBAC, unprotected WebSockets.
```bash
# Find all route handlers
grep -rn "@router\.\|@app\." python/api/ --include="*.py" | head -20
# Check for auth dependencies
grep -rn "Depends(\|HTTPBearer\|APIKey\|OAuth\|jwt\|token" python/api/ --include="*.py" | head -10
# Unprotected WebSocket endpoints
grep -rn "websocket\|WebSocket" python/api/ --include="*.py" | head -10
# IDOR: Object lookups by ID without ownership check
grep -rn "\.get(.*_id\|\.filter(.*user_id\|\.query.*id=" python/ --include="*.py" | grep -v "test_\|self\." | head -10
# CSRF: State-changing endpoints without CSRF middleware
grep -rn "@router\.post\|@router\.put\|@router\.delete\|@app\.post" python/ --include="*.py" | head -15
# JWT: Algorithm enforcement and expiration
grep -rn "jwt\.\|JWT\|PyJWT\|jose\.\|decode(" python/ --include="*.py" | head -10
# Session: Cookie flags and token management
grep -rn "Set-Cookie\|session\[.*=\|cookie\|httponly\|secure\|samesite" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if ANY endpoint lacks authentication. HIGH if auth exists but no authorization/RBAC. MEDIUM if auth exists but WebSocket unprotected. CRITICAL if IDOR (DB query by user-supplied ID without ownership check). HIGH if state-changing endpoint without CSRF protection. CRITICAL if JWT with algorithm not enforced server-side.

### Dimension 6.2: Secret Management
**Search for:** Hardcoded secrets, .env committed to git, default passwords, secrets in logs.
```bash
# Hardcoded secrets in source
grep -rn "password\s*=\s*['\"].*['\"]" python/ --include="*.py" | grep -v "test_\|#\|example\|change-me" | head -10
# .env in git history
git log --all --diff-filter=A -- "*.env" ".env*" 2>/dev/null | head -5
# Default/placeholder credentials still active
grep -rn "change-me\|changeme\|default\|placeholder\|xxx\|TODO.*password" python/ --include="*.py" .env* | head -10
# Secrets in logs
grep -rn "logger.*password\|logger.*token\|logger.*secret\|logger.*key\|print.*password\|print.*token" python/ --include="*.py" | head -10
# Run detect-secrets if installed
detect-secrets scan python/ 2>/dev/null | head -30
```
```bash
# RECOMMENDED: Run dedicated secret scanner for 800+ patterns (if installed)
trufflehog filesystem . --only-verified 2>/dev/null | head -20
gitleaks detect --source . --report-format json 2>/dev/null | head -20
detect-secrets scan . 2>/dev/null | head -20
```
**Classify:** CRITICAL if actual secret hardcoded. HIGH if .env committed to git. MEDIUM if default placeholder passwords. LOW if secrets only referenced via os.environ.

### Dimension 6.3: Network Exposure
**Search for:** Services binding to 0.0.0.0, missing TLS, exposed management ports.
```bash
# Bind address check
grep -rn "0\.0\.0\.0\|host.*0\.0\.0\.0\|bind.*0\.0\.0\.0" python/ --include="*.py" | head -10
grep -rn "host.*0\.0\.0\.0" *.yml *.yaml docker-compose* 2>/dev/null | head -5
# TLS/SSL enforcement
grep -rn "ssl\|tls\|https\|rediss://" python/ --include="*.py" | head -10
# CORS configuration
grep -rn "CORSMiddleware\|allow_origins\|allow_methods" python/ --include="*.py" | head -10
# Exposed ports
grep -rn "port.*=\|:8000\|:6379\|:5432\|:8384\|:8050" python/ --include="*.py" docker-compose* *.yml 2>/dev/null | head -15
```
**Classify:** CRITICAL if API binds 0.0.0.0 without auth. HIGH if no TLS on database/Redis connections. MEDIUM if CORS uses wildcard methods/headers. LOW if only localhost binding.

### Dimension 6.4: Injection Vulnerabilities
**Search for:** SQL injection, OS command injection, unsafe deserialization, eval/exec.
```bash
# SQL injection (string formatting in queries)
grep -rn 'f".*SELECT\|f".*INSERT\|f".*UPDATE\|f".*DELETE\|\.format.*execute\|%.*execute' python/ --include="*.py" | head -10
# OS command injection
grep -rn "os\.system\|os\.popen\|subprocess.*shell=True\|eval(\|exec(" python/ --include="*.py" | head -10
# Unsafe deserialization
grep -rn "pickle\.load\|pickle\.loads\|joblib\.load\|torch\.load\|pd\.read_pickle\|yaml\.load(" python/ --include="*.py" | grep -v "yaml\.safe_load\|test_" | head -15
# Run bandit if installed
bandit -r python/ -ll -q 2>/dev/null | head -30
# SSRF: Server-side requests with user-controlled URLs
grep -rn "requests\.get\|requests\.post\|urllib\.request\|urlopen\|fetch(" python/ --include="*.py" | head -15
# XXE: XML parsers without disabled external entities
grep -rn "etree\.parse\|SAXParser\|xml\.dom\|minidom\|pulldom" python/ --include="*.py" | head -10
# SSTI: Template rendering with user input
grep -rn "render_template_string\|Template(\|Markup(\|safe\b" python/ --include="*.py" | head -10
# Mass Assignment: Request data passed directly to model create/update
grep -rn "\.create(\|\.update(\|from_dict\|model_dump" python/ --include="*.py" | grep -v "test_" | head -10
```
```bash
# Unsafe YAML loading (arbitrary code execution)
grep -rn "yaml\.load\|yaml\.unsafe_load\|yaml\.full_load" python/ --include="*.py" | grep -v "safe_load\|SafeLoader\|test_" | head -10
# Unsafe ML model loading (torch.load, joblib.load without safetensors)
grep -rn "torch\.load\|joblib\.load\|np\.load.*allow_pickle" python/ --include="*.py" | grep -v "test_" | head -10
# pandas.eval() / DataFrame.query() code injection
grep -rn "pd\.eval\|\.eval(\|\.query(" python/ --include="*.py" | grep -v "test_" | head -10
# tarfile path traversal
grep -rn "tarfile.*extract\|\.extractall(" python/ --include="*.py" | head -5
# marshal deserialization
grep -rn "marshal\.load" python/ --include="*.py" | head -5
```
**Classify:** CRITICAL if SQL injection found (f-string in query). CRITICAL if pickle.load on user-supplied file. HIGH if eval/exec on any input. MEDIUM if shell=True with controlled input. CRITICAL if SSRF with user-controlled URL. CRITICAL if XXE with external entities enabled. CRITICAL if SSTI with user input in template. HIGH if mass assignment without field whitelist. CRITICAL if yaml.load without SafeLoader. CRITICAL if torch.load on untrusted model. CRITICAL if pandas.eval with user input. HIGH if tarfile.extractall without filter.

### Dimension 6.5: Supply Chain Security
**Search for:** Known CVEs, unpinned dependencies, typosquatting risk.
```bash
# CVE scan
pip-audit --format=columns 2>/dev/null | head -20
safety check 2>/dev/null | head -20
# Unpinned dependencies
grep -v "==" requirements*.txt 2>/dev/null | grep -v "^#\|^$\|^-" | head -15
# Check for hash pinning
grep -c "\-\-hash" requirements*.txt 2>/dev/null
# Compare package names against known typosquats
pip list --format=freeze 2>/dev/null | awk -F= '{print $1}' | sort > /tmp/installed_pkgs.txt
```
**Classify:** CRITICAL if known CVE with exploit. HIGH if >10 unpinned dependencies. MEDIUM if outdated security-relevant packages. LOW if all pinned but no hash verification.

### Dimension 6.6: Infrastructure Hardening
**Search for:** Redis without auth, PostgreSQL trust mode, Docker running as root, exposed management interfaces.
```bash
# Redis authentication
grep -rn "requirepass\|redis.*password\|REDIS_PASSWORD" python/ --include="*.py" .env* *.conf 2>/dev/null | head -10
# PostgreSQL auth mode
grep -rn "trust\|md5\|scram" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null | head -10
# Docker as root
grep -rn "^USER\|^RUN.*useradd\|^RUN.*adduser" Dockerfile* 2>/dev/null | head -5
# Management interfaces exposed
grep -rn "debug=True\|--reload\|docs_url\|redoc_url" python/ --include="*.py" | head -10
# Sync service API key exposure
grep -rn "API.Key\|X-API-Key" python/ --include="*.py" docs/ *.md | head -5
```
**Classify:** CRITICAL if Redis has no requirepass AND is network-accessible. HIGH if PostgreSQL uses trust auth. HIGH if Docker runs as root. MEDIUM if debug/docs endpoints enabled.

### Dimension 6.7: Rate Limiting & DoS Protection
**Search for:** Missing rate limiters, unbounded resource allocation, WebSocket flooding.
```bash
# Rate limiter presence
grep -rn "slowapi\|ratelimit\|throttle\|RateLimiter\|Limiter" python/ --include="*.py" | head -5
# Unbounded API operations
grep -rn "async def\|@router\." python/api/routes/ --include="*.py" | wc -l
# WebSocket without limits
grep -rn "websocket\|WebSocket" python/api/ --include="*.py" -A5 | grep -i "limit\|max\|timeout" | head -5
# File upload size limits
grep -rn "max.*size\|upload.*limit\|content.*length" python/ --include="*.py" | head -5
```
```bash
# ReDoS: Regex with nested quantifiers on user input
grep -rn "re\.compile\|re\.match\|re\.search\|re\.sub" python/ --include="*.py" | head -15
```
**Classify:** CRITICAL if no rate limiting on job creation/process launch endpoints. HIGH if WebSocket has no connection limit. MEDIUM if rate limiting exists but thresholds too high.

### Dimension 6.8: ML Model Security
**Search for:** Model files loaded without integrity check, adversarial input validation, model theft via API.
```bash
# Model loading without hash/signature verification
grep -rn "load_model\|joblib\.load\|onnx.*load\|torch\.load" python/ --include="*.py" | grep -v "test_" | head -15
# Model integrity checks
grep -rn "sha256\|hashlib\|verify.*model\|checksum" python/ --include="*.py" | head -5
# Prediction endpoint exposure (model theft)
grep -rn "predict\|inference\|score" python/api/ --include="*.py" | head -10
# Feature validation before inference
grep -rn "validate.*feature\|validate.*input\|sanitize" python/strategies/ --include="*.py" | head -10
```
**Classify:** CRITICAL if models loaded without any integrity check AND model files can be user-supplied. HIGH if prediction API exposed without rate limiting. MEDIUM if feature validation exists but is incomplete.

### Dimension 6.9: Audit Logging & Compliance
**Search for:** Missing trade audit trail, incomplete signal logging, no failed-auth logging.
```bash
# Trade/signal audit trail
grep -rn "audit\|trade.*log\|signal.*log\|order.*log" python/ --include="*.py" | head -10
# API request logging
grep -rn "AccessLogMiddleware\|access.*log\|request.*log" python/api/ --include="*.py" | head -5
# Failed operation logging
grep -rn "failed.*log\|error.*log\|unauthorized\|forbidden" python/ --include="*.py" | head -10
# Data retention policy
grep -rn "retention\|purge\|archive\|cleanup.*old" python/ --include="*.py" | head -5
```
**Classify:** CRITICAL if no audit trail for trade signals/execution (regulatory requirement). HIGH if no API request logging. MEDIUM if logging exists but no retention policy.

### Dimension 6.10: Data Protection
**Search for:** Unencrypted data at rest, missing TLS in transit, insecure backup procedures.
```bash
# Encryption at rest
grep -rn "encrypt\|cipher\|fernet\|AES\|PRAGMA.*key" python/ --include="*.py" | head -10
# SQLite encryption
grep -rn "sqlite.*connect" python/ --include="*.py" | head -10
# Backup security
grep -rn "backup\|dump\|export.*db\|pg_dump" python/ scripts/ --include="*.py" --include="*.sh" | head -10
# PII/sensitive data handling
grep -rn "email\|phone\|address\|ssn\|account.*number" python/ --include="*.py" | head -5
# Temporary file security
grep -rn "tempfile\|mktemp\|/tmp/" python/ --include="*.py" | grep -v "test_" | head -10
```
**Classify:** HIGH if SQLite databases unencrypted with sensitive data. HIGH if backups stored without encryption. MEDIUM if temp files in predictable locations. LOW if no PII stored.

### Dimension 6.11: Client-Side & Web Application Security
**Search for:** XSS sinks, open redirects, clickjacking gaps, debug endpoints, file upload weaknesses.
```bash
# XSS sinks in templates/JS
grep -rn "innerHTML\|dangerouslySetInnerHTML\|document\.write\|\.html(\|v-html\||safe" python/ --include="*.py" --include="*.html" --include="*.js" | head -10
# Open Redirect: User-controlled redirect targets
grep -rn "redirect(\|Location.*=\|url_for.*next\|return_url\|redirect_uri" python/ --include="*.py" | head -10
# Clickjacking: Missing frame protection
grep -rn "X-Frame-Options\|frame-ancestors\|DENY\|SAMEORIGIN" python/ --include="*.py" | head -5
# Debug endpoints active in production
grep -rn "debug=True\|DEBUG.*=.*True\|--reload\|/debug\|/console\|/phpinfo" python/ --include="*.py" | head -10
# File upload without validation
grep -rn "upload\|UploadFile\|file.*save\|FileResponse\|send_file" python/ --include="*.py" | head -10
# Certificate validation disabled
grep -rn "verify=False\|CERT_NONE\|check_hostname.*=.*False" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if XSS sink with user input. CRITICAL if debug endpoint in production code. HIGH if open redirect without domain validation. HIGH if file upload without type/size check. HIGH if TLS verification disabled.

### Dimension 6.12: Cryptographic Correctness
**Search for:** Weak hash algorithms for security, insecure ciphers, nonce reuse, non-cryptographic RNG for secrets.
```bash
# Weak hashing for security (MD5/SHA1 for passwords or tokens)
grep -rn "hashlib\.md5\|hashlib\.sha1\|\.new.*MD5\|\.new.*SHA1" python/ --include="*.py" | grep -v "checksum\|file.*hash\|test_" | head -10
# Insecure cipher modes (ECB) or algorithms (DES, RC4, Blowfish)
grep -rn "ECB\|DES\|RC4\|Blowfish\|ARC4" python/ --include="*.py" | head -5
# Weak key sizes (RSA <2048)
grep -rn "generate.*key\|key_size\|rsa.*1024\|dsa.*1024" python/ --include="*.py" | head -5
# Non-cryptographic RNG for security (random.random instead of secrets)
grep -rn "random\.random\|random\.randint\|random\.choice" python/ --include="*.py" | grep -i "token\|secret\|key\|password\|salt\|nonce" | head -10
# Timing-unsafe comparison for secrets
grep -rn "==.*token\|==.*secret\|==.*api_key\|==.*password" python/ --include="*.py" | grep -v "hmac\.compare_digest\|constant_time\|test_" | head -10
# Hardcoded IV/nonce
grep -rn "iv\s*=\s*b\|nonce\s*=\s*b\|IV\s*=\s*b" python/ --include="*.py" | head -5
```
**Classify:** CRITICAL if MD5/SHA1 used for password hashing. CRITICAL if timing-unsafe secret comparison. HIGH if non-crypto RNG for security tokens. HIGH if hardcoded IV/nonce. MEDIUM if weak key size.

### Dimension 6.13: Web Hardening & HTTP Security
**Search for:** Missing security headers, error info leakage, cache poisoning, browser storage issues.
```bash
# Missing security headers (HSTS, X-Content-Type-Options, X-Frame-Options, CSP)
grep -rn "Strict-Transport\|X-Content-Type\|Content-Security-Policy\|Referrer-Policy\|SecurityHeaders" python/ --include="*.py" | head -10
# Server fingerprinting (X-Powered-By, Server header)
grep -rn "X-Powered-By\|server_header\|Server:" python/ --include="*.py" | head -5
# Error info leakage (stack traces to users)
grep -rn "except.*as.*e" python/api/ --include="*.py" -A2 | grep "str(e)\|traceback\|detail.*exc\|return.*error" | head -10
# HTTP parameter pollution (duplicate params accepted)
grep -rn "request\.args\|request\.form\|query_params" python/api/ --include="*.py" | head -10
# Account enumeration (different responses for valid/invalid users)
grep -rn "not found\|does not exist\|invalid.*user\|no such" python/ --include="*.py" | grep -v "test_\|#" | head -10
# Password policy (length, complexity enforcement)
grep -rn "password" python/ --include="*.py" | grep -i "length\|min_\|complex\|policy\|zxcvbn" | head -5
# Cache poisoning (sensitive responses without no-store)
grep -rn "Cache-Control\|no-cache\|no-store\|private" python/api/ --include="*.py" | head -5
# Sensitive data in browser storage
grep -rn "localStorage\|sessionStorage\|document\.cookie" python/ --include="*.py" --include="*.js" --include="*.html" | head -5
# CSP bypass (unsafe-inline, unsafe-eval)
grep -rn "unsafe-inline\|unsafe-eval" python/ --include="*.py" --include="*.html" | head -5
# Subresource integrity missing on external scripts
grep -rn "<script.*src=\|<link.*href=" python/ --include="*.html" | grep -v "integrity=" | head -5
# Data retention / right to delete
grep -rn "retention\|purge\|delete.*user\|gdpr\|anonymize" python/ --include="*.py" | head -5
# Backup security (unencrypted backups)
grep -rn "backup\|pg_dump\|dump\|export" python/ scripts/ --include="*.py" --include="*.sh" 2>/dev/null | grep -v "encrypt" | head -5
# Hardcoded IP addresses
grep -rn "10\.\|192\.168\.\|172\.\(1[6-9]\|2[0-9]\|3[01]\)\." python/ --include="*.py" | grep -v "test_\|#\|\.env" | head -10
# Basic auth credentials in URLs
grep -rn "://.*:.*@" python/ --include="*.py" | grep -v "test_\|#\|example" | head -5
# Webhook URLs with embedded secrets
grep -rn "webhook\|hooks\.slack\|hooks\.teams" python/ --include="*.py" | head -5
```
**Classify:** MEDIUM for all. Error info leakage and missing security headers are most impactful for web-facing applications. Hardcoded IPs and basic-auth-in-URLs are deployment risks.
