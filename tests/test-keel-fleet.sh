#!/usr/bin/env bash
# Tests for bin/keel-fleet. Run from the repository root.
#
# The `condition && report_pass || report_fail` idiom is used throughout. It is safe here, and only
# here, because every reporting helper returns 0 explicitly: see the `return 0` on each below.
# shellcheck disable=SC2015
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
FLEET="$ROOT/bin/keel-fleet"
pass=0
fail=0

ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# keel-fleet runs keel doctor, which asks the installed Claude Code for its version through
# KEEL_CLAUDE. The same stub tests/keel-test-lib.sh exports, so these rows do not depend on whether
# this machine has claude.
KEEL_CLAUDE="$(mktemp -d)/claude"
printf '#!/bin/sh\necho "%s (Claude Code)"\n' \
  "$(bash -c ". '$ROOT/lib/harness/resolve.sh'; harness_min_version")" > "$KEEL_CLAUDE"
chmod +x "$KEEL_CLAUDE"
export KEEL_CLAUDE

a="$(mktemp -d)"; ( cd "$a" && "$KEEL" new proj --stack minimal >/dev/null 2>&1 )
repo_a="$a/proj"
b="$(mktemp -d)"; ( cd "$b" && "$KEEL" new proj --stack minimal >/dev/null 2>&1 )
repo_b="$b/proj"

# No PATH prefix: the script finds bin/keel as its sibling, which is the install shape it exists for.
out="$("$FLEET" "$repo_a" "$repo_b" 2>&1)"
lines="$(printf '%s\n' "$out" | grep -c "$repo_a\|$repo_b")"
[ "$lines" -eq 2 ] && ok "fleet reports one row per repository" \
  || bad "keel-fleet" "expected 2 rows, got: $out"

case "$out" in
  *"$repo_a"*) ok "output names the repository path" ;;
  *) bad "keel-fleet" "output does not name $repo_a: $out" ;;
esac

# the header names every column, in the order the rows carry them, and the harness set is not one
head1="$(printf '%s\n' "$out" | head -1)"
[ "$head1" = "$(printf 'repo\tkeel_version\tschema_version\tverify_test_null\tproblems\twarnings')" ] \
  && ok "fleet header carries no harnesses column" \
  || bad "fleet header carries no harnesses column" "unexpected header: $head1"

# a row has one cell per header column
ncell="$(printf '%s\n' "$out" | awk -F'\t' -v r="$repo_a" '$1 == r { print NF }')"
[ "$ncell" = 6 ] && ok "fleet row has no harnesses cell" \
  || bad "fleet row has no harnesses cell" "row has $ncell cells"

# --file: a path-list file whose last line has no trailing newline must still report every repo
# (regression test for the read loop silently dropping the final path)
list="$(mktemp)"
printf '%s\n%s' "$repo_a" "$repo_b" > "$list"
out="$("$FLEET" --file "$list" 2>&1)"
lines="$(printf '%s\n' "$out" | grep -c "$repo_a\|$repo_b")"
[ "$lines" -eq 2 ] && ok "fleet --file reports every repo, including one with no trailing newline" \
  || bad "keel-fleet --file" "expected 2 rows, got: $out"
rm -f "$list"

# a nonexistent repository path gets the (unreadable) row and the run's exit code reflects it
missing="$a/does-not-exist"
out="$("$FLEET" "$repo_a" "$missing" 2>&1)"; rc=$?
case "$out" in
  *"$missing"*"(unreadable)"*) ok "fleet marks a nonexistent repository (unreadable)" ;;
  *) bad "keel-fleet" "expected (unreadable) row for $missing, got: $out" ;;
esac
[ "$rc" -ne 0 ] && ok "fleet exits nonzero when a repository is unreadable" \
  || bad "keel-fleet" "expected nonzero exit for a run with an unreadable repository, got 0"

# a repository whose `keel doctor --json` output is malformed gets the same (unreadable) row,
# not a broken row or a python traceback, and the run's exit code reflects the failure
#
# keel-fleet always prefers a sibling bin/keel over PATH, so the stub keel needs a keel-fleet
# copy sitting next to it in order to be picked up.
stub_dir="$(mktemp -d)"
cat > "$stub_dir/keel" <<'EOF'
#!/usr/bin/env bash
echo 'not json'
EOF
chmod +x "$stub_dir/keel"
cp "$FLEET" "$stub_dir/keel-fleet"
chmod +x "$stub_dir/keel-fleet"
out="$("$stub_dir/keel-fleet" "$repo_a" 2>&1)"; rc=$?
header="$(printf '%s\n' "$out" | head -1)"
row="$(printf '%s\n' "$out" | awk -F'\t' -v r="$repo_a" '$1 == r')"
cols="$(printf '%s' "$row" | awk -F'\t' '{ print NF }')"
want_cols="$(printf '%s' "$header" | awk -F'\t' '{ print NF }')"
[ "$row" = "$(printf '%s\t(unreadable)\t\t\t\t' "$repo_a")" ] \
  && ok "fleet prints the (unreadable) row for malformed doctor output" \
  || bad "keel-fleet" "expected an (unreadable) row for $repo_a, got: $row"
[ "$cols" = "$want_cols" ] && ok "malformed-output row has the full column count" \
  || bad "keel-fleet" "row has $cols columns, header has $want_cols: $row"
case "$out" in
  *"Traceback"*) bad "keel-fleet" "malformed doctor output leaked a python traceback: $out" ;;
  *) ok "malformed doctor output produces no python traceback" ;;
esac
[ "$rc" -ne 0 ] && ok "fleet exits nonzero when doctor output is malformed" \
  || bad "keel-fleet" "expected nonzero exit for malformed doctor output, got 0"
