# Round 7 - Token & API Cost Efficiency

12 dimensions for auditing LLM API token usage and cost optimization. Use `--preset token` to run only this round.

---

### Dimension 7.1: Prompt Size Audit
**Search for:** Oversized prompts sent to LLM APIs, unnecessary context in system prompts.
```bash
grep -rn "system.*prompt\|SYSTEM_PROMPT\|_SYSTEM\s*=" python/ --include="*.py" | head -15
grep -rn '""".*"""' python/ --include="*.py" | awk '{print length, FILENAME":"NR}' | sort -rn | head -10
grep -rn "f\".*{.*}\|\.format(.*)\|prompt.*\+" python/ --include="*.py" | grep -i "prompt\|system\|message" | head -10
```
**Classify:** HIGH if any prompt >2000 tokens (approx. 8000 chars). MEDIUM if >1000 tokens. LOW if <500 tokens.
**Note:** Character count is approximate. Use `tiktoken`, a provider token counter, or your local tokenizer for exact counts.

### Dimension 7.2: Model Routing
**Search for:** Expensive models used for simple tasks, missing context-window validation, no routing logic.
```bash
grep -rn "opus\|sonnet\|haiku\|gpt-4\|gpt-4o\|gpt-4\.1\|gpt-5\|o1\|o3\|model.*=\|engine.*=" python/ --include="*.py" | head -15
grep -rn "def.*route\|def.*select_model\|def.*choose_model\|tier\|routing" python/ --include="*.py" | head -10
grep -rn "haiku\|claude-haiku\|gpt-4o-mini\|gpt-5-mini" python/ --include="*.py" | head -10
grep -rn "len(.*token\|count.*token\|token.*limit\|context.*limit\|max_context" python/ --include="*.py" | head -10
```
**Classify:** HIGH if a top-tier review/reasoning model is used for simple extraction or classification. HIGH if no context-length guard exists before large inputs are sent. MEDIUM if no routing logic exists. LOW if tiered routing with context-length guards is implemented.
**Model-family reference:**
| Provider | Fast / Cheap | Standard | Deep Review |
|----------|--------------|----------|-------------|
| Claude | Haiku | Sonnet | Opus |
| OpenAI / Codex | mini / lightweight model | standard GPT or Codex model | top-tier reasoning/review model |

### Dimension 7.3: Response Caching
**Search for:** Identical LLM calls made repeatedly without caching.
```bash
grep -rn "cache\|lru_cache\|@cached\|redis.*cache\|_cache\[" python/ --include="*.py" | grep -i "llm\|prompt\|completion\|chat\|response" | head -10
grep -rn "def.*llm\|def.*ask\|def.*query\|def.*complete\|def.*respond" python/ --include="*.py" | head -10
grep -rn "cache_control\|prompt_cache\|cached_input\|reuse_prompt" python/ --include="*.py" | head -5
```
**Classify:** HIGH if LLM functions have no caching and are called repeatedly. MEDIUM if caching exists but has no TTL or invalidation. MEDIUM if stable prefixes are rebuilt every call with no reuse strategy. LOW if proper cache/reuse exists.

### Dimension 7.4: Context Window Waste
**Search for:** Full file contents loaded when only a function or section is needed.
```bash
grep -rn "read_text()\|read_bytes()\|\.read()" python/ --include="*.py" | grep -i "prompt\|context\|llm\|send" | head -10
grep -rn "Path.*read_text\|open.*read" python/ --include="*.py" | head -15
grep -rn "os\.walk\|glob\.glob\|rglob" python/ --include="*.py" | grep -i "prompt\|context\|llm" | head -10
```
**Classify:** HIGH if entire files are sent without extraction. MEDIUM if files >500 lines are sent whole. LOW if targeted extraction is used.

### Dimension 7.5: System Prompt Duplication
**Search for:** Same system prompt sent on every call instead of using reusable prefixes or caching.
```bash
grep -rn "system.*message\|role.*system\|SystemMessage" python/ --include="*.py" | head -10
grep -rn "messages.*=.*\[.*{.*role.*system" python/ --include="*.py" | head -10
```
**Classify:** HIGH if a system prompt is rebuilt inline per call. MEDIUM if it is constant but always re-sent without a reuse strategy. LOW if stable prefixes are reused efficiently.

### Dimension 7.6: Output Token Control
**Search for:** Missing or badly calibrated output limits on LLM calls.
```bash
grep -rn "max_tokens\|max_output\|max_completion_tokens\|stop_sequences\|stop=" python/ --include="*.py" | head -10
grep -rn "\.create(\|\.complete(\|\.generate(\|\.chat(\|responses\.create" python/ --include="*.py" | grep -v "max_tokens\|max_output\|max_completion_tokens" | head -10
grep -rn "max_tokens.*=.*[0-9]\|max_output.*=.*[0-9]" python/ --include="*.py" | head -15
```
**Classify:** CRITICAL if LLM calls have no output limit. HIGH if output limits are very large for simple extraction tasks. MEDIUM if limits exist but are obviously miscalibrated.
**Reference budgets:**
| Agent type | Suggested output limit |
|------------|------------------------|
| Extraction / classification | 500-1000 |
| Code analysis | 1000-2000 |
| Code generation / fix | 2000-4000 |
| Deep review | 3000-5000 |

