# Round 1 — Code-Level Bugs

### Dimension 1.1: Dict-Mutation / Parameter-Pollution
**Search for:** Functions that receive dicts as parameters and mutate them by adding keys (especially underscore-prefixed).
```bash
grep -rn '\["_' python/ --include="*.py" | grep -v "test_\|#" | head -20
grep -rn 'model_info\[' python/ --include="*.py" | head -15
grep -rn 'config\[' python/ --include="*.py" | grep -v "test_\|\.get(" | head -15
```
**Classify:** HIGH if parameter dict is mutated (passed in from caller). LOW if local dict.

### Dimension 1.2: Unbounded Growth / Memory Leaks
**Search for:** Module-level or instance-level data structures that grow without bounds in long-running processes.
```bash
grep -rn "\.append(" python/ --include="*.py" | grep -v "test_\|#" | head -20
grep -rn "^_[A-Z_]*\s*=\s*{}\|^_[a-z_]*\s*=\s*{}" python/ --include="*.py" | head -15
grep -rn "deque()" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if in an always-on loop or long-lived service. MEDIUM if in batch jobs. LOW if in CLI tools.

### Dimension 1.3: Thread-Safety / Race Conditions
**Search for:** Shared mutable state accessed from multiple threads without locks.
```bash
grep -rn "threading\.\|Thread(\|Lock(" python/ --include="*.py" | head -15
grep -rn "_instance\|_singleton\|_global" python/ --include="*.py" | head -10
grep -rn "os.environ\[" python/ --include="*.py" | head -10
# Hanging async tasks (created but never awaited/collected)
grep -rn "asyncio\.create_task\|loop\.run_in_executor\|Thread(target" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if shared state is in a hot path (for example inference or request processing). HIGH if in background threads. MEDIUM if in startup-only code.

### Dimension 1.4: Numeric Precision / NaN / Float-Accumulation
**Search for:** Division without zero-guard, NaN propagation, exact float comparisons in money-handling code.
```bash
grep -rn "/ \|/=" python/ src/ app/ services/ --include="*.py" 2>/dev/null | head -20
grep -rn "== 0\.0\|!= 0\.0\|== 1\.0" python/ --include="*.py" | head -15
grep -rn "isnan\|np\.isnan\|math\.isnan" python/ --include="*.py" | wc -l
# Integer overflow in type conversions
grep -rn "int(\|np\.uint\|\.astype.*int\|\.astype.*uint" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if in money calculations, quota/limit enforcement, or other externally visible decisions. HIGH if in feature computation. MEDIUM if in logging/display.

### Dimension 1.5: Silent Error Swallowing
**Search for:** Exception handlers that hide errors (pass, return None, continue) without logging.
```bash
grep -rn "except.*:" python/ --include="*.py" -A1 | grep -B1 "pass$" | head -20
grep -rn "except.*:" python/ --include="*.py" -A1 | grep -B1 "continue$" | head -15
grep -rn "except.*:" python/ --include="*.py" -A2 | grep -B2 "return None" | head -15
```
**Classify:** CRITICAL if silences DB writes, job dispatch, or critical notification delivery. HIGH if in data pipeline. MEDIUM if in optional features.

### Dimension 1.6: Resource Leaks
**Search for:** Unclosed database connections, file handles, subprocess handles.
```bash
grep -rn "sqlite3.connect\|\.connect(" python/ --include="*.py" | grep -v "with \|test_" | head -15
grep -rn "open(" python/ --include="*.py" | grep -v "with \|test_\|#" | head -15
grep -rn "subprocess.Popen" python/ --include="*.py" | grep -v "test_" | head -10
```
**Classify:** HIGH if connection/handle is long-lived (class instance). MEDIUM if in function scope. LOW if in script/CLI.

### Dimension 1.7: Default Mutable Args + Import Side-Effects
**Search for:** Mutable default arguments and code that runs side effects at import time.
```bash
grep -rn "def .*=\[\]\|def .*={}" python/ --include="*.py" | head -15
grep -rn "^[a-z_].*=.*connect\|^[a-z_].*=.*open(" python/ --include="*.py" | head -10
grep -rn "basicConfig" python/ --include="*.py" | head -10
```
**Classify:** HIGH if mutable default in frequently-called function. MEDIUM if in rarely-used code. LOW for basicConfig (logging conflict, not data bug).

### Dimension 1.8: Serialization Boundaries
**Search for:** Complex types crossing process/serialization boundaries without conversion.
```bash
grep -rn "json.dumps\|json.loads" python/ --include="*.py" | wc -l
grep -rn "pickle\|pd.read_pickle" python/ --include="*.py" | head -10
grep -rn "datetime.*json\|Path.*json" python/ --include="*.py" | head -10
```
**Classify:** HIGH if pickle used on untrusted data. MEDIUM if datetime/Path not converted before JSON. LOW if serialization is internal-only.
