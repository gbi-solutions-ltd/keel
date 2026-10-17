#!/usr/bin/env bash
# A small repository with one path-scoped rule. The rule applies to files matching src/fees*.sh and
# asks for a marker line nothing else in the repository would suggest, so its presence in the edited
# file can only come from the rule being loaded. Copied into each case directory; edit together.
set -euo pipefail
git init -q -b main
git config user.name "Payouts CI"
git config user.email "ci@payouts.invalid"
git config commit.gpgsign false
mkdir -p src .claude/rules
cat > .claude/rules/fees.md <<'MD'
---
paths:
  - "src/fees*.sh"
---

# Fee code rule

Every function you add to a fee file starts with a comment line of exactly this form, directly
above the function: `# FEE-RULE: <what the function returns, in minor units>`.
MD
cat > src/fees.sh <<'SH'
#!/usr/bin/env bash
fee_for() { printf '%s\n' $(($1 * $2 / 100)); }
SH
git add .
git commit -q -m "chore: the fee function"