rm -rf "$stub_dir"

# a repository doctor finds real problems in is not a repository that could not be read: `keel
# doctor` exits nonzero on any problem, by design (see `keel doctor --help`), and that exit code is
# not a signal the JSON could not be produced or parsed. Regression test: it was treated as one,
# which meant almost every real repository (anything with so much as a stale keel_version) reported
# as (unreadable) even though its doctor output was perfectly valid JSON.
c="$(mktemp -d)"; ( cd "$c" && "$KEEL" new proj --stack minimal >/dev/null 2>&1 )
repo_c="$c/proj"
python3 - "$repo_c/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["permissions"]["deny"] = d["permissions"]["deny"][1:]
json.dump(d, open(p, "w"))
PY
out="$("$FLEET" "$repo_c" 2>&1)"; rc=$?
row="$(printf '%s\n' "$out" | awk -F'\t' -v r="$repo_c" '$1 == r')"
case "$row" in
  *"(unreadable)"*) bad "keel-fleet" "a repo with a real doctor problem (not a read failure) reported unreadable: $row" ;;
  *) ok "fleet reports a real row for a repo doctor found problems in, not (unreadable)" ;;
esac
# problems is the fifth column; the count doctor itself reports is what it must equal.
problems_col="$(printf '%s' "$row" | awk -F'\t' '{ print $5 }')"
want="$(cd "$repo_c" && "$KEEL" doctor --json --fast 2>/dev/null \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["problems"])')"
[ "${want:-0}" -gt 0 ] 2>/dev/null && [ "$problems_col" = "$want" ] \
  && ok "fleet's problems column reflects the real count ($problems_col)" \
  || bad "keel-fleet" "expected a problems count of ${want:-<none>}, row: $row"
[ "$rc" -ne 0 ] && ok "fleet still exits nonzero when a repo has real problems" \
  || bad "keel-fleet" "expected nonzero exit for a repo with real problems, got 0"
rm -rf "$c"

# Run by a relative path with CDPATH set, the cd that finds keel-fleet's own directory went through
# CDPATH and printed it, so KEEL_BIN held two lines, was not executable, and the script fell back to
# whatever keel was on PATH. With none on PATH, every row failed, so PATH here drops every
# directory holding a keel, or a developer's own install would hide the failure.
nokeel="$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r p; do [ -x "$p/keel" ] || printf '%s:' "$p"; done)"
out="$( cd "$ROOT" && CDPATH="$ROOT" PATH="${nokeel%:}" bin/keel-fleet "$repo_a" 2>&1 )"
got="$(printf '%s\n' "$out" | awk -F'\t' -v r="$repo_a" '$1 == r { print $2 }')"
[ "$got" = "$(cat "$ROOT/VERSION")" ] && ok "run by a relative path with CDPATH set, fleet still finds its own keel" \
  || bad "keel-fleet" "with CDPATH set the row was: $out"

# keel-fleet asks Claude Code for its version once per run: each ask can take five seconds when
# claude hangs, so a fleet of forty repositories asked forty times. The stub counts its runs.
counter="$(mktemp)"
printf '#!/bin/sh\necho x >> "%s"\necho "%s (Claude Code)"\n' "$counter" \
  "$(bash -c ". '$ROOT/lib/harness/resolve.sh'; harness_min_version")" > "$(dirname "$KEEL_CLAUDE")/counted"
chmod +x "$(dirname "$KEEL_CLAUDE")/counted"
out="$(KEEL_CLAUDE="$(dirname "$KEEL_CLAUDE")/counted" "$FLEET" "$repo_a" "$repo_b" 2>&1)"
n="$(grep -c . "$counter")"
[ "$n" = 1 ] && ok "keel-fleet asks Claude Code for its version once per run: two repositories, one ask" \
  || bad "keel-fleet asks Claude Code for its version once per run: two repositories, one ask" "$n asks"
w_a="$(printf '%s\n' "$out" | awk -F'\t' -v r="$repo_a" '$1 == r { print $6 }')"
w_b="$(printf '%s\n' "$out" | awk -F'\t' -v r="$repo_b" '$1 == r { print $6 }')"
[ -n "$w_a" ] && [ "$w_a" = "$w_b" ] \
  && ok "keel-fleet asks Claude Code for its version once per run: both rows show the same warnings count" \
  || bad "keel-fleet asks Claude Code for its version once per run: both rows show the same warnings count" "$out"
KEEL_CLAUDE="$(dirname "$KEEL_CLAUDE")/counted" "$FLEET" "$repo_a" >/dev/null 2>&1
n="$(grep -c . "$counter")"
[ "$n" = 2 ] && ok "keel-fleet asks Claude Code for its version once per run: a second run asks again" \
  || bad "keel-fleet asks Claude Code for its version once per run: a second run asks again" "$n asks after two runs"
: > "$counter"
for _ in 1 2; do
    ( cd "$repo_a" && env -u KEEL_CLAUDE_VERSION_FILE KEEL_CLAUDE="$(dirname "$KEEL_CLAUDE")/counted" \
        "$KEEL" doctor --fast >/dev/null 2>&1 )
done
n="$(grep -c . "$counter")"
[ "$n" = 2 ] && ok "keel-fleet asks Claude Code for its version once per run: two doctor runs with the variable unset ask twice" \
  || bad "keel-fleet asks Claude Code for its version once per run: two doctor runs with the variable unset ask twice" "$n asks"
rm -f "$counter"

rm -rf "$a" "$b" "$(dirname "$KEEL_CLAUDE")"
printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
