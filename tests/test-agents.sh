#!/usr/bin/env bash
# What keel's shipped agents may do, read from their frontmatter.
#
# keel-fanout reads and reports leads; it never writes. Until 2026-10-13 that was a sentence in its
# body, and a sentence binds only as far as the model follows it. The frontmatter field is enforced
# by Claude Code (task 1 of docs/plans/2026-10-13-harness-held-dispatch-guarantees.md probed it).
# Bash is deliberately NOT denied: fan-out reading runs `git log` and `grep`, and the user chose
# edits-only on 2026-10-13, so a Bash command could still change a file. This test pins both halves.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

f=agents/keel-fanout.md
# Read the file as a harness does, so the check is never stricter than correct output: CRLF line
# endings are line endings, so the CR goes before a delimiter or a key is compared.
fm="$(awk '{sub(/\r$/, "")} /^---$/{c++; if(c>=2) exit; next} c==1' "$f")"

# The value of disallowedTools, read as a harness does: a trailing comment (a # after whitespace),
# trailing spaces and one pair of outer quotes are not part of it. Only a one-line comma list is
# read. A YAML block or flow list is left out because whether Claude Code accepts one for this field
# is unverified, so it reads as "no list found" or as a list whose tokens fail to match.
#
# The read fails closed. The key must appear exactly once, and every token must look like a tool
# name (a letter, then letters, digits and _ . : -, then at most one parenthesised specifier).
# A stray quote or # in a token, as in an unclosed quote or a comment inside quotes, is not a tool
# name, so that line is refused rather than read as a list that denies something it does not.
keys="$(printf '%s\n' "$fm" | grep -c '^disallowedTools:')"
denied="$(printf '%s\n' "$fm" | sed -n '/^disallowedTools:/{
s/^disallowedTools:[[:space:]]*//
s/^#.*$//
s/[[:space:]][[:space:]]*#.*$//
s/[[:space:]]*$//
p
q
}')"
case "$denied" in
    \"*\") denied="${denied#\"}"; denied="${denied%\"}" ;;
    \'*\') denied="${denied#\'}"; denied="${denied%\'}" ;;
esac
# One trimmed token per line, compared whole: `Edit` must not match `MultiEdit`, nor `Bash` match
# a longer name that merely contains it.
tokens="$(printf '%s\n' "$denied" | tr ',' '\n' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
denies() { grep -qxF -- "$1" <<<"$tokens"; }

# `problem` stays empty when the list was read cleanly. Otherwise it says why not, and both cases
# fail on it: a list that could not be read must not pass either one. An empty token (a trailing
# comma) is harmless and skipped.
tool_re='^[A-Za-z][A-Za-z0-9_.:-]*(\([^()]*\))?$'
problem=""
if [ "$keys" -gt 1 ]; then
    problem="the \`disallowedTools:\` key appears more than once in the frontmatter"
elif [ -z "$denied" ]; then
    problem="no one-line \`disallowedTools:\` comma list found in the frontmatter"
else
    while IFS= read -r tok; do
        if [ -n "$tok" ] && ! [[ $tok =~ $tool_re ]]; then
            problem="unrecognised token '$tok' in the one-line comma list"
            break
        fi
    done <<<"$tokens"
fi

if [ -n "$problem" ]; then
    bad "keel-fanout is denied Edit, Write and NotebookEdit" "$problem"
else
    missing=""
    for t in Edit Write NotebookEdit; do
        denies "$t" || missing="$missing $t"
    done
    if [ -z "$missing" ]; then
        ok "keel-fanout is denied Edit, Write and NotebookEdit"
    else
        bad "keel-fanout is denied Edit, Write and NotebookEdit" \
            "not denied:$missing (read from the one-line comma list '$denied')"
    fi
fi

if [ -n "$problem" ]; then
    bad "keel-fanout keeps Bash and sets no tools allowlist" \
        "the denied list could not be read, so Bash cannot be checked ($problem)"
elif denies Bash; then
    bad "keel-fanout keeps Bash and sets no tools allowlist" \
        "Bash is denied, which breaks git log and grep reads"
elif grep -q '^tools:' <<<"$fm"; then
    bad "keel-fanout keeps Bash and sets no tools allowlist" \
        "a tools: line narrows what it inherits"
else
    ok "keel-fanout keeps Bash and sets no tools allowlist"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
