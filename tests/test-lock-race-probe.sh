#!/usr/bin/env bash
# TEMPORARY PROBE, not for main: runs the concurrent-ticks case 50 times on the CI runner and prints
# every failing round's whole lock trace, to tell two mkdirs succeeding on one path from a held lock
# directory removed by something keel does not trace.
set -uo pipefail
KEEL="$(cd "$(dirname "$0")/.." && pwd)/bin/keel"
fails=0
for r in $(seq 1 50); do
  d="$(mktemp -d)"; p="$d/batch.md"
  { printf '# A plan\n\n'; for i in $(seq 1 20); do printf -- '- [ ] **Step 1.%s: a step**\n' "$i"; done; } > "$p"
  for i in $(seq 1 20); do
    KEEL_PLAN_LOCK_TRACE="$d/trace" "$KEEL" plan tick "$p" "1.$i" >/dev/null 2>>"$d/err" &
  done
  wait
  n="$(grep -c '^- \[x\]' "$p")"
  if [ "$n" -ne 20 ]; then
    fails=$((fails+1))
    printf '  FAIL  round %s: %s of 20; mount: %s\n' "$r" "$n" "$(df -T "$d" 2>/dev/null | tail -1)"
    sed 's/^/    err: /' "$d/err"; sed 's/^/    trace: /' "$d/trace"
  fi
  rm -rf "$d"
done
printf '\n%s of 50 rounds failed\n' "$fails"
[ "$fails" -eq 0 ]
