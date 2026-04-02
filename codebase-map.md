# Codebase Map — Per-File Dimension Memory

A persistent map that tracks which files matched which dimensions across audits. Enables incremental scanning, contextual exploration, and risk-based prioritization.

## File: `artifacts/audit-memory/codebase-map.json`

### Schema

```json
{
  "schema_version": 1,
  "last_scan": "YYYY-MM-DD",
  "last_commit": "abc123",
  "files": {
    "path/to/file.py": {
      "last_scanned": "YYYY-MM-DD",
      "file_hash": "sha256_first16",
      "loc": 587,
      "dimensions_matched": ["1.3", "1.6", "2.10"],
      "findings": [
        {
          "dim": "1.3",
          "line": 292,
          "severity": "HIGH",
          "status": "open|fixed|wontfix|false_positive",
          "summary": "Thread race in _get_pg_pool()",
          "found_in": "YYYY-MM-DD",
          "fixed_in": null
        }
      ],
      "risk_score": 0,
      "tags": []
    }
  },
  "hot_spots": [],
  "clean_files": []
}
```

### Risk Score Calculation

Per file: `risk_score = (open_critical × 10) + (open_high × 5) + (open_medium × 2) + (historical_bugs × 1)`

Hot spots = files with risk_score >= 10. Clean files = files scanned with 0 findings in last 2 audits.

### 3 Usage Modes

#### Mode 1: First Scan (no map exists)

1. Explorer agents scan ALL files as normal
2. After consolidation, build the map from findings:
   - Each finding → file entry + dimension + severity + line
   - Calculate risk scores
   - Identify hot spots and clean files
3. Save to `artifacts/audit-memory/codebase-map.json`
4. Commit to Git

#### Mode 2: Incremental Scan (`--scope changed`)

1. Load existing map
2. Get changed files: `git diff --name-only <last_commit>..HEAD`
3. For changed files: run ALL relevant dimensions (map tells which dims to prioritize)
4. For unchanged hot-spots: run a QUICK re-check (only their historically-matched dimensions)
5. Skip clean files entirely
6. Update map: new findings, resolved findings, new risk scores

**Agent context injection:** When dispatching an Explorer for a changed file, include its history:
```
"File python/services/db_pool.py has been modified since last audit.
Previous findings: Thread race at line 42 (fixed), Resource leak at line 87 (open).
Focus on: Dim 1.3 (Thread-Safety), Dim 1.6 (Resource Leaks), Dim 2.10 (Data Store).
Also check for NEW issues — the file changed, so new bugs may have been introduced."
```

#### Mode 3: Targeted Scan (`--scope file <path>`)

1. Load map for the specified file(s)
2. Show historical dimensions and findings
3. Run ONLY the historically-relevant dimensions + any user-specified extras
4. Update map

### How Explorer Agents Use the Map

**Without map (current):** Agent gets dimension + grep commands. Searches blindly.

**With map:** Agent gets dimension + grep commands + file context:
```
DIMENSION: 1.3 Thread-Safety
CONTEXT FROM MAP:
- python/services/db_pool.py: KNOWN HOT-SPOT (risk=7). Previous: thread race at line 42 (fixed 1.5.0). Watch for regression.
- python/core/inference.py: Previous: cache lock issue at line 88 (fixed 1.5.0). Verify fix intact.
- python/workers/collector.py: Previous: _last_check unprotected (fixed 1.5.0). Clean since fix.

SEARCH: Focus on files above + any NEW files not in map + files changed since last scan.
```

This reduces false positives (agent knows what's already been found/fixed) and increases true positives (agent focuses on known-fragile code).

### Map Maintenance

**After each audit:**
1. Merge new findings into existing map
2. Mark fixed findings (if fix-phase resolved them)
3. Recalculate risk scores
4. Update hot_spots and clean_files lists
5. Commit updated map

**Staleness:** If a file's `file_hash` no longer matches disk, the file was modified outside an audit → flag for re-scan.

**Cross-machine:** Map is in `artifacts/audit-memory/` which is Git-tracked → syncs via push/pull.

## Anti-Blindness Safeguards

The map must NEVER cause bugs to be missed. These 3 safeguards prevent the map from creating blind spots:

### Safeguard 1: Changed Files Get ALL Dimensions
When a file appears in `git diff`, scan it with ALL 73 dimensions — not just the historically-matched ones. The map PRIORITIZES (known dims first) but must NOT RESTRICT the search scope.

```
WRONG:  db_pool.py changed → scan only Dim 1.3, 2.10 (from map)
                             → MISSES new eval() injection (Dim 6.4)

RIGHT:  db_pool.py changed → scan Dim 1.3, 2.10 FIRST (from map, high-priority)
                            → THEN scan ALL other dims (lower-priority, can be quick-check)
```

### Safeguard 2: Periodic Full Rescan
Every 5th audit MUST be a full scan (`--preset full`) regardless of map state. This catches bugs that accumulated in "clean" files through gradual changes below the diff threshold.

The map tracks this: `"full_rescan_counter": N` — increments each incremental audit, resets to 0 on full scan. When counter reaches 5, the skill prompts: "Full rescan recommended (5 incremental audits since last full). Run --preset full? [y/n]"

### Safeguard 3: Random Sampling of Clean Files
Each incremental audit: randomly select 10% of `clean_files` and scan them with ALL dimensions. If ANY finding is discovered:
1. Remove that file from `clean_files` immediately
2. Add it to `hot_spots`
3. Log a WARNING: "Clean file had hidden bug — consider full rescan"

This prevents false confidence in the "clean" classification.

### The Golden Rule
**The map is an OPTIMIZATION tool, not a FILTERING tool.** It tells agents WHERE to look first, not WHERE to look only.

### Map-Aware Consolidation

When consolidating findings, compare against the map to categorize:

| Category | Meaning | Action |
|----------|---------|--------|
| **NEW** | Finding in file not previously scanned for this dimension | Normal priority |
| **REGRESSION** | Finding was previously marked "fixed" but is back | HIGH priority — fix broke |
| **PERSISTENT** | Finding was "open" in last audit and still open | Lower priority (known debt) |
| **RESOLVED** | Finding was "open" but no longer found | Mark as "fixed" in map |
| **CLEAN SURPRISE** | Finding in a file previously marked "clean" | WARNING — trigger Safeguard 3 review |

### Integration with Existing Memory

The codebase map EXTENDS (not replaces) the existing memory system:
- `history.json` — audit-level stats (unchanged)
- `tuning.json` — dimension-level skip/boost (unchanged)
- `regression-watch.json` — pattern-level watches (unchanged)
- `false-positives.json` — finding-level exclusions (unchanged)
- **`codebase-map.json`** — NEW: file-level dimension mapping

The map is the most granular layer:
```
Audit History (coarse) → Dimension Tuning → Regression Watch → Codebase Map (fine)
```
