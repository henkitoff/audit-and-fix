# Round 2 — System-Level Issues

### Dimension 2.1: Data Integrity
**Search for:** Non-atomic file writes, missing DB transactions, read-modify-write without locks.
```bash
grep -rn "\.write_text(\|\.write_bytes(" python/ --include="*.py" | grep -v "test_" | head -15
grep -rn "execute.*INSERT\|execute.*UPDATE\|execute.*DELETE" python/ --include="*.py" | head -15
grep -rn "datetime.now()" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if writes model files, state, or signals. HIGH if writes training data. MEDIUM if writes logs or reports.

### Dimension 2.2: Security + Credentials
**Search for:** Hardcoded secrets, SQL injection, path traversal, exposed endpoints.
```bash
grep -rn "API_KEY\|SECRET\|TOKEN\|PASSWORD" python/ --include="*.py" | grep -v "os.environ\|os.getenv\|test_\|#" | head -15
grep -rn 'f".*SELECT\|f".*INSERT\|f".*DELETE' python/ --include="*.py" | head -10
grep -rn "shell=True" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if actual secret hardcoded or SQL injectable. HIGH if path traversal possible. MEDIUM for overly permissive CORS.

### Dimension 2.3: Stale State + Config Drift
**Search for:** Caches without TTL, config loaded once, env vars cached at import, conflict files.
```bash
grep -rn "_cache\s*=\s*{}\|_CACHE\s*=" python/ --include="*.py" | head -10
grep -rn "os.environ\[.*\]\|os.getenv(" python/ --include="*.py" | head -15
find python/ -name "*.sync-conflict-*" -type f
```
**Classify:** CRITICAL if stale model cache in live trading. HIGH if stale config in 24/5 system. MEDIUM if stale cache in batch jobs.

### Dimension 2.4: Import/Dependency Graph
**Search for:** Circular imports, dependency DAG violations, overly broad import exception handling.
```bash
grep -rn "from strategies\|import strategies" python/common/ --include="*.py"
grep -rn "from gui\|import gui" python/training/ --include="*.py"
grep -rn "from .* import \*" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if circular import causes runtime failure. HIGH if DAG violation. LOW for star imports in re-export stubs.

### Dimension 2.5: String-Literal Inconsistencies + Magic Numbers
**Search for:** Inconsistent naming, missing constants, divergent sets.
```bash
grep -rn '"asian"\|"london"\|"ny"\|"overlap"' python/ --include="*.py" | wc -l
grep -rn '"xgboost"\|"catboost"\|"sklearn"\|"lstm"' python/ --include="*.py" | wc -l
grep -rn "0\.53\|0\.45\|0\.0001" python/ --include="*.py" | head -15
```
**Classify:** HIGH if inconsistent sets (e.g., session names differ between modules). MEDIUM for magic numbers. LOW for consistent string literals.

### Dimension 2.6: Utility Duplicates
**Search for:** Functions defined identically in multiple files.
```bash
grep -rn "def.*_resolve_path\|def.*_safe_float\|def.*load_json\|def.*save_json" python/ --include="*.py" | head -20
grep -rn "def.*utc_now\|def.*utc_id\|def.*_utc" python/ --include="*.py" | head -10
grep -rn "def.*atomic_write" python/ --include="*.py" | head -5
```
**Classify:** MEDIUM for all duplicates (maintenance burden, not runtime risk). Note identical vs variant signatures.

### Dimension 2.7: Logging Configuration Conflicts
**Search for:** Multiple basicConfig calls, handler duplication.
```bash
grep -rn "basicConfig\|addHandler\|StreamHandler\|FileHandler" python/ --include="*.py" | head -15
grep -rn "logging.getLogger(__name__)" python/ --include="*.py" | wc -l
```
**Classify:** MEDIUM if module-level basicConfig (silently overrides). LOW for duplicate handlers (verbose but not broken).

### Dimension 2.8: Test Coverage Gaps
**Search for:** Critical code paths without any test.
```bash
# List all source files, check which have corresponding test files
for f in $(find python/strategies/ai/ python/online/ python/common/ -name "*.py" -not -name "__init__.py"); do
  base=$(basename "$f" .py)
  test_count=$(find tests/ -name "test_${base}*" | wc -l)
  [ "$test_count" -eq 0 ] && echo "NO TEST: $f"
