# Token Optimization Guide

How the audit-and-fix skill minimizes token consumption without hard-coding itself to one provider.

## For Orchestrators: Reducing Audit Token Cost

### 1. Provider-Native Model Selection

| Agent Role | Claude Path | Codex Path | Why |
|-----------|-------------|------------|-----|
| Explorer | Sonnet | inherited Codex model or another available fast code-capable model | Fast, strong code understanding |
| Fix Agent | Sonnet | inherited Codex model by default; optional code-specialized worker model if the host exposes model selection | Editing quality matters |
| Deep Review | Opus | strongest available OpenAI/Codex reviewer model, or the inherited model if overrides are unavailable | Deep cross-file reasoning |
| Cleanup Agent | Sonnet | inherited Codex model or another available fast code-capable model | Focused review, bounded output |
| Learning Agent | Sonnet | inherited Codex model or another available fast code-capable model | Structured analysis |

**Rule:** In Codex, stay OpenAI/Codex-only. If explicit model overrides are unavailable, keep the inherited model and route by task type instead. Default to single-agent execution; use delegated workers only when they are available, policy-allowed, and explicitly requested by the user.

### 2. One Dimension Per Agent

Wrong: give an agent the full exploration index.

Right: give the agent only:
- its round file section
- its search commands
- its classification criteria

This keeps prompts short and reduces false positives.

### 3. Structured Output

Add this to Explorer and Verification prompts:

```json
{
  "dimension": "1.3",
  "findings": [
    {"severity": "CRITICAL", "file": "...", "line": 1, "issue": "...", "fix": "..."}
  ],
  "total": {"critical": 0, "high": 0, "medium": 0, "low": 0}
}
```

Structured output cuts narration and makes consolidation cheaper.

### 4. Per-Agent Token Budgets

| Agent Role | max_tokens |
|-----------|------------|
| Explorer | 1000 |
| Verification | 1200 |
| Fix Agent | 2000 |
| Deep Review | 3000-5000 |
| Cleanup Agent | 1000 |

### 5. Stable Prefixes and Reusable Context

Put stable content first, variable content last:

```text
[stable: project context + audit instructions]
[variable: dimension checks + files + diff]
```

This makes reuse, caching, and prompt compression easier regardless of provider.

### 6. Diff-Based Scope for Re-Audits

After the first full audit, use changed-file scope when appropriate:

```bash
git diff --name-only main..HEAD
```

Feed changed files to the relevant dimensions first. This usually cuts the number of Explorer agents dramatically.

### 7. Skip Tuning from Audit Memory

After several audits, `tuning.json` should recommend:
- zero-finding dimensions to de-prioritize
- high-yield dimensions to boost

This keeps future runs shorter without losing the important checks.

### 8. Codebase Map Token Savings

The codebase map delivers the biggest savings on repeat audits:

| Audit Type | Without Map | With Map | Savings |
|-----------|-------------|----------|---------|
| First full audit | All dims x all files | Same | 0% |
| Incremental audit | All dims x all files | Changed files x all dims; hot-spots x matched dims; clean files mostly skipped | 60-80% |
| Targeted audit | Selected files x broad dims | Selected files x map-recommended dims first | 30-50% |

**Why it works:**
- Explorer agents get a focused file list
- Verification agents get historical context
- Clean files are skipped except for a periodic sample

### 9. Batch or Deferred APIs for Non-Interactive Audits

For scheduled audits where results do not need to be immediate:
- Prefer your provider's batch/offline API if available
- Otherwise queue background audits and consolidate later

This is lower priority than routing and scope reduction, but still useful on large codebases.

## Token Budget Calculator

Estimate before running:

```text
Full audit:    75 dimensions x ~5K tokens/agent = ~375K tokens
Quick audit:   14 dimensions x ~5K tokens/agent = ~70K tokens
Changed-only:  ~5 dimensions x ~5K tokens/agent = ~25K tokens

Fix phases:    4 phases x 4 agents x ~8K tokens/agent = ~128K tokens
Reviews:       4 x ~15K tokens/review = ~60K tokens
Cleanup:       4 x 3 agents x ~5K tokens/agent = ~60K tokens

TOTAL FULL:    ~623K tokens
TOTAL OPTIMIZED: often ~200K-250K tokens
```

Provider pricing changes over time, so keep the calculator in tokens and apply current pricing separately when needed.
