# Round 7 — Token & API Cost Efficiency

12 dimensions for auditing LLM API token usage and cost optimization. Use `--preset token` to run only this round.

---

### Dimension 7.1: Prompt Size Audit
**Search for:** Oversized prompts sent to LLM APIs, unnecessary context in system prompts.
```bash
grep -rn "system.*prompt\|SYSTEM_PROMPT\|_SYSTEM\s*=" python/ --include="*.py" | head -15
# Check prompt sizes (string lengths)
grep -rn '""".*"""' python/ --include="*.py" | awk '{print length, FILENAME":"NR}' | sort -rn | head -10
# Dynamic prompt construction (may be larger than static analysis shows)
grep -rn "f\".*{.*}\|\.format(.*)\|prompt.*\+" python/ --include="*.py" | grep -i "prompt\|system\|message" | head -10
```
**Classify:** HIGH if any prompt >2000 tokens (approx. 8000 chars). MEDIUM if >1000 tokens. LOW if <500 tokens.
**Note:** Character count is approximate — 1 token ≈ 4 chars for English text. Use `tiktoken` or `anthropic.count_tokens()` for exact counts.

### Dimension 7.2: Model Routing
**Search for:** Expensive models used for simple tasks, missing context-window validation, no routing logic.
```bash
grep -rn "opus\|sonnet\|haiku\|gpt-4\|gpt-3.5\|model.*=\|engine.*=" python/ --include="*.py" | head -15
grep -rn "def.*route\|def.*select_model\|def.*choose_model\|tier\|routing" python/ --include="*.py" | head -10
# Context-window mismatch: input larger than model limit
grep -rn "haiku\|claude-haiku" python/ --include="*.py" | head -10
# Check for context-length validation before API call
grep -rn "len(.*token\|count.*token\|token.*limit\|context.*limit\|max_context" python/ --include="*.py" | head -10
```
**Classify:** HIGH if Opus used for simple extraction/classification tasks. HIGH if no context-length guard before feeding large inputs to any model. MEDIUM if no routing logic exists. LOW if tiered routing with context-length guards implemented.
**Model reference (Anthropic, 2025):**
| Model | Context | Best for |
|-------|---------|----------|
| Haiku | 200K | Simple extraction, classification, short tasks |
| Sonnet | 200K | Complex analysis, code, most agent tasks |
| Opus | 200K | Deep architectural review, cross-file reasoning |

### Dimension 7.3: Response Caching
**Search for:** Identical LLM calls made repeatedly without caching.
```bash
grep -rn "cache\|lru_cache\|@cached\|redis.*cache\|_cache\[" python/ --include="*.py" | grep -i "llm\|prompt\|completion\|chat" | head -10
grep -rn "def.*llm\|def.*ask\|def.*query\|def.*complete" python/ --include="*.py" | head -10
# Anthropic prompt caching hint (cache_control)
grep -rn "cache_control\|ephemeral\|cache_type" python/ --include="*.py" | head -5
```
**Classify:** HIGH if LLM functions have no caching and are called >1x per session. MEDIUM if caching exists but no TTL. MEDIUM if Anthropic prompt caching not used for repeated system prompts (saves ~90% on cached prefix). LOW if proper cache with TTL.

### Dimension 7.4: Context Window Waste
**Search for:** Full file contents loaded when only a function/section is needed, entire codebases passed to LLM.
```bash
grep -rn "read_text()\|read_bytes()\|\.read()" python/ --include="*.py" | grep -i "prompt\|context\|llm\|send" | head -10
grep -rn "Path.*read_text\|open.*read" python/ --include="*.py" | head -15
# Entire directory trees passed as context
grep -rn "os\.walk\|glob\.glob\|rglob" python/ --include="*.py" | grep -i "prompt\|context\|llm" | head -10
```
**Classify:** HIGH if entire files sent to LLM without extraction. MEDIUM if files >500 lines sent whole. LOW if targeted extraction used.

