#!/usr/bin/env bash
# The mockup engine (lib/mockup-engine): keel's command for it, and the engine's own suite.
#
# The engine is Node and a browser; keel's suite needs nothing installed. So, as the lint step does
# without shellcheck, a machine with no usable Node, no installed engine packages or no launchable
# browser prints SKIP with the reason and passes. In CI the engine job sets
# KEEL_REQUIRE_MOCKUP_ENGINE=1, and the same absence fails: a suite that skipped there would read
# as an engine that passed.
#
# The engine's suite runs with a bounded concurrency (KEEL_ENGINE_JOBS, default 2) because it runs
# inside run-tests.sh's own parallel jobs, and its browser tests time out on an oversubscribed
# machine: a timing failure is not the engine's.
# The `condition && ok || bad` idiom is safe here, as in tests/validate-skills.sh: ok and bad both
# return 0 explicitly, so the third part runs only when the condition fails.
# shellcheck disable=SC2015
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
ENGINE="$ROOT/lib/mockup-engine"
pass=0
fail=0

ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }
done_() { printf '\n%s passed, %s failed\n' "$pass" "$fail"; [ "$fail" -eq 0 ] || exit 1; exit 0; }
unavailable() {   # unavailable <reason>: SKIP here, FAIL where the engine is required
    if [ "${KEEL_REQUIRE_MOCKUP_ENGINE:-}" = 1 ]; then bad "the engine can run" "$1"; done_; fi
    printf 'SKIP  test-mockup-engine.sh, the engine suite: %s. CI runs it.\n' "$1"
    done_
}

out="$("$KEEL" mockup-engine path 2>&1)"
[ "$out" = "$ENGINE" ] && ok "keel mockup-engine path prints the engine's folder" \
  || bad "keel mockup-engine path" "printed '$out', not '$ENGINE'"
"$KEEL" mockup-engine nonsense >/dev/null 2>&1 && bad "an unknown mockup-engine command" "exited 0" \
  || ok "an unknown mockup-engine command is refused"
out="$(cd "$ROOT" && "$KEEL" --help 2>&1)"
grep -q 'mockup-engine path|check' <<<"$out" && ok "keel --help names mockup-engine" \
  || bad "keel --help" "does not name mockup-engine"

command -v node >/dev/null 2>&1 || unavailable "node is absent"
pre="$(node "$ENGINE/scripts/toolchain.mjs" 2>&1)" || unavailable "$(printf '%s' "$pre" | head -3 | tr '\n' ' ')"
ok "toolchain.mjs: $(printf '%s' "$pre" | head -1 | sed 's/^toolchain: //' | cut -c1-90)"
launch="$(cd "$ENGINE/scripts" && node --input-type=module -e "import { chromium } from 'playwright'; const b = await chromium.launch(); await b.close();" 2>&1)" \
  || unavailable "the pinned browser does not launch (node_modules/.bin/playwright install chromium-headless-shell in lib/mockup-engine/scripts): $(printf '%s' "$launch" | grep -m1 -i error | cut -c1-120)"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
( cd "$ENGINE/scripts" && node --test --test-concurrency="${KEEL_ENGINE_JOBS:-2}" "test/*.test.mjs" ) >"$log" 2>&1
status=$?
count() { sed -n "s/^ℹ $1 \([0-9][0-9]*\)$/\1/p" "$log" | tail -1; }
tests="$(count tests)"; passed="$(count pass)"; failed="$(count fail)"; skipped="$(count skipped)"
if [ "$status" -eq 0 ] && [ -n "$tests" ] && [ "${failed:-1}" -eq 0 ] && [ "${skipped:-1}" -eq 0 ] && [ "$tests" -gt 0 ]; then
    ok "the engine suite: $passed of $tests pass, none skipped"
else
    bad "the engine suite" "exit $status, ${tests:-?} tests, ${passed:-?} pass, ${failed:-?} fail, ${skipped:-?} skipped; first failures: $(grep -E '^✖' "$log" | head -5 | tr '\n' ' ')"
fi
done_
