---
name: audit-and-fix
description: Use when starting a comprehensive codebase audit, after major feature additions, before releases, or when multiple bugs suggest systemic issues. Runs an environment-aware 75-dimension audit across 7 rounds, using Claude-native workflows in Claude and Codex/OpenAI-native workflows in Codex before parallel fix phases and deep-review gates.
---

# Audit and Fix

## Overview

Multi-round codebase audit across 75 dimensions in 7 rounds, followed by fix phases with a native deep review and cleanup pass after each phase.

**Core principle:** Explore first, fix second. Never fix without understanding the full scope.

**Runtime rule:** Detect the current host and available capabilities first via `runtime-routing.md`.
- In Claude Code or Claude in VS Code, use the Claude-native path.
- In Codex or Codex in VS Code, use the Codex/OpenAI-native path only.
- In Codex, default to a single-agent workflow.
- Use delegated sub-agents only when the current host exposes them, the current policy allows delegated execution, and the user explicitly asks for delegation or parallel agent work.
- Never mix Claude-only commands (`Agent(...)`, `run_in_background`, `/simplify`, Opus reviewer) with Codex-only tools (`spawn_agent`, `wait_agent`, `worker`/`explorer`, `apply_patch`) in the same audit.

## Installation (once per machine)

```bash
# Mac/Linux:
bash scripts/install_skill.sh auto

# Windows (PowerShell):
powershell -File scripts\install_skill.ps1 -Target auto
```

`auto` installs to both `~/.claude/skills/audit-and-fix/` and `${CODEX_HOME:-~/.codex}/skills/audit-and-fix/`.
Use `claude`, `codex`, or `both` to control the target explicitly.

Audit memory (`artifacts/audit-memory/*.json`) syncs automatically via Git - no extra setup.

## Quick Start (5 minutes to first results)

1. Detect the host runtime with `runtime-routing.md`.
2. Quick scan:
   - Claude path: `/audit-and-fix --preset quick`
   - Codex path: `Use $audit-and-fix to run the quick preset on this repo.`
3. Review findings. Focus on CRITICAL items first.
4. Run fix phases using the host-native execution path from `gate-pattern.md`.
5. Run the full audit when ready:
   - Claude path: `/audit-and-fix --preset full`
   - Codex path: `Use $audit-and-fix to run the full preset on this repo.`

**First time?** The skill auto-detects your project (see `auto-detect.md`) and skips irrelevant dimensions.
**Invocation note:** In Codex, invoke the skill with `$audit-and-fix` inside a normal prompt. `/audit-and-fix` remains a Claude-style slash invocation and is not exposed as a native Codex slash command by this skill format.

## When to Use

**Use when:**
- After major feature additions
- Multiple unrelated bugs suggest systemic issues
- Before production deployment of high-impact workflows
- Quarterly codebase health check
- Post-incident to find related vulnerabilities

**Do not use when:**
- Single known bug (use `systematic-debugging`)
- Code review of a PR (use `requesting-code-review`)
- Simple cleanup (use the host-native cleanup flow directly)
- Performance-only issues (use profiling tools)

## The Process

```text
Exploration -> Consolidation -> Verification -> Fix Phases -> Version Bump
```

### Exploration (7 Rounds)

> "Round" = exploration sweep, "Phase" = fix batch, "Step" = gate action.

Run one dimension at a time or fan out independent dimensions, depending on the current host capabilities. Each exploration unit gets one dimension with search commands from `exploration-dimensions.md`.

| Round | Focus | Dims |
|-------|-------|------|
| 1 | Code-Level Bugs (dict-mutation, memory, threads, NaN, ...) | 8 |
| 2 | System-Level (data integrity, security, imports, tests, ...) | 12 |
| 3 | Domain-Specific (look-ahead bias, drift, cost-model, ...) | 9 |
| 4 | Architecture (cascading chains, complexity, API stability, OOP, ...) | 9 |
| 5 | Environment & Platform (paths, WSL2, datetime, closures, ...) | 12 |
| 6 | Security Deep Dive (auth, secrets, injection, supply chain, ...) | 13 |
| 7 | Token & API Cost Efficiency (prompt size, model routing, caching, streaming, compression, ...) | 12 |

**Default dispatch pattern:**
- Claude path: mega-parallel dispatch with N-1 background agents and 1 blocking agent to avoid idle sessions.
- Codex path: single-agent by default. Run dimensions sequentially in the main thread unless delegated sub-agents are available, policy-allowed, and explicitly requested by the user.
- Codex delegated fast-path: if delegated sub-agents are available, policy-allowed, and explicitly requested by the user, fan out independent exploration slices and keep the main thread on consolidation or setup work.

Round 4 starts after Rounds 1-3 complete because it depends on their findings. See `agent-prompts.md` for runtime-specific dispatch examples.

