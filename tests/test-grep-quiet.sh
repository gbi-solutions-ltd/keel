#!/usr/bin/env bash
# The grep shim in tests/grep-quiet.sh: a `grep` function for test files that reads all of its input
# when asked to be quiet. Plan: docs/plans/2026-10-21-flake-and-batched-scenario.md, task 1.
#
# Why it exists: `producer | grep -q needle` under `set -o pipefail` is a race. grep exits at the
# first match, the producer dies of SIGPIPE on its next write, and pipefail turns that into a failed
# pipeline. The shim drops the quiet option and sends stdout to /dev/null, so grep reads to the end.
#
# What is pinned: the quiet forms it rewrites, that a big producer is not cut off, that everything
# else passes through unchanged, how option arguments are told from flags, that a file operand or a
# recursive option passes through, that the exit status is grep's own, that nothing is unbound under
# `set -u`, that the function stays out of child processes, and that every variable it names starts
# with `_gq_` (shellcheck does not scope a function's locals across the files that source it).
#
# This file loads the shim on its own `set` line, as the files that use it do.
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SHIM="$ROOT/tests/grep-quiet.sh"

# expect <name> <got> <want>: one comparison, one line of output.
expect() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "got: $2 / want: $3"; fi
  return 0
}

# rp <printf-format> <grep args...>: feed the text through a pipe, print what grep printed and then
# its status as rc=N, so one string carries both.
rp() {
  local text="$1"
  shift
  printf '%b' "$text" | grep ${1+"$@"}
  printf 'rc=%s\n' "$?"
}

# 1. Every spelling of quiet: it matches, finds nothing, and prints nothing either way.
chk_quiet() {
  local label="$1"
  shift
  expect "quiet form $label matches silently" "$(rp 'a\nb\n' "$@" b)" "rc=0"
  expect "quiet form $label misses silently" "$(rp 'a\n' "$@" zz)" "rc=1"
}
for f in -q -qE -Eq -qxF -xqF -qs --quiet --silent; do
  chk_quiet "$f" "$f"
done
chk_quiet "-E -q" -E -q

# 2. A producer bigger than a pipe is not cut off. The same loop with `command grep -q` fails on
#    nearly every run; that is timing, so this case asserts the shim and not the bare failure.
big_failures=0
n=0
while [ "$n" -lt 200 ]; do
  if ! ( set -o pipefail; seq 1 200000 | grep -q '^1$' ) 2>/dev/null; then
    big_failures=$((big_failures+1))
  fi
  n=$((n+1))
done
expect "a 200000-line producer is read to the end in 200 of 200 runs" "$big_failures" "0"

# 3. No quiet option: every argument passes through.
expect "no quiet option prints the match" "$(rp 'a\nb\n' b)" "$(printf 'b\nrc=0')"
expect "no quiet option keeps -c" "$(rp 'a\nb\n' -c .)" "$(printf '2\nrc=0')"

# 4. The argument of an option is data, not a flag.
expect "-e -q: the pattern is -q" "$(rp '-q\n' -e -q)" "$(printf -- '-q\nrc=0')"
expect "-qe -qx: q dropped, -qx is the pattern" "$(rp '-qx\n' -qe -qx)" "rc=0"
expect "-eq: the q after e is the pattern" "$(rp 'q\n' -eq)" "$(printf 'q\nrc=0')"
expect "-- ends options" "$(rp '-q\n' -- -q)" "$(printf -- '-q\nrc=0')"
expect "-q -- -q: quiet, then a pattern" "$(rp '-q\n' -q -- -q)" "rc=0"
expect "--regexp -q: the next word is the pattern" "$(rp '-q\n' --regexp -q)" \
  "$(printf -- '-q\nrc=0')"
expect "--regexp=-q carries its own argument" "$(rp '-q\n' --quiet --regexp=-q)" "rc=0"
expect "-m 1 keeps its number out of the flags" "$(rp 'a\nb\n' -m 1 -q a)" "rc=0"

# 5. A file operand or a recursive option passes through untouched.
F="$TMP/f"
printf 'x\n' > "$F"
mkdir "$TMP/d"
printf 'x\n' > "$TMP/d/g"
expect "a file operand passes through" "$(grep -q x "$F"; printf 'rc=%s' "$?")" "rc=0"
want_rc="$(command grep -q x /no/such/file "$F" 2>/dev/null; printf 'rc=%s' "$?")"
expect "a missing and a present file keep grep's own status" \
  "$(grep -q x /no/such/file "$F" 2>/dev/null; printf 'rc=%s' "$?")" "$want_rc"
