# Auto-Detection: Skip Irrelevant Dimensions

## Map-Based Detection (overrides code-based when map exists)

If `artifacts/audit-memory/codebase-map.json` exists, use it INSTEAD of the code-based detection below:
- Skip dimensions with 0 matches across ALL files in the map (more precise than code-based)
- Prioritize dimensions that historically found CRITICAL findings
- The map knows which technologies are actually USED (not just installed)

Fall back to code-based detection only on first audit (no map yet).

Run these checks BEFORE launching exploration rounds to skip dimensions that don't apply.

## Language Detection
```bash
# Python project?
ls python/ pyproject.toml setup.py requirements*.txt 2>/dev/null | head -1
# JavaScript/TypeScript?
ls package.json tsconfig.json 2>/dev/null | head -1
# Go?
ls go.mod 2>/dev/null | head -1
```
If not Python: Skip all Python-specific dimensions (1.7, 5.9-5.12).

## ML/Trading Detection
```bash
grep -rl "torch\|sklearn\|xgboost\|catboost\|tensorflow\|keras" requirements*.txt pyproject.toml 2>/dev/null
```
If no ML frameworks: Skip Round 3 entirely (Dimensions 3.1-3.8).

## Threading Detection
```bash
grep -rl "threading\|multiprocessing\|asyncio" python/ --include="*.py" 2>/dev/null | wc -l
```
If 0: Skip Dimension 1.3 (Thread-Safety).

## WSL2 Detection
```bash
uname -r 2>/dev/null | grep -qi microsoft && echo "WSL2" || echo "NOT_WSL2"
```
If not WSL2: Skip Dimensions 5.5-5.8 (WSL2-specific).

## Syncthing Detection
```bash
ls .stignore .stfolder 2>/dev/null | head -1
```
If no Syncthing: Skip Dimension 5.4 (Sync-Tool Artifacts).

## Docker Detection
```bash
ls Dockerfile docker-compose*.yml 2>/dev/null | head -1
```
If no Docker: Skip Docker-related checks in 5.5.

## CI Detection
```bash
ls .github/workflows/*.yml .gitlab-ci.yml Jenkinsfile 2>/dev/null | head -1
```
If no CI: Flag as HIGH finding (no automated testing).

## Summary: Dimension Skip Matrix
| Condition | Skip Dimensions |
|-----------|----------------|
| Not Python | 1.7, 5.9-5.12 |
| No ML frameworks | 3.1-3.8 |
| No threading | 1.3 |
| Not WSL2 | 5.5-5.8 |
| No Syncthing | 5.4 |
| No Docker | Docker checks in 5.5 |
| <1000 LOC | Use --preset quick |
| >100K LOC | Use --preset full (all rounds) |
