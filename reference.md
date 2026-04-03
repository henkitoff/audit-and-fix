# Audit and Fix - Reference

Detailed reference material for the audit-and-fix skill. See `SKILL.md` for the core process.

## Fix Phase Dependency Graph

Before dispatching fix phases, build the dependency graph to maximize parallelism.

**Step 1 - list each phase's file scope:**

```text
Phase A: data_writer.py, compute_kernels.py, simulator.py
Phase B: inference.py, registry.py, event_collector.py
Phase C: core.py, job_queue.py, dispatcher.py
Phase D: core.py, inference.py
```

**Step 2 - find dependencies:**

```text
A -> B: no overlap -> PARALLEL
A -> C: no overlap -> PARALLEL
B -> C: inference dependency -> C WAITS for B
B -> D: inference.py in both -> D WAITS for B
C -> D: core.py in both -> D WAITS for C
```

**Rules:**
- Zero file overlap -> parallel is usually safe
- One phase writes a file another phase reads -> sequence them
- Two phases both write the same file -> merge them into one phase
- When in doubt, prefer sequential execution over merge risk

## Advanced Parallelization

Five strategies reduce audit time from ~6-8h to ~3-4h.

### Strategy 1: Mega-Parallel Exploration

Dispatch all independent rounds in one batch:

```text
Rounds 1,2,3,5,6,7 -> parallel
Round 4 -> after 1-3 complete
Consolidation -> after Round 4
```

**Claude path:** use one dispatch message with N-1 background agents and 1 blocking agent.

**Codex default path:** execute the independent rounds sequentially in the main thread.

**Codex delegated fast-path:** if delegated sub-agents are available, policy-allowed, and explicitly requested by the user, `spawn_agent` the independent rounds, continue local work, and `wait_agent` only when blocked on the results.

### Strategy 2: Deep Review + Cleanup in Parallel

**Warning:** The deep review must finish first if it finds any `CRITICAL` issue. Cleanup on unfixed code wastes tokens.

Instead of:

```text
Integrate -> Tests -> Deep Review -> Fix Review Findings -> Cleanup -> Fix Cleanup Findings
```

Only when deep review reports 0 `CRITICAL`, allow:

```text
Integrate -> Tests -> [Deep Review + Cleanup in parallel] -> Merge findings -> Fix combined
```

**How:**
- Claude path: launch the reviewer and cleanup agents together in one message
- Codex default path: run deep review first, then cleanup sequentially in the main thread
- Codex delegated fast-path: if the user explicitly requested delegation and the host allows it, spawn one review agent plus up to three cleanup agents, then `wait_agent` for all of them

### Strategy 3: Overlapping Fix Phases

When two fix phases touch zero common files, run them simultaneously.

```text
Phase A files: data_writer.py, compute_kernels.py
Phase B files: cache_pool.py, event_bus.py
Overlap: NONE -> SAFE TO PARALLELIZE
```

**Risk:** if any file overlap exists, keep them sequential.

### Strategy 4: Early Consolidation

Start consolidating completed rounds while the last dependency-bound round is still running.

```text
Rounds 1,2,3,5,6 done -> partial consolidation
Round 4 still running
Round 4 done -> merge architecture findings into the report
```

### Strategy 5: Cross-Machine Split

Split exploration rounds between two machines on the same Git commit:

```text
Machine A: Rounds 1,3,4
Machine B: Rounds 2,5,6,7
```

Push findings to Git, then consolidate on one machine.

## Parallelization Summary

| Strategy | Time Saved | Risk | Complexity |
|----------|-----------|------|------------|
| Mega-Parallel Exploration | ~90min | Low | Low |
| Deep Review + Cleanup Parallel | ~30min/gate | Low | Low |
| Overlapping Fix Phases | up to ~50% of fix time | Medium | Medium |
| Early Consolidation | ~15min | Low | Low |
| Cross-Machine Split | up to ~50% of exploration time | Medium | Medium |

**Combined maximum:** 6-8h -> ~3h when all strategies fit the codebase.

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

Save it to `artifacts/audit-memory/tuning.json`.

## Regression Watch

After fixing findings, create `artifacts/audit-memory/regression-watch.json` with watched patterns:

```json
{
  "watched_patterns": [
    {"pattern": "except Exception:\\s*pass", "max_allowed": 0, "description": "Silent error swallowing"},
    {"pattern": "shutil.copy2", "files": ["model_updater.py"], "description": "Non-atomic file promotion"},
    {"pattern": "== 0\\.0", "files": ["data_writer.py", "simulator.py"], "description": "Exact float comparison"}
  ]
}
```

Flag any reintroduced pattern as `REGRESSION`.

## Audit Memory

All audit data lives in `artifacts/audit-memory/`:
- `history.json`
- `tuning.json`
- `regression-watch.json`
- `false-positives.json`

Before each audit:
- load memory
- apply tuning
- check regressions
- filter false positives

After each audit:
- append history
- regenerate tuning
- update regressions
- commit changes if that fits the repo workflow

## Skill Self-Improvement

Every third audit, or when explicitly requested, run a skill-improvement pass:
- remove or merge dead dimensions only by proposal, never automatically
- refine noisy search commands
- improve runtime-specific routing if the host workflows drift over time

See `skill-improvement.md`.
