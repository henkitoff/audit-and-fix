# audit-and-fix

A comprehensive, self-improving codebase audit skill for Claude Code (Superpowers).

**75 dimensions** across **7 rounds** -- from NaN propagation to OWASP security, from WSL2 clock drift to ML feedback loops.

## Features

- **7 Exploration Rounds:** Code-Level, System-Level, Domain-Specific (ML/Trading), Architecture, Platform, Security, Token Efficiency
- **75 Dimensions** with concrete grep/find search commands
- **Parallel Fix Phases** with Opus reviews and adaptive /simplify after each phase
- **Self-Improving:** Learns from each audit via persistent memory (JSON in Git)
- **8 Presets:** quick, full, security, security-deep, ml, perf, platform, token
- **Cross-Machine:** Audit memory syncs via Git across Mac/Windows/Linux
- **Model Routing:** Sonnet for 80% of agents (speed), Opus only for reviews (quality)
- **5 Parallelization Strategies:** Cut audit time from ~6-8h to ~3h
- **Token-Efficient by Default:** Filtered codebase-map injection (saves ~10-16K tokens/run), adaptive /simplify dispatch, sub-agent templates for large dimensions, verification category split

## Installation

### Claude Code (Superpowers)
```bash
# Clone this repo (or copy the skill directory)
mkdir -p ~/.claude/skills/
cp -r audit-and-fix ~/.claude/skills/

# Or use the install script from a project that includes this skill:
bash scripts/install_skill.sh
```

### Quick Start
```
/audit-and-fix --preset quick
```
Runs Round 1 (Code) + Round 4 (Architecture) -- ~2 hours, 14 dimensions.

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
| `ml` | 3 | ~1h | ML/trading model audit |
| `perf` | Selected | ~1h | Performance hotspots |
| `platform` | 5 | ~30min | Cross-platform + WSL2 |
| `token` | 7 | ~30min | LLM API cost audit |

## Self-Improving Audit Memory

The skill learns from each audit:
- `artifacts/audit-memory/history.json` -- Append-only audit history
- `artifacts/audit-memory/tuning.json` -- Auto-skip zero-finding dimensions
- `artifacts/audit-memory/regression-watch.json` -- Watch for re-introduced bugs
- `artifacts/audit-memory/false-positives.json` -- Don't re-report confirmed non-bugs

All Git-tracked -- syncs across machines automatically.

## File Structure

```
audit-and-fix/
├── SKILL.md                    Main orchestration
├── README.md                   This file
├── exploration-dimensions.md   Index -> 7 round files
├── dimensions/
│   ├── round1-code-level.md
│   ├── round2-system-level.md
│   ├── round3-domain-specific.md
│   ├── round4-architecture.md
│   ├── round5-platform.md
│   ├── round6-security.md
│   └── round7-token-efficiency.md
├── gate-pattern.md             7-step fix phase gate
├── report-templates.md         3 report templates
├── progress-template.md        Live dashboard
├── agent-prompts.md            Copy-paste agent prompts + model routing
├── auto-detect.md              Skip irrelevant dimensions
├── custom-dimensions-template.md  Add project-specific dimensions
├── audit-memory.md             Persistent learning system
├── learning-agents.md          Post-audit analysis agents
├── skill-improvement.md        Self-improvement proposals
├── reference.md                Parallelization, benchmarks, tuning
└── token-optimization-guide.md Token cost reduction strategies
```

## Real-World Results

Tested on a production Python system (120K LOC):
- 14 exploration agents found **87 bugs + 5 cascading chains + 8 design flaws**
- 22 CRITICAL findings (NaN in financial calculations, stale model cache, no circuit-breaker)
- 12 fix agents across 4 phases, 3 Opus reviews
- All fixes merged, 119+ tests green
- **Health Score: 47/100 -> 91/100 in ~8 hours**

## What's New

**v4.3** — Token Waste Fixes
- `agent-prompts.md`: Codebase-map injection now filtered per agent (dimension match / git diff / risk score) — saves ~10-16K tokens per mega-parallel run
- `agent-prompts.md`: Sub-agent dispatch template for large dimensions (>15 checks) — split by technology, each agent gets ONE slice
- `gate-pattern.md`: Adaptive /simplify — 1 agent for small phases (≤2 files), 2 for medium, 3 for large; each agent gets a different file slice
- `SKILL.md`: Verification agents split by dimension category (Code+System vs Domain+Arch+Platform+Security)

**v4.2** — Token Efficiency Round expanded to 12 dimensions
- New: Dim 7.11 (Prompt Compression & Tokenization), Dim 7.12 (Streaming vs. Blocking)
- Improved: Dims 7.2, 7.3, 7.6, 7.7, 7.10 with concrete budgets and Batch API guidance

**v4.1** — Initial public release (74 dimensions)

## Requirements

- **Claude Code** with Superpowers plugin
- Python codebase (dimensions are Python-focused, but architecture/security rounds are language-agnostic)
- Git (for audit memory persistence)

## License

MIT
