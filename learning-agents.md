# Post-Audit Learning Agents

After every audit (after fix phases, before version bump), run the 3 analysis passes using the current host's native execution flow.

## Agent 1: Trend Analyzer

```text
You are the Trend Analyzer for the audit-and-fix skill.

Read `artifacts/audit-memory/history.json`. Compare the current audit with previous audits.

Also analyze the codebase map:
- Which files have improved over time?
- Which files have degraded?
- Which clean files had surprise findings?
- Recommend files to promote to hot-spots or demote to clean.

Report:
1. Finding trend
2. Health score trend
3. Dimension effectiveness trend
4. Duration trend
5. Fix durability

Output: append the trend summary to the current audit entry in history.json.
```

## Agent 2: Dimension Effectiveness Analyzer

```text
You are the Dimension Effectiveness Analyzer.

Read `artifacts/audit-memory/history.json`. For each dimension:
1. Count findings across the last 3 audits
2. If it found 0 issues in 3 consecutive audits, add it to tuning.json skip_candidates
3. If it found >5 CRITICAL issues in any audit, add it to tuning.json priority_boost
4. Calculate ROI = findings_count / estimated_agent_time

Output: write updated tuning.json with skip/boost recommendations.
```

## Agent 3: Regression Checker

```text
You are the Regression Checker.

Read `artifacts/audit-memory/regression-watch.json`. For each watched pattern:
1. Run the check command
2. If the pattern is found -> REGRESSION
3. If the pattern is not found -> CLEAR

Also check `false-positives.json`:
1. Verify each false positive is still valid
2. Remove stale entries

Output: report regressions and stale false positives.
```

## When to Run

These analysis passes run as the last step before version bump:

```text
Fix Phase D -> Learning Passes -> Version Bump
```

They should produce JSON/report updates only, not code changes.

## Example Dispatch

### Claude path

```python
Agent("Trend Analyzer", prompt=TREND_PROMPT, run_in_background=True)
Agent("Dimension Effectiveness", prompt=EFFECTIVENESS_PROMPT, run_in_background=True)
Agent("Regression Checker", prompt=REGRESSION_PROMPT, run_in_background=True)
```

### Codex default path

```text
Run the Trend Analyzer prompt
Run the Dimension Effectiveness prompt
Run the Regression Checker prompt
```

### Codex delegated fast-path

Use this only when delegated execution is available, policy-allowed, and explicitly requested by the user.

```text
spawn_agent(agent_type="explorer", message=TREND_PROMPT)
spawn_agent(agent_type="explorer", message=EFFECTIVENESS_PROMPT)
spawn_agent(agent_type="explorer", message=REGRESSION_PROMPT)
wait_agent([...])
```
