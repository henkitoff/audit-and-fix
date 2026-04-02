# Ollama Integration (Optional)

Use local Ollama models for low-criticality tasks where 10-20% quality loss is acceptable.

## When to Use Ollama

| Task | Use Ollama? | Why |
|------|------------|-----|
| Exploration (grep + classify) | NO | grep is faster and more precise than any LLM |
| Fix Agents (code edits) | NO | Quality matters — use Sonnet |
| Opus Review | NO | Deep reasoning required — use Opus |
| /simplify Agents | NO | Quality matters for code review |
| **Post-Audit Summary** | YES | Summarizing findings is low-risk |
| **Handoff Compression** | YES | Already implemented in context_compressor.py |
| **Regression Check Narration** | YES | Converting JSON to readable text |

## Post-Audit Summary via Ollama

After consolidation, generate a human-readable 1-paragraph summary of the audit:

```python
# Adapt to your project's Ollama client (or use the ollama Python package directly):
# pip install ollama
import ollama

client = ollama.Client()
# Or if your project has a wrapper: from your_package.ollama_client import OllamaClient
response = client.generate(
    model="qwen3-coder:30b",
    prompt=f"Summarize this audit in 3-4 sentences: {consolidated_findings_json}\nBe concise. Mention: total findings, top 3 critical issues, recommended priority."
)
summary = response['response']
```

**Expected output:** "Audit found 45 issues (8 critical, 12 high). Top priorities: NaN in financial calculations, missing authentication on API endpoints, and unbounded memory growth in the signal loop. Recommend fixing critical issues first (~4 hours), then addressing high-priority thread safety issues."

**Quality trade-off:** Summary may miss nuances. Acceptable because the full report is still available.
**Speed:** ~5 seconds on qwen3-coder:30b (local, free).
**Fallback:** If Ollama unavailable, skip summary (not critical).

## What Ollama is NOT Good For

- **Code analysis** — grep/find is faster and more precise
- **Bug detection** — Claude catches subtle bugs Ollama misses
- **Architecture review** — requires deep reasoning beyond Ollama's capability
- **Fix generation** — code edits need high accuracy; Ollama's 70% isn't enough