expect "an operand of - is standard input" \
  "$(printf 'x\n' | grep -q x -; printf 'rc=%s' "$?")" "rc=0"
expect "-q -e x file passes through" "$(grep -q -e x "$F"; printf 'rc=%s' "$?")" "rc=0"
expect "-r passes through" "$(grep -rq x "$TMP/d"; printf 'rc=%s' "$?")" "rc=0"
expect "--recursive passes through" \
  "$(grep --recursive --quiet x "$TMP/d"; printf 'rc=%s' "$?")" "rc=0"

# 6. The status is command grep's, with standard input a file and not a pipe.
printf 'a\nb\n(\n' > "$TMP/three"
same_status() {
  local label="$1" want got
  shift
  command grep "$@" < "$TMP/three" > /dev/null 2>&1
  want=$?
  grep "$@" < "$TMP/three" > /dev/null 2>&1
  got=$?
  expect "status of grep $label equals command grep's" "$got" "$want"
}
same_status "-q a" -q a
same_status "-q zz" -q zz
same_status "-qv a" -qv a
same_status "-qc a" -qc a
same_status "-qx a" -qx a
same_status "-qE (" -qE '('
same_status "-q with no pattern" -q

# 7. Nothing is unbound under set -u, with no arguments or every argument removed.
out7="$(set -u; grep -q < /dev/null 2>&1; printf 'rc=%s' "$?")"
want7="$(set -u; command grep -q < /dev/null 2>/dev/null; printf 'rc=%s' "$?")"
case "$out7" in
  *unbound*) bad "grep -q with every argument removed" "unbound variable: $out7" ;;
  *) ok "grep -q with every argument removed names nothing unbound" ;;
esac
expect "grep -q on empty input has command grep's status" "${out7##*rc=}" "${want7##*rc=}"
out7b="$(set -u; grep < /dev/null 2>&1; printf 'rc=%s' "$?")"
want7b="$(set -u; command grep < /dev/null 2>/dev/null; printf 'rc=%s' "$?")"
case "$out7b" in
  *unbound*) bad "grep with no arguments" "unbound variable: $out7b" ;;
  *) ok "grep with no arguments names nothing unbound" ;;
esac
expect "grep with no arguments has command grep's status" "${out7b##*rc=}" "${want7b##*rc=}"

# 8. The function stays in this shell.
expect "type -t grep is a function here" "$(type -t grep)" "function"
expect "type -t grep is a file in a child" "$(bash -c 'type -t grep')" "file"
case "$(type -P grep)" in
  /*) ok "type -P grep is an absolute path" ;;
  *) bad "type -P grep is an absolute path" "got: $(type -P grep)" ;;
esac
expect "command -v grep prints the function's name" "$(command -v grep)" "grep"

# 9. Every variable the shim names starts with _gq_. shellcheck -x follows the source into every
#    test file and does not scope a function's locals, so a bare name would collide with the test's.
#    Names are collected after `local` and `local -a`, after `for` before `in`, and before `=` or
#    `+=` at the start of a statement.
shim_names() {
  awk '
    /^[ \t]*#/ { next }
    {
      n = split($0, parts, /;/)
      for (i = 1; i <= n; i++) {
        s = parts[i]
        sub(/^[ \t]+/, "", s)
        if (s ~ /^local[ \t]/) {
          sub(/^local[ \t]+(-a[ \t]+)?/, "", s)
          m = split(s, toks, /[ \t]+/)
          for (j = 1; j <= m; j++) {
            t = toks[j]
            sub(/=.*/, "", t)
            if (t != "") print t
          }
        } else if (s ~ /^for[ \t]/) {
          sub(/^for[ \t]+/, "", s)
          sub(/[ \t].*/, "", s)
          print s
        } else if (match(s, /^[A-Za-z_][A-Za-z0-9_]*\+?=/)) {
          t = substr(s, 1, RLENGTH - 1)
          sub(/\+$/, "", t)
          print t
        }
      }
    }' "$1"
}
unprefixed() {
  shim_names "$1" | awk '!/^_gq_/ && !seen[$0]++'
}
found9="$(shim_names "$SHIM" | awk 'END { print NR }')"
if [ "${found9:-0}" -ge 1 ]; then
  names9="$(unprefixed "$SHIM")"
  if [ -z "$names9" ]; then
    ok "every variable the shim names starts with _gq_ ($found9 found)"
  else
    bad "every variable the shim names starts with _gq_" "not prefixed: $names9"
  fi
