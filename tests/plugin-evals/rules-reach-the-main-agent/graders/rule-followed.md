---
type: regex
pattern: '# FEE-RULE: .+\n\s*(function\s+)?fee_cap'
target:
  source: file
  path: src/fees.sh
---

The added function carries the marker comment the path-scoped rule asks for, directly above it.
