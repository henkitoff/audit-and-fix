# Round 4 — Architecture Analysis

### Dimension 4.1: Cascading Bug Chains
**Search for:** How individual bugs interact to create compound failures. Requires findings from Rounds 1-3 as input.
```
For each CRITICAL finding from Rounds 1-3:
  1. Trace: what happens if this bug triggers?
  2. Does it enable another bug?
  3. What is the worst-case cascade?
  4. What existing safeguard (if any) catches it?
```
**Classify:** CRITICAL if chain leads to data loss or financial loss. HIGH if chain causes system outage. MEDIUM if chain causes degraded performance.

### Dimension 4.2: Architecture Design Flaws
**Search for:** Missing circuit breakers, single points of failure, consensus poisoning.
```bash
grep -rn "can_trade\|halt\|circuit.*break\|pause.*trad" python/ --include="*.py" | head -10
grep -rn "consensus\|ensemble\|voting" python/strategies/ --include="*.py" | head -15
grep -rn "health.*check\|is_alive\|ping" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if no mechanism to halt trading on critical errors. HIGH if consensus can be poisoned. MEDIUM if no degradation strategy for component failure.

### Dimension 4.3: Fundamentally Wrong Approaches
**Search for:** File-based IPC, model-as-file, config without hot-reload, missing crash recovery.
```bash
grep -rn "write_signal\|read_signal\|lockfile\|\.lock" python/ --include="*.py" | head -10
grep -rn "shutil.copy\|os.replace\|os.rename" python/ --include="*.py" | head -10
grep -rn "reload\|hot.*load\|refresh.*config" python/ --include="*.py" | head -5
```
**Output format:** For each approach found, assess: current approach, what's wrong, what's better, migration effort.

### Dimension 4.4: Cognitive Complexity + God-Module Detection
**Search for:** Files >500 LOC, functions >50 LOC, files with >15 imports.
```bash
find python/ -name "*.py" -exec wc -l {} + | sort -rn | head -20
for f in $(find python/ -name "*.py" -not -path "*test*"); do
  count=$(grep -c "^import\|^from" "$f" 2>/dev/null)
  [ "$count" -gt 15 ] && echo "GOD_MODULE: $f ($count imports)"
done
```
**Classify:** HIGH if >1000 LOC. MEDIUM if >500 LOC or >15 imports. LOW if >300 LOC.

### Dimension 4.5: Dependency Graph Fitness
**Search for:** Layer violations, cross-context imports, missing public API boundaries.
```bash
# Check declared layer order (adapt to your architecture — e.g. common -> core -> services -> api -> gui)
# Example for a layered Python project:
grep -rn "from api\|import api" python/common/ python/core/ --include="*.py"
grep -rn "from gui\|import gui\|import dash\|import plotly" python/common/ python/core/ python/services/ --include="*.py"
grep -rn "from services\|import services" python/common/ python/core/ --include="*.py"
```
**Classify:** CRITICAL if circular dependency causes import failure. HIGH if layer violation exists. LOW if violation is in re-export stub.

### Dimension 4.6: API Contract Stability + Temporal Coupling
**Search for:** Inconsistent return types, methods requiring specific call order.
```bash
grep -rn "def setup\|def init\|def start\|def configure" python/ --include="*.py" | head -15
grep -rn "-> None\|-> bool\|-> dict\|-> list\|-> tuple" python/common/ --include="*.py" | head -20
grep -rn "must.*call.*before\|call.*first\|requires.*init" python/ --include="*.py" | head -10
```
**Classify:** HIGH if temporal coupling without runtime enforcement. MEDIUM if return types inconsistent across similar functions. LOW if documented but not enforced.

### Dimension 4.8: Cross-Cutting Concerns
**Search for:** Patterns that span multiple dimensions — e.g., a stale cache (2.3) that causes a NaN (1.4) that silently swallows (1.5).
```
Review all CRITICAL+HIGH findings from Rounds 1-3.
Group findings that touch the same file or data flow.
Identify compound risks.
```
**Classify:** Based on worst-case compound impact.

### Dimension 4.9: Missing Defensive Patterns
**Search for:** Assertions, invariant checks, runtime type guards that should exist but don't.
```bash
grep -rn "assert " python/ --include="*.py" | grep -v "test_\|pytest" | wc -l
grep -rn "isinstance\|type(" python/ --include="*.py" | grep -v "test_" | wc -l
grep -rn "raise ValueError\|raise TypeError" python/ --include="*.py" | wc -l
```
**Classify:** HIGH if no assertions in critical paths (order execution, model promotion). MEDIUM if assertions exist but don't cover edge cases.

### Dimension 4.7: OOP Design & Code Smells
**Search for:** Inheritance issues, encapsulation violations, abstraction problems, code complexity smells.
```bash
# Deep hierarchy (>4 levels of inheritance)
grep -rn "class.*\(.*\):" python/ --include="*.py" | head -20
# Diamond/multipath inheritance
grep -rn "class.*\(.*,.*\):" python/ --include="*.py" | head -10
# Override without super() call
grep -rn "def __init__" python/ --include="*.py" -A10 | grep -v "super()" | head -10
# isinstance instead of polymorphism
grep -rn "isinstance(" python/ --include="*.py" | grep -v "test_" | wc -l
# Single-method classes (imperative abstraction)
for f in $(find python/ -name "*.py" -not -path "*/test*"); do m=$(grep -c "def " "$f"); [ "$m" -eq 2 ] && echo "SINGLE_METHOD: $f"; done 2>/dev/null | head -10
# Dead classes (defined but never imported elsewhere)
grep -rh "^class " python/ --include="*.py" | sed 's/class \([^(:]*\).*/\1/' | while read c; do n=$(grep -rc "\b$c\b" python/ --include="*.py"); [ "$n" -le 1 ] && echo "UNUSED: $c"; done 2>/dev/null | head -10
# Long parameter lists (>5 params)
grep -rn "def .*,.*,.*,.*,.*," python/ --include="*.py" | grep -v "test_\|#" | head -10
# Long statements (>120 chars)
grep -rn ".\{121,\}" python/ --include="*.py" | wc -l
# Complex conditionals (deeply nested if/elif)
grep -rn "elif\|else:" python/ --include="*.py" | head -20
# Hub-like modules (>15 imports = god module with high fan-in/fan-out)
for f in $(find python/ -name "*.py"); do c=$(grep -c "^import\|^from" "$f"); [ "$c" -gt 15 ] && echo "HUB: $f ($c imports)"; done 2>/dev/null | head -10
# Missing default in match/case (Python 3.10+)
grep -rn "match " python/ --include="*.py" -A10 | grep -v "case _:" | head -5
# Deficient encapsulation (public attrs that could be private)
grep -rn "self\.[a-z][a-zA-Z0-9_]*\s*=" python/ --include="*.py" | grep -v "self\._\|test_\|__init__\.py" | wc -l
```
**Classify:** MEDIUM for all. These are maintainability issues, not runtime bugs. Prioritize: dead classes and hub modules first (highest maintenance burden), inheritance smells second.
