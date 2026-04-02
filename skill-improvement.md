# Skill Self-Improvement System

After every 3rd audit (or manually triggered), a Skill Improvement Agent analyzes the audit memory and proposes concrete improvements to the skill itself.

## Trigger

Automatically after every 3rd audit entry in history.json, OR when user runs:
```
/audit-and-fix --improve
```

## Improvement Agent Prompt

```
You are the Skill Improvement Agent for audit-and-fix.

Read ALL skill files in skills/audit-and-fix/ and artifacts/audit-memory/*.

Analyze:
1. **Dead Dimensions:** Any dimensions that found 0 issues in ALL audits? Propose merging with related dimension or removing.
2. **Missing Dimensions:** Based on the types of issues found, are there bug patterns NOT covered by any existing dimension? Propose new dimensions.
3. **False Positive Rate:** Which dimensions produce the most false positives? Propose refined search commands.
4. **Search Command Effectiveness:** Which grep commands return too many results (>50) or zero results? Propose better patterns.
5. **Gate Pattern Effectiveness:** Did Opus reviews catch issues that /simplify missed, or vice versa? Propose focus adjustments.
6. **Duration Optimization:** Which rounds take longest relative to findings? Propose parallel execution or skip rules.
7. **Cross-Machine Patterns:** Do Mac audits find different issues than Windows audits? Propose machine-specific presets.

Output: Write `artifacts/audit-memory/skill-improvement-suggestions.md` with:
- PROPOSED CHANGES (concrete edits to skill files)
- RATIONALE (why each change helps)
- RISK (what could go wrong if applied)
- RECOMMENDATION: APPLY / REVIEW / SKIP

IMPORTANT: NEVER automatically modify skill files. Only propose changes.
The user decides what to apply.
```

## Safety Rules

1. **NEVER delete dimensions automatically.** Only propose removal with rationale.
2. **NEVER modify search commands automatically.** Propose refined versions for user review.
3. **Always keep history.json append-only.** Never truncate or rewrite past entries.
4. **Version the skill itself.** After applying improvements, bump a version comment in SKILL.md.
5. **Diff before apply.** Show the user exactly what would change before modifying any skill file.

## Improvement Cycle

```
Audit 1 → Memory Update
Audit 2 → Memory Update
Audit 3 → Memory Update → Skill Improvement Agent → User Review → Apply/Skip
Audit 4 → Memory Update (with improved skill)
...
```

Over 10+ audits, the skill accumulates:
- Which dimensions matter for THIS codebase
- Which search commands produce the best signal-to-noise
- Which presets are most time-efficient
- Which machines find which types of issues