### Dimension 7.5: System Prompt Duplication
**Search for:** Same system prompt sent with every API call instead of using prompt caching or static prefix.
```bash
grep -rn "system.*message\|role.*system\|SystemMessage" python/ --include="*.py" | head -10
# Check if system prompts are defined as constants (good) vs inline strings (bad)
grep -rn "messages.*=.*\[.*{.*role.*system" python/ --include="*.py" | head -10
```
**Classify:** HIGH if system prompt is an inline string rebuilt per call. MEDIUM if constant but sent every call without cache hint. LOW if using prompt caching.

### Dimension 7.6: Output Token Control
**Search for:** Missing or miscalibrated max_tokens on LLM calls.
```bash
grep -rn "max_tokens\|max_output\|stop_sequences\|stop=" python/ --include="*.py" | head -10
grep -rn "\.create(\|\.complete(\|\.generate(\|\.chat(" python/ --include="*.py" | grep -v "max_tokens" | head -10
# Check if limits match task complexity
grep -rn "max_tokens.*=.*[0-9]" python/ --include="*.py" | head -15
```
**Classify:** CRITICAL if LLM calls have no max_tokens (model generates until context full). HIGH if max_tokens >4000 for simple extraction tasks. MEDIUM if max_tokens set but not calibrated to task.
**Reference budgets (adapt to your tasks):**
| Agent type | Suggested max_tokens |
|------------|---------------------|
| Extraction / classification | 500–1000 |
| Code analysis | 1000–2000 |
| Code generation / fix | 2000–4000 |
| Deep review (Opus) | 3000–5000 |

### Dimension 7.7: Batch vs Real-Time
**Search for:** LLM calls inside loops (use Batch API instead), missing asyncio.gather for parallelizable calls.
```bash
grep -rn "for.*in.*:\s*$" python/ --include="*.py" -A3 | grep -B1 "llm\|complete\|generate\|chat" | head -15
grep -rn "async.*for\|asyncio.gather\|batch\|bulk" python/ --include="*.py" | grep -i "llm\|api" | head -10
# Anthropic Batch API usage (50% cost reduction)
grep -rn "batches\|message_batches\|batch_id\|results_url" python/ --include="*.py" | head -5
```
**Classify:** HIGH if LLM calls inside loops where Batch API would apply. MEDIUM if sequential calls could be parallelized with asyncio.gather. LOW if already using Batch API or parallel calls.
**Decision guide:**
- Results needed in <1 min → parallel real-time (asyncio.gather)
- Results needed in <24h, cost matters → Anthropic Batch API (50% cheaper, same quality)
- Single interactive call → streaming real-time

### Dimension 7.8: Embedding Efficiency
**Search for:** Repeated embedding of the same text, missing embedding cache.
```bash
grep -rn "embed\|embedding\|encode.*text\|vectorize" python/ --include="*.py" | head -15
grep -rn "embed.*cache\|_embed_cache\|cached.*embed" python/ --include="*.py" | head -5
# Stale embeddings — computed at startup, never refreshed on code change
grep -rn "embed" python/ --include="*.py" | grep -i "startup\|init\|load\|__init__" | head -5
```
**Classify:** HIGH if same text embedded multiple times without cache. MEDIUM if cache exists but no TTL/invalidation. MEDIUM if embeddings computed at startup but content can change. LOW if efficient caching with invalidation.

### Dimension 7.9: Retry Waste
**Search for:** Failed LLM calls retried with identical prompt (same input = same failure).
```bash
grep -rn "retry\|retries\|max_retries\|backoff\|tenacity" python/ --include="*.py" | grep -i "llm\|api\|complete\|chat" | head -10
grep -rn "except.*:.*retry\|except.*:.*sleep" python/ --include="*.py" | head -10
# Check for prompt modification on retry (good) vs identical retry (bad)
grep -rn "retry" python/ --include="*.py" -A5 | grep -i "prompt\|message\|modify\|append\|shorten" | head -10
```
**Classify:** HIGH if retrying identical prompt without modification after content/format errors. MEDIUM if retrying on rate limits without exponential backoff. LOW if proper exponential backoff with modified or shortened prompts on retry.

