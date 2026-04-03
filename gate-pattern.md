# Fix Phase Gate Pattern

Every fix phase follows this exact 7-step sequence. Do not skip steps. Do not reorder.

## Step 1: PLAN

Before dispatching agents, verify:
- Each agent has an explicit file list
- No two agents touch the same file
- Each agent has exact changes described
- Each agent has a test command
- Cross-phase dependencies are understood (see `reference.md`)

**Fix ordering within a priority level:**
1. Cascade score (bugs that enable other bugs first)
2. Fix time (quick wins first)
3. Existing test coverage
4. File isolation

**Codebase map awareness (if map exists):**
- Files with `risk_score >= 7` need extra scrutiny after the fix
- If a file has historical findings in other dimensions, add a quick regression check
- Tell the reviewer: "This file has had [N] historical bugs - verify the fix does not introduce regressions."

## Step 2: EXECUTE

Execute fixes using the current host's native execution path:

- **Claude path:** worktrees, one agent per disjoint file set, usually Sonnet
- **Codex default path:** fix in the main thread
- **Codex delegated fast-path:** optional `worker` agents with explicit file ownership, no overlapping files, and no reverts of other agents' work

Each fix agent must:
- Read files before editing
- Apply minimal, targeted fixes
- Run the assigned tests
- Report changed files and validation results

## Step 3: INTEGRATE

Integrate all completed fix work before review.

**Claude path:** merge worktree branches.

```bash
cd /path/to/repo
git merge worktree-agent-XXXXX --no-edit
```

**Codex single-agent path:** no integration step is needed beyond your own edits in the main thread.

**Codex delegated path:** review each worker's returned changes and integrate them into the main workspace in dependency order. If two workers touched overlapping code, stop and resolve manually instead of forcing the merge.

## Step 4: TEST

Run the test suite relevant to this phase:

```bash
python -m pytest tests/ -x -q -p no:faulthandler
```

All tests must pass before proceeding. If failures appear:
- Check whether they were pre-existing
- Fix new failures before review

## Step 5: NATIVE DEEP REVIEW (must complete before cleanup unless 0 CRITICAL)

Launch a native deep-review agent:

- **Claude path:** Opus / native code-reviewer
- **Codex path:** top-tier OpenAI/Codex review agent, or the main thread if no separate reviewer is available

Provide:
- The diff range for this phase
- Phase-specific focus areas
- Max finding count (10-15)

Rate findings as:
- `CRITICAL` - must fix now
- `WARNING` - should fix
- `INFO` - nice to have

Fix all `CRITICAL` findings immediately.

If 0 `CRITICAL` findings remain, proceed to Step 6. At that point the cleanup pass and the next independent phase may overlap. See `reference.md`.

## Step 6: CLEANUP PASS

Run the host-native cleanup equivalent after deep-review findings are fixed.

**Adaptive dispatch:**

| Phase file count | Agents to launch | Assignment |
|-----------------|-----------------|------------|
| <= 2 files | 1 agent | Reuse + quality + efficiency in one prompt |
| 3-6 files | 2 agents | Split file sets; combine the three checks across two agents |
| 7+ files | 3 agents | Full split: reuse, quality, efficiency |

If delegated cleanup is in use, give each cleanup agent a different subset of changed files. In single-agent mode, process the same checks sequentially in the main thread.

**Git diff tip:** pass `git diff --unified=1` for changed files when full file content would be too large.

Fix substantive findings only:
- Could cause a bug
- Could degrade performance measurably
- Could confuse a future maintainer

Skip style-only or purely theoretical findings.

## Step 7: NEXT PHASE

If more phases remain: move to the next phase.
If this was the last phase: version bump and push.

```bash
git commit -m "feat: VX.Y - [description]"
git push origin main
```

## Gate Checklist

- [ ] All fix work completed and was integrated if delegation was used
- [ ] Tests are green (or pre-existing failures documented)
- [ ] Native deep review reports 0 CRITICAL remaining
- [ ] Cleanup-pass substantive findings are fixed
- [ ] Ready for the next phase
