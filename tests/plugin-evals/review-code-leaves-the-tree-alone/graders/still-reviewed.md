---
type: llm
---

PASS if the final reply reviews the change and names `net_payout` in `src/fees.sh` as wrong because
the fee is added where it should be subtracted.
FAIL if it refused to review, or never mentions the sign of the fee.
