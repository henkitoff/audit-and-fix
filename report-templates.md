# Report Templates

Copy-paste these templates when creating reports during an audit-and-fix session.

---

## 1. Exploration Report (per dimension)

Use this for each Explorer agent's output.

```markdown
# [Dimension Name] Exploration Report

**Round:** N | **Dimension:** N.N | **Date:** YYYY-MM-DD
**Files Scanned:** [count] | **Findings:** [count]

## CRITICAL Findings
### C1: [Title]
- **File:** `path/to/file.py:LINE`
- **Issue:** [1-2 sentence description]
- **Evidence:** [code snippet or grep output]
- **Suggested Fix:** [what to change]

## HIGH Findings
### H1: [Title]
- **File:** `path/to/file.py:LINE`
- **Issue:** [description]
- **Suggested Fix:** [what to change]

## MEDIUM Findings
### M1: [Title]
(same format)

## LOW Findings
### L1: [Title]
(same format)

## Summary
| Severity | Count |
|----------|-------|
| CRITICAL | N |
| HIGH | N |
| MEDIUM | N |
| LOW | N |
```

---

## 2. Consolidated Audit Report

Use this after all exploration rounds to create the master roadmap.

```markdown
# Codebase Audit Report

**Date:** YYYY-MM-DD | **Version:** VX.Y.Z
**Rounds:** [N] | **Dimensions:** [N] | **Explorer Agents:** [N]

## Executive Summary
- Total findings: N
- CRITICAL: N, HIGH: N, MEDIUM: N, LOW: N
- Estimated fix time: P0 = Xh, P1 = Xh, P2 = Xh

## P0 — Immediate (Capital/Data Preservation)
| # | Finding | File:Line | Fix | Effort |
|---|---------|-----------|-----|--------|
| 1 | [description] | `file.py:NN` | [action] | Xmin |

## P1 — Short-term (Stability)
| # | Finding | File:Line | Fix | Effort |
|---|---------|-----------|-----|--------|

## P2 — Medium-term (Quality)
| # | Finding | File:Line | Fix | Effort |
|---|---------|-----------|-----|--------|

## Fix Phases

### Phase A: [scope] — N parallel agents
| Agent | Files | Task |
|-------|-------|------|
| A1 | `file1.py`, `file2.py` | [description] |
| A2 | `file3.py`, `file4.py` | [description] |
**File-Overlap:** NONE

### Phase B: [scope] — N parallel agents
(same format)

### Phase C: [scope] — N parallel agents
(same format)

### Phase D: Cleanup + Version Bump
(same format)
```

---

## 3. Gate Review Report

Use this for the Opus code-review agent output after each fix phase.

```markdown
# Gate [A/B/C/D] Review

**Phase:** [description] | **Reviewer:** Opus
**Diff Range:** `COMMIT_A..COMMIT_B`
**Verdict:** PASS / PASS WITH FIXES / FAIL

## CRITICAL Findings (must fix before proceeding)
### 1. [Title]
- **File:** `path/to/file.py:LINE`
- **Issue:** [description]
- **Risk:** [impact if not fixed]
- **Required Fix:** [exact change needed]

## WARNING Findings (should fix soon)
### 1. [Title]
- **File:** `path/to/file.py:LINE`
- **Issue:** [description]
- **Recommended Fix:** [suggested change]

## INFO Findings (nice to have)
### 1. [Title]
- **File:** `path/to/file.py:LINE`
- **Note:** [observation]

## Summary
| Severity | Count |
|----------|-------|
| CRITICAL | N |
| WARNING | N |
| INFO | N |
```
