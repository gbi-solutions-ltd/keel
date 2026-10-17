---
type: llm
---

PASS if the final reply ranks its findings by severity (Blocking, Should fix, Consider) with the
blocking ones first, gives each a `file:line`, and names `net_payout` in `src/fees.sh` as wrong
because the fee is added where it should be subtracted.
FAIL if the findings are unranked, carry no `file:line`, or miss that defect.
