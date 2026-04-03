# Runtime Routing

Detect the host and available capabilities before doing anything else. This skill supports:
- Claude Code
- Claude in VS Code
- Codex
- Codex in VS Code

## Non-Negotiable Rule

Stay native to the current host. Never mix Claude-only commands with Codex-only tools in the same audit.

Prefer capability-based routing over product-based assumptions:
- Detect the host to choose the command family.
- Detect available capabilities to choose between single-agent and delegated execution.
- In Codex, treat delegated execution as opt-in, not as a silent default.

## Detection Signals

| Signal | Host | Use |
|--------|------|-----|
| `Agent(...)`, `run_in_background`, `TaskOutput`, `/simplify`, `superpowers:code-reviewer` | Claude | Claude-native path |
| `spawn_agent`, `wait_agent`, `send_input`, `worker`, `explorer`, `apply_patch`, `$skill-name` invocation | Codex | Codex/OpenAI-native path |

If the host is ambiguous:
1. Prefer the tool names that are actually available in the current session.
2. Prefer the session's default model family over explicit cross-provider model names.
3. Do not mention Sonnet/Opus in Codex.
4. Do not mention GPT/Codex model names in Claude unless the audited repo itself contains them.

## Capability Signals

| Capability | Meaning | Default |
|------------|---------|---------|
| Delegated sub-agent tools are available | Parallel or split execution is possible | Optional fast-path only when the user explicitly requests delegation |
| Delegated sub-agent tools are unavailable | Stay in the main thread | Default Codex fallback |
| Native reviewer exists | Use it for deep review | Preferred |
| No native reviewer exists | Run deep review in the main thread | Fallback |

## Installation Paths

| Host | Skill path | Typical invocation |
|------|------------|--------------------|
| Claude | `~/.claude/skills/audit-and-fix/` | `/audit-and-fix --preset quick` |
| Codex | `${CODEX_HOME:-~/.codex}/skills/audit-and-fix/` | `Use $audit-and-fix to run the quick preset on this repo.` |

## Invocation Note

- Claude may expose the skill through `/audit-and-fix`.
- Codex uses `$audit-and-fix` or implicit skill invocation in a normal prompt.
- This skill format does not define a Codex slash-command alias for `/audit-and-fix`.

## Tool Mapping

| Task | Claude Path | Codex Path |
|------|-------------|------------|
| Exploration | `Agent(..., run_in_background=True)` with one blocking agent | Main-thread sequential scan by default; optional delegated `explorer` fan-out only if tools are available, policy allows it, and the user explicitly requests delegation |
| Fix execution | Parallel worktrees with disjoint file lists | Main-thread fixes by default; optional delegated `worker` execution only if tools are available, policy allows it, and the user explicitly requests delegation |
| Integration | Merge worktree branches | No integration step in single-agent mode; integrate delegated results only when delegation was used |
| Gate review | Opus / native reviewer | Native OpenAI/Codex review agent or main-thread review |
| Cleanup pass | `/simplify` or equivalent cleanup prompts | Main-thread cleanup by default; optional 1-3 delegated cleanup/review agents only if tools are available, policy allows it, and the user explicitly requests delegation |
| Waiting | Task output / notifications | `wait_agent` only when delegated agents were actually launched |

## Model Routing

| Role | Claude Path | Codex Path |
|------|-------------|------------|
| Explorer | Sonnet | inherited Codex model or another available fast code-capable model |
| Verification | Sonnet | inherited Codex model or another available fast code-capable model |
| Fix | Sonnet | inherited Codex model; optionally a code-specialized worker model if the host exposes model selection |
| Deep review | Opus | strongest available OpenAI/Codex reviewer model, or the inherited model if overrides are unavailable |
| Cleanup / learning | Sonnet | inherited Codex model or another available fast code-capable model |

In Codex:
- Use OpenAI/Codex models only.
- If model overrides are unavailable, stay on the inherited model.
- Prefer single-agent execution by default.
- Use `explorer` agents for read-only scans and `worker` agents for edits only when delegated execution is available, policy-allowed, and explicitly requested by the user.

## Review and Cleanup Mapping

| Concept | Claude Meaning | Codex Meaning |
|---------|----------------|---------------|
| Deep review | Opus/native reviewer | Best available OpenAI/Codex reviewer |
| Cleanup pass | `/simplify` or equivalent prompts | Reuse/quality/efficiency cleanup prompts |
| Parallel fix agents | Worktrees | Optional worker agents with disjoint ownership |

## Execution Rule

1. Detect the current host.
2. Choose the matching host command family.
3. Detect whether delegated sub-agent execution is available and policy-allowed.
4. In Codex, stay single-agent unless step 3 is true, the user explicitly requests delegation or parallel agent work, and parallelization materially helps.
5. Treat deep review and cleanup as abstract phases and map them to the strongest native implementation available.

## Safe Defaults

If you are still unsure which path applies:
1. Use the current host's native tools only.
2. Avoid cross-provider model names.
3. Keep prompts provider-neutral.
4. In Codex, prefer the single-agent path.
5. Treat "deep review" and "cleanup" as abstract steps and map them to the host-native implementation.
