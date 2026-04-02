# Agent Prompt Templates

Copy-paste these templates when dispatching agents during an audit-and-fix session.

## Dispatch Pattern: Avoid Idle Sessions

**CRITICAL:** Never dispatch ALL agents with `run_in_background: true`. This makes the session idle — you'll have to type "update" to check progress.

**Correct pattern:** N-1 agents in background, 1 agent blocking (foreground):
```
# 4 background + 1 foreground = session stays active
Agent(prompt="...", run_in_background=True)   # background
Agent(prompt="...", run_in_background=True)   # background
Agent(prompt="...", run_in_background=True)   # background
Agent(prompt="...", run_in_background=True)   # background
Agent(prompt="...")                           # BLOCKING — keeps session alive
```

The blocking agent should be the one you need results from FIRST (usually the fastest or most critical).
After it completes, immediately check background agents via TaskOutput or wait for notifications.

---

## Model Selection

See `token-optimization-guide.md` Section 1 for the full model-per-role table and rationale.
**TL;DR:** Sonnet for 80% of agents (Explorer, Fix, /simplify, Learning). Opus only for Reviews.

---

## Explorer Agent (model: "sonnet")

```
You are exploring the codebase at [PATH] for [DIMENSION_NAME].

Search commands:
[PASTE COMMANDS FROM DIMENSION]

For EACH check, report a clear verdict:

PASS: [file:line] — [what was checked] — no issue found
FAIL: [file:line] — [what's wrong] — [suggested fix]
WARN: [file:line] — [ambiguous finding] — [needs human review]

Classification:
[PASTE CLASSIFY CRITERIA FROM DIMENSION]

Return structured results. Every finding must be PASS, FAIL, or WARN — no prose descriptions without a verdict.
At the end: summary count of PASS/FAIL/WARN.
```

## Explorer Agent WITH Codebase Map (model: "sonnet")

Use this template when `codebase-map.json` exists from a previous audit:

```
You are exploring the codebase at [PATH] for [DIMENSION_NAME].

CODEBASE MAP CONTEXT:
[PASTE relevant entries from codebase-map.json for this dimension]

Hot-spot files for this dimension:
[LIST files with risk_score >= 10 that match this dimension]

Changed files since last scan:
[LIST from git diff --name-only <last_commit>..HEAD]

Instructions:
1. CHANGED FILES: Full scan with all search commands
2. HOT-SPOT FILES: Quick re-check — verify previous findings are still fixed, look for new issues
3. CLEAN FILES: Skip unless they appear in git diff
4. NEW FILES (not in map): Full scan

Report findings as PASS/FAIL/WARN with file:line.
Mark regressions (previously fixed, now broken again) as REGRESSION.
```

## Verification Agent WITH Codebase Map (model: "sonnet")

```
You are verifying findings before they go to fix phase.

MAP CONTEXT FOR THIS FILE:
[PASTE file entry from codebase-map.json]

Historical findings in this file:
- [LIST previous findings with dim, line, status]

Your tasks:
1. CONFIRM each new finding is real (not false positive)
2. CHECK if any previously-fixed findings have regressed
3. If the file is marked "clean" but you found something → flag as CLEAN SURPRISE
4. Rate confidence: HIGH (definitely a bug), MEDIUM (likely but needs context), LOW (might be false positive)
```

---

## Fix Agent (model: "sonnet")

```
You are fixing [N] findings in [FILES].

Findings to fix:
[PASTE FINDINGS LIST]

Rules:
- Read each file BEFORE editing
- Apply minimal, targeted fixes (no refactoring)
- Run tests after all fixes: [TEST_COMMAND]
- Commit: "[COMMIT_MESSAGE]"
- Add "Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

Use isolation: worktree. Do NOT touch files outside your scope: [OTHER_AGENTS_FILES].
```

## Opus Review Agent (model: opus — default, do NOT override)

```
Review all Phase [X] changes. Diff range: [COMMIT_A..COMMIT_B]

Focus areas for this phase:
[PHASE_SPECIFIC_FOCUS]

Rate each finding: CRITICAL (must fix now) / WARNING (should fix) / INFO (nice to have).
Max 15 findings. Be concise.
```

## /simplify Agents (launch 3 in parallel, model: "sonnet")

Agent 1 — Reuse:
```
Review [FILES] for duplicated utilities, existing helpers not used. Max 5 findings.
```

Agent 2 — Quality:
```
Review [FILES] for redundant state, copy-paste, unnecessary comments, stringly-typed code. Max 5 findings.
```

Agent 3 — Efficiency:
```
Review [FILES] for hot-path bloat, unnecessary work, lock contention, unbounded structures. Max 5 findings.
```
