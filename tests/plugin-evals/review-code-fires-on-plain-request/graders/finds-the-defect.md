---
type: llm
---

The branch's `net_payout` adds the fee to the amount where it should subtract it, and its only test
checks `fee_for`, so the suite stays green.

PASS if the review names `net_payout` in `src/fees.sh` as wrong because the fee is added instead of
taken off, and ranks it above any comment about style or naming.
FAIL if it passes the change, reports only style or naming points, or never mentions the sign of the
fee.
