# Agent Prompt Templates

Copy-paste these templates when dispatching agents during an audit-and-fix session.

## Runtime Rule

Before dispatching anything, detect the host and current capabilities via `runtime-routing.md`.

- **Claude host:** use Claude-native agent commands, model names, and `/simplify` if available.
- **Codex host:** use OpenAI/Codex models only, default to the main thread, and use `spawn_agent`/`wait_agent` only when delegated execution is available, policy-allowed, and explicitly requested by the user.
- **Never mix them.**

---

## Dispatch Pattern

### Claude dispatch pattern: avoid idle sessions

**CRITICAL:** Never dispatch all Claude agents with `run_in_background: true`. That leaves the session idle.

```python
Agent(prompt="...", run_in_background=True)
Agent(prompt="...", run_in_background=True)
Agent(prompt="...", run_in_background=True)
Agent(prompt="...")  # blocking
```

Keep one blocking agent - usually the fastest or most decision-critical one.

### Codex default pattern: single-agent first

For Codex, run the workflow in the main thread by default.

```text
1. Read the relevant dimension or phase instructions
2. Execute the scan, verification, fix, or cleanup in the main thread
3. Continue to the next independent slice sequentially
```

### Codex delegated fast-path: only when explicitly requested

If delegated execution is available, policy-allowed, and explicitly requested by the user, fan out independent work with explicit ownership and keep the main thread doing useful local work.

```text
spawn_agent(agent_type="explorer", message="...")
spawn_agent(agent_type="explorer", message="...")
spawn_agent(agent_type="explorer", message="...")

# Continue local consolidation, reads, or setup work.
# Call wait_agent only when the next step is blocked on those results.
```

For edit phases, prefer `worker` agents with disjoint file ownership only when delegation is in use because the user explicitly requested it. Otherwise keep the fixes in the main thread.

---

## Model Selection

Use provider-native model routing:

| Agent Role | Claude Path | Codex Path | Why |
|-----------|-------------|------------|-----|
| Explorer | Sonnet | inherited Codex model or another available fast code-capable model | Fast, strong code reading |
| Verification | Sonnet | inherited Codex model or another available fast code-capable model | Read-only confirmation |
| Fix Agent | Sonnet | inherited Codex model by default; optional code-specialized worker model if the host exposes model selection | Code edits |
| Deep Review | Opus | strongest available OpenAI/Codex reviewer model, or the inherited model if overrides are unavailable | Cross-file reasoning |
| Cleanup / Learning | Sonnet | inherited Codex model or another available fast code-capable model | Structured follow-up work |

**Codex rule:** If model overrides are unavailable or uncertain, omit the override and stay on the inherited host model. Do not reference Sonnet/Opus in the Codex path.

---

## Explorer Agent

Use this prompt body in either host:

```text
You are exploring the codebase at [PATH] for [DIMENSION_NAME].

Search commands:
[PASTE COMMANDS FROM DIMENSION]

For EACH check, report a clear verdict:

PASS: [file:line] - [what was checked] - no issue found
FAIL: [file:line] - [what's wrong] - [suggested fix]
WARN: [file:line] - [ambiguous finding] - [needs human review]

Classification:
[PASTE CLASSIFY CRITERIA FROM DIMENSION]

Return structured results. Every finding must be PASS, FAIL, or WARN.
At the end: summary count of PASS/FAIL/WARN.
```

### Explorer Agent with Codebase Map

Use when `codebase-map.json` exists from a previous audit.

```text
You are exploring the codebase at [PATH] for [DIMENSION_NAME].

CODEBASE MAP CONTEXT (filtered to this dimension only):
[PASTE ONLY ENTRIES WHERE ONE OF THESE IS TRUE]
- dimensions_matched contains this dimension ID
- file changed since the last scan
- risk_score >= 10

Hot-spot files:
[LIST file paths only]

Changed files since last scan:
[LIST changed files]

Instructions:
1. CHANGED FILES: full scan with all search commands
2. HOT-SPOT FILES: quick re-check plus new-issue scan
3. CLEAN FILES: skip unless a search command hits
4. NEW FILES: full scan

Report findings as PASS/FAIL/WARN with file:line.
Mark regressions as REGRESSION.
```

### Slice Large Dimensions

Use when a dimension has >15 checks. Split by technology/category and process one slice at a time. If delegated execution is available, policy-allowed, and explicitly requested by the user, each slice can become its own sub-agent.

```text
You are exploring the codebase at [PATH] for [DIMENSION_NAME] - [TECHNOLOGY] only.

Checks for this technology:
[PASTE ONLY THIS TECHNOLOGY'S CHECKS]

Search commands:
[PASTE ONLY THIS TECHNOLOGY'S GREP COMMANDS]

Report findings as PASS/FAIL/WARN with file:line. Include a summary count.
```

---

## Verification Agent

```text
You are verifying findings before they go to fix phase.

MAP CONTEXT FOR THIS FILE:
[PASTE file entry from codebase-map.json]

Historical findings in this file:
- [LIST previous findings with dim, line, status]

Your tasks:
1. CONFIRM each new finding is real
2. CHECK whether previously fixed findings have regressed
3. If the file was marked clean but you found something, flag CLEAN SURPRISE
4. Rate confidence: HIGH / MEDIUM / LOW
```

---

## Fix Agent

Use this prompt body in either host. Adapt the execution notes to the current runtime.

```text
You are fixing [N] findings in [FILES].

Findings to fix:
[PASTE FINDINGS LIST]

Rules:
- Read each file before editing
- Apply minimal, targeted fixes
- Do not refactor outside the stated findings
- Run tests after all fixes: [TEST_COMMAND]
- Do not touch files outside your scope: [OTHER_AGENTS_FILES]
- Report exactly which files changed and which tests ran

Claude path execution:
- Commit inside the worktree with: [COMMIT_MESSAGE]

Codex single-agent execution:
- Apply the changes directly in the main thread and report changed files plus tests run

Codex delegated execution:
- Keep changes inside your owned files and return a concise changed-files summary for integration
```

---

## Native Deep Review Agent

Use the current host's strongest reviewer path:
- Claude: Opus / native code-reviewer
- Codex: top-tier OpenAI/Codex review agent or the main thread if no reviewer agent is available

```text
Review all Phase [X] changes. Diff range: [COMMIT_A..COMMIT_B]

Focus areas for this phase:
[PHASE_SPECIFIC_FOCUS]

Rate each finding:
- CRITICAL: must fix now
- WARNING: should fix
- INFO: nice to have

Max 15 findings. Be concise.
```

---

## Cleanup Agents (/simplify Equivalent)

Run cleanup in the main thread by default. If delegated execution is available, policy-allowed, and explicitly requested by the user, launch 1-3 cleanup agents depending on phase size.

Agent 1 - Reuse:
```text
Review [FILES] for duplicated utilities and existing helpers not used. Max 5 findings.
```

Agent 2 - Quality:
```text
Review [FILES] for redundant state, copy-paste, unnecessary comments, and stringly-typed code. Max 5 findings.
```

Agent 3 - Efficiency:
```text
Review [FILES] for hot-path bloat, unnecessary work, lock contention, and unbounded structures. Max 5 findings.
```

In Claude, these can map to `/simplify` or equivalent cleanup prompts.
In Codex, these remain ordinary review agents using OpenAI/Codex models only.