else
  bad "every variable the shim names starts with _gq_" "found no names in $SHIM"
fi
{ cat "$SHIM"; printf '%s\n' 'for w in a b; do :; done'; } > "$TMP/with-w.sh"
expect "the _gq_ check names a stray for-loop variable" "$(unprefixed "$TMP/with-w.sh")" "w"

# 10. The test file's own shape, and that the runner lists it.
if [ -x "$0" ]; then
  ok "this test file is executable"
else
  bad "this test file is executable" "not +x"
fi
expect "tests/run-tests.sh lists this file on one line" \
  "$(grep -c 'tests/test-grep-quiet.sh' tests/run-tests.sh)" "1"

# 11. The shim file: a bash dialect line, and not executable, as it is only ever sourced.
expect "the shim starts with a bash shebang" \
  "$(sed -n 1p "$SHIM" 2>/dev/null)" "#!/usr/bin/env bash"
if [ -f "$SHIM" ] && [ ! -x "$SHIM" ]; then
  ok "the shim is not executable"
else
  bad "the shim is not executable" "missing or +x"
fi

# 12. The lint for quiet grep pipelines (task 2). Every line a case writes into a fixture file is
#     assembled from pieces, so none of this file's own text is a finding.

# The one quiet pipeline that is allowed. `keel` writes this line into a generated CI workflow, and
# GitHub Actions runs a `run:` step that names no `shell:` as `bash -e`, without pipefail, so the
# race cannot arise there. The allowance is this path and this fixed string and nothing wider.
LINT_G="gr""ep"
LINT_ALLOW_PATH="bin/keel"
LINT_ALLOW_TEXT="if git ls-files | ${LINT_G} -qE"

# What the rules look for, assembled from pieces. A quiet pipeline is a `|` that is not half of
# `||`, blanks, an optional `command `, a word ending in grep, option words, and a quiet option (a
# single-dash word holding q, --quiet or --silent). LINT_FOREIGN is the same with a word that the
# shim function cannot stand in for: `command grep`, `\grep`, a path ending in /grep, egrep, fgrep.
# shellcheck disable=SC2016
LINT_FORM='set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"'
LINT_PIPE="(^|[^|])\\|[[:space:]]*"
LINT_OPTS="(-[^[:space:]]+[[:space:]]+)*"
LINT_QUIET="(-[^-[:space:]]*q[^[:space:]]*|--quiet|--silent)([[:space:]]|$)"
LINT_WORD="(command[[:space:]]+)?[^[:space:]|]*${LINT_G}"
LINT_ANY="${LINT_PIPE}${LINT_WORD}[[:space:]]+${LINT_OPTS}${LINT_QUIET}"
LINT_FOREIGN="${LINT_PIPE}(command[[:space:]]+[^[:space:]|]*${LINT_G}|[^[:space:]|]+${LINT_G})"
LINT_FOREIGN="${LINT_FOREIGN}[[:space:]]+${LINT_OPTS}${LINT_QUIET}"

# lint_scan <pattern> <file>: the line numbers where the pattern matches, comment lines left out.
lint_scan() {
  grep -En "$1" "$2" 2>/dev/null | grep -Ev '^[0-9]+:[[:space:]]*#' | cut -d: -f1
  return 0
}
# lint_hits <file>: the line numbers of its quiet grep pipelines.
lint_hits() {
  lint_scan "$LINT_ANY" "$1"
  return 0
}
# lint_tag <display>: prefix each line number on standard input with the display path and a colon.
lint_tag() {
  awk -v d="$1" '{ print d ":" $0 }'
}

