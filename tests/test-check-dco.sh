#!/usr/bin/env bash
# Tests for tests/check-dco.sh <base> <head>: the Developer Certificate of Origin check CI runs over
# the commits of a pull request. Run from anywhere; it runs the script from this checkout.
#
# What is pinned: a signed commit passes and an unsigned one fails with the exact lines the script
# promises; a merge is exempt and a commit authored by a name ending in [bot] is skipped; a
# sign-off whose email differs from the author's only in case passes, one for another email fails,
# and a Signed-off-by text that is only part of the subject line fails; an empty range is
# OK with 0; one argument prints the usage line and exits 2; a base that is not a commit exits 2.
#
# EVERY IDENTIFIER IN THIS FILE IS INVENTED: Quillbank and zephyr-ledger stand for a client name
# and a repository name, and the addresses end in .invalid.
#
# Isolation. Only tests/run-tests.sh isolates git configuration, and the device gates run test files
# directly, so this file does it itself: its own global config with an identity and no signing, no
# system config, no GIT_CONFIG_COUNT family. Every fixture commit names its own author, so the
# owner's real identity and signing key never reach a case.
#
# The `condition && ok || bad` idiom is not used: every check goes through expect/has/lacks.
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/tests/check-dco.sh"
pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---- git isolation ------------------------------------------------------------------------------
unset GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE XDG_CONFIG_HOME
while IFS= read -r v; do unset "$v"; done < <(compgen -e | awk '/^GIT_CONFIG_(KEY|VALUE)_/ || /^GIT_(AUTHOR|COMMITTER)_/')
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
printf '[user]\n\tname = Test User\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n[init]\n\tdefaultBranch = main\n' \
  > "$GIT_CONFIG_GLOBAL"

# expect <name> <got> <want>; has <name> <text> <needle>; lacks <name> <text> <needle>
expect() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "got: $2 / want: $3"; fi; return 0; }
has() {
    case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "no '$3' in: $(printf '%s' "$2" | tr '\n' '|')" ;; esac
    return 0
}
lacks() {
    case "$2" in *"$3"*) bad "$1" "found '$3' in: $(printf '%s' "$2" | tr '\n' '|')" ;; *) ok "$1" ;; esac
    return 0
}

# ---- fixture ------------------------------------------------------------------------------------
REPO="$TMP/zephyr-ledger"
mkdir -p "$REPO"
git -C "$REPO" init -q
n=0
# commit <name> <email> <message> [extra git commit args...]: one new commit, author and committer
# as given, a file that is new each time so the commit is never empty. Sets SHA to the full sha. It
# is called, never captured with $( ), so its counter survives.
commit() {
    local name="$1" email="$2" msg="$3"
    shift 3
    n=$((n+1))
    printf '%s\n' "$n" > "$REPO/f$n"
    git -C "$REPO" add "f$n"
    GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" \
        git -C "$REPO" commit -q ${1+"$@"} -m "$msg" || return 1
    SHA="$(git -C "$REPO" rev-parse HEAD)"
}
# check <base> <head>: the script's output with its status as rc=N on a last line.
check() {
    local out rc
    out="$(cd "$REPO" && "$CHECK" "$@" 2>&1)"
    rc=$?
    printf '%s\nrc=%s' "$out" "$rc"
}

if [ ! -x "$CHECK" ]; then
    bad "tests/check-dco.sh exists and is executable" "missing or not executable: $CHECK"
fi

commit "Ada Dev" "ada@example.invalid" "base"; BASE="$SHA"
commit "Ada Dev" "ada@example.invalid" "signed change" -s; A="$SHA"
commit "Bea Dev" "bea@example.invalid" "unsigned change"; B="$SHA"
A7="${A:0:7}"
B7="${B:0:7}"

# ---- 1. signed and unsigned ---------------------------------------------------------------------
out="$(check "$BASE" "$A")"
expect "a signed commit: OK 1, exit 0" "$out" "$(printf 'OK    1 commit(s) signed off\nrc=0')"

out="$(check "$BASE" "$B")"
expect "an unsigned commit: FAIL line, summary line, exit 1" "$out" \
    "$(printf 'FAIL  %s: no Signed-off-by for bea@example.invalid\n1 commit(s) without a sign-off. Add one to each with: git rebase --signoff %s\nrc=1' "$B7" "$BASE")"

out="$(check "$BASE" "$B")"
lacks "a failing range prints no OK line" "$out" "OK    "
lacks "the sign-off of the earlier commit is not reported against the later one" "$out" "$A7"

# ---- 2. exemptions ------------------------------------------------------------------------------
# A merge: a side branch of one signed commit, merged into main with an unsigned merge commit.
git -C "$REPO" branch -q side "$BASE"
git -C "$REPO" checkout -q side
commit "Ada Dev" "ada@example.invalid" "signed side change" -s
git -C "$REPO" checkout -q main
GIT_AUTHOR_NAME="Cy Dev" GIT_AUTHOR_EMAIL="cy@example.invalid" GIT_COMMITTER_NAME="Cy Dev" GIT_COMMITTER_EMAIL="cy@example.invalid" \
    git -C "$REPO" merge -q --no-ff -m "merge side without a sign-off" side
