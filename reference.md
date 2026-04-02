# Audit and Fix — Reference

Detailed reference material for the audit-and-fix skill. See `SKILL.md` for the core process.

## Fix Phase Dependency Graph

Before dispatching fix phases, build the dependency graph to maximize parallelism.

**Step 1 — List each phase's file scope:**
```
Phase A: data_writer.py, compute_kernels.py, simulator.py
Phase B: inference.py, registry.py, event_collector.py
Phase C: core.py (consensus), job_queue.py (NEW), dispatcher.py
Phase D: core.py (cleanup), inference.py (dict-mutation)
```

**Step 2 — Find dependencies (does Phase X modify a file Phase Y also touches?):**
```
A -> B: no overlap -> PARALLEL
A -> C: no overlap -> PARALLEL
B -> C: inference.py (B modifies lock, C reads) -> C WAITS for B
B -> D: inference.py in both -> D WAITS for B
C -> D: core.py in both -> D WAITS for C
```

**Step 3 — Draw the graph:**
```
Phase A ------+
Phase B --+---+
          |   +-> Phase D (waits for B+C)
Phase C --+   |
              v
         Version Bump
```

**Step 4 — Execute:** Launch A+B parallel. When B finishes, launch C. When B+C finish, launch D.

**Rules:**
- Two phases with ZERO file overlap -> safe to parallelize
- One phase WRITES a file another phase READS -> sequential (writer first)
- One phase WRITES a file another phase also WRITES -> merge into one phase
- When in doubt: sequential is safer than debugging merge conflicts

## Advanced Parallelization

5 strategies to reduce audit time from ~6-8h to ~3-4h.

### Strategy 1: Mega-Parallel Exploration

Instead of running rounds sequentially, dispatch ALL independent rounds in a single batch:

```
# Single dispatch call — 20+ agents at once
Round 1 agents (4-5) ─┐
Round 2 agents (4-5) ──┤
Round 3 agents (4-5) ──┼── ALL PARALLEL (independent rounds)
Round 5 agents (4)   ──┤
Round 6 agents (3-4) ──┘
                       ↓ (wait for all)
Round 4 agents (3)  ──── SEQUENTIAL (needs Round 1-3 findings)
                       ↓
Consolidation
```

**Time saved:** ~90 minutes (5 sequential rounds × 30min → 1 parallel batch of 30min + Round 4 of 30min = 60min total vs 150min).

**Resource cost:** 20+ concurrent agents. Ensure machine has enough CPU/memory.

**How to dispatch:** Use Agent tool with `run_in_background: true` for all agents in ONE message. Each agent gets its dimension + search commands from the relevant round file.

### Strategy 2: Opus Review + /simplify in Parallel

**WARNING: Opus MUST complete and CRITICAL fixes applied BEFORE /simplify starts.** /simplify on unfixed code wastes tokens on findings that become irrelevant after the Opus fix. Only parallelize if Opus found 0 CRITICAL findings.

Instead of:
```
Merge → Tests → Opus Review → Fix Opus Findings → /simplify → Fix Simplify Findings
```

Do (only if 0 CRITICAL findings from Opus):
```
Merge → Tests → [Opus Review + /simplify in PARALLEL] → Merge all findings → Fix combined
```

**Time saved:** ~30 minutes per gate (review and simplify run concurrently).

**Risk:** /simplify might flag something Opus also flags — deduplicate findings before fixing.

**How:** Launch Opus reviewer and 3 /simplify agents all with `run_in_background: true` in one message. Wait for all 4, then combine findings.

### Strategy 3: Overlapping Fix Phases

When two fix phases touch ZERO common files, run them simultaneously:

```
# Check file overlap between Phase A and Phase B:
Phase A files: data_writer.py, compute_kernels.py, simulator.py
Phase B files: cache_pool.py, event_bus.py, job_store.py
Overlap: NONE → SAFE TO PARALLELIZE

# Dispatch:
Phase A agents (worktree A1, A2) ──┐
Phase B agents (worktree B1, B2) ──┼── PARALLEL
                                    ↓
Gate A+B combined (merge both, test, review)
```

**Time saved:** Up to 50% of fix time when phases are independent.

**Risk:** If ANY file overlap exists between phases, do NOT parallelize — sequential is safer.

### Strategy 4: Early Consolidation

Start consolidating findings from completed rounds while the last round is still running:

```
Round 1+2+3+5+6 complete → Start partial consolidation (P0 candidates)
                            ↓ (while Round 4 runs)
Round 4 complete          → Merge Round 4 findings into consolidated report
                            ↓
Full consolidation + fix phase planning
```

**Time saved:** ~15 minutes (consolidation overlaps with Round 4).

**How:** After Rounds 1-3+5+6 complete, launch a consolidation agent that writes preliminary P0/P1 lists. When Round 4 finishes, a second agent merges architecture findings into the existing report.

### Strategy 5: Cross-Machine Split

Split exploration rounds between two machines:

```
Machine A:                         Machine B:
├── Round 1 (Code-Level)           ├── Round 2 (System-Level)
├── Round 3 (Domain/ML)            ├── Round 5 (Platform)
├── Round 4 (Architecture)         ├── Round 6 (Security)
└── Consolidation                  └── Push findings to Git
```

