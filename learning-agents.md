# Post-Audit Learning Agents

After every audit (after fix phases, before version bump), launch 3 parallel analysis agents.

## Agent 1: Trend Analyzer

```
You are the Trend Analyzer for the audit-and-fix skill.

Read `artifacts/audit-memory/history.json`. Compare the current audit with previous audits.

Also analyze the codebase map:
- Which files have IMPROVED over time (risk score decreasing)?
- Which files have DEGRADED (risk score increasing)?
- Which "clean" files have had SURPRISE findings?
- Recommend: files that should be promoted to hot_spots or demoted to clean.

Report:
1. **Finding Trend:** Is CRITICAL count increasing, stable, or decreasing?
2. **Health Score Trend:** Is the codebase getting healthier or sicker?
3. **Dimension Effectiveness:** Which dimensions found the most issues over time?
4. **Duration Trend:** Are audits getting faster or slower?
5. **Fix Durability:** What percentage of previous fixes are still in place?

Output: Append trend summary to current audit entry in history.json.
```

## Agent 2: Dimension Effectiveness Analyzer

```
You are the Dimension Effectiveness Analyzer.

Read `artifacts/audit-memory/history.json`. For each dimension:
1. Count findings across last 3 audits
2. If dimension found 0 issues in 3 consecutive audits → add to tuning.json skip_candidates
3. If dimension found >5 CRITICAL in any audit → add to tuning.json priority_boost
4. Calculate ROI: findings_count / estimated_agent_time

Output: Write updated tuning.json with skip/boost recommendations.
```

## Agent 3: Regression Checker

```
You are the Regression Checker.

Read `artifacts/audit-memory/regression-watch.json`. For each watched pattern:
1. Run the check_command
2. If pattern found → REGRESSION (the fix was reverted or bypassed)
3. If pattern not found → CLEAR (fix is still in place)

Also check `false-positives.json`:
1. Verify each false positive is still valid (file/line still exists)
2. Remove stale entries (file deleted or line changed)

Output: Report regressions and stale false-positives.
```

## When to Run

These agents run as the LAST step before version bump:
```
Fix Phase D → Learning Agents (3 parallel) → Version Bump
```

They take ~5 minutes total and produce no code changes — only JSON updates.

## Example Dispatch

```python
# Launch all 3 in parallel (background)
Agent("Trend Analyzer", prompt=TREND_PROMPT, subagent_type="Explore", run_in_background=True)
Agent("Dimension Effectiveness", prompt=EFFECTIVENESS_PROMPT, subagent_type="Explore", run_in_background=True)
Agent("Regression Checker", prompt=REGRESSION_PROMPT, subagent_type="Explore", run_in_background=True)
```
