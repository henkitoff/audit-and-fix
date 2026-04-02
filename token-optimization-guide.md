# Token Optimization Guide

How the audit-and-fix skill itself minimizes token consumption.

## For Orchestrators: Reducing Audit Token Cost

### 1. Model Selection per Agent Role
| Agent Role | Recommended Model | Why |
|-----------|-------------------|-----|
| Explorer (grep + classify) | **Sonnet** | Good code understanding, fast, loose rate limits |
| Fix Agent (read + edit + test) | **Sonnet** | Code edits, no architecture judgment needed |
| Opus Review | **Opus** | Deep architectural reasoning required |
| /simplify Agents | **Sonnet** | Pattern matching with code context |
| Learning Agents | **Sonnet** | Data comparison, structured output |

**Speed impact:** Sonnet has ~3x looser rate limits than Opus. With 20+ parallel agents, Opus throttles — Sonnet doesn't. Result: ~2x faster audit.

**Why Sonnet over Haiku?** Haiku misses subtle code bugs (NaN propagation, thread races). Sonnet catches them reliably. The quality difference matters more than the speed difference for code auditing.

**How to set:** Use the `model` parameter when dispatching Agent tool:
```
Agent(description="...", prompt="...", subagent_type="Explore", model="sonnet")
```

### 2. One Dimension Per Agent (Never Load All)
WRONG: Give agent the full exploration-dimensions.md (10K tokens)
RIGHT: Give agent only its specific round file + dimension section (~200 tokens)

**How:** Extract the specific dimension section and paste it into the agent prompt. Don't reference the file — embed the content directly.

### 3. Structured Output (JSON, Not Prose)
Add to every Explorer agent prompt:
```
Output ONLY this JSON format, no explanation:
{
  "dimension": "1.3",
  "findings": [
    {"severity": "CRITICAL", "file": "...", "line": N, "issue": "...", "fix": "..."},
    ...
  ],
  "total": {"critical": N, "high": N, "medium": N, "low": N}
}
```

**Savings:** 40-70% output tokens (no prose, no headers, no explanations).

### 4. Per-Agent Token Budgets
| Agent Role | max_tokens |
|-----------|------------|
| Explorer | 1000 |
| Fix Agent | 2000 |
| Review Agent | 3000 |
| /simplify Agent | 1000 |

### 5. Prompt Caching (Anthropic)
Structure every prompt with STABLE content first, VARIABLE content last:
```
[STABLE: System prompt + project context + audit instructions]  <- cached after 1st call
[VARIABLE: Specific dimension + specific files to scan]          <- unique per agent
```

Anthropic caches the stable prefix — subsequent agents pay 90% less for it.

### 6. Diff-Based Scope for Re-Audits
After the first full audit, subsequent runs should use `--scope changed`:
```
/audit-and-fix --scope changed
```
This only scans files from `git diff main..HEAD`, reducing agents from 20+ to 3-5.

### 7. Skip Tuning (from Audit Memory)
After 3+ audits, `tuning.json` recommends skipping zero-finding dimensions.
A full audit that started with 52 dimensions may run only 35 after tuning.

### 8. Codebase Map Token Savings (Incremental Audits)

The biggest token savings come from the codebase map on repeat audits:

| Audit Type | Without Map | With Map | Savings |
|-----------|-------------|----------|---------|
| Full (1st) | 73 dims × all files | Same (no map yet) | 0% |
| Incremental (2nd+) | 73 dims × all files | Changed files: all dims. Hot-spots: known dims. Clean: skip (+ 10% random) | **60-80%** |
| Targeted | 73 dims × selected files | Selected files: map-recommended dims first | **30-50%** |

**How it saves tokens:**
- Explorer agents get a FOCUSED file list (not "scan everything")
- Consolidation is instant (map comparison, no agent needed for categorization)
- Verification agents get historical context (fewer false positives to investigate)
- Clean files are skipped entirely (except 10% random sample)

**Token budget with map (incremental audit, 500-file codebase):**
```
Changed files (20) × all dims: 20 × 5K = 100K tokens
Hot-spots (10) × 5 dims each: 10 × 1K = 10K tokens
Random clean sample (50) × all dims: 50 × 5K = 250K tokens (reduced from 2,500K)
Fix + Review: unchanged ~250K tokens

TOTAL: ~610K (vs ~2,900K without map) = **79% savings**
```

### 9. Batch API for Background Audits
For scheduled/non-interactive audits, use Anthropic's Batch API:
- 50% cost reduction
- Results within 24h (usually much faster)
- Ideal for nightly/weekly automated audits

## Token Budget Calculator

Estimate before running:
```
Full audit:    73 dimensions x ~5K tokens/agent = ~365K tokens
Quick audit:   14 dimensions x ~5K tokens/agent = ~70K tokens
Changed-only:  ~5 dimensions x ~5K tokens/agent = ~25K tokens

Fix phases:    4 phases x 4 agents x ~8K tokens/agent = ~128K tokens
Reviews:       4 x ~15K tokens/review = ~60K tokens
/simplify:     4 x 3 agents x ~5K tokens/agent = ~60K tokens

TOTAL FULL:    ~613K tokens (~$9.20 at Opus, ~$1.85 at Sonnet, ~$0.30 at Haiku)
TOTAL OPTIMIZED: ~200K tokens (~$2.00 mixed models)
```
