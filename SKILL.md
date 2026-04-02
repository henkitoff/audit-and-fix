---
name: audit-and-fix
description: Use when starting a comprehensive codebase audit, after major feature additions, before releases, or when multiple bugs suggest systemic issues — explores 75 dimensions across 7 rounds then fixes in parallel phases with Opus reviews
---

# Audit and Fix

## Overview

Multi-round, multi-agent codebase audit across 75 dimensions in 7 rounds, followed by parallel fix phases with Opus reviews and /simplify after each phase.

**Core principle:** Explore first, fix second. Never fix without understanding the full scope.

## Installation (once per machine)

```bash
# Mac:
bash scripts/install_skill.sh

# Windows (PowerShell):
powershell -File scripts\install_skill.ps1
```

Copies the skill to `~/.claude/skills/audit-and-fix/`. Re-run after skill updates (or after `git pull`).
Audit memory (`artifacts/audit-memory/*.json`) syncs automatically via Git — no extra setup.

## Quick Start (5 minutes to first results)

1. **Quick scan:** Run `/audit-and-fix --preset quick` — explores Round 1 (Code) + Round 4 (Architecture) only. ~2 hours.
2. **Review findings:** Read the consolidated report. Focus on CRITICAL items first.
3. **Fix phase:** Skill guides you through parallel fix agents + Opus review + /simplify.
4. **Full audit:** When ready, run `/audit-and-fix --preset full` for all 75 dimensions.

**First time?** The skill auto-detects your project (see `auto-detect.md`) and skips irrelevant dimensions.

## When to Use

**Use when:**
- After major feature additions (milestone releases)
- Multiple unrelated bugs suggest systemic issues
- Before production deployment of new strategies
- Quarterly codebase health check
- Post-incident to find related vulnerabilities

**Don't use when:**
- Single known bug (use `systematic-debugging`)
- Code review of a PR (use `requesting-code-review`)
- Simple cleanup (use `/simplify` directly)
- Performance-only issues (use profiling tools)

## The Process

```
Exploration → Consolidation → **Verification** → Fix Phases → Version Bump
```

### Exploration (7 Rounds)

> "Round" = exploration sweep, "Phase" = fix batch, "Step" = gate action.

Launch parallel Explorer agents per round. Each agent gets one dimension with search commands from `exploration-dimensions.md`.

| Round | Focus | Dims |
|-------|-------|------|
| 1 | Code-Level Bugs (dict-mutation, memory, threads, NaN, ...) | 8 |
| 2 | System-Level (data integrity, security, imports, tests, ...) | 12 |
| 3 | Domain-Specific (look-ahead bias, drift, cost-model, ...) | 9 |
| 4 | Architecture (cascading chains, complexity, API stability, OOP, ...) | 9 |
| 5 | Environment & Platform (paths, WSL2, datetime, closures, ...) | 12 |
| 6 | Security Deep Dive (auth, secrets, injection, supply chain, ...) | 13 |
| 7 | Token & API Cost Efficiency (prompt size, model routing, caching, streaming, compression, ...) | 12 |

**DEFAULT: Mega-Parallel Dispatch.** Launch ALL independent rounds (1,2,3,5,6,7) in a single batch using `run_in_background: true`. This is ~60 minutes faster than sequential dispatch. Round 4 starts when Rounds 1-3 complete (needs their findings).

**Codebase Map (incremental mode):** If `artifacts/audit-memory/codebase-map.json` exists from a previous audit, Explorer agents receive per-file context: known hot-spots, previous findings, and historically-matched dimensions. This improves focus and reduces false positives. See `codebase-map.md`.

**IMPORTANT:** Keep exactly one agent blocking (not `run_in_background`) to prevent idle sessions. See `agent-prompts.md` "Dispatch Pattern" for details.

```
Exploration → One batch (Rounds 1,2,3,5,6,7) → Wait for all → Round 4 → Consolidation
```

**Large Dimension Splitting:** Dimensions with >15 checks should be split into sub-agents:
- Each sub-agent gets ONE technology/category from the dimension
- Example: Dim 2.10 (Data Store Safety, 40 checks) → 6 sub-agents (SQLite, PostgreSQL, DuckDB, Redis, Parquet, MinIO)
- Each sub-agent is more focused → better findings, fewer false positives
- Sub-agents run in parallel (different technologies = no file overlap)

### Consolidation

Produce a single prioritized report (`report-templates.md`): P0 (capital/data, fix this week), P1 (stability, next week), P2 (quality, this month). Group P0+P1 into fix phases with no file overlap.

