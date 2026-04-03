# Ollama Integration (Optional)

Use local Ollama models only for low-criticality tasks where some quality loss is acceptable.

## When to Use Ollama

| Task | Use Ollama? | Why |
|------|-------------|-----|
| Exploration (grep + classify) | NO | grep is faster and more precise |
| Fix Agents (code edits) | NO | Use the current host's native high-quality code model |
| Deep Review | NO | Cross-file reasoning quality matters |
| Cleanup Agents | NO | Review quality matters |
| Post-Audit Summary | YES | Low-risk summarization |
| Handoff Compression | YES | Summaries are acceptable here |
| Regression Check Narration | YES | Converting JSON to prose is low risk |

## Post-Audit Summary via Ollama

After consolidation, generate a human-readable paragraph:

```python
import ollama

client = ollama.Client()
response = client.generate(
    model="qwen3-coder:30b",
    prompt=(
        "Summarize this audit in 3-4 sentences. "
        "Mention total findings, top 3 critical issues, and recommended priority. "
        f"{consolidated_findings_json}"
    ),
)
summary = response["response"]
```

**Fallback:** if Ollama is unavailable, skip the summary.

## What Ollama Is Not Good For

- Code analysis
- Bug detection
- Architecture review
- Fix generation

Use Claude-native review models in Claude hosts and OpenAI/Codex-native models in Codex hosts for those tasks.
