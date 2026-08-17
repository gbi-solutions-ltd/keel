#!/usr/bin/env bash
# Countable claims in README.md must match the tree.
#
# Not prose. A test that asserts on wording fails whenever somebody improves a sentence, which
# teaches people to ignore checks, and CONTRIBUTING.md says the too-strict failure is the
# unrecoverable one. A count is different: one right answer, derivable from the tree, and the
# class of claim that goes stale in total silence.
#
# Every assertion here was wrong when this file was written. README said four eval scenarios when
# there were six, four structural scan rules when there were five, and "Nine decisions: 5 resolved,
# 4 open" when all eleven were resolved. Nothing had noticed for months.
#
# Usage: tests/test-doc-claims.sh   (from the repository root)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# claim <name> <actual> <phrase containing exactly one [0-9]+>
# Matches the phrase in README.md, pulls the number out of what matched, and compares.
#
# Two numbers in one phrase would make the first one win silently, so each phrase below carries
# exactly one. And the phrase is matched with grep -o rather than captured with sed: a leading `.*`
# in an ERE is greedy, so `.*([0-9]+) skills built` captures `4` out of `24 skills built` and this
# whole file would have asserted the wrong thing while looking correct.
claim() {
    local name="$1" actual="$2" phrase="$3" matched claimed
    matched="$(grep -oE "$phrase" README.md | head -1)"
    if [ -z "$matched" ]; then
        bad "$name" "no claim in README.md matched /$phrase/. A number a check cannot read is the same problem as a wrong one: reword the sentence to carry a digit, or delete this case if the claim is gone"
        return 0
    fi
    claimed="$(printf '%s' "$matched" | grep -oE '[0-9]+' | head -1)"
    if [ "$claimed" = "$actual" ]; then
        ok "$name ($actual)"
    else
        bad "$name" "README says '$matched', the tree says $actual"
    fi
}

claim "skill count" \
      "$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" \
      '[0-9]+ skills built'

claim "eval scenario count" \
      "$(find tests/evals/scenarios -name '*.md' | wc -l | tr -d ' ')" \
      '[0-9]+ scenarios'

claim "supply chain pattern rules" \
      "$(tests/supply-chain-scan.sh --list-rules | grep -vc structural)" \
      '[0-9]+ pattern rules'

claim "supply chain structural rules" \
      "$(tests/supply-chain-scan.sh --list-rules | grep -c structural)" \
      'and [0-9]+ structural'

claim "open decision count" \
      "$(grep -cE '^## [0-9]+\.' docs/07-open-decisions.md)" \
      'of [0-9]+ resolved'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
