# audit-and-fix

A comprehensive, self-improving, runtime-aware codebase audit skill for Claude Code, Claude in VS Code, Codex, and Codex in VS Code.

**75 dimensions** across **7 rounds** - from NaN propagation to OWASP security, from WSL2 clock drift to ML and automation feedback loops.

## Features

- **Runtime-Aware Orchestration:** Detects Claude vs Codex and stays on the native toolchain for that host
- **Capability-Aware Execution:** Defaults to single-agent in Codex and uses delegation only when it is available, policy-allowed, and explicitly requested by the user
- **7 Exploration Rounds:** Code-Level, System-Level, Domain-Specific (ML/Stateful Systems), Architecture, Platform, Security, Token Efficiency
- **75 Dimensions** with concrete grep/find search commands
- **Parallel Fix Phases** with a native deep review and cleanup pass after each phase
- **Self-Improving:** Learns from each audit via persistent memory (JSON in Git)
- **8 Presets:** quick, full, security, security-deep, ml, perf, platform, token
- **Cross-Machine:** Audit memory syncs via Git across Mac/Windows/Linux
- **Provider-Native Routing:** Claude path uses Claude-native review models; Codex path stays OpenAI/Codex-only
- **5 Parallelization Strategies:** Cut audit time from ~6-8h to ~3h
- **Token-Efficient by Default:** Filtered codebase-map injection, adaptive cleanup dispatch, sub-agent templates for large dimensions, verification category split

## Installation

### Installer scripts

```bash
# Mac/Linux
bash scripts/install_skill.sh auto

# Windows PowerShell
powershell -File scripts\install_skill.ps1 -Target auto
```

`auto` installs to both supported hosts:
- `~/.claude/skills/audit-and-fix/`
- `${CODEX_HOME:-~/.codex}/skills/audit-and-fix/`

Use `claude`, `codex`, or `both` if you want a narrower target.

### Manual install: Claude Code / Claude in VS Code

```bash
mkdir -p ~/.claude/skills/
cp -r audit-and-fix ~/.claude/skills/
```

### Manual install: Codex / Codex in VS Code

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills/"
cp -r audit-and-fix "${CODEX_HOME:-$HOME/.codex}/skills/"
```

Codex/OpenAI metadata lives in `agents/openai.yaml`.

## Quick Start

### Claude path

```text
/audit-and-fix --preset quick
```

### Codex path

```text
Use $audit-and-fix to run the quick preset on this repository.
```

Quick preset runs Round 1 (Code) + Round 4 (Architecture) - about 2 hours, 14 dimensions.

**Invocation note:** In Codex, use `$audit-and-fix`. `/audit-and-fix` is a Claude-style slash invocation and is not registered as a native Codex slash command by this skill format.

## Runtime Routing

Before dispatching work, detect the host and current capabilities:

- **Claude host:** use `Agent(...)`, `run_in_background`, Claude-native review flow, and `/simplify` if available
- **Codex host:** use OpenAI/Codex models only, default to single-agent execution, and use `spawn_agent`/`wait_agent` only when delegated execution is available, policy-allowed, and explicitly requested by the user

Do not mix the command sets. Full mapping lives in `runtime-routing.md`.

## Rounds & Dimensions

| Round | Dimensions | Focus |
|-------|-----------|-------|
| 1 Code-Level | 1.1-1.8 | Dict-Mutation, Memory Leaks, Thread-Safety, NaN, Error Swallowing, Resource Leaks, Mutable Defaults, Serialization |
| 2 System-Level | 2.1-2.12 | Data Integrity, Security, Stale State, Import Graph, String Literals, Duplicates, Logging, Test Gaps, Test Quality, Data Store Safety, Python Security Patterns, Test Smell Deep Scan |
| 3 Domain-Specific | 3.1-3.9 | Look-Ahead Bias, Training-Serving Skew, Drift Detection, Cost Model, Feedback Loops, Pipeline Breaks, Model Rollback, Hardcoded Assumptions, Business Logic Invariants |
| 4 Architecture | 4.1-4.9 | Cascading Chains, Design Flaws, Wrong Approaches, Complexity, Dependency Graph, API Contracts, OOP Design & Code Smells, Cross-Cutting Concerns, Defensive Patterns |
| 5 Platform | 5.1-5.12 | CRLF, Path Handling, Encoding, Sync Artifacts, WSL2 (4 dims), Datetime/TZ, Signals, Closures, Identity |
| 6 Security | 6.1-6.13 | Auth, Secrets, Network, Injection, Supply Chain, Infra Hardening, Rate Limiting, ML Security, Audit Logging, Data Protection, Client-Side & Web Security, Cryptographic Correctness, Web Hardening & HTTP Security |
| 7 Token Efficiency | 7.1-7.12 | Prompt Size, Model Routing, Caching, Context Waste, System Prompts, Output Control, Batch API, Embeddings, Retries, Cost Tracking, Prompt Compression, Streaming |

## Presets

| Preset | Rounds | Time | Use Case |
|--------|--------|------|----------|
| `quick` | 1 + 4 | ~2h | Fast scan after feature branch |
| `full` | 1-7 | ~6-8h | Quarterly health check |
| `security` | Selected from 1+2 | ~1h | Quick security scan |
| `security-deep` | 6 | ~1-2h | Full OWASP-style audit |
| `ml` | 3 | ~1h | ML / inference pipeline audit |
| `perf` | Selected | ~1h | Performance hotspots |
| `platform` | 5 | ~30min | Cross-platform + WSL2 |
| `token` | 7 | ~30min | LLM API cost audit |

## Self-Improving Audit Memory

The skill learns from each audit:
- `artifacts/audit-memory/history.json` - Append-only audit history
- `artifacts/audit-memory/tuning.json` - Auto-skip recommendations for zero-finding dimensions
- `artifacts/audit-memory/regression-watch.json` - Watch for re-introduced bugs
- `artifacts/audit-memory/false-positives.json` - Do not re-report confirmed non-bugs

All Git-tracked - syncs across machines automatically.

## File Structure

```text
audit-and-fix/
├── SKILL.md
├── README.md
├── runtime-routing.md
├── exploration-dimensions.md
├── dimensions/
│   ├── round1-code-level.md
│   ├── round2-system-level.md
│   ├── round3-domain-specific.md
│   ├── round4-architecture.md
│   ├── round5-platform.md
│   ├── round6-security.md
│   └── round7-token-efficiency.md
├── gate-pattern.md
├── report-templates.md
├── progress-template.md
├── agent-prompts.md
├── auto-detect.md
├── audit-memory.md
├── learning-agents.md
├── skill-improvement.md
├── reference.md
├── token-optimization-guide.md
├── agents/
│   └── openai.yaml
└── scripts/
    ├── install_skill.ps1
    └── install_skill.sh
```

## What's New

**v4.4** - Runtime-Aware Claude/Codex Support
- Added `runtime-routing.md` to separate Claude-native and Codex/OpenAI-native execution paths
- Added `agents/openai.yaml` so Codex/OpenAI surfaces the skill cleanly
- Added cross-host install scripts for Claude and Codex skill directories
- Reworked prompts, gate pattern, and token guidance to stay provider-native instead of hard-coding Claude-only assumptions

## Requirements

- **Claude Code / Claude in VS Code** or **Codex / Codex in VS Code**
- Python codebase (dimensions are Python-focused, but architecture/security rounds are language-agnostic)
- Git (for audit memory persistence)

## License

MIT