# Rule 1, a test file: the one-line form of task 1 comes before its first quiet pipeline.
# lint_rule1 <file> <display>
lint_rule1() {
  local hits first form
  hits="$(lint_hits "$1")"
  [ -n "$hits" ] || return 0
  first="$(printf '%s\n' "$hits" | sed -n 1p)"
  form="$(FORM="$LINT_FORM" awk '$0 == ENVIRON["FORM"] { print NR; exit }' "$1")"
  if [ -n "$form" ] && [ "$form" -lt "$first" ]; then
    return 0
  fi
  printf '%s\n' "$hits" | lint_tag "$2"
  return 0
}
# Rule 2, every file: a quiet pipeline into a grep the function cannot stand in for.
# lint_rule2 <file> <display>
lint_rule2() {
  lint_scan "$LINT_FOREIGN" "$1" | lint_tag "$2"
  return 0
}
# Rule 3, a script outside the tests: no quiet pipeline, bar the allowed line of bin/keel.
# lint_rule3 <file> <display>
lint_rule3() {
  local n text
  lint_hits "$1" | while IFS= read -r n; do
    if [ "$2" = "$LINT_ALLOW_PATH" ]; then
      text="$(sed -n "${n}p" "$1")"
      case "$text" in *"$LINT_ALLOW_TEXT"*) continue ;; esac
    fi
    printf '%s:%s\n' "$2" "$n"
  done
  return 0
}
# lint_class <display>: 1 for a file directly under tests/, 3 for every other file.
lint_class() {
  case "${1#tests/}" in
    */* | "$1") printf '3\n' ;;
    *) printf '1\n' ;;
  esac
}
# lint_one <file> <display>: the finding of rule 1 or rule 3, whichever reads this file.
lint_one() {
  if [ "$(lint_class "$2")" = 1 ]; then lint_rule1 "$1" "$2"; else lint_rule3 "$1" "$2"; fi
  return 0
}
# lint_paths <root>: every path the rules read under the root, relative to it, one per line.
lint_paths() {
  (
    cd "$1" || exit 0
    for f in tests/*.sh bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh \
      hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard \
      hooks/review-guard tests/evals/*.sh tests/evals/fixtures/*/setup.sh; do
      if [ -f "$f" ]; then printf '%s\n' "$f"; fi
    done
  )
  return 0
}
# lint_tree_rule <1|3> <root>: the findings of one rule over a tree.
lint_tree_rule() {
  local rule="$1" root="$2" p
  lint_paths "$root" | while IFS= read -r p; do
    [ "$(lint_class "$p")" = "$rule" ] || continue
    lint_one "$root/$p" "$p"
  done
  return 0
}
# lint_tree_rule2 <root>: the findings of rule 2 over a tree.
lint_tree_rule2() {
  local p
  lint_paths "$1" | while IFS= read -r p; do
    lint_rule2 "$1/$p" "$p"
  done
  return 0
}
LG="gr""ep"
# fx <name> <line>...: write the lines to $TMP/<name> and print the path.
fx() {
  local p="$TMP/$1"
  shift
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "$@" > "$p"
  printf '%s' "$p"
}
# res <command...>: what the command printed, on one line, then its status as rc=N. A function that
# does not exist yields "command not found" and 127, so a missing function fails its case.
res() {
  local o rc
  o="$("$@" 2>&1)"
  rc=$?
  o="$(printf '%s' "$o" | tr '\n' ' ')"
  if [ -n "$o" ]; then printf '%s rc=%s' "$o" "$rc"; else printf 'rc=%s' "$rc"; fi
}
PLAIN="set -uo pipefail"
# shellcheck disable=SC2016
FORMLINE='set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"'

# 12.1 What a quiet grep pipeline is.
hit_case() {
  expect "detector, $2" "$(res lint_hits "$(fx hit.sh "$3")")" "$1"
}
hit_case "1 rc=0" "a pipe into grep -q" "printf x | $LG -q x"
hit_case "1 rc=0" "a pipe with no blank before grep" "printf x |$LG -qxF x"
hit_case "1 rc=0" "a pipe into grep -E -q" "printf x | $LG -E -q x"
hit_case "1 rc=0" "a pipe into grep --silent" "out | $LG --silent y"
hit_case "1 rc=0" "a pipe into grep --quiet" "out | $LG --quiet y"
hit_case "1 rc=0" "a pipe into grep -Eq" "out | $LG -Eq y"
hit_case "rc=0" "an || before grep -q" "a || $LG -q x f"
hit_case "rc=0" "grep -q on a file, no pipe" "$LG -q x f"
hit_case "rc=0" "a pipe into grep -c" "printf x | $LG -c x"
hit_case "rc=0" "a pipe into grep -o q" "printf x | $LG -o q"
hit_case "rc=0" "a commented-out pipeline" "  # printf x | $LG -q x"