**Codebase Map (incremental mode):** If `artifacts/audit-memory/codebase-map.json` exists from a previous audit, Explorer agents receive per-file context: known hot-spots, previous findings, and historically-matched dimensions. This improves focus and reduces false positives. See `codebase-map.md`.

**Large Dimension Splitting:** Dimensions with >15 checks should be split into smaller slices:
- Each slice gets one technology/category from the dimension
- Example: Dim 2.10 (Data Store Safety, 40 checks) -> 6 slices
- If delegated sub-agents are available, policy-allowed, and explicitly requested by the user, run the slices in parallel
- Otherwise process the same slices sequentially in the main thread

### Consolidation

Produce a single prioritized report (`report-templates.md`): P0 (critical correctness/data, fix this week), P1 (stability, next week), P2 (quality, this month). Group P0+P1 into fix phases with no file overlap.

### Verification (2nd-Eye Check)

Before fixing, verify the top findings are real:

1. Scale verification to finding count:
   - <= 8 P0+P1 findings -> 1 agent handles all
   - 9-20 findings -> 2 agents
   - 20+ findings -> 3 agents
2. Suggested split for 2 agents:
   - Agent 1: Dims 1.x + 2.x
   - Agent 2: Dims 3.x + 4.x + 5.x + 6.x
3. Each verifier reads the actual code and labels each finding:
   - `CONFIRMED`
   - `FALSE POSITIVE`
   - `NEEDS CONTEXT`
4. Only `CONFIRMED` findings proceed to Fix Phases.
5. Remove false positives from the roadmap immediately.

**Why:** Exploration uses grep and broad scans - fast but imprecise. Verification reads code - slower but higher signal.

### Fix Phases (A, B, C, D)

Each phase follows `gate-pattern.md`:

```text
Agents (parallel, disjoint scope) -> Integrate -> Tests -> Native Deep Review -> Cleanup -> Next Phase
```

Fix phases with zero file overlap can run in parallel. See `reference.md` for dependency rules and overlap strategies.

### Version Bump

After all phases pass gates: full test suite -> final deep review -> version bump -> push.

## Quick Reference

| Phase | Units | Duration |
|-------|--------|----------|
| Rounds 1-3, 5-7 | 4-5 each | ~30min-1h each |
| Round 4 (Architecture) | 3 | ~30min |
| Consolidation | 1 | ~15min |
| Fix Phases A-D | 1-4 each | ~1-2h each |

**Total:** ~20-30 execution units, ~6-8 hours, 75 dimensions, 3+ deep reviews, 3+ cleanup passes

## Presets

- `--preset quick`: Round 1 + Round 4 only. ~2 hours.
- `--preset full`: All 75 dimensions, all 7 rounds. ~6-8 hours.
- `--preset platform`: Round 5 only. ~30 min, cross-platform + WSL2 + Python gotchas.
- `--preset security-deep`: Round 6 only. ~1-2 hours, comprehensive security audit with tool integration.
- `--preset token`: Round 7 only. ~30 min, LLM API cost optimization.

## Common Mistakes

1. Fixing during exploration - rounds are read-only.
2. Mixing Claude and Codex command sets in one audit.
3. File overlap in parallel agents - check ownership first.
4. Skipping the native deep-review gate.
5. Skipping the cleanup pass after review fixes.
6. Treating all findings equally - P0 before P1 before P2.

## Supporting Files

| File | Purpose |
|------|---------|
| `runtime-routing.md` | Detect host and map Claude vs Codex workflows |
| `exploration-dimensions.md` | Index of all 75 dimensions |
| `dimensions/round1-*.md` .. `round7-*.md` | Per-round dimensions with search commands |
| `token-optimization-guide.md` | Token budget calculator + provider-native routing guidance |
| `gate-pattern.md` | Gate sequence: integrate -> test -> review -> cleanup |
| `report-templates.md` | Templates for exploration, consolidation, reviews |
| `progress-template.md` | Live progress dashboard |
| `agent-prompts.md` | Runtime-aware prompts for all agent types |
| `auto-detect.md` | Skip-logic for irrelevant dimensions |
| `audit-memory.md` | Persistent learning system |
| `codebase-map.md` | Per-file dimension memory for incremental scanning |
| `reference.md` | Parallelization strategies, benchmarks, dependency graphs |
| `ollama-integration.md` | Optional Ollama usage for low-risk summaries only |

## Related Skills

- `systematic-debugging` - Single bug root-cause investigation
- `dispatching-parallel-agents` - Core parallel execution pattern
- `requesting-code-review` - Native deep-review pattern
- `simplify` - Cleanup after changes
- `verification-before-completion` - Test-before-claim pattern

## Real-World Impact

Large Python codebase (120K LOC): 14 exploration agents, 87 bugs + 5 cascading chains + 8 design flaws found, 22 CRITICAL. 12 fix agents across 4 phases, 3 deep reviews caught 5 additional issues. All 119+ tests green. ~8 hours total.
