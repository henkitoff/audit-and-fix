# Changelog

## [4.4] - 2026

### Added
- Runtime-aware host routing for Claude Code, Claude in VS Code, Codex, and Codex in VS Code
- `runtime-routing.md` with native tool/model mapping for Claude vs Codex
- `agents/openai.yaml` for Codex/OpenAI skill discovery
- `scripts/install_skill.sh` and `scripts/install_skill.ps1` for cross-host installation

### Changed
- `SKILL.md`, `README.md`, `agent-prompts.md`, and `gate-pattern.md` now route to the host-native path instead of assuming Claude-only commands
- Deep-review language is provider-neutral; Claude keeps Opus, Codex stays OpenAI/Codex-only
- Round 7 token-efficiency guidance now audits Claude and OpenAI/Codex model routing patterns
- Cleanup flow is described as a host-native pass instead of a Claude-only `/simplify` requirement

## [4.0] - 2025

### Added
- Codebase Map: per-file dimension memory with risk scores and hot-spots
- Anti-Blindness safeguards: changed files get ALL dims, periodic full rescan, 10% random sampling
- Map-aware consolidation (NEW/REGRESSION/RESOLVED/PERSISTENT/CLEAN SURPRISE)
- Verification phase (2nd-eye check before fixes)
- PASS/FAIL/WARN output format for Explorer agents
- Dim 2.9: Test Quality (6 test smell checks)
- Dim 2.10: Data Store Safety (40 DB-specific checks across SQLite/PostgreSQL/DuckDB/Redis/Parquet/MinIO)
- Dim 2.11: Python Security Patterns (14 Bandit-style checks)
- Dim 2.12: Test Smell Deep Scan (12 additional test quality checks)
- Dim 3.9: Business Logic Invariants
- Dim 4.7: OOP Design & Code Smells (13 checks)
- Dim 4.8-4.9: Performance Hotspots + Dependency Vulnerabilities
- Dim 6.12: Cryptographic Correctness (6 checks)
- Dim 6.13: Web Hardening & HTTP Security (15 checks)
- Enriched injection checks: YAML, torch.load, pandas.eval, tarfile, marshal
- Enriched secret scanning: trufflehog, gitleaks, detect-secrets recommendations
- Fix priority scoring formula (cascade, speed, test, isolation)
- Function-level parallelism (Strategy 6)
- Sub-dimension splitting for large dimensions
- Dispatch pattern: N-1 background + 1 blocking (prevents idle sessions)
- Ollama integration for post-audit summary
- Consistent dimension numbering (Round N = Dims N.x)
- Token savings: 79% reduction on incremental audits via codebase map

### Changed
- Dimensions renumbered: Round 5 (was 6.x/7.x/8.x -> 5.x), Round 6 (was 9.x -> 6.x), Round 7 (was 10.x -> 7.x)
- Gate order corrected: deep review MUST complete before cleanup (unless 0 CRITICAL)
- Tuning skip-candidates are user-confirmed recommendations (no auto-skip)
- Mega-parallel dispatch is DEFAULT exploration mode
- Model routing: fast models for exploration/fix, deeper review model for gates

## [3.1] - 2025

### Added
- Enriched security from 10 bug-bounty repos (350+ cases analyzed)
- Dim 6.11: Client-Side & Web Security (XSS, redirects, clickjacking, debug endpoints)
- IDOR, CSRF, JWT, SSRF, XXE, SSTI, Mass Assignment sub-checks in existing dims

## [3.0] - 2025

### Added
- Round 7: Token & API Cost Efficiency (10 dimensions)
- Round 6: Security Deep Dive (10 dimensions, OWASP-based)
- 3-layer learning system (audit memory, learning agents, self-improvement)
- 5 parallelization strategies
- Agent prompt templates, auto-detection, custom dimensions

## [2.0] - 2025

### Added
- Round 5: Environment & Platform (12 dimensions)
- 8 presets, adaptive depth, diff-based scope, incremental audit, health score

## [1.0] - 2025

### Added
- Initial release: 30 dimensions across 4 rounds
- Gate pattern, report templates, real-world validation