# 12.2 Rule 1: a test file carries the one-line form before its first quiet pipeline.
r1_case() {
  local name="$1" want="$2"
  shift 2
  expect "rule 1, $name" "$(res lint_rule1 "$(fx r1.sh "$@")" tests/a.sh)" "$want"
}
r1_case "the form then a pipeline" "rc=0" "$FORMLINE" "x | $LG -q y"
r1_case "a plain set then a pipeline" "tests/a.sh:2 rc=0" "$PLAIN" "x | $LG -q y"
r1_case "the form after the pipeline" "tests/a.sh:1 rc=0" "x | $LG -q y" "$FORMLINE"
r1_case "only a commented-out pipeline" "rc=0" "$PLAIN" "# x | $LG -q y"
r1_case "two pipelines, no form" "tests/a.sh:2 tests/a.sh:3 rc=0" "$PLAIN" "x | $LG -q y" \
  "z | $LG -q w"

# 12.3 Rule 2: a quiet pipeline into a grep the function cannot stand in for, form or not.
r2_case() {
  expect "rule 2, $1" "$(res lint_rule2 "$(fx r2.sh "$FORMLINE" "$2")" tests/a.sh)" "$3"
}
r2_case "command grep" "x | command $LG -q y" "tests/a.sh:2 rc=0"
r2_case "a path ending in /grep" "x | /usr/bin/$LG -q y" "tests/a.sh:2 rc=0"
r2_case "egrep" "x | e$LG -q y" "tests/a.sh:2 rc=0"
r2_case "fgrep" "x | f$LG -q y" "tests/a.sh:2 rc=0"
r2_case "a backslash grep" "x | \\$LG -q y" "tests/a.sh:2 rc=0"
r2_case "plain grep is the function's" "x | $LG -q y" "rc=0"
r2_case "command grep with no quiet option" "x | command $LG -c y" "rc=0"

# 12.4 Rule 3: the scripts outside the tests hold no quiet pipeline, bar one allowed line.
ALLOWED="  if git ls-files | $LG -qE 'x'; then"
r3_case() {
  expect "rule 3, $1" "$(res lint_rule3 "$(fx r3.sh "$2")" "$3")" "$4"
}
r3_case "a production file" "x | $LG -q y" lib/a.sh "lib/a.sh:1 rc=0"
r3_case "the allowed line under bin/keel" "$ALLOWED" bin/keel "rc=0"
r3_case "the allowed line under another path" "$ALLOWED" bin/keel-fleet "bin/keel-fleet:1 rc=0"
r3_case "another pipeline under bin/keel" "x | $LG -q y" bin/keel "bin/keel:1 rc=0"
r3_case "a clean file" "echo hi" hooks/session-start "rc=0"

# 12.5 The tree rules over a fixture tree: each names the files it reads and no others.
FX="$TMP/tree"
fx tree/tests/clean.sh "$FORMLINE" "x | $LG -q y" > /dev/null
fx tree/tests/dirty.sh "$PLAIN" "x | $LG -q y" > /dev/null
fx tree/tests/foreign.sh "$FORMLINE" "x | command $LG -q y" > /dev/null
fx tree/lib/prod.sh "$PLAIN" "x | $LG -q y" > /dev/null
fx tree/hooks/session-start "echo hi" > /dev/null
expect "tree rule 1 names the unconverted test file" \
  "$(res lint_tree_rule 1 "$FX")" "tests/dirty.sh:2 rc=0"
expect "tree rule 3 names the production file" \
  "$(res lint_tree_rule 3 "$FX")" "lib/prod.sh:2 rc=0"
expect "tree rule 2 names the foreign grep" \
  "$(res lint_tree_rule2 "$FX")" "tests/foreign.sh:2 rc=0"

# 12.6 The tree checks: the same functions, run over this repository, which must pass as it stands.
expect "rule 1: every test file carries the one-line form" \
  "$(res lint_tree_rule 1 "$ROOT")" "rc=0"
expect "rule 2: no quiet pipeline into a grep the function cannot stand in for" \
  "$(res lint_tree_rule2 "$ROOT")" "rc=0"
expect "rule 3: no quiet pipeline in the scripts outside the tests, bar the allowed line" \
  "$(res lint_tree_rule 3 "$ROOT")" "rc=0"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
