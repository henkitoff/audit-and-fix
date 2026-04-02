# Custom Dimensions

Add project-specific exploration dimensions here. The audit-and-fix skill will include these in a Custom Round (appended after the standard rounds).

To use: Copy this template to your project as `audit-custom-dimensions.md` and fill in your dimensions.

## Template

### Custom Dimension: [Name]
**Search for:** [What to look for]
```bash
[Your grep/find commands]
```
**Classify:** CRITICAL if [condition]. HIGH if [condition]. MEDIUM otherwise.

---

## Examples

### Custom: MQL5 EA Safety
**Search for:** MQL5 Expert Advisors without stop-loss validation.
```bash
grep -rn "OrderSend\|Trade.Buy\|Trade.Sell" mql5/ --include="*.mq5" | grep -v "sl\|StopLoss\|stop_loss" | head -10
```
**Classify:** CRITICAL if order without SL. HIGH if SL is hardcoded. MEDIUM if SL from config.

### Custom: Redis Key Expiry
**Search for:** Redis keys set without TTL (grow forever).
```bash
grep -rn "\.set(\|\.hset(\|\.lpush(" python/ --include="*.py" | grep -v "ex=\|px=\|expire" | head -15
```
**Classify:** HIGH if no TTL on frequently-written keys. MEDIUM if TTL exists but >24h.
