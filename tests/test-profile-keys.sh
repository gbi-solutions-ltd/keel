#!/usr/bin/env bash
# Tests for tests/generate-profile-keys.sh, which produces docs/profile-keys.md.
#
# The generator is the only thing standing between the schema and a reference page that would
# otherwise be written by hand and go stale. What is asserted here is that it covers every declared
# key, omits what the schema does not declare, and produces the same bytes twice.
#
# Run from the repository root.
#
# The `condition && ok ... || bad ...` idiom is used throughout, as it is in the other suites.
# It is safe because both reporting helpers return 0 explicitly: see the `return 0` on each.
# shellcheck disable=SC2015
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$ROOT/tests/generate-profile-keys.sh"
pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

command -v python3 >/dev/null 2>&1 || { printf 'SKIP  python3 absent\n'; exit 0; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

bash "$GEN" > "$work/a.md" 2>"$work/err.txt"
rc=$?
[ "$rc" -eq 0 ] && ok "the generator exits 0" || bad "generator" "rc=$rc: $(head -3 "$work/err.txt")"

# Every declared leaf key gets a row. A generator that silently skips a key produces a reference
# that is wrong in the one way nobody checks: by omission.
missing="$(SCHEMA="$ROOT/templates/profile.schema.json" PAGE="$work/a.md" python3 -c "
import json, os, re
d = json.load(open(os.environ['SCHEMA']))
def declared(node, p=''):
    out = []
    for k, v in (node.get('properties') or {}).items():
        path = f'{p}.{k}' if p else k
        if isinstance(v, dict) and v.get('properties'): out += declared(v, path)
        else: out.append(path)
    return out
page = open(os.environ['PAGE']).read()
rows = set(re.findall(r'^\| \`([^\`]+)\` \|', page, re.M))
print(' '.join(sorted(set(declared(d)) - rows)))
")"
[ -z "$missing" ] && ok "every declared key has a row" \
  || bad "coverage" "no row for: $missing"

# artifacts._note is written by keel init and not declared by the schema. It is a note to the
# reader rather than a key anyone sets, and declaring it would cost a SCHEMA_VERSION bump.
grep -qF 'artifacts._note' "$work/a.md" \
  && bad "omission" "artifacts._note appears; the schema does not declare it and FR-12 omits it" \
  || ok "a key the schema does not declare is omitted"

# Determinism is what makes the drift rule in validate-skills usable. A generator that varies
# produces a rule that fails at random, and a rule that fails at random gets disabled.
bash "$GEN" > "$work/b.md" 2>/dev/null
cmp -s "$work/a.md" "$work/b.md" && ok "two runs produce identical bytes" \
  || bad "determinism" "the generator is not reproducible"

# The check has to run where nobody is watching, so it cannot depend on a key existing.
env -u ANTHROPIC_API_KEY bash "$GEN" > "$work/c.md" 2>/dev/null
cmp -s "$work/a.md" "$work/c.md" && ok "the generator needs no API key" \
  || bad "offline" "output differed with ANTHROPIC_API_KEY unset"

# The pattern below names the things it is looking for, so the supply chain scanner sees its own
# vocabulary in this file and reports the line. Suppressed rather than obfuscated: building the
# pattern out of fragments to keep the scanner quiet is the exact instinct that scanner exists to
# catch. The marker has to sit on the line holding the tokens, which is why the pattern is a
# variable rather than an argument on a continued line.
net_pattern='curl|wget|urllib|requests|socket'  # supply-chain-scan: allow the pattern this assertion searches for
if grep -qE "$net_pattern" "$GEN"; then
    bad "offline" "the generator reaches the network"
else
    ok "the generator makes no network call"
fi

# The page is committed, not generated on demand, so a reader browsing the repository finds it.
[ -f "$ROOT/docs/profile-keys.md" ] && ok "docs/profile-keys.md is committed" \
  || bad "page" "the reference page is not committed"

# And it says what it is, so nobody edits it by hand and loses the edit on the next regeneration.
grep -qF 'generate-profile-keys.sh' "$ROOT/docs/profile-keys.md" 2>/dev/null \
  && ok "the page names the script that produces it" \
  || bad "page" "the page does not say it is generated"

# The gap this whole change exists to close is discovery. A page nothing links to repeats it.
grep -qF 'docs/profile-keys.md' "$ROOT/README.md" \
  && ok "the README links the reference" \
  || bad "discovery" "README.md does not link docs/profile-keys.md"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