### Verification (2nd-Eye Check)

Before fixing, verify the top findings are REAL:

1. Launch 1-2 Sonnet verification agents on the P0+P1 findings from consolidation
2. Each agent READS the actual code (not just grep output) and confirms:
   - **CONFIRMED**: Bug exists, reproducer possible
   - **FALSE POSITIVE**: Not a bug (add to `false-positives.json`)
   - **NEEDS CONTEXT**: Can't determine without domain knowledge (escalate to user)
3. Only CONFIRMED findings proceed to Fix Phases
4. FALSE POSITIVES are removed from the roadmap immediately

**Why:** Exploration uses grep — fast but imprecise. Verification reads code — slower but catches false positives. Without this step, ~20-30% of fix agent time is wasted on non-bugs.

### Fix Phases (A, B, C, D)

Each phase follows `gate-pattern.md`: Agents (parallel, worktrees) -> Merge -> Tests -> Opus Review -> Fix -> /simplify -> Next Phase. For dependency graphs and parallelization rules, see `reference.md`.

Fix phases with zero file overlap can run in parallel. See `reference.md` "Overlapping Fix Phases".

### Version Bump

After all phases pass gates: full test suite -> final Opus review -> version bump -> push.

## Quick Reference

| Phase | Agents | Duration |
|-------|--------|----------|
| Rounds 1-3, 5-7 (parallel) | 4-5 each | ~30min-1h each |
| Round 4 (Architecture, sequential) | 3 | ~30min |
| Consolidation | 1 | ~15min |
| Fix Phases A-D | 3-4 worktree each | ~1-2h each |

**Total:** ~20-30 agents, ~6-8 hours, 75 dimensions, 3+ Opus reviews, 3+ /simplify runs

## Presets

- `--preset quick`: Round 1 (Code) + Round 4 (Architecture) only. ~2 hours.
- `--preset full`: All 75 dimensions, all 7 rounds. ~6-8 hours.
- `--preset platform`: Round 5 only. ~30 min, cross-platform + WSL2 + Python gotchas.
- `--preset security-deep`: Round 6 only. ~1-2 hours, comprehensive security audit with tool integration (bandit, pip-audit, detect-secrets).
- `--preset token`: Round 7 only. ~30 min, LLM API cost optimization.

## Common Mistakes

1. **Fixing during exploration** — Rounds are READ-ONLY. Full picture first, fix second.
2. **File overlap in parallel agents** — Two agents on same file = merge conflicts. Check overlap matrix.
3. **Skipping Opus review** — Tests miss design flaws and race conditions. Review catches what tests miss.
4. **Skipping /simplify** — Review fixes introduce their own code smells. /simplify is final polish.
5. **Treating all findings equally** — P0 (account blowup) before P1 before P2. Always.

## Supporting Files

| File | Purpose |
|------|---------|
| `exploration-dimensions.md` | Index of all 75 dimensions (links to round files) |
| `dimensions/round1-*.md` .. `round7-*.md` | Per-round dimensions with search commands |
| `token-optimization-guide.md` | Token budget calculator + cost reduction strategies |
| `gate-pattern.md` | Gate sequence: merge -> test -> review -> simplify |
| `report-templates.md` | Templates for exploration, consolidation, reviews |
| `progress-template.md` | Live progress dashboard |
| `agent-prompts.md` | Copy-paste prompts for all agent types |
| `auto-detect.md` | Skip-logic for irrelevant dimensions |
| `audit-memory.md` | Persistent learning system (schemas, sync) |
| `codebase-map.md` | Per-file dimension memory for incremental scanning and risk-based prioritization |
| `reference.md` | Parallelization strategies (6), benchmarks, dependency graphs, regression watch, tuning |
| `ollama-integration.md` | Optional Ollama usage for post-audit summary and handoff compression |

## Related Skills

- `systematic-debugging` — Single bug root-cause investigation
- `dispatching-parallel-agents` — Core parallel execution pattern
- `requesting-code-review` — Opus review pattern
- `simplify` — Code cleanup after changes
- `verification-before-completion` — Test-before-claim pattern

## Real-World Impact

Production Python system (120K LOC): 14 exploration agents, 87 bugs + 5 cascading chains + 8 design flaws found, 22 CRITICAL. 12 fix agents across 4 phases, 3 Opus reviews caught 5 additional issues. All 119+ tests green. ~8 hours total.
