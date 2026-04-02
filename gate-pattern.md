# Fix Phase Gate Pattern

Every fix phase follows this exact 7-step sequence. Do NOT skip steps. Do NOT reorder.

## Step 1: PLAN

Before dispatching agents, verify:
- Each agent has an explicit file list (no overlaps with other agents in this phase)
- Each agent has exact changes described (not "fix the bugs")
- Each agent has a test command to run after changes
- No two agents touch the same file
- Check cross-phase dependencies: can this phase run parallel with others? (see `reference.md` "Fix Phase Dependency Graph")

**Fix Ordering Within Priority Level:**
Sort findings within each priority by this formula:
1. **Cascade score** (×3): Does this bug enable other bugs? (check Round 4 cascading chains)
2. **Fix time** (×2, inverse): 5-minute fixes before 2-hour fixes (quick wins first)
3. **Test exists** (×1): Bugs with existing test coverage first (verifiable fix)
4. **File isolated** (×1): Bugs in files no other fix touches first (no merge risk)

Example: NaN-guard in data_writer.py scores HIGH (cascade: enables downstream errors, fix: 5min, test: yes, isolated: yes) = 3+2+1+1 = 7. Thread-lock in inference.py scores MEDIUM (cascade: no, fix: 30min, test: no, isolated: no) = 0+1+0+0 = 1.

**Codebase Map Awareness (if map exists):**
- Check `risk_score` for each file in the fix scope. Files with risk >= 7 need extra review after fix.
- If a fix touches a file with historical findings in OTHER dimensions, add a quick regression check.
- Flag to Opus reviewer: "This file has had [N] historical bugs — verify fix doesn't introduce regressions."

## Step 2: EXECUTE

Launch N agents in parallel:
- `subagent_type: general-purpose`
- `isolation: worktree` (ALWAYS — never edit main directly)
- Max 4 parallel agents per phase
- Each agent must: read file first, apply fix, run tests, commit with Co-Authored-By

## Step 3: MERGE

After all agents complete:
```bash
cd /path/to/repo
git merge worktree-agent-XXXXX --no-edit
# Repeat for each agent branch
```
If conflicts: prefer newer changes. If unclear, read both versions and merge manually.

## Step 4: TEST

Run the test suite relevant to this phase:
```bash
python -m pytest tests/ -x -q -p no:faulthandler
```
ALL tests must pass before proceeding. If failures:
- Check if failure is pre-existing (existed before this phase)
- If new failure: fix immediately before review

## Step 5: OPUS REVIEW (must complete before /simplify — unless 0 CRITICAL)

Launch Opus code-review agent:
```
subagent_type: superpowers:code-reviewer
```
Provide:
- The git diff range for this phase
- Phase-specific focus areas (e.g., "lock ordering" for thread-safety phase)
- Max finding count (10-15 per review)

Rate findings: CRITICAL (must fix now) / WARNING (should fix) / INFO (nice to have).
Fix ALL CRITICAL findings immediately.
If CRITICAL findings exist: fix them, THEN proceed to Step 6.
If 0 CRITICAL findings: proceed to Step 6 immediately. Additionally, /simplify (Step 6) and the NEXT fix phase can overlap — see `reference.md` Strategy 2 for details.

## Step 6: /SIMPLIFY (runs on post-fix code)

**Adaptive dispatch — scale agents to phase size:**

| Phase file count | Agents to launch | Assignment |
|-----------------|-----------------|------------|
| ≤ 2 files | 1 agent | All 3 checks combined into one prompt |
| 3–6 files | 2 agents | Agent 1: Reuse + Quality · Agent 2: Efficiency (give different file sets) |
| 7+ files | 3 agents | Full parallel split (see below) |

**Full 3-agent split (large phases only):**

Give each agent a DIFFERENT subset of the changed files — no overlap.
Split the file list roughly by thirds (e.g. 9 files → 3 per agent).

1. **Code Reuse** — duplicated utilities, existing helpers not used
2. **Code Quality** — redundant state, copy-paste, unnecessary comments
3. **Efficiency** — hot-path bloat, lock contention, unnecessary work

**Git diff tip:** Pass `git diff --unified=1 HEAD~1` rather than full files when file contents are large — this shows only changed context and cuts token cost ~60–80%.

These review the code AFTER Opus findings are fixed — ensuring they don't waste time on code that's about to change.

Fix substantive findings — a finding is substantive if it could cause a bug, degrade performance measurably, or confuse a future maintainer. Skip style-only or theoretical findings (note them, don't argue).

## Step 7: NEXT PHASE

If more fix phases remain: proceed to next phase.
If this was the last phase: version bump + push.

```bash
# Version bump (last phase only — adapt to your project's versioning script):
# python scripts/bump_version.py minor --summary "VX.Y — [description]"
# OR manually update version files, then:
git commit -m "feat: VX.Y — [description]"
git push origin main
```

## Gate Checklist (copy per phase)

- [ ] All agents completed and merged
- [ ] Tests green (or pre-existing failures documented)
- [ ] Opus review: 0 CRITICAL remaining
- [ ] /simplify: substantive findings fixed
- [ ] Ready for next phase
