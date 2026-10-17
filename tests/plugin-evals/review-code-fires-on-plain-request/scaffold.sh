#!/usr/bin/env bash
# Seeds a case's empty workspace with a small git repository: `main` holds a payout total, and the
# branch under review adds a fee. The fee function adds the fee to the amount where it should take
# it off, and its test checks the fee alone, so the defect is real and the suite is green.
#
# `claude plugin eval` runs a case's scaffold only with --scaffold, in the empty workspace. It is
# copied into each case directory because a case may name only a script beside itself; edit the
# copies together.
set -euo pipefail

git init -q -b main
git config user.name "Payouts CI"
git config user.email "ci@payouts.invalid"
git config commit.gpgsign false

mkdir -p src tests docs .keel
cat > .keel/profile.json <<'JSON'
{
  "project": { "name": "payouts", "kind": "service" },
  "stack": { "language": "bash", "runtime": "posix-sh", "package_manager": "none" },
  "verify": { "test": "tests/run-tests.sh", "test_one": null, "lint": null, "build": null },
  "conventions": { "default_branch": "main", "protect_default_branch": true },
  "docs_root": "docs"
}
JSON
cat > docs/standards.md <<'MD'
# Standards

- A change ships with a test that fails without it.
- Money is handled in whole minor units. No floating point.
- A function does one thing and its name says what.
MD
cat > src/payouts.sh <<'SH'
#!/usr/bin/env bash
# payout_total <amount>...: the sum of the amounts, in minor units.
payout_total() {
    local total=0 a
    for a in "$@"; do total=$((total + a)); done
    printf '%s\n' "$total"
}
SH
cat > tests/run-tests.sh <<'SH'
#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
fail=0
for t in tests/test-*.sh; do
    [ -f "$t" ] || continue
    bash "$t" || fail=1
done
[ "$fail" -eq 0 ] && echo "All test files passed"
exit "$fail"
SH
cat > tests/test-payouts.sh <<'SH'
#!/usr/bin/env bash
. src/payouts.sh
[ "$(payout_total 100 250)" = "350" ] && echo "  PASS  sums amounts" || { echo "  FAIL  sums amounts"; exit 1; }
SH
chmod +x tests/run-tests.sh
git add .
git commit -q -m "chore: payout total and the test harness"

git checkout -q -b feat/payout-fee
cat > src/fees.sh <<'SH'
#!/usr/bin/env bash
# fee_for <amount> <rate_percent>: the fee in minor units, rounded down.
fee_for() { printf '%s\n' $(($1 * $2 / 100)); }

# net_payout <amount> <rate_percent>: what the merchant receives.
net_payout() {
    local fee
    fee="$(fee_for "$1" "$2")"
    printf '%s\n' $(($1 + fee))
}
SH
cat > tests/test-fees.sh <<'SH'
#!/usr/bin/env bash
. src/fees.sh
[ "$(fee_for 1000 3)" = "30" ] && echo "  PASS  fee is 3 percent" || { echo "  FAIL  fee is 3 percent"; exit 1; }
SH
git add src/fees.sh tests/test-fees.sh
git commit -q -m "feat(fees): work out the net payout after the fee"
