# Round 5 — Environment & Platform

### Dimension 5.1: Line Endings (CRLF/LF)
**Search for:** Files with Windows-style line endings that could break on Mac/Linux.
```bash
grep -rPl '\r\n' python/ --include="*.py" 2>/dev/null | head -20
grep -rPl '\r$' scripts/ --include="*.sh" | head -10
git ls-files "*.py" | head -1 | xargs -I{} cat -A "{}" | grep '\^M' | head -5
```
**Classify:** HIGH if .sh scripts have CRLF (won't execute on Linux). MEDIUM if .py files have mixed endings. LOW if consistent CRLF (just needs .gitattributes).

### Dimension 5.2: Path Handling
**Search for:** Hardcoded path separators, case-sensitivity issues, paths exceeding 260 chars.
```bash
grep -rn '\\\\' python/ --include="*.py" | grep -v "test_\|#\|re\.\|regex" | head -15
git ls-files | sort -f | uniq -di
find . -path '*' | awk '{print length, $0}' | sort -rn | head -10
```
**Classify:** HIGH if hardcoded backslashes in production code. HIGH if case-collision detected. MEDIUM if paths >200 chars.

### Dimension 5.3: Encoding Defaults
**Search for:** open() calls without explicit encoding parameter (platform-dependent default: UTF-8 on Mac, cp1252 on Windows).
```bash
grep -rn "open(" python/ --include="*.py" | grep -v "encoding=\|'rb'\|'wb'\|test_\|#" | head -20
grep -rn "\.decode()\|\.encode()" python/ --include="*.py" | grep -v "utf" | head -10
```
**Classify:** HIGH if open() without encoding in code that reads/writes user data or configs. MEDIUM for internal-only files. LOW for binary mode files.

### Dimension 5.4: Sync-Tool Artifacts
**Search for:** Syncthing conflict files, stale lock files, SQLite databases in sync scope.
```bash
find . -name "*.sync-conflict-*" -type f
find . -name "*.lock" -not -path "*/.git/*" -not -path "*/node_modules/*"
find . -name "*.db" -not -path "*/.git/*" | xargs -I{} echo "CHECK_STIGNORE: {}"
```
**Classify:** CRITICAL if .sync-conflict Python files exist (importable!). HIGH if .db files in sync scope. MEDIUM for stale .lock files.

### Dimension 5.5: WSL2 Filesystem
**Search for:** Code or configs referencing /mnt/c paths (5-50x slower), large files in WSL2 scope.
```bash
grep -rn "/mnt/c\|/mnt/d" python/ --include="*.py" | head -10
grep -rn "C:\\\\Users\|C:/Users" python/ --include="*.py" | head -10
# Check if project is on /mnt/c (CRITICAL performance issue)
pwd | grep -q "/mnt/" && echo "WARNING: Project on /mnt/ — 5-50x slower than /home/"
```
**Classify:** CRITICAL if project root is on /mnt/c. HIGH if hardcoded /mnt/c paths in code. MEDIUM if Windows paths in configs.

### Dimension 5.6: WSL2 Networking
**Search for:** Hardcoded IPs that break on WSL2 reboot, localhost assumptions, missing port-forwarding.
```bash
grep -rn "10\.0\.\|172\.\|192\.168\.\|127\.0\.0\.1\|localhost" python/ --include="*.py" | grep -v "test_\|#\|doc" | head -20
grep -rn "REDIS_URL\|BROKER_URL\|DATABASE_URL" python/ --include="*.py" | head -10
```
**Classify:** HIGH if hardcoded IPs in connection strings (break on WSL2 reboot). MEDIUM if localhost used (works with mirrored networking). LOW if IPs only in .env files.

### Dimension 5.7: WSL2 Lifecycle
**Search for:** Missing systemd services, no auto-restart for critical services, clock drift vulnerability.
```bash
# Check for systemd service files
find /etc/systemd/system/ -name "*.service" 2>/dev/null | head -10
# Check .wslconfig for vmIdleTimeout
cat ~/.wslconfig 2>/dev/null || echo "NO .wslconfig FOUND"
# Check clock drift
date +%s && python3 -c "import time; print(int(time.time()))" 2>/dev/null
```
**Classify:** CRITICAL if no .wslconfig exists (auto-shutdown after 8min idle). HIGH if vmIdleTimeout not set. MEDIUM if systemd not enabled.

### Dimension 5.8: WSL2 Config Audit
**Search for:** Missing or suboptimal .wslconfig settings.
```bash
cat ~/.wslconfig 2>/dev/null || echo "MISSING"
# Recommended settings check:
grep -q "memory=" ~/.wslconfig 2>/dev/null || echo "MISSING: memory limit"
grep -q "networkingMode=mirrored" ~/.wslconfig 2>/dev/null || echo "MISSING: mirrored networking"
grep -q "vmIdleTimeout" ~/.wslconfig 2>/dev/null || echo "MISSING: idle timeout"
grep -q "dnsTunneling" ~/.wslconfig 2>/dev/null || echo "MISSING: DNS tunneling"
```
**Classify:** HIGH if .wslconfig missing entirely. MEDIUM per missing recommended setting.

### Dimension 5.9: Datetime/Timezone Safety
**Search for:** Deprecated utcnow(), naive datetime usage, timezone mixing.
```bash
grep -rn "datetime.utcnow\|datetime.now()" python/ --include="*.py" | grep -v "timezone\|tz=" | head -15
grep -rn "\.replace(tzinfo=" python/ --include="*.py" | head -10
grep -rn "datetime.now()" python/ --include="*.py" | head -15
```
**Classify:** HIGH if utcnow() used (deprecated in Python 3.12). HIGH if datetime.now() without timezone in time-critical code. MEDIUM if .replace(tzinfo=) used instead of .astimezone().

### Dimension 5.10: Signal/Shutdown Handling
**Search for:** Missing SIGTERM handlers, atexit limitations, protection for in-flight work or external side effects on crash.
```bash
grep -rn "signal\.signal\|signal\.SIGTERM\|signal\.SIGINT" python/ --include="*.py" | head -10
grep -rn "atexit\.register" python/ --include="*.py" | head -10
grep -rn "def.*shutdown\|def.*cleanup\|def.*graceful" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if no shutdown handler exists in a process with in-flight work or external side effects. HIGH if atexit is used for critical cleanup (doesn't run on SIGKILL). MEDIUM if shutdown exists but does not safely flush or close in-flight work.

### Dimension 5.11: Closure/Generator Bugs
**Search for:** Late-binding closures in loops, exhausted generators reused, lru_cache on methods.
```bash
grep -rn "lambda.*for\|lambda.*in " python/ --include="*.py" | head -10
grep -rn "@lru_cache" python/ --include="*.py" | head -10
grep -rn "@functools.lru_cache" python/ --include="*.py" | head -10
```
**Classify:** HIGH if lambda in for-loop captures loop variable. HIGH if @lru_cache on instance method (prevents GC). MEDIUM for generator reuse patterns.

### Dimension 5.12: Identity vs Equality
**Search for:** Using `is` for value comparison, missing __hash__ when __eq__ defined.
```bash
grep -rn "is True\|is False\|is 0\|is 1\|is ''" python/ --include="*.py" | grep -v "is True:" | head -10
grep -rn "def __eq__" python/ --include="*.py" | head -10
# For each __eq__, check if __hash__ exists in same class
```
**Classify:** MEDIUM for `is True/False` (usually works but wrong semantics). HIGH if __eq__ without __hash__ (breaks sets/dicts). LOW for `is None` (correct usage).