done
```
**Classify:** CRITICAL if signal generation or trade execution has no tests. HIGH if model promotion untested. MEDIUM for utility functions.

### Dimension 2.9: Test Quality & Test Smells
**Search for:** Empty tests, missing assertions, sleepy tests, exception handling in tests, external dependencies in tests.
```bash
# Empty tests (pass only, no assertion)
grep -rn "def test_" tests/ --include="*.py" -A3 | grep -B1 "pass$" | grep "def test_" | head -10
# Tests without any assertion
for f in $(find tests/ -name "test_*.py"); do
  for func in $(grep -n "def test_" "$f" | cut -d: -f1); do
    next=$(awk "NR>$func && /^    def |^class /{print NR; exit}" "$f")
    [ -z "$next" ] && next=$(wc -l < "$f")
    count=$(sed -n "${func},${next}p" "$f" | grep -c "assert\|raises\|mock")
    [ "$count" -eq 0 ] && echo "NO_ASSERT: $f:$func"
  done
done 2>/dev/null | head -10
# Sleepy tests (time.sleep in test code)
grep -rn "time\.sleep\|sleep(" tests/ --include="*.py" | head -10
# try/except in tests (swallows failures)
grep -rn "try:" tests/ --include="*.py" | grep -v "pytest\.raises\|#" | head -10
# External dependencies in tests (Mystery Guest)
grep -rn "requests\.get\|urlopen\|connect(\|open(" tests/ --include="*.py" | grep -v "mock\|patch\|monkeypatch\|tmp_path\|fixture" | head -10
# Skipped tests without reason
grep -rn "@pytest\.mark\.skip\|@unittest\.skip" tests/ --include="*.py" | grep -v "reason=" | head -5
```
**Classify:** HIGH if tests without assertions (pass but verify nothing). HIGH if time.sleep in tests (flaky). MEDIUM if try/except swallows test failures. MEDIUM if external dependencies make tests brittle.

### Dimension 2.10: Data Store Safety & Multi-DB Security
**Search for:** DB-specific security misconfigurations, connection leaks, cross-DB inconsistencies, CVE exposure.

**SQLite:**
```bash
# Connections without context manager (resource leak)
grep -rn "sqlite3\.connect" python/ --include="*.py" | grep -v "with \|test_\|#" | head -10
# load_extension enabled (RCE via malicious .so/.dll)
grep -rn "enable_load_extension" python/ --include="*.py" | head -5
# DB file permissions (should be 0600, not world-readable)
find . -name "*.db" -o -name "*.sqlite3" 2>/dev/null | xargs ls -la 2>/dev/null | head -10
# DDL with string interpolation (identifier injection)
grep -rn "execute(f\".*ALTER\|execute(f\".*CREATE\|execute(f\".*DROP" python/ --include="*.py" | head -10
```

```bash
# trusted_schema not OFF (schema-level attacks via malicious DB files)
grep -rn "trusted_schema" python/ --include="*.py" | head -3
# writable_schema not OFF (sqlite_master manipulation)
grep -rn "writable_schema" python/ --include="*.py" | head -3
# No progress_handler (no query timeout — DoS via complex queries)
grep -rn "progress_handler\|set_progress_handler" python/ --include="*.py" | head -3
# No sqlite3_limit (default limits too permissive)
grep -rn "sqlite3_limit\|LIMIT_EXPR_DEPTH" python/ --include="*.py" | head -3
```

**PostgreSQL:**
```bash
# SSL not enforced (credentials in cleartext)
grep -rn "sslmode\|ssl_mode" python/ --include="*.py" | head -5
# App connects as superuser (postgres)
grep -rn "user.*=.*postgres\|USER.*postgres" python/ --include="*.py" .env* | head -5
# search_path not set (schema injection CVE-2018-1058)
grep -rn "search_path\|SET search_path" python/ --include="*.py" | head -5
# No statement_timeout (runaway queries hold locks forever)
grep -rn "statement_timeout\|idle_in_transaction" python/ --include="*.py" | head -5
# Pool config validation
grep -rn "pool_size\|max_overflow\|POOL_MAX\|maxconn" python/ --include="*.py" | head -5
```

```bash
# MD5 auth instead of SCRAM-SHA-256 (CIS Benchmark)
grep -rn "password_encryption\|md5\|scram" python/ --include="*.py" --include="*.conf" 2>/dev/null | head -5
# No pgAudit / statement logging
grep -rn "pgaudit\|log_statement\|log_min_duration" python/ --include="*.py" --include="*.conf" 2>/dev/null | head -5
# Pool connections not validated (stale/broken detection)
grep -rn "pool_pre_ping\|keepalives_idle\|tcp_keepalives" python/ --include="*.py" | head -5
# Row-Level Security not used (multi-tenant data isolation)
grep -rn "CREATE POLICY\|ROW LEVEL SECURITY" python/ --include="*.sql" --include="*.py" 2>/dev/null | head -3
```

**DuckDB:**
```bash
# enable_external_access not disabled (reads /etc/passwd, network access)
grep -rn "enable_external_access" python/ --include="*.py" | head -5
# allow_community_extensions not disabled (third-party code execution)
grep -rn "allow_community_extensions" python/ --include="*.py" | head -5
# lock_configuration not set (config changeable after init)
grep -rn "lock_configuration" python/ --include="*.py" | head -5
# ATTACH with f-string (SQL injection via file path)
grep -rn "execute(f\".*ATTACH\|execute(f\".*COPY" python/ --include="*.py" | head -5
# No memory_limit (OOM-kill on crafted queries)
grep -rn "memory_limit\|max_temp_directory" python/ --include="*.py" | head -5
```

```bash
# disabled_filesystems not set (reads local files via read_csv)
grep -rn "disabled_filesystems" python/ --include="*.py" | head -3
# DuckDB version check (CVE-2025-64429: weak crypto before 1.4.2)
pip show duckdb 2>/dev/null | grep Version
```

**Redis:**
```bash
# No authentication (redis:// without password)
grep -rn "redis://\|from_url" python/ --include="*.py" | grep -v "password\|auth\|rediss" | head -10
# No TLS (rediss:// or ssl=True missing)
grep -rn "rediss://\|ssl=True\|ssl_cert" python/ --include="*.py" | head -5
# KEYS * in production (blocks entire server)
grep -rn "\.keys(\|KEYS \*" python/ --include="*.py" | grep -v "\.scan(\|test_" | head -5
# No maxmemory configured (OOM-kill)
grep -rn "maxmemory\|CONFIG SET maxmemory" python/ --include="*.py" *.conf 2>/dev/null | head -5
# Pickle serialization for Redis values (RCE if attacker controls key)
grep -rn "pickle\.dumps\|pickle\.loads" python/ --include="*.py" | grep -i "redis\|cache\|set(\|get(" | head -5
# Data without TTL (memory leak)
grep -rn "\.set(\|\.hset(\|\.lpush(" python/ --include="*.py" | grep -v "ex=\|px=\|expire\|ttl\|test_" | head -10
```

```bash
# CONFIG SET not restricted (arbitrary file write = RCE)
grep -rn "config_set\|CONFIG SET" python/ --include="*.py" | head -5
# FLUSHALL/FLUSHDB not restricted (total data loss)
grep -rn "flushall\|flushdb\|FLUSHALL\|FLUSHDB" python/ --include="*.py" | head -5
# EVAL/EVALSHA Lua scripting (CVE-2025-49844: RCE via use-after-free)
grep -rn "\.eval(\|\.evalsha(\|EVAL\|register_script" python/ --include="*.py" | grep -i "redis" | head -5
# Redis bound to 0.0.0.0 without protected-mode
grep -rn "bind.*0\.0\.0\.0\|host.*0\.0\.0\.0" python/ --include="*.py" --include="*.conf" 2>/dev/null | grep -i "redis" | head -5
```

**Parquet:**
```bash
# Reading untrusted Parquet without schema validation
grep -rn "read_parquet\|ParquetFile\|pq\.read_table" python/ --include="*.py" | head -10
# No row_group_size limit (decompression bomb)
grep -rn "row_group_size\|max_file_size" python/ --include="*.py" | head -5
# CVE-2025-30065: Check pyarrow version
pip show pyarrow 2>/dev/null | grep Version
```

```bash
# No encryption for sensitive columns (plaintext on disk/S3)
grep -rn "encryption_config\|parquet_encryption" python/ --include="*.py" | head -3
# String columns without bounds (zip-bomb potential)
grep -rn "read_parquet\|pq\.read_table" python/ --include="*.py" | grep -v "columns=" | head -5
```

**MinIO/S3:**
```bash
# HTTP instead of HTTPS (credentials in cleartext)
grep -rn "http://.*:9000\|http://.*minio\|secure=False\|secure.*=.*False" python/ --include="*.py" | head -5
# No server-side encryption
grep -rn "ServerSideEncryption\|SSE-S3\|SSE-KMS" python/ --include="*.py" | head -5
# No bucket versioning (ransomware risk)
grep -rn "put_bucket_versioning\|versioning" python/ --include="*.py" | head -5
# Bucket policy with Principal:* (public access)
grep -rn "Principal.*\*\|public-read\|ACL.*public" python/ --include="*.py" | head -5
```

```bash
# S3 credentials hardcoded
grep -rn "access_key.*=.*['\"].*['\"]\\|secret_key.*=.*['\"]" python/ --include="*.py" | grep -v "os\.environ\|os\.getenv\|test_" | head -5
# No lifecycle rules (old data accumulates)
grep -rn "put_bucket_lifecycle\|lifecycle\|Expiration" python/ --include="*.py" | head -3
# No object locking / retention for compliance
grep -rn "object_lock\|retention\|GOVERNANCE\|COMPLIANCE" python/ --include="*.py" | head -3
```

**Cross-DB:**
```bash
# N+1 queries (DB calls inside loops)
grep -rn "for.*in.*:" python/ --include="*.py" -A3 | grep -B1 "\.execute(\|\.query(" | head -10
# Missing transactions (multiple writes without BEGIN/COMMIT)
grep -rn "\.execute.*INSERT\|\.execute.*UPDATE\|\.execute.*DELETE" python/ --include="*.py" -A2 | grep -v "commit\|COMMIT\|BEGIN" | head -10
# DB error messages exposed to users (info leakage)
grep -rn "except.*Error.*as.*e" python/api/ --include="*.py" -A2 | grep "str(e)\|detail.*e\|return.*e" | head -5
```

**Classify:**
- CRITICAL: DuckDB enable_external_access not disabled, Redis without auth on network, SQLite load_extension enabled, Parquet CVE exposure, MinIO HTTP without TLS, PostgreSQL as superuser
- HIGH: DuckDB ATTACH injection, Redis KEYS *, PostgreSQL no SSL, no search_path, Redis pickle serialization, DDL identifier injection
- MEDIUM: No statement_timeout, no memory_limit, no bucket versioning, N+1 queries, missing transactions
- MEDIUM: SQLite trusted_schema/writable_schema not hardened, no query timeout, PostgreSQL MD5 auth, no audit logging, stale pool connections, DuckDB no filesystem restriction, Parquet no encryption, MinIO no lifecycle/retention, Redis CONFIG not restricted

### Dimension 2.11: Python Security Patterns (Bandit)
**Search for:** Security anti-patterns that require context beyond simple grep — best detected by running `bandit -r python/` if installed.
```bash
# HTTP requests without timeout (hangs indefinitely)
grep -rn "requests\.\(get\|post\|put\|delete\|patch\)\|urlopen\|urllib\.request" python/ --include="*.py" | grep -v "timeout\|test_" | head -15
# Subprocess with partial path (PATH hijacking)
grep -rn "subprocess\.\(Popen\|call\|run\)" python/ --include="*.py" | grep -v "/" | head -10
# Random module for security-sensitive context
grep -rn "random\.\(random\|randint\|choice\|sample\)" python/ --include="*.py" | grep -i "token\|secret\|key\|salt\|nonce\|password" | head -10
# Assert used for security validation (disabled with -O flag)
grep -rn "^assert\s\|^\s*assert\s" python/ --include="*.py" | grep -iE "auth\|perm\|access\|token\|valid\|allow" | head -10
# Jinja2 autoescape disabled (XSS in templates)
grep -rn "autoescape\s*=\s*False\|Environment(" python/ --include="*.py" | head -5
# SSH auto-add host key (MITM vulnerability)
grep -rn "AutoAddPolicy\|WarningPolicy\|paramiko" python/ --include="*.py" | head -5
# FTP/Telnet cleartext protocols
grep -rn "ftplib\|telnetlib\|ftp://\|telnet://" python/ --include="*.py" | head -5
# Flask/FastAPI debug mode in production
grep -rn "debug\s*=\s*True\|--reload" python/ --include="*.py" | grep -v "test_\|#" | head -5
# Insecure file permissions
grep -rn "chmod\|0o777\|0o666\|0o755" python/ --include="*.py" | head -5
# CSV/Excel formula injection (user data starting with =,+,-,@)
grep -rn "\.to_csv\|\.to_excel\|csv\.writer" python/ --include="*.py" | head -10
# Insecure UUID (uuid1 leaks MAC address)
grep -rn "uuid\.uuid1\|uuid1()" python/ --include="*.py" | head -5
# Sync sleep in async code (blocks event loop)
grep -rn "async def" python/ --include="*.py" -A20 | grep "time\.sleep" | head -5
# Unchecked return values from OS operations
grep -rn "^\s*os\.rename\|^\s*os\.remove\|^\s*shutil\." python/ --include="*.py" | grep -v "=\|if \|assert\|try" | head -10
# NumPy RNG in PyTorch DataLoader workers
grep -rn "np\.random" python/ --include="*.py" | grep -i "dataset\|dataloader\|__getitem__" | head -5
# RECOMMENDED: Run bandit for context-aware detection
# bandit -r python/ -f json -ll 2>/dev/null | head -30
```
**Classify:** MEDIUM for all. HTTP-without-timeout and assert-for-security are most impactful. Run `bandit -r python/` for comprehensive AST-based detection.

### Dimension 2.12: Test Smell Deep Scan
**Search for:** Additional test quality issues beyond Dim 2.9 — assertion quality, test independence, test design.
```bash
# Assertion Roulette (multiple asserts without descriptive message)
grep -rn "def test_" tests/ --include="*.py" -A15 | grep -c "assert" | awk '$1>3{print "ROULETTE: " FILENAME}' 2>/dev/null | head -10
# Conditional logic in tests (if/while/for = non-deterministic)
grep -rn "def test_" tests/ --include="*.py" -A15 | grep "^\s*if \|^\s*while \|^\s*for " | head -10
# Duplicate assertions (same assert repeated)
grep -rn "assert" tests/ --include="*.py" | sort -t: -k3 | uniq -d -f2 | head -10
# Eager test (calls >3 production methods)
grep -rn "def test_" tests/ --include="*.py" -A20 | grep -v "assert\|#\|self\.\|import" | head -15
# Magic numbers in assertions
grep -rn "assert.*==\s*[0-9]" tests/ --include="*.py" | grep -v "== 0\|== 1\|== True\|== False\|== None" | head -10
# Redundant print statements in tests
grep -rn "print(" tests/ --include="*.py" | head -10
# Redundant assertions (assert True, assertEqual(x, x))
grep -rn "assert True\|assert 1\b\|assertEqual.*,.*same" tests/ --include="*.py" | head -5
# Resource optimism (file access without tmp_path/fixture)
grep -rn "open(\|read_csv\|read_parquet" tests/ --include="*.py" | grep -v "mock\|patch\|tmp_path\|fixture\|conftest" | head -10
# Sensitive equality (str(obj) for comparison)
grep -rn "str(" tests/ --include="*.py" | grep "assert\|==" | head -10
# General fixture (setUp defines unused attributes)
grep -rn "def setUp\|@pytest\.fixture" tests/ --include="*.py" -A15 | grep "self\.\|return " | head -10
# Constructor initialization (__init__ in test class)
grep -rn "def __init__" tests/ --include="*.py" | head -5
# Lazy test (same production method called by multiple tests with similar setup)
grep -rn "def test_" tests/ --include="*.py" -A5 | grep -v "def test_\|assert\|#" | sort | uniq -c | sort -rn | head -10
```
**Classify:** MEDIUM for conditional logic and resource optimism (cause flaky tests). LOW for magic numbers, redundant prints, sensitive equality (code style).