M="$(git -C "$REPO" rev-parse HEAD)"
out="$(check "$B" "$M")"
expect "a range whose only unsigned commit is a merge passes" "$out" "$(printf 'OK    1 commit(s) signed off\nrc=0')"
expect "the merge range holds one commit besides the merge" "$(git -C "$REPO" rev-list --no-merges "$B..$M" | wc -l | tr -d ' ')" "1"

# A bot: skipped by name, and counted nowhere.
commit "dependabot[bot]" "49699333+dependabot[bot]@users.noreply.example.invalid" "bump a dependency"; D="$SHA"
out="$(check "$M" "$D")"
expect "a [bot] author is printed as SKIP and passes" "$out" \
    "$(printf 'SKIP  %s authored by dependabot[bot], a bot\nOK    0 commit(s) signed off\nrc=0' "${D:0:7}")"

# ---- 3. edges -----------------------------------------------------------------------------------
commit "Dee Dev" "Dee.Dev@Example.Invalid" "case differs" -s --author="Dee Dev <dee.dev@example.invalid>"; E1="$SHA"
out="$(check "$D" "$E1")"
expect "a sign-off differing from the author email only in case passes" "$out" \
    "$(printf 'OK    1 commit(s) signed off\nrc=0')"

commit "Eli Dev" "eli@example.invalid" "another email" -s --author="Eli Dev <eli.other@example.invalid>"; E2="$SHA"
out="$(check "$E1" "$E2")"
has "a sign-off for another email fails" "$out" "FAIL  ${E2:0:7}: no Signed-off-by for eli.other@example.invalid"
expect "a sign-off for another email exits 1" "${out##*rc=}" "1"

commit "Fay Dev" "fay@example.invalid" "fix a typo, Signed-off-by: Fay Dev <fay@example.invalid>"; E3="$SHA"
out="$(check "$E2" "$E3")"
has "a Signed-off-by in the subject line only fails" "$out" "FAIL  ${E3:0:7}: no Signed-off-by for fay@example.invalid"
expect "a Signed-off-by in the subject line only exits 1" "${out##*rc=}" "1"

commit "Gus Dev" "gus@example.invalid" "a change signed in its body

Signed-off-by: Someone Else <gus@example.invalid>"; E4="$SHA"
out="$(check "$E3" "$E4")"
expect "a sign-off line in the body by any name, with the author's email, passes" "$out" \
    "$(printf 'OK    1 commit(s) signed off\nrc=0')"

out="$(check "$E4" "$E4")"
expect "an empty range: OK 0, exit 0" "$out" "$(printf 'OK    0 commit(s) signed off\nrc=0')"

out="$(check "$BASE" "$E4")"
has "a mixed range reports every unsigned commit" "$out" "FAIL  ${B7}: no Signed-off-by for bea@example.invalid"
has "a mixed range counts its unsigned commits" "$out" "3 commit(s) without a sign-off."
lacks "a signed commit in a mixed range is not reported" "$out" "FAIL  $A7"

out="$(check "$BASE")"
expect "one argument: the usage line, exit 2" "$out" "$(printf 'usage: tests/check-dco.sh <base> <head>\nrc=2')"

out="$(check)"
expect "no argument: the usage line, exit 2" "$out" "$(printf 'usage: tests/check-dco.sh <base> <head>\nrc=2')"

out="$(check "$BASE" "$E4" extra)"
expect "three arguments: the usage line, exit 2" "$out" "$(printf 'usage: tests/check-dco.sh <base> <head>\nrc=2')"

out="$(check "not-a-revision" "$A")"
expect "a base that is not a commit exits 2" "${out##*rc=}" "2"
lacks "a base that is not a commit prints no OK line" "$out" "OK    "

out="$(check "$BASE" "not-a-revision")"
expect "a head that is not a commit exits 2" "${out##*rc=}" "2"

TREE="$(git -C "$REPO" rev-parse "$A^{tree}")"
out="$(check "$TREE" "$A")"
expect "a tree is not a commit: exit 2" "${out##*rc=}" "2"

# ---- 4. the script's own shape ------------------------------------------------------------------
n_rebase="$(grep -c 'rebase --signoff' "$CHECK" 2>/dev/null)"
expect "the header says how to fix a failure" "$([ "${n_rebase:-0}" -ge 1 ] && echo yes || echo no)" "yes"
first="$(head -n 1 "$CHECK" 2>/dev/null)"
expect "it is a bash script" "$first" "#!/usr/bin/env bash"
if grep -v '^[[:space:]]*#' "$CHECK" | grep -qF -e readarray -e mapfile -e 'declare -A' -e ',,}' -e '^^}'; then
    bad "it avoids bash 4 features" "found one in $CHECK"
else
    ok "it avoids bash 4 features"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