### Dimension 7.7: Batch vs Real-Time
**Search for:** LLM calls inside loops, missing concurrency, missing batch/deferred APIs.
```bash
grep -rn "for.*in.*:\s*$" python/ --include="*.py" -A3 | grep -B1 "llm\|complete\|generate\|chat\|response" | head -15
grep -rn "async.*for\|asyncio.gather\|batch\|bulk\|parallel" python/ --include="*.py" | grep -i "llm\|api\|response" | head -10
grep -rn "batches\|message_batches\|batch_id\|responses\.batch" python/ --include="*.py" | head -5
```
**Classify:** HIGH if LLM calls live inside loops where batching would apply. MEDIUM if sequential calls could be parallelized. LOW if batching or safe parallel calls already exist.
**Decision guide:**
- Results needed in <1 min -> parallel real-time
- Results can wait -> provider batch/offline API
- Single interactive call -> streaming real-time

### Dimension 7.8: Embedding Efficiency
**Search for:** Repeated embedding of the same text, missing embedding cache.
```bash
grep -rn "embed\|embedding\|encode.*text\|vectorize" python/ --include="*.py" | head -15
grep -rn "embed.*cache\|_embed_cache\|cached.*embed" python/ --include="*.py" | head -5
grep -rn "embed" python/ --include="*.py" | grep -i "startup\|init\|load\|__init__" | head -5
```
**Classify:** HIGH if the same text is embedded repeatedly with no cache. MEDIUM if cache exists but no invalidation or TTL. LOW if efficient caching with invalidation exists.

### Dimension 7.9: Retry Waste
**Search for:** Failed LLM calls retried with the same prompt and same likely outcome.
```bash
grep -rn "retry\|retries\|max_retries\|backoff\|tenacity" python/ --include="*.py" | grep -i "llm\|api\|complete\|chat\|response" | head -10
grep -rn "except.*:.*retry\|except.*:.*sleep" python/ --include="*.py" | head -10
grep -rn "retry" python/ --include="*.py" -A5 | grep -i "prompt\|message\|modify\|append\|shorten" | head -10
```
**Classify:** HIGH if identical prompts are retried after content/format errors. MEDIUM if retries lack exponential backoff. LOW if retries adapt the prompt and back off correctly.

### Dimension 7.10: Cost Tracking
**Search for:** Whether token usage and cost are tracked, alerted on, and attributed per operation.
```bash
grep -rn "token.*count\|usage\|cost\|billing\|track.*token\|log.*token" python/ --include="*.py" | head -10
grep -rn "prompt_tokens\|completion_tokens\|total_tokens\|output_tokens" python/ --include="*.py" | head -10
grep -rn "budget\|threshold\|alert\|limit.*token\|token.*limit" python/ --include="*.py" | head -10
grep -rn "cost.*phase\|token.*phase\|cost.*agent\|token.*agent\|cost.*dim" python/ --include="*.py" | head -5
```
**Classify:** CRITICAL if no cost tracking exists and LLM APIs run in production. HIGH if tracking exists but no budget alerts. MEDIUM if tracked globally but not per operation. LOW if full tracking and alerts exist.

---

### Dimension 7.11: Prompt Compression & Tokenization
**Search for:** Prompts built from raw verbose content when semantic compression would suffice; character length used as token proxy.
```bash
grep -rn "prompt.*=\|context.*=\|message.*=" python/ --include="*.py" -A3 | grep -i "join\|concat\|\+" | head -15
grep -rn "len(.*prompt\|len(.*context\|len(.*message" python/ --include="*.py" | grep -v "token" | head -10
grep -rn "tiktoken\|count_tokens\|tokenize\|num_tokens\|anthropic.*count" python/ --include="*.py" | head -5
grep -rn "few.shot\|example.*prompt\|shots.*=\|examples.*=" python/ --include="*.py" | head -10
grep -rn "read_text\|\.read()\|file.*content" python/ --include="*.py" | grep -i "prompt\|message\|context" | head -10
```
**Classify:** HIGH if large raw content is injected without summarization. HIGH if `len(str)` gates token budgets. MEDIUM if few-shot examples are added without measuring token overhead. LOW if semantic compression and tokenizer-based budgeting both exist.

### Dimension 7.12: Streaming vs Blocking
**Search for:** Blocking LLM calls where streaming would reduce latency or allow early termination.
```bash
grep -rn "\.create(\|\.complete(\|\.messages\.create\|responses\.create" python/ --include="*.py" | grep -v "stream\|streaming" | head -15
grep -rn "stream.*=.*True\|stream=True\|\.stream(\|for.*chunk\|for.*event" python/ --include="*.py" | head -10
grep -rn "break\|stop_reason\|end_turn" python/ --include="*.py" | grep -i "stream\|chunk\|delta\|event" | head -10
```
**Classify:** HIGH if long-running calls use blocking mode with no early-exit path. MEDIUM if streaming exists but no early-termination logic. LOW if streaming with early-exit is implemented.
