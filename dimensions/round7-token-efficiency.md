# Round 7 — Token & API Cost Efficiency

10 dimensions for auditing LLM API token usage and cost optimization. Use `--preset token` to run only this round.

---

### Dimension 7.1: Prompt Size Audit
**Search for:** Oversized prompts sent to LLM APIs, unnecessary context in system prompts.
```bash
grep -rn "system.*prompt\|SYSTEM_PROMPT\|_SYSTEM\s*=" python/ --include="*.py" | head -15
# Check prompt sizes (string lengths)
grep -rn '""".*"""' python/ --include="*.py" | awk '{print length, FILENAME":"NR}' | sort -rn | head -10
```
**Classify:** HIGH if any prompt >2000 tokens. MEDIUM if >1000 tokens. LOW if <500 tokens.

### Dimension 7.2: Model Routing
**Search for:** Expensive models used for simple tasks, no model selection logic.
```bash
grep -rn "opus\|sonnet\|haiku\|gpt-4\|gpt-3.5\|model.*=\|engine.*=" python/ --include="*.py" | head -15
grep -rn "def.*route\|def.*select_model\|def.*choose_model\|tier\|routing" python/ --include="*.py" | head -10
```
**Classify:** HIGH if Opus/GPT-4 used for extraction/classification tasks. MEDIUM if no routing logic exists. LOW if tiered routing implemented.

### Dimension 7.3: Response Caching
**Search for:** Identical LLM calls made repeatedly without caching.
```bash
grep -rn "cache\|lru_cache\|@cached\|redis.*cache\|_cache\[" python/ --include="*.py" | grep -i "llm\|prompt\|completion\|chat" | head -10
grep -rn "def.*llm\|def.*ask\|def.*query\|def.*complete" python/ --include="*.py" | head -10
```
**Classify:** HIGH if LLM functions have no caching and are called >1x per session. MEDIUM if caching exists but no TTL. LOW if proper cache with TTL.

### Dimension 7.4: Context Window Waste
**Search for:** Full file contents loaded when only a function/section is needed, entire codebases passed to LLM.
```bash
grep -rn "read_text()\|read_bytes()\|\.read()" python/ --include="*.py" | grep -i "prompt\|context\|llm\|send" | head -10
grep -rn "Path.*read_text\|open.*read" python/ --include="*.py" | head -15
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
**Search for:** Missing max_tokens parameter on LLM calls, allowing unlimited output.
```bash
grep -rn "max_tokens\|max_output\|stop_sequences\|stop=" python/ --include="*.py" | head -10
grep -rn "\.create(\|\.complete(\|\.generate(\|\.chat(" python/ --include="*.py" | grep -v "max_tokens" | head -10
```
**Classify:** HIGH if LLM calls have no max_tokens (model generates until context full). MEDIUM if max_tokens >4000 for simple tasks. LOW if appropriate limits set.

### Dimension 7.7: Batch vs Real-Time
**Search for:** Individual LLM calls that could be batched for cost savings.
```bash
grep -rn "for.*in.*:\s*$" python/ --include="*.py" -A3 | grep -B1 "llm\|complete\|generate\|chat" | head -15
grep -rn "async.*for\|asyncio.gather\|batch\|bulk" python/ --include="*.py" | grep -i "llm\|api" | head -10
```
**Classify:** HIGH if LLM calls inside loops (N calls instead of 1 batch). MEDIUM if sequential calls could be parallelized. LOW if already batched or inherently serial.

### Dimension 7.8: Embedding Efficiency
**Search for:** Repeated embedding of the same text, missing embedding cache.
```bash
grep -rn "embed\|embedding\|encode.*text\|vectorize" python/ --include="*.py" | head -15
grep -rn "embed.*cache\|_embed_cache\|cached.*embed" python/ --include="*.py" | head -5
```
**Classify:** HIGH if same text embedded multiple times without cache. MEDIUM if cache exists but no TTL/invalidation. LOW if efficient caching.

### Dimension 7.9: Retry Waste
**Search for:** Failed LLM calls retried with identical prompt (same input = same failure).
```bash
grep -rn "retry\|retries\|max_retries\|backoff\|tenacity" python/ --include="*.py" | grep -i "llm\|api\|complete\|chat" | head -10
grep -rn "except.*:.*retry\|except.*:.*sleep" python/ --include="*.py" | head -10
```
**Classify:** HIGH if retrying identical prompt without modification after content errors. MEDIUM if retrying on rate limits without backoff. LOW if proper exponential backoff with modified prompts.

### Dimension 7.10: Cost Tracking
**Search for:** Whether token usage and costs are tracked at all.
```bash
grep -rn "token.*count\|usage\|cost\|billing\|track.*token\|log.*token" python/ --include="*.py" | head -10
grep -rn "prompt_tokens\|completion_tokens\|total_tokens" python/ --include="*.py" | head -10
```
**Classify:** CRITICAL if no cost tracking exists and LLM API is used in production. HIGH if tracking exists but not monitored/alerted. MEDIUM if tracked but no budget limits. LOW if full tracking + alerts.