### Dimension 7.10: Cost Tracking
**Search for:** Whether token usage and costs are tracked, alerted on, and attributed per operation.
```bash
grep -rn "token.*count\|usage\|cost\|billing\|track.*token\|log.*token" python/ --include="*.py" | head -10
grep -rn "prompt_tokens\|completion_tokens\|total_tokens" python/ --include="*.py" | head -10
# Budget alerts
grep -rn "budget\|threshold\|alert\|limit.*token\|token.*limit" python/ --include="*.py" | head -10
# Per-operation attribution (not just global totals)
grep -rn "cost.*phase\|token.*phase\|cost.*agent\|token.*agent\|cost.*dim" python/ --include="*.py" | head -5
```
**Classify:** CRITICAL if no cost tracking exists and LLM API is used in production. HIGH if tracking exists but no budget alerts. MEDIUM if tracked globally but no per-operation attribution (can't identify which agent/phase costs most). LOW if full tracking + per-operation attribution + alerts.

---

### Dimension 7.11: Prompt Compression & Tokenization
**Search for:** Prompts built from raw verbose content when semantic compression would suffice; character-length used as token proxy.
```bash
# Large context blocks passed without summarization
grep -rn "prompt.*=\|context.*=\|message.*=" python/ --include="*.py" -A3 | grep -i "join\|concat\|\+" | head -15
# Character-length used to gate prompts (imprecise — use token count instead)
grep -rn "len(.*prompt\|len(.*context\|len(.*message" python/ --include="*.py" | grep -v "token" | head -10
# tiktoken / tokenizer usage (good)
grep -rn "tiktoken\|count_tokens\|tokenize\|num_tokens\|anthropic.*count" python/ --include="*.py" | head -5
# Few-shot examples added without token budget check
grep -rn "few.shot\|example.*prompt\|shots.*=\|examples.*=" python/ --include="*.py" | head -10
# Raw file content injected into prompts (high token cost)
grep -rn "read_text\|\.read()\|file.*content" python/ --include="*.py" | grep -i "prompt\|message\|context" | head -10
```
**Classify:** HIGH if large raw content (full files, long tracebacks, entire diffs) injected without summarization. HIGH if `len(str)` used as token budget gate instead of a tokenizer. MEDIUM if few-shot examples added without measuring their token overhead. LOW if semantic compression + tokenizer-based budgeting both used.
**Compression techniques to look for (absence = finding):**
- Summarize long inputs before injection (gisting)
- Strip docstrings/comments from code before passing to LLM
- Use `tiktoken` or `anthropic.count_tokens()` instead of `len()`
- Deduplicate repeated context across chained calls

### Dimension 7.12: Streaming vs. Blocking
**Search for:** Blocking LLM calls where streaming would reduce latency and enable early termination.
```bash
# Blocking create() calls (no streaming)
grep -rn "\.create(\|\.complete(\|\.messages\.create" python/ --include="*.py" | grep -v "stream\|streaming" | head -15
# Streaming enabled (good)
grep -rn "stream.*=.*True\|stream=True\|\.stream(\|for.*chunk\|for.*event" python/ --include="*.py" | head -10
# Early termination on streaming (best — stops tokens mid-generation)
grep -rn "break\|stop_reason\|end_turn" python/ --include="*.py" | grep -i "stream\|chunk\|delta" | head -10
```
**Classify:** HIGH if long-running LLM calls (expected output >500 tokens) use blocking mode — no early-exit possible, full output buffered. MEDIUM if streaming used but no early-termination logic (pays for full output even when first valid answer found early). LOW if streaming with early-exit implemented.
**When streaming matters:**
- User-facing output: always stream (perceived latency)
- Background agents: blocking OK if result consumed whole
- Early-exit patterns: stream + break on first valid JSON/answer = significant token savings
