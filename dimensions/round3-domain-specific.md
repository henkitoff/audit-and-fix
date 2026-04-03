# Round 3 — Domain-Specific (ML / Stateful Systems)

### Dimension 3.1: Look-Ahead Bias / Temporal Leakage
**Search for:** Feature importance computed on test data, global normalization, labels using future outcomes.
```bash
grep -rn "shap\|SHAP\|feature_importance" python/ src/ --include="*.py" 2>/dev/null | head -10
grep -rn "StandardScaler\|MinMaxScaler\|normalize" python/ src/ --include="*.py" 2>/dev/null | head -10
grep -rn "shift(-\|\.shift(" python/ src/ --include="*.py" 2>/dev/null | head -10
```
**Classify:** CRITICAL if explanation or importance scores are computed on held-out data before the split. HIGH if global normalization is used instead of a time-safe or partition-safe approach. MEDIUM if shift() could access future records.

### Dimension 3.2: Training-Serving Skew
**Search for:** Different feature computation paths in training vs live inference.
```bash
# Adapt file paths to your project's training and serving pipeline files:
diff <(grep -oP "def (compute|build|calc)_\w+" python/features/pipeline.py 2>/dev/null | sort) \
     <(grep -oP "def (compute|build|calc)_\w+" python/features/serving.py 2>/dev/null | sort)
grep -rn "SCHEMA_VERSION\|schema_version" python/ src/ --include="*.py" 2>/dev/null | head -5
grep -rn "FEATURE_COLUMNS\|BASE_FEATURE\|INPUT_SCHEMA" python/ src/ --include="*.py" 2>/dev/null | head -10
```
**Classify:** CRITICAL if training pipeline and serving pipeline define different features. HIGH if schema version not checked at inference. MEDIUM if minor ordering differences.

### Dimension 3.3: Concept/Data Drift Detection
**Search for:** Whether drift detection is active, baseline frozen, thresholds calibrated.
```bash
grep -rn "check.*drift\|drift.*check\|psi\|PSI" python/ --include="*.py" | head -15
grep -rn "drift_baseline\|_baseline\|set_reference" python/ --include="*.py" | head -10
grep -rn "0\.1\|0\.25" python/common/monitor.py | head -5
```
**Classify:** HIGH if drift detection exists but is never called in production. MEDIUM if baseline frozen at startup. LOW if thresholds are hardcoded but reasonable.

### Dimension 3.4: Cost-Model Correctness
**Search for:** Cost, impact, or latency-model calculations in simulation, replay, or benchmark code.
```bash
grep -rn "latency_cost\|retry_cost\|unit_cost\|impact\|penalty\|fee\|cost_model" python/ src/ --include="*.py" 2>/dev/null | head -15
grep -rn "price_step\|cost_per_call\|cost_per_unit\|resource_unit\|budget_per_job" python/ src/ --include="*.py" 2>/dev/null | head -10
```
**Classify:** HIGH if a core cost or impact component is calculated incorrectly, hardcoded, or impossible. MEDIUM if the impact model is missing. LOW if the model is simplified but explicit.

### Dimension 3.5: Feedback Loop Analysis
**Search for:** Online learning training on own predictions, stale feedback, recursive bias.
```bash
grep -rn "update_model\|train_on\|online.*learn\|incremental" python/ src/ --include="*.py" 2>/dev/null | head -10
grep -rn "feedback\|pending.*event\|action.*complete\|job.*complete" python/ src/ --include="*.py" 2>/dev/null | head -10
grep -rn "buffer\|replay\|experience" python/ src/ --include="*.py" 2>/dev/null | head -10
```
**Classify:** HIGH if model trains on feedback from own predictions without freshness check. MEDIUM if replay buffer mixes regimes. LOW if online learning has rollback.

### Dimension 3.6: Silent Pipeline Breaks
**Search for:** Missing schema validation, null-rate monitoring, feature range checks at ingest.
```bash
grep -rn "validate\|schema\|assert.*column\|required_columns" python/features/ --include="*.py" | head -10
grep -rn "isnull\|isna\|dropna\|fillna" python/features/ --include="*.py" | head -15
grep -rn "\.dtypes\|astype" python/features/ --include="*.py" | head -10
```
**Classify:** HIGH if no validation at pipeline entry. MEDIUM if validation exists but uses fillna(0) for missing data. LOW if validation is comprehensive.

### Dimension 3.7: Model Rollback + Registry
**Search for:** Model version tracking, rollback mechanism, artifact registry, feature-schema-to-model mapping.
```bash
grep -rn "artifact_registry\|registry\|register_artifact\|register_version" python/ src/ --include="*.py" 2>/dev/null | head -10
grep -rn "rollback\|revert\|previous.*model" python/ src/ --include="*.py" 2>/dev/null | head -10
grep -rn "feature_names\|feature_schema\|input_schema" python/ src/ --include="*.py" 2>/dev/null | head -10
```
**Classify:** HIGH if no version tracking exists. MEDIUM if tracking exists but rollback untested. LOW if registry + rollback both implemented.

### Dimension 3.8: Hardcoded Assumptions
**Search for:** Feature lists, category sets, value ranges hardcoded in source instead of config.
```bash
grep -rn "FEATURE_COLUMNS\|BASE_FEATURE\|DEFAULT_FEATURES" python/ --include="*.py" | head -10
grep -rn "MODE_NAMES\|ROLE_NAMES\|QUEUE_NAMES\|FEATURE_FLAGS\|SCHEMA_KEYS" python/ --include="*.py" | head -10
grep -rn "0\.1\|0\.25\|0\.5\|0\.75" python/ --include="*.py" | head -15
```
**Classify:** MEDIUM for all hardcoded assumptions. Note which ones change frequently vs rarely.

### Dimension 3.9: Business Logic Invariants
**Search for:** Operations that bypass validation, missing trust boundaries, feature misuse potential.
```bash
# Functions that modify state without validation
grep -rn "def.*update\|def.*delete\|def.*create\|def.*rollout\|def.*execute\|def.*publish" python/ --include="*.py" | head -20
# Check for authorization/permission checks near state-changing operations
grep -rn "def.*update\|def.*rollout\|def.*publish" python/ --include="*.py" -A5 | grep -v "if.*auth\|if.*permission\|if.*allowed\|if.*valid" | head -15
# Trust boundaries: are there cross-module calls without validation?
grep -rn "from.*import\|import " python/ --include="*.py" | grep "execute\|rollout\|publish\|delete\|write" | head -10
```
**Classify:** CRITICAL if state-changing operation has no validation gate. HIGH if validation exists but can be bypassed. MEDIUM if trust boundary is implicit (not enforced in code).
