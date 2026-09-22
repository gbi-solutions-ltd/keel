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

# the header names every column, harnesses included, in the order the rows carry them
head1="$(printf '%s\n' "$out" | head -1)"
[ "$head1" = "$(printf 'repo\tkeel_version\tschema_version\tharnesses\tverify_test_null\tproblems\twarnings')" ] \
  && ok "fleet header carries the harnesses column" \
  || bad "keel-fleet" "unexpected header: $head1"

# the harnesses cell is the profile's list, comma-joined
want="$(python3 -c "import json; print(','.join(json.load(open('$repo_a/.keel/profile.json')).get('harnesses', [])))")"
got="$(printf '%s\n' "$out" | awk -F'\t' -v r="$repo_a" '$1 == r { print $4 }')"
[ "$got" = "$want" ] && ok "fleet harnesses cell matches the profile ($got)" \
  || bad "keel-fleet" "harnesses cell is '$got', profile says '$want'"

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
[ "$row" = "$(printf '%s\t(unreadable)\t\t\t\t\t' "$repo_a")" ] \
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
problems_col="$(printf '%s' "$row" | awk -F'\t' '{ print $6 }')"
[ "${problems_col:-0}" -gt 0 ] 2>/dev/null && ok "fleet's problems column reflects the real count ($problems_col)" \
  || bad "keel-fleet" "expected a positive problems count, row: $row"
[ "$rc" -ne 0 ] && ok "fleet still exits nonzero when a repo has real problems" \
  || bad "keel-fleet" "expected nonzero exit for a repo with real problems, got 0"
rm -rf "$c"

rm -rf "$a" "$b"
printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
