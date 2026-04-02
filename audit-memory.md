# Audit Memory System

Persistent learning across sessions and machines. All data stored in Git-tracked JSON files under `artifacts/audit-memory/`.

## File Structure

```
artifacts/audit-memory/
  history.json            — All past audits (append-only log)
  tuning.json             — Skip/boost recommendations (auto-updated)
  regression-watch.json   — Patterns to watch for re-introduction
  false-positives.json    — Known false positives (skip in future audits)
  codebase-map.json       — Per-file dimension mapping (risk scores, hot spots)
```

All files are committed to Git after each audit → available on both machines via push/pull.

## history.json Schema

Append one entry per audit:
```json
[
  {
    "date": "YYYY-MM-DD",
    "version": "1.0.0",
    "machine": "mac",
    "preset": "full",
    "rounds_executed": [1, 2, 3, 4, 5, 6],
    "dimensions_executed": 52,
    "dimensions_skipped": ["5.5", "5.6"],
    "findings": {
      "total": 87,
      "critical": 22,
      "high": 21,
      "medium": 28,
      "low": 16
    },
    "health_score_before": 47,
    "health_score_after": 91,
    "fixes_applied": 37,
    "duration_minutes": 480,
    "top_dimensions": ["1.3", "2.1", "6.1"],
    "zero_dimensions": ["1.7", "1.8", "5.12"]
  }
]
```

## tuning.json Schema

Auto-generated from history.json after each audit:
```json
{
  "last_updated": "YYYY-MM-DD",
  "skip_candidates": {
    "1.7": {"reason": "0 findings in last 3 audits", "last_finding": null},
    "1.8": {"reason": "0 findings in last 2 audits", "last_finding": null}
  },
  "priority_boost": {
    "1.3": {"reason": "avg 8.5 CRITICAL per audit", "trend": "increasing"},
    "6.1": {"reason": "CRITICAL in every audit", "trend": "stable"}
  },
  "estimated_duration": {
    "quick": 120,
    "full": 480,
    "security-deep": 90
  }
}
```

**IMPORTANT: Never auto-skip dimensions.** The tuning.json `skip_candidates` are RECOMMENDATIONS for the user to review. A dimension finding 0 issues could mean: (a) no bugs exist (safe to skip), or (b) the search commands are ineffective (dangerous to skip). Only the user can distinguish these cases.

Show skip candidates to the user at audit start:
```
"Tuning suggests skipping dimensions 1.7, 1.8, 5.12 (0 findings in last 2 audits). Accept? [y/n/review]"
```

## regression-watch.json Schema

Patterns that were fixed — check if they come back:
```json
{
  "watches": [
    {
      "id": "example-nan-guard",
      "pattern": "value <= 0",
      "file": "python/services/calculator.py",
      "description": "NaN passes numeric guard without validation",
      "fixed_in": "1.5.0",
      "fixed_date": "YYYY-MM-DD",
      "check_command": "grep -n 'value <= 0' python/services/calculator.py"
    }
  ]
}
```

## false-positives.json Schema

Findings confirmed as not-bugs — don't report again:
```json
{
  "false_positives": [
    {
      "dimension": "1.5",
      "file": "python/services/worker.py",
      "line": 42,
      "pattern": "except Exception",
      "reason": "Intentional top-level crash handler, documented with comment",
      "confirmed_by": "user",
      "date": "YYYY-MM-DD"
    }
  ]
}
```

## Usage in Audit Flow

### Before Exploration (Read Phase):
1. Load `history.json` — check last audit date, trending dimensions
2. Load `tuning.json` — apply skip/boost recommendations
3. Load `regression-watch.json` — add regression checks to Round 1
4. Load `false-positives.json` — filter known false positives from results

### After Fix Phases (Write Phase):
1. Append to `history.json` — new audit entry
2. Regenerate `tuning.json` — from last 3 audits in history
3. Update `regression-watch.json` — add newly fixed patterns
4. Update `false-positives.json` — confirmed non-bugs from verification phase
5. Update `codebase-map.json` — merge new findings, mark fixed, recalculate risk scores
6. Commit all to Git: `git add artifacts/audit-memory/ && git commit -m "audit: memory update [date]"`

### Cross-Machine Sync:
All files in `artifacts/audit-memory/` are Git-tracked. After audit:
```bash
git add artifacts/audit-memory/
git commit -m "audit: memory update YYYY-MM-DD"
git push origin main
```
Other machine picks up changes via `git pull` before next audit.

**See also:** `codebase-map.md` — per-file dimension memory: modes, risk scoring, agent context injection.