**Coordination:**
1. Both machines pull latest main
2. Machine A runs Rounds 1+3+4, Machine B runs Rounds 2+5+6 — simultaneously
3. Each machine commits findings to `docs/handoffs/round-N-findings.md`
4. Push to Git
5. One machine pulls all findings and runs consolidation
6. Fix phases run on the machine that owns the affected files

**Time saved:** Up to 50% of exploration time (split across 2 machines).

**Prerequisite:** Both machines on same Git commit. Syncthing or Git for finding sync.

### Strategy 6: Function-Level Parallelism (Same File, Different Functions)

When two fix agents need the SAME file but different FUNCTIONS, they can still run in parallel:

```
# Traditional (conservative): Sequential because same file
Agent A: fix connect() in db_pool.py → WAIT
Agent B: fix execute() in db_pool.py → WAIT after A

# Function-Level Parallel: Both in worktrees, merge has non-overlapping hunks
Agent A (worktree): db_pool.py lines 50-80 (connect fix)
Agent B (worktree): db_pool.py lines 200-230 (execute fix)
→ git merge: Auto-merge succeeds (different hunks, no conflict)
```

**When it's safe:**
- Fixes touch different functions (>20 lines apart)
- Neither fix adds/removes imports that the other needs
- Neither fix changes class-level state that the other reads

**When it's NOT safe:**
- Fixes touch the same function
- One fix changes a function signature the other calls
- Both fixes modify the same import block

**How to verify:** After both agents commit, dry-run the merge:
```bash
git merge-tree $(git merge-base branch-A branch-B) branch-A branch-B
```
If no conflict markers → safe to merge. If conflicts → resolve manually.

**Time saved:** Eliminates sequential waiting when multiple bugs are in the same large file (common in god-modules).

### Parallelization Summary

| Strategy | Time Saved | Risk | Complexity |
|----------|-----------|------|------------|
| Mega-Parallel Exploration | ~90min | Low (independent rounds) | Low |
| Review + /simplify Parallel | ~30min/gate | Low (deduplicate findings) | Low |
| Overlapping Fix Phases | ~50% fix time | Medium (file overlap check needed) | Medium |
| Early Consolidation | ~15min | Low (partial report extended) | Low |
| Cross-Machine Split | ~50% exploration | Medium (Git coordination) | Medium |
| Function-Level Parallelism | ~20-40min | Low (different-hunk merge check) | Low |

**Combined maximum:** 6-8h → **~3h** (all strategies active).

## Benchmark Comparison

| Metric | Healthy | Moderate | Poor |
|--------|---------|----------|------|
| Health Score | >80 | 50-80 | <50 |
| CRITICAL / KLOC | <0.5 | 0.5-2.0 | >2.0 |
| Broad Exceptions | <10 | 10-50 | >50 |
| Utility Duplicates | <5 | 5-20 | >20 |
| Test Coverage (critical paths) | >70% | 40-70% | <40% |
| Thread-Safety Issues | 0 | 1-3 | >3 |
| Stale Config Items | 0 | 1-5 | >5 |

## Lessons Learned (Auto-Tuning)

After each audit, generate tuning data for future runs:

```json
{
  "date": "YYYY-MM-DD",
  "dimensions_zero_findings": ["1.7", "1.8", "5.12"],
  "dimensions_most_findings": ["1.3", "2.1", "3.1"],
  "suggested_skip_next": ["1.7", "1.8"],
  "suggested_priority_boost": ["1.3", "2.1"],
  "duration_minutes": 480,
  "health_before": 47,
  "health_after": 91
}
```

Save to `artifacts/audit-memory/tuning.json`. Next audit loads this file and:
- Skips dimensions that found 0 issues in last 2 audits
- Boosts priority of dimensions that found >5 CRITICAL issues
- Estimates duration based on previous runs

## Regression Watch

After fixing findings, create `artifacts/audit-memory/regression-watch.json` with fixed patterns:

```json
{
  "watched_patterns": [
    {"pattern": "except Exception:\\s*pass", "max_allowed": 0, "description": "Silent error swallowing"},
    {"pattern": "shutil.copy2", "files": ["model_updater.py"], "description": "Non-atomic file promotion"},
    {"pattern": "== 0\\.0", "files": ["data_writer.py", "simulator.py"], "description": "Exact float comparison"}
  ]
}
```

Next audit checks: are any watched patterns re-introduced? If yes -> flag as REGRESSION (higher priority than new findings).

## Audit Memory (Persistent Learning)

All audit data is stored in `artifacts/audit-memory/` (Git-tracked, cross-machine via push/pull):
- `history.json` — Append-only log of all audits
- `tuning.json` — Auto-generated skip/boost recommendations
- `regression-watch.json` — Watched patterns from previous fixes
- `false-positives.json` — Confirmed non-bugs to skip

Before each audit: load memory -> apply tuning -> check regressions -> filter false positives.
After each audit: append history -> regenerate tuning -> update regressions -> commit to Git.

See `audit-memory.md` for schemas and `learning-agents.md` for the post-audit analysis agents.

## Skill Self-Improvement

Every 3rd audit (or `--improve` flag), a Skill Improvement Agent proposes changes:
- Dead dimensions to merge/remove
- Missing dimensions to add
- Search commands to refine
- Presets to optimize

See `skill-improvement.md`. Changes are NEVER applied automatically — user reviews first.
