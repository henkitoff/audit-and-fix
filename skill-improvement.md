# Skill Self-Improvement System

After every 3rd audit (or when manually triggered), a Skill Improvement Agent analyzes audit memory and proposes improvements to the skill itself.

## Trigger

Automatically after every 3rd audit entry in `history.json`, or when the user explicitly requests an improvement pass.

Examples:
- Claude path: `/audit-and-fix --improve`
- Codex path: `Use $audit-and-fix to run the improvement pass on this skill.`

## Improvement Agent Prompt

```text
You are the Skill Improvement Agent for audit-and-fix.

Read all skill files and artifacts/audit-memory/*.

Analyze:
1. Dead dimensions - did any dimension find 0 issues in all audits?
2. Missing dimensions - are there recurring issue patterns not covered?
3. False positive rate - which dimensions are noisy?
4. Search command effectiveness - which grep patterns are too broad or too weak?
5. Gate pattern effectiveness - did the native deep review catch issues the cleanup pass missed, or vice versa?
6. Duration optimization - which rounds take longest relative to findings?
7. Host drift - are Claude and Codex paths diverging and needing updated instructions?

Output: write artifacts/audit-memory/skill-improvement-suggestions.md with:
- PROPOSED CHANGES
- RATIONALE
- RISK
- RECOMMENDATION: APPLY / REVIEW / SKIP

IMPORTANT: never modify skill files automatically. Only propose changes.
```

## Safety Rules

1. Never delete dimensions automatically.
2. Never rewrite search commands automatically.
3. Keep `history.json` append-only.
4. Version the skill itself when accepted improvements are applied.
5. Show the exact diff before applying skill changes.

## Improvement Cycle

```text
Audit 1 -> Memory Update
Audit 2 -> Memory Update
Audit 3 -> Memory Update -> Skill Improvement Agent -> User Review -> Apply or Skip
Audit 4 -> Memory Update with improved skill
```

Over repeated audits, the skill should learn:
- which dimensions matter for this codebase
- which search commands produce the best signal
- which presets are most time-efficient
- whether Claude and Codex need routing updates
