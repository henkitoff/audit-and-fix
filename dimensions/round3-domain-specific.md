# Round 3 — Domain-Specific (Trading/ML)

### Dimension 3.1: Look-Ahead Bias / Temporal Leakage
**Search for:** Feature importance computed on test data, global normalization, labels using future prices.
```bash
grep -rn "shap\|SHAP\|feature_importance" python/training/ --include="*.py" | head -10
grep -rn "StandardScaler\|MinMaxScaler\|normalize" python/features/ --include="*.py" | head -10
grep -rn "shift(-\|\.shift(" python/features/ --include="*.py" | head -10
```
**Classify:** CRITICAL if SHAP computed on test data before split. HIGH if global normalization instead of rolling. MEDIUM if shift() could access future bars.

### Dimension 3.2: Training-Serving Skew
**Search for:** Different feature computation paths in training vs live inference.
```bash
# Adapt file paths to your project's training and inference pipeline files:
diff <(grep -oP "def (compute|build|calc)_\w+" python/features/pipeline.py | sort) \
     <(grep -oP "def (compute|build|calc)_\w+" python/features/serving.py | sort) 2>/dev/null
grep -rn "SCHEMA_VERSION\|schema_version" python/ --include="*.py" | head -5
grep -rn "FEATURE_COLUMNS\|BASE_FEATURE" python/features/ --include="*.py" | head -10
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
**Search for:** Spread/slippage/commission calculations in backtest.
```bash
grep -rn "spread\|slippage\|commission\|swap" python/backtest/ --include="*.py" | head -15
grep -rn "pip_size\|pip_value\|tick_size\|tick_value" python/backtest/ --include="*.py" | head -10
```
**Classify:** HIGH if spread calculated incorrectly (negative, zero, or hardcoded). MEDIUM if slippage model missing. LOW if commission model simplified.

### Dimension 3.5: Feedback Loop Analysis
**Search for:** Online learning training on own predictions, stale feedback, recursive bias.
```bash
grep -rn "update_model\|train_on\|online.*learn\|incremental" python/online/ --include="*.py" | head -10
grep -rn "feedback\|pending.*signal\|trade.*close" python/online/ --include="*.py" | head -10
grep -rn "buffer\|replay\|experience" python/online/ --include="*.py" | head -10
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
**Search for:** Model version tracking, rollback mechanism, feature-schema-to-model mapping.
```bash
grep -rn "model_registry\|ModelRegistry\|register_model" python/ --include="*.py" | head -10
grep -rn "rollback\|revert\|previous.*model" python/ --include="*.py" | head -10
grep -rn "feature_names\|feature_schema" python/strategies/ai/ --include="*.py" | head -10
```
**Classify:** HIGH if no version tracking exists. MEDIUM if tracking exists but rollback untested. LOW if registry + rollback both implemented.

### Dimension 3.8: Hardcoded Assumptions
**Search for:** Feature lists, category sets, value ranges hardcoded in source instead of config.
```bash
grep -rn "FEATURE_COLUMNS\|BASE_FEATURE\|DEFAULT_FEATURES" python/ --include="*.py" | head -10
grep -rn "SESSION_NAMES\|MODEL_TYPES\|QUEUE_NAMES" python/ --include="*.py" | head -10
grep -rn "0\.53\|0\.45\|0\.35\|0\.60" python/ --include="*.py" | head -15
```
**Classify:** MEDIUM for all hardcoded assumptions. Note which ones change frequently vs rarely.

### Dimension 3.9: Business Logic Invariants
**Search for:** Operations that bypass validation, missing trust boundaries, feature misuse potential.
```bash
# Functions that modify state without validation
grep -rn "def.*update\|def.*delete\|def.*create\|def.*promote\|def.*execute" python/ --include="*.py" | head -20
# Check for authorization/permission checks near state-changing operations
grep -rn "def.*update\|def.*promote" python/ --include="*.py" -A5 | grep -v "if.*auth\|if.*permission\|if.*allowed\|if.*valid" | head -15
# Trust boundaries: are there cross-module calls without validation?
grep -rn "from.*import\|import " python/ --include="*.py" | grep "execute\|promote\|delete\|write" | head -10
```
**Classify:** CRITICAL if state-changing operation has no validation gate. HIGH if validation exists but can be bypassed. MEDIUM if trust boundary is implicit (not enforced in code).
