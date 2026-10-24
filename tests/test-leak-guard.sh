#!/usr/bin/env bash
# Tests for `keel scan --leaks <remote> [<object>:<ref>]...` and `keel scan --leaks-message <file>`,
# and for the deny list loader they share (lib/deny-list.sh, whose own cases are in
# tests/test-no-leaks.sh). Run from anywhere; it runs bin/keel from this checkout.
#
# What the leak guard is. A push to the public repository must carry no client name, no developer
# home path and no Claude-Session trailer, in a commit message, an author line, a path, a ref name
# or a file a commit in the push added. The names come from a deny list the owner keeps outside any
# repository. The guard prints WHERE a pattern matched and WHICH deny list line it was, and never
# the text, the pattern or a path that matches, because its output ends up in a terminal log and a
# CI log, and a leak guard that prints the leak has made a second copy of it.
#
# EVERY IDENTIFIER IN THIS FILE IS INVENTED: Quillbank, zephyr-ledger and QBK stand for a client
# name, a repository name and an acronym. The deny file each case uses lives under that case's home
# directory, outside its repository, as the real one does. A developer home path is assembled from
# pieces, so tests/no-internal-leaks.sh and the push scan itself never report this file.
#
# Isolation. Only tests/run-tests.sh isolates git configuration, and the device gates run test files
# directly, so this file does it itself: its own global config with an identity and no signing, no
# system config, no GIT_CONFIG_COUNT family. Every case sets HOME and KEEL_DENY_FILE, so the
# owner's real deny list and identity never reach a case and a run on the owner's machine gives
# what a run in CI gives.
#
# The `condition && ok || bad` idiom is not used: every check goes through expect/has/lacks.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---- git isolation ------------------------------------------------------------------------------
unset GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE XDG_CONFIG_HOME KEEL_DENY_FILE
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

# ---- fixtures -----------------------------------------------------------------------------------
# The three-pattern file of the task. Line 3 is Quillbank, line 4 zephyr-ledger, line 5 \bQBK\b.
write_deny() {
    cat > "$1" <<'DENY'
# invented identifiers for the leak guard's tests

Quillbank
zephyr-ledger
\bQBK\b
DENY
}

FXN=0
# newfx: a work repository W with a bare remote B named origin, main pushed and fetched. H is the
# HOME of the case and DF its deny list, both outside W.
newfx() {
    FXN=$((FXN+1))
    FX="$TMP/fx$FXN"; H="$FX/home"; B="$FX/remote.git"; W="$FX/w"; DF="$H/deny.txt"
    mkdir -p "$H"
    write_deny "$DF"
    git init -q --bare "$B"
    git init -q "$W"
    g remote add origin "$B"
    printf 'readme\n' > "$W/README.md"
    g add README.md
    g commit -q -m 'chore: base'
    g push -q origin main
    g fetch -q origin
}
g() { ( cd "$W" && git "$@" ); }
# put <path> <printf format>: a file in W, with the directories it needs.
put() { mkdir -p "$(dirname "$W/$1")"; printf '%b' "$2" > "$W/$1"; }
# commit_file <message> <path> <printf format>: one commit adding or changing one file.
commit_file() { put "$2" "$3"; g add "$2"; g commit -q -m "$1"; }
s7() { g rev-parse --short=7 "$1"; }
# leaks <args...>: keel scan --leaks <args> in W with this case's HOME and deny list.
leaks() {
    OUT="$( cd "$W" && HOME="$H" KEEL_DENY_FILE="$DF" "$KEEL" scan --leaks "$@" 2>&1 )"
    RC=$?
}
# lmsg <file>: keel scan --leaks-message <file>.
lmsg() {
    OUT="$( cd "$W" && HOME="$H" KEEL_DENY_FILE="$DF" "$KEEL" scan --leaks-message "$@" 2>&1 )"
    RC=$?
}
# first_line <text>
first_line() { printf '%s\n' "$1" | sed -n 1p; }

MODE_OK='leak guard: deny list loaded from ~/deny.txt (3 patterns)'

# ---- behaviour 4: the mode line comes first, every run ---------------------------------------------
newfx
leaks origin
expect "4: loaded list, nothing pushed: exit 0" "$RC" "0"
expect "4: loaded list, nothing pushed: the output is the mode line and the nothing line" "$OUT" \
  "$MODE_OK
leak guard: nothing pushed, nothing checked"

DF="$H/absent.txt"
leaks origin
expect "4: absent list: the first line is the warning" "$(first_line "$OUT")" \
  'leak guard: WARNING no deny list at ~/absent.txt, so only the 2 generic patterns ran. Client names are not checked on this machine.'
expect "4: absent list, nothing pushed: exit 0" "$RC" "0"

# With the list absent, a client name passes and a developer home path does not.
commit_file 'fix: Quillbank only' a.txt 'x\n'
leaks origin "$(s7 HEAD)":refs/heads/topic
expect "4: an absent list does not know the client name: exit 0" "$RC" "0"
g commit -q --amend -m "fix: see $(printf '%s' '/ho''me/someone')/x"
leaks origin HEAD:refs/heads/topic
expect "4: an absent list still catches a developer path: exit 1" "$RC" "1"

# ---- behaviour 5: which commits are checked ------------------------------------------------------
newfx
g checkout -q -b topic
commit_file 'fix: one' a.txt 'one\n'
commit_file 'fix: two' b.txt 'two\n'
leaks origin "$(g rev-parse HEAD)":refs/heads/topic
expect "5: a branch with two new commits: exit 0" "$RC" "0"
has "5: a branch with two new commits: two commits and one ref name" "$OUT" \
  'leak guard: checked 2 commit(s), 0 tag(s) and 1 ref name(s), no findings'
expect "5: the mode line is first" "$(first_line "$OUT")" "$MODE_OK"

# A rewritten branch: origin/topic is A, the local branch holds A' naming the client.
newfx
g checkout -q -b topic
commit_file 'fix: one' a.txt 'one\n'
g push -q origin topic
g fetch -q origin
g commit -q --amend -m 'fix: Quillbank retry'
A2="$(g rev-parse HEAD)"
leaks origin "$A2":refs/heads/topic
expect "5: a rewritten branch: exit 1" "$RC" "1"
has "5: a rewritten branch: the amended commit is checked and reported" "$OUT" \
  "leak guard: $(s7 "$A2") message line 1: deny list line 3"
lacks "5: a rewritten branch: the old commit is not in range" "$OUT" "checked"

# A new branch with no upstream, made from origin/main with one commit.
newfx
g checkout -q -b fresh origin/main
commit_file 'feat: fresh' f.txt 'f\n'
leaks origin "$(g rev-parse HEAD)":refs/heads/fresh
expect "5: a new branch with no upstream: exit 0" "$RC" "0"
has "5: a new branch with no upstream: exactly that commit" "$OUT" \
  'leak guard: checked 1 commit(s), 0 tag(s) and 1 ref name(s), no findings'

# A remote with no fetched refs here, named by its path: the whole history is in range.
newfx
BASE="$(g rev-parse origin/main)"
g checkout -q -b topic
commit_file 'fix: one' a.txt 'one\n'
leaks "$B" "$(g rev-parse HEAD)":refs/heads/topic
expect "5: a remote named by path walks the whole history: exit 1" "$RC" "1"
has "5: ... so the root rule of behaviour 11 fires on the base commit" "$OUT" \
  "leak guard: $(s7 "$BASE") has no parent, so this push carries a history the remote does not have"

# ---- behaviour 6: messages, every line --------------------------------------------------------------
newfx
g checkout -q -b topic
put m.txt 'm\n'; g add m.txt
printf 'fix: retry\n\nSee zephyr-ledger notes\n' | g commit -q -F -
C="$(g rev-parse HEAD)"
leaks origin "$C":refs/heads/topic
expect "6: a body line is checked: exit 1" "$RC" "1"
has "6: a body line is reported with its line number" "$OUT" \
  "leak guard: $(s7 "$C") message line 3: deny list line 4"

# An annotated tag pushed as <tag id>:refs/tags/v9.9.9, the message's second line holding QBK.
newfx
g tag -a -m 'release notes
QBK was here' v9.9.9
T="$(g rev-parse v9.9.9)"
leaks origin "$T":refs/tags/v9.9.9
expect "6: an annotated tag message is checked: exit 1" "$RC" "1"
has "6: the tag message line is reported" "$OUT" \
  "leak guard: tag $(s7 "$T") message line 2: deny list line 5"

# ---- behaviour 7: author and committer ---------------------------------------------------------------
newfx
g checkout -q -b topic
put a.txt 'a\n'; g add a.txt
GIT_AUTHOR_NAME=Pat GIT_AUTHOR_EMAIL=pat@zephyr-ledger.example g commit -q -m 'chore: author'
C1="$(g rev-parse HEAD)"
put b.txt 'b\n'; g add b.txt
GIT_COMMITTER_NAME=Pat GIT_COMMITTER_EMAIL=pat@zephyr-ledger.example g commit -q -m 'chore: committer'
C2="$(g rev-parse HEAD)"
leaks origin "$C2":refs/heads/topic
expect "7: an identity is checked: exit 1" "$RC" "1"
has "7: the author email is reported" "$OUT" \
  "leak guard: $(s7 "$C1") author email: deny list line 4"
has "7: the committer email is reported" "$OUT" \
  "leak guard: $(s7 "$C2") committer email: deny list line 4"

newfx
g checkout -q -b topic
put a.txt 'a\n'; g add a.txt
GIT_AUTHOR_NAME=Owner GIT_AUTHOR_EMAIL=owner@gbi-solutions.com \
  GIT_COMMITTER_NAME=Owner GIT_COMMITTER_EMAIL=owner@gbi-solutions.com \
  g commit -q -m 'feat: GBi house defaults'
leaks origin "$(g rev-parse HEAD)":refs/heads/topic
expect "7: the owner's identity and the organisation name are not a leak: exit 0" "$RC" "0"

# ---- behaviour 8: files a commit in range added, modified or changed in type ---------------------------
newfx
g checkout -q -b topic
commit_file 'docs: note' docs/n.md 'line one\nQuillbank\n'
C="$(g rev-parse HEAD)"
leaks origin "$(g rev-parse HEAD)":refs/heads/topic
expect "8: a file with the client name on line 2: exit 1" "$RC" "1"
has "8: ... is reported with its path and line" "$OUT" \
  "leak guard: $(s7 "$C") docs/n.md line 2: deny list line 3"
g rm -q docs/n.md; g commit -q -m 'docs: drop note'
leaks origin "$(g rev-parse HEAD)":refs/heads/topic
has "8: ... and still is when a later commit in the range deletes the file" "$OUT" \
  "leak guard: $(s7 "$C") docs/n.md line 2: deny list line 3"

# The same file already on origin/main gives nothing.
newfx
commit_file 'docs: note' docs/n.md 'line one\nQuillbank\n'
g push -q origin main; g fetch -q origin
commit_file 'chore: other' other.txt 'o\n'
leaks origin "$(g rev-parse HEAD)":refs/heads/main
expect "8: a file the remote already holds is not in range: exit 0" "$RC" "0"

# A binary file is skipped by the scanner's own test, which the accepted risks name.
newfx
g checkout -q -b topic
put img.bin 'Quillbank\0\n'; g add img.bin; g commit -q -m 'chore: image'
leaks origin "$(g rev-parse HEAD)":refs/heads/topic
expect "8: a binary file holding the client name gives no finding: exit 0" "$RC" "0"

# ---- behaviour 9: paths and ref names are checked and never printed ------------------------------------
newfx
g checkout -q -b topic
commit_file 'docs: note' notes/zephyr-ledger.md 'Quillbank\n'
C="$(g rev-parse HEAD)"
leaks origin "$(g rev-parse HEAD)":refs/heads/topic
has "9: a matching path is reported without being printed" "$OUT" \
  "leak guard: $(s7 "$C") a changed path: deny list line 4"
has "9: its content is reported under the same unnamed path" "$OUT" \
  "leak guard: $(s7 "$C") a changed path line 1: deny list line 3"
lacks "9: the output holds no part of the path" "$OUT" "zephyr-ledger"

newfx
g checkout -q -b topic
commit_file 'fix: timeout' t.txt 't\n'
leaks origin "$(g rev-parse HEAD)":refs/heads/fix/zephyr-ledger-timeout
expect "9: a matching ref name: exit 1" "$RC" "1"
has "9: ... is reported without being printed" "$OUT" \
  'leak guard: a pushed ref name: deny list line 4'
lacks "9: the output holds no part of the ref name" "$OUT" "zephyr-ledger"

# ---- behaviour 10: an ignored path is refused ----------------------------------------------------------
newfx
printf 'private/\n' > "$W/.gitignore"; g add .gitignore; g commit -q -m 'chore: ignore'
g push -q origin main; g fetch -q origin
g checkout -q -b topic
put private/n.md 'n\n'; g add -f private/n.md; g commit -q -m 'docs: audit'
C="$(g rev-parse HEAD)"
leaks origin "$C":refs/heads/topic
expect "10: a force-added ignored path: exit 1" "$RC" "1"
has "10: ... is reported" "$OUT" "leak guard: $(s7 "$C") private/n.md: a path this repository ignores"

newfx
printf 'private/\n' > "$W/.gitignore"; g add .gitignore; g commit -q -m 'chore: ignore'
g push -q origin main; g fetch -q origin
g checkout -q -b topic
put private/zephyr-ledger.md 'n\n'; g add -f private/zephyr-ledger.md; g commit -q -m 'docs: audit'
C="$(g rev-parse HEAD)"
leaks origin "$C":refs/heads/topic
has "10: an ignored path that matches a pattern is not named" "$OUT" \
  "leak guard: $(s7 "$C") a changed path: a path this repository ignores"
has "10: ... and its path finding sits beside it" "$OUT" \
  "leak guard: $(s7 "$C") a changed path: deny list line 4"
lacks "10: ... and the output holds no part of the path" "$OUT" "zephyr-ledger"

# ---- behaviour 10a: a Claude-Session trailer is refused at push ------------------------------------------
newfx
g checkout -q -b topic
put a.txt 'a\n'; g add a.txt
printf 'fix: x\n\nClaude-Session: https://claude.ai/code/session_example\n' | g commit -q --no-verify -F -
C="$(g rev-parse HEAD)"
leaks origin "$C":refs/heads/topic
expect "10a: a commit made with --no-verify and the trailer: exit 1" "$RC" "1"
has "10a: ... gives the trailer line with its number" "$OUT" \
  "leak guard: $(s7 "$C") message line 3: a Claude-Session trailer"
put b.txt 'b\n'; g add b.txt
printf 'fix: y\n\nclaude-session: lower case key\n' | g commit -q -F -
C="$(g rev-parse HEAD)"
leaks origin "$C":refs/heads/topic
has "10a: the key matches in any case" "$OUT" \
  "leak guard: $(s7 "$C") message line 3: a Claude-Session trailer"
lacks "10a: the trailer's value is not printed" "$OUT" "lower case key"

printf 'fix: x\n\nClaude-Session: https://claude.ai/code/session_example\n' > "$TMP/trailer.txt"
lmsg "$TMP/trailer.txt"
expect "10a: --leaks-message on a file holding the trailer: exit 1" "$RC" "1"
has "10a: ... gives the trailer line" "$OUT" 'leak guard: message line 3: a Claude-Session trailer'

# ---- behaviour 11: a root commit in range is refused ------------------------------------------------------
FXN=$((FXN+1)); FX="$TMP/fx$FXN"; H="$FX/home"; B="$FX/remote.git"; W="$FX/w"; DF="$H/deny.txt"
mkdir -p "$H"; write_deny "$DF"
git init -q --bare "$B"; git init -q "$W"; g remote add origin "$B"
commit_file 'chore: first' a.txt 'a\n'
ROOT_C="$(g rev-parse HEAD)"
commit_file 'chore: second' b.txt 'b\n'
leaks origin "$(g rev-parse HEAD)":refs/heads/main
expect "11: a push from a repository with no fetched refs of the remote: exit 1" "$RC" "1"
has "11: ... names the root commit" "$OUT" \
  "leak guard: $(s7 "$ROOT_C") has no parent, so this push carries a history the remote does not have"
expect "11: ... and only the root" "$(printf '%s\n' "$OUT" | grep -c 'has no parent')" "1"

# ---- behaviour 12: matched text is never printed -------------------------------------------------------------
newfx
g checkout -q -b topic
put notes/zephyr-ledger.md 'Quillbank and QBK\n'; g add notes/zephyr-ledger.md
put private/zephyr-ledger.md 'x\n'
printf 'private/\n' > "$W/.gitignore"; g add .gitignore; g add -f private/zephyr-ledger.md
printf 'subjecttoken-17: retry\n\nSee zephyr-ledger notes\nand %s/x here\nClaude-Session: https://example.invalid/s\n' \
  "/ho""me/someone" | GIT_AUTHOR_EMAIL=pat@zephyr-ledger.example g commit -q -F -
C="$(g rev-parse HEAD)"
g tag -a -m 'tag
QBK in a tag' v1.0.0
T="$(g rev-parse v1.0.0)"
leaks origin "$C":refs/heads/fix/zephyr-ledger-timeout "$T":refs/tags/v1.0.0
expect "12: a fixture holding every kind of finding: exit 1" "$RC" "1"
for needle in Quillbank zephyr-ledger QBK 'subjecttoken-17' 'someone' '\bQBK\b' '/home' 'retry'; do
    lacks "12: the output holds none of '$needle'" "$OUT" "$needle"
done
has "12: a generic pattern is reported by its number" "$OUT" \
  "leak guard: $(s7 "$C") message line 4: generic pattern 2"
n_lines="$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
expect "13: the summary counts every finding line" "$(printf '%s\n' "$OUT" | tail -n 1)" \
  "leak guard: $((n_lines-2)) finding(s)"

# ---- behaviour 13: summary and exit codes -------------------------------------------------------------------
newfx
leaks
expect "13: --leaks with no remote: exit 2" "$RC" "2"
has "13: ... with a usage line" "$OUT" "usage:"
BLOB="$(g rev-parse HEAD:README.md)"
leaks origin "$BLOB":refs/heads/x
expect "13: an object that is not a commit or tag: exit 2" "$RC" "2"
has "13: ... named as such" "$OUT" "$BLOB is not a commit or tag in this repository"
leaks origin nosuchobject:refs/heads/x
expect "13: an object that does not exist: exit 2" "$RC" "2"
leaks origin "$(g rev-parse HEAD)"
expect "13: an argument with no ref: exit 2" "$RC" "2"

# ---- behaviour 14: --leaks-message ---------------------------------------------------------------------------
newfx
printf 'chore: tidy\n\nQBK follow-up\n' > "$TMP/m1.txt"
lmsg "$TMP/m1.txt"
expect "14: a message naming QBK: exit 1" "$RC" "1"
has "14: ... reports its line" "$OUT" 'leak guard: message line 3: deny list line 5'
expect "14: the mode line is first" "$(first_line "$OUT")" "$MODE_OK"
expect "14: the summary is last" "$(printf '%s\n' "$OUT" | tail -n 1)" 'leak guard: 1 finding(s)'

printf 'chore: tidy\n# ------------------------ >8 ------------------------\nQBK below the scissors\n' \
  > "$TMP/m2.txt"
lmsg "$TMP/m2.txt"
expect "14: QBK only below a scissors line: exit 0" "$RC" "0"
has "14: ... says so" "$OUT" 'leak guard: message checked, no findings'

printf 'chore: tidy\n# QBK in a comment line\n' > "$TMP/m3.txt"
lmsg "$TMP/m3.txt"
expect "14: a comment line is checked: exit 1" "$RC" "1"
has "14: ... and reported" "$OUT" 'leak guard: message line 2: deny list line 5'

printf 'chore: tidy\nzephyr-ledger' > "$TMP/m4.txt"
lmsg "$TMP/m4.txt"
has "14: a last line with no newline is checked" "$OUT" 'leak guard: message line 2: deny list line 4'

lmsg "$TMP/no-such-file.txt"
expect "14: a missing file: exit 2" "$RC" "2"

printf 'see %s/x\n' "/Us""ers/someone" > "$TMP/m5.txt"
lmsg "$TMP/m5.txt"
has "12: a developer path in a message is reported as generic pattern 1" "$OUT" \
  'leak guard: message line 1: generic pattern 1'
lacks "12: ... and none of it is printed" "$OUT" "someone"

# ---- behaviour 15: one grep per pattern -------------------------------------------------------------------------
newfx
g checkout -q -b topic
i=0
while [ "$i" -lt 30 ]; do
    j=0
    while [ "$j" -lt 30 ]; do put "d$i/f$j.txt" "content $i $j\n"; j=$((j+1)); done
    g add . >/dev/null
    g commit -q -m "chore: batch $i"
    i=$((i+1))
done
mkdir -p "$TMP/wrap"
REAL_GREP="$(type -P grep)"
printf '#!/bin/sh\nprintf "call\\n" >> "%s"\nexec "%s" "$@"\n' "$TMP/grep.log" "$REAL_GREP" > "$TMP/wrap/grep"
chmod +x "$TMP/wrap/grep"
: > "$TMP/grep.log"
OUT="$( cd "$W" && PATH="$TMP/wrap:$PATH" HOME="$H" KEEL_DENY_FILE="$DF" "$KEEL" scan --leaks origin "$(g rev-parse HEAD)":refs/heads/topic 2>&1 )"
RC=$?
expect "15: 30 commits of 30 files: exit 0" "$RC" "0"
has "15: ... all of them checked" "$OUT" 'leak guard: checked 30 commit(s), 0 tag(s) and 1 ref name(s), no findings'
expect "15: two validity checks per loaded pattern, one binary test and one grep per pattern, 12 calls, not one per file" \
  "$(wc -l < "$TMP/grep.log" | tr -d ' ')" "12"

# ---- behaviour 16: help and the documentation ------------------------------------------------------------------
HELP="$( HOME="$TMP" "$KEEL" --help 2>&1 )"
has "16: help lists the push mode" "$HELP" \
  '  scan --leaks <remote> [<object>:<ref>]...   check what a push carries against the deny list'
has "16: help lists the message mode" "$HELP" \
  '  scan --leaks-message <file>   check a message or any text file against the deny list'
has "16: the scan --push line is unchanged" "$HELP" \
  "  scan --push <remote> <commit>   the same scan of a commit being pushed, and of its history's key files"

DOC="$ROOT/docs/03-install-and-distribution.md"
section="$(awk '/^keel scan --leaks </{f=1} /^keel plan status/{f=0} f' "$DOC")"
has "16: the install document describes both modes" "$section" 'keel scan --leaks-message <file>'
has "16: ... and says a first push needs --no-verify" "$section" 'git push --no-verify'

# ---- behaviour 17: shape ----------------------------------------------------------------------------------------
expect "17: tests/run-tests.sh runs this file once" \
  "$(grep -c 'test-leak-guard.sh' "$ROOT/tests/run-tests.sh")" "1"

# ==== task 6: keel guard install --leak-guard, the push and commit-message hooks ====================
# A hook runs as its own process under whatever PATH the owner has, so these cases set PATH
# explicitly: KP has this checkout's keel on it, and /usr/bin:/bin has none.
KP="$ROOT/bin:$PATH"
NOKEEL=/usr/bin:/bin
ZERO=0000000000000000000000000000000000000000
mkdir -p "$TMP/oldpush" "$TMP/oldmsg"
# A keel from before the leak guard: its help names scan --push and not scan --leaks, and it exits 0
# for anything, as the keel that ran the supply chain scan for a mode it did not know did.
# shellcheck disable=SC2016
printf '#!/bin/sh\ncase "$1" in --help) printf "keel <command>\\n  scan --push <remote> <commit>   the scan\\n" ;; esac\nexit 0\n' \
  > "$TMP/oldpush/keel"
chmod +x "$TMP/oldpush/keel"
# A keel that has scan --leaks and not scan --leaks-message.
# shellcheck disable=SC2016
printf '#!/bin/sh\ncase "$1" in --help) printf "keel <command>\\n  scan --leaks <remote> [<object>:<ref>]...   push\\n" ;; esac\nexit 0\n' \
  > "$TMP/oldmsg/keel"
chmod +x "$TMP/oldmsg/keel"

# ginst <args>: keel guard install in W. GOUT and GRC.
ginst() {
    GOUT="$( cd "$W" && HOME="$H" KEEL_DENY_FILE="$DF" "$KEEL" "guard" "$@" 2>&1 )"
    GRC=$?
}
# hook_push <PATH> <branch>: the pre-push hook as git runs it for a push of that branch's tip.
hook_push() {
    local sha; sha="$(g rev-parse "$2")"
    HOUT="$( cd "$W" && printf 'refs/heads/%s %s refs/heads/%s %s\n' "$2" "$sha" "$2" "$ZERO" \
        | HOME="$H" KEEL_DENY_FILE="$DF" PATH="$1" .git/hooks/pre-push origin "$B" 2>&1 )"
    HRC=$?
}
# cm <PATH> <git commit args...>: a commit as Test Owner, with the hooks installed in W.
cm() {
    local p="$1"; shift
    COUT="$( cd "$W" && HOME="$H" KEEL_DENY_FILE="$DF" PATH="$p" \
        git -c user.name='Test Owner' -c user.email=owner@example.com commit -q "$@" 2>&1 )"
    CRC=$?
}
line3() { sed -n 3p "$W/.git/hooks/pre-push"; }
body_of() { ( cd "$W" && git cat-file commit "$1" | sed '1,/^$/d' ); }

# ---- guard 1: opt in per repository ---------------------------------------------------------------
newfx
ginst install
expect "guard 1: a plain install: exit 0" "$GRC" "0"
expect "guard 1: a plain install writes LEAK_GUARD=0 on line 3" "$(line3)" "LEAK_GUARD=0"
expect "guard 1: ... after the VERIFY_KEYS line" "$(sed -n 2p "$W/.git/hooks/pre-push" | cut -c1-12)" "VERIFY_KEYS="
expect "guard 1: ... and writes no commit-msg" "$([ -e "$W/.git/hooks/commit-msg" ] && echo yes || echo no)" "no"
expect "guard 1: ... and prints the three lines it printed before" "$GOUT" "installed pre-push, pre-commit and prepare-commit-msg in .git/hooks, where no checkout can replace them
the commit hook stays inert until gates.commit_guard is 'required' or 'warn'
the hooks are not committed: each clone runs 'keel guard install' for itself"

newfx
ginst install --leak-guard
expect "guard 1: install --leak-guard: exit 0" "$GRC" "0"
expect "guard 1: ... writes LEAK_GUARD=1 on line 3" "$(line3)" "LEAK_GUARD=1"
expect "guard 1: ... and an executable commit-msg" "$([ -x "$W/.git/hooks/commit-msg" ] && echo yes || echo no)" "yes"
# shellcheck disable=SC2016
has "guard 1: ... carrying keel's mark" "$(cat "$W/.git/hooks/commit-msg")" 'installed by `keel guard install`'
has "guard 1: ... printing the four-hook line" "$GOUT" \
  "installed pre-push, pre-commit, prepare-commit-msg and commit-msg in .git/hooks, where no checkout can replace them"
has "guard 1: ... and the leak guard line" "$GOUT" \
  'the leak guard is on: each push and each commit message is checked against the deny list'

# ---- guard 2: a reinstall keeps the choice -----------------------------------------------------------
rm -f "$W/.git/hooks/commit-msg"
ginst install
expect "guard 2: a plain reinstall keeps LEAK_GUARD=1" "$(line3)" "LEAK_GUARD=1"
expect "guard 2: ... and rewrites commit-msg" "$([ -x "$W/.git/hooks/commit-msg" ] && echo yes || echo no)" "yes"
has "guard 2: ... and says the leak guard is on" "$GOUT" 'the leak guard is on: each push'
ginst install --no-leak-guard
expect "guard 2: --no-leak-guard: exit 0" "$GRC" "0"
expect "guard 2: ... writes LEAK_GUARD=0" "$(line3)" "LEAK_GUARD=0"
expect "guard 2: ... removes keel's commit-msg" "$([ -e "$W/.git/hooks/commit-msg" ] && echo yes || echo no)" "no"
has "guard 2: ... and says so" "$GOUT" "the leak guard is off; removed keel's commit-msg"
ginst install
expect "guard 2: a plain install after it stays off" "$(line3)" "LEAK_GUARD=0"
ginst install --leak-guard --no-leak-guard
expect "guard 2: both flags together: exit 1" "$GRC" "1"

# ---- guard 3: another tool's commit-msg --------------------------------------------------------------
newfx
printf '#!/bin/sh\nexit 0\n' > "$W/.git/hooks/commit-msg"; chmod +x "$W/.git/hooks/commit-msg"
ginst install --leak-guard
expect "guard 3: --leak-guard over another tool's commit-msg: exit 1" "$GRC" "1"
has "guard 3: ... gives guard_foreign_hook's message" "$GOUT" \
  ".git/hooks/commit-msg is another tool's hook, and installing would overwrite it. Remove or rename it, then re-run."
expect "guard 3: ... and writes nothing" "$([ -e "$W/.git/hooks/pre-push" ] && echo yes || echo no)" "no"
expect "guard 3: ... leaving the other tool's hook as it was" "$(cat "$W/.git/hooks/commit-msg")" "#!/bin/sh
exit 0"
ginst install
expect "guard 3: a plain install ignores it: exit 0" "$GRC" "0"
expect "guard 3: ... writes LEAK_GUARD=0" "$(line3)" "LEAK_GUARD=0"
expect "guard 3: ... and leaves it as it was" "$(cat "$W/.git/hooks/commit-msg")" "#!/bin/sh
exit 0"
ginst install --no-leak-guard
expect "guard 3: --no-leak-guard leaves it too" "$(cat "$W/.git/hooks/commit-msg")" "#!/bin/sh
exit 0"

# ---- guard 4: the pre-push hook with the leak guard on -----------------------------------------------
newfx
g checkout -q -b leaky
commit_file 'fix: Quillbank retry' a.txt 'a\n'
g checkout -q -b clean origin/main
commit_file 'feat: clean change' b.txt 'b\n'
ginst install --leak-guard
hook_push "$KP" leaky
expect "guard 4: a branch whose message names the client: exit 1" "$HRC" "1"
has "guard 4: ... names the deny list line" "$HOUT" 'deny list line 3'
has "guard 4: ... and the refusal" "$HOUT" 'keel guard: push refused by the leak guard.'
has "guard 4: ... and the way out" "$HOUT" 'To push anyway, deliberately and on the record:  git push --no-verify'
has "guard 4: ... and the Claude-Session remedy" "$HOUT" "git rebase <upstream> --exec 'git commit --amend --no-edit'"
lacks "guard 4: ... and never the client name" "$HOUT" "Quillbank"
hook_push "$KP" clean
expect "guard 4: a clean branch: exit 0" "$HRC" "0"
has "guard 4: ... prints the mode line" "$HOUT" 'leak guard: deny list loaded'
has "guard 4: ... and the supply chain scan still runs" "$HOUT" 'keel guard: scanning before push'
HOUT="$( cd "$W" && HOME="$H" KEEL_DENY_FILE="$DF" PATH="$KP" .git/hooks/pre-push </dev/null 2>&1 )"; HRC=$?
expect "guard 4: run by hand with no arguments: exit 0" "$HRC" "0"
has "guard 4: ... still prints the mode line" "$HOUT" 'leak guard: deny list loaded'

# ---- guard 5: generic mode lets a clean push through, and says so ------------------------------------
DF="$H/absent.txt"
hook_push "$KP" clean
expect "guard 5: no deny list, a clean push: exit 0" "$HRC" "0"
has "guard 5: ... says there is no deny list" "$HOUT" 'WARNING no deny list'

# ---- guard 6: fail closed when the leak guard cannot run ---------------------------------------------
DF="$H/deny.txt"
hook_push "$NOKEEL" clean
expect "guard 6: leak guard on, no keel on PATH: exit 1" "$HRC" "1"
has "guard 6: ... says nothing was checked" "$HOUT" \
  'keel guard: the leak guard is on and keel is not on PATH, so nothing was checked. Push refused.'
hook_push "$TMP/oldpush:$NOKEEL" clean
expect "guard 6: leak guard on, a keel without scan --leaks: exit 1" "$HRC" "1"
has "guard 6: ... says it is too old" "$HOUT" \
  'keel guard: the keel on PATH is too old for the leak guard, so nothing was checked. Push refused.'
ginst install --no-leak-guard
hook_push "$NOKEEL" clean
expect "guard 6: leak guard off, no keel on PATH: exit 0 as before" "$HRC" "0"
has "guard 6: ... allowed, as before" "$HOUT" 'keel is not on PATH, so nothing was scanned. Push allowed.'
hook_push "$TMP/oldpush:$NOKEEL" clean
expect "guard 6: leak guard off, a keel without scan --leaks: exit 0 as before" "$HRC" "0"
lacks "guard 6: ... and no leak guard line" "$HOUT" 'leak guard'

# ---- guard 7: the commit-msg hook ---------------------------------------------------------------------
newfx
ginst install --leak-guard
printf 'feat: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_example\n' \
  > "$TMP/msg1.txt"
cm "$KP" --allow-empty -F "$TMP/msg1.txt"
expect "guard 7: a message with the trailer: the commit is made" "$CRC" "0"
printf 'feat: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nSigned-off-by: Test Owner <owner@example.com>\n' \
  > "$TMP/want1.txt"
body_of HEAD > "$TMP/got1.txt"
expect "guard 7: ... the message is exactly the expected one" "$(cmp "$TMP/got1.txt" "$TMP/want1.txt" 2>&1 && echo same)" "same"
before="$(g rev-parse HEAD)"
cm "$KP" --amend --no-edit --allow-empty
body_of HEAD > "$TMP/got1b.txt"
expect "guard 7: an amend --no-edit leaves the message unchanged" "$(cmp "$TMP/got1b.txt" "$TMP/want1.txt" 2>&1 && echo same)" "same"
expect "guard 7: ... and the amend succeeded" "$CRC" "0"
printf 'feat: y\n\nclaude-session: x\nKeep: this line\n' > "$TMP/msg2.txt"
cm "$KP" --allow-empty -F "$TMP/msg2.txt"
printf 'feat: y\n\nKeep: this line\nSigned-off-by: Test Owner <owner@example.com>\n' > "$TMP/want2.txt"
body_of HEAD > "$TMP/got2.txt"
expect "guard 7: a lower case claude-session line is removed too" "$(cmp "$TMP/got2.txt" "$TMP/want2.txt" 2>&1 && echo same)" "same"
before="$(g rev-parse HEAD)"
printf 'feat: z\n\nSee Quillbank notes\n' > "$TMP/msg3.txt"
cm "$KP" --allow-empty -F "$TMP/msg3.txt"
expect "guard 7: a message naming the client: the commit fails" "$CRC" "1"
expect "guard 7: ... and HEAD is unchanged" "$(g rev-parse HEAD)" "$before"
has "guard 7: ... with the commit-refused line" "$COUT" \
  'keel guard: commit refused by the leak guard. The message is kept in .git/COMMIT_EDITMSG; edit it and commit again.'
has "guard 7: ... and the deny list line" "$COUT" 'deny list line 3'
lacks "guard 7: ... never the client name" "$COUT" "Quillbank"
printf 'feat: clean\n' > "$TMP/msg4.txt"
cm "$NOKEEL" --allow-empty -F "$TMP/msg4.txt"
expect "guard 7: no keel on PATH: the commit fails" "$CRC" "1"
has "guard 7: ... with the cannot-check line" "$COUT" \
  'keel guard: the leak guard is on and the keel on PATH cannot check a message, so nothing was checked. Commit refused.'
expect "guard 7: ... and HEAD is unchanged" "$(g rev-parse HEAD)" "$before"
cm "$TMP/oldpush:$NOKEEL" --allow-empty -F "$TMP/msg4.txt"
expect "guard 7: an old keel that exits 0 for anything: the commit fails" "$CRC" "1"
has "guard 7: ... with the same line" "$COUT" 'cannot check a message, so nothing was checked. Commit refused.'
cm "$TMP/oldmsg:$NOKEEL" --allow-empty -F "$TMP/msg4.txt"
expect "guard 7: a keel with scan --leaks and not scan --leaks-message: the commit fails" "$CRC" "1"
cm "$KP" --allow-empty -F "$TMP/msg4.txt"
expect "guard 7: a clean message with a usable keel: the commit is made" "$CRC" "0"

# ---- guard 8: keel guard status -----------------------------------------------------------------------
newfx
ginst install
ginst status
lacks "guard 8: a repository that never opted in: no leak guard line" "$GOUT" 'leak guard:'
ginst install --leak-guard
ginst status
has "guard 8: on, deny list loaded" "$GOUT" 'leak guard: on, deny list loaded (3 patterns)'
DF="$H/absent.txt"
ginst status
has "guard 8: on, no deny list" "$GOUT" 'leak guard: on, WARNING no deny list at ~/absent.txt, generic patterns only'
DF="$H/deny.txt"
rm -f "$W/.git/hooks/commit-msg"
ginst status
has "guard 8: on, commit-msg missing" "$GOUT" \
  "leak guard: on, but commit-msg is missing or not keel's. Re-run 'keel guard install --leak-guard'"
printf '#!/bin/sh\nexit 0\n' > "$W/.git/hooks/commit-msg"; chmod +x "$W/.git/hooks/commit-msg"
ginst status
has "guard 8: on, commit-msg not keel's" "$GOUT" "leak guard: on, but commit-msg is missing or not keel's."

# ---- guard 9: uninstall --------------------------------------------------------------------------------
newfx
ginst install --leak-guard
ginst uninstall
expect "guard 9: uninstall removes keel's commit-msg" "$([ -e "$W/.git/hooks/commit-msg" ] && echo yes || echo no)" "no"
expect "guard 9: ... and the pre-push" "$([ -e "$W/.git/hooks/pre-push" ] && echo yes || echo no)" "no"
printf '#!/bin/sh\nexit 0\n' > "$W/.git/hooks/commit-msg"; chmod +x "$W/.git/hooks/commit-msg"
ginst uninstall
expect "guard 9: uninstall leaves another tool's commit-msg" "$(cat "$W/.git/hooks/commit-msg")" "#!/bin/sh
exit 0"

# ---- guard 10: the generated hooks are clean ------------------------------------------------------------
newfx
ginst install --leak-guard
if command -v shellcheck >/dev/null 2>&1; then
    for hk in pre-push commit-msg; do
        sc="$(shellcheck -s bash "$W/.git/hooks/$hk" 2>&1)"
        expect "guard 10: shellcheck -s bash reports nothing on the generated $hk" "$sc" ""
    done
else
    printf '  SKIP  guard 10: shellcheck is not installed\n'
fi
if [ -x /bin/bash ] && case "$(/bin/bash --version 2>/dev/null | sed -n 1p)" in *"version 3.2"*) true ;; *) false ;; esac; then
    for hk in pre-push commit-msg; do
        bn="$(/bin/bash -n "$W/.git/hooks/$hk" 2>&1)"
        expect "guard 10: /bin/bash -n parses the generated $hk" "$bn" ""
    done
else
    printf '  SKIP  guard 10: /bin/bash is not bash 3.2 here\n'
fi

# ---- guard 11: help and the documentation ----------------------------------------------------------------
has "guard 11: the guard line of help names the flags" "$HELP" \
  '  guard install [--leak-guard|--no-leak-guard]|status|uninstall   pre-push hook: the scan, and no pushes to the default branch, plus a pre-commit hook that stays off until gates.commit_guard turns it on'
gsection="$(awk '/^keel guard install /{f=1} /^### keel ci-review/{f=0} f' "$DOC")"
has "guard 11: the install document describes the flag" "$gsection" '--leak-guard'
has "guard 11: ... the commit-msg hook" "$gsection" 'commit-msg'
has "guard 11: ... the reversal of the 2026-09-27 choice" "$gsection" '2026-09-27'
has "guard 11: ... the main working copy and never a worktree" "$gsection" 'never in a worktree'
has "guard 11: ... the residual, GitHub-made text" "$gsection" 'release notes'

# ==== a deny list holding a pattern that is not valid: every scan refuses ===========================
# The broken list, line 1 a comment, line 2 Quillbank, line 3 an unclosed parenthesis, line 4
# \bQBK\b, line 5 an unclosed bracket. grep exits 2 on lines 3 and 5, and the guard used to discard
# that.
write_broken() {
    printf '%s\n' '# invented identifiers, two of them not valid' 'Quillbank' 'Quill(bank' \
      '\bQBK\b' 'zephyr[ledger' > "$1"
}
BROKEN_OUT='leak guard: deny list loaded from ~/broken.txt (2 patterns)
leak guard: deny list line 3: not a valid pattern, so it checked nothing
leak guard: deny list line 5: not a valid pattern, so it checked nothing
leak guard: refusing to scan: fix the deny list at ~/broken.txt'
REFUSE='leak guard: refusing to scan: fix the deny list at ~/broken.txt'

# ---- invalid 1: keel scan --leaks and --leaks-message refuse ---------------------------------------
newfx
BL="$H/broken.txt"; write_broken "$BL"; DF="$BL"
leaks origin
expect "invalid 1: scan --leaks origin: exit 2" "$RC" "2"
expect "invalid 1: ... prints the mode line, a line per invalid pattern and the refusal" "$OUT" "$BROKEN_OUT"

g checkout -q -b topic
commit_file 'fix: Quillbank retry' a.txt 'a\n'
leaks origin "$(g rev-parse HEAD)":refs/heads/topic
expect "invalid 1: a push whose message names the client: exit 2" "$RC" "2"
expect "invalid 1: ... the same four lines, no finding and no checked line" "$OUT" "$BROKEN_OUT"
lacks "invalid 1: ... and none of the pattern text" "$OUT" 'Quill('
lacks "invalid 1: ... nor the other pattern" "$OUT" 'zephyr['

printf 'chore: tidy\n\nQBK follow-up\n' > "$TMP/inv-m1.txt"
lmsg "$TMP/inv-m1.txt"
expect "invalid 1: scan --leaks-message: exit 2" "$RC" "2"
expect "invalid 1: ... the same four lines" "$OUT" "$BROKEN_OUT"
lacks "invalid 1: ... and none of the pattern text" "$OUT" 'Quill('

# ---- invalid 2: the hooks fail closed, their handling unchanged ------------------------------------
newfx
g checkout -q -b clean origin/main
commit_file 'feat: clean change' b.txt 'b\n'
ginst install --leak-guard
BL="$H/broken.txt"; write_broken "$BL"; DF="$BL"
hook_push "$KP" clean
expect "invalid 2: pre-push over a clean branch: exit 1" "$HRC" "1"
has "invalid 2: ... names the deny list to fix" "$HOUT" "$REFUSE"
has "invalid 2: ... and the push refusal" "$HOUT" 'keel guard: push refused by the leak guard.'
lacks "invalid 2: ... and the supply chain scan never ran" "$HOUT" 'keel guard: scanning before push'
HOUT="$( cd "$W" && HOME="$H" KEEL_DENY_FILE="$DF" PATH="$KP" .git/hooks/pre-push </dev/null 2>&1 )"; HRC=$?
expect "invalid 2: run by hand with no arguments, as a delete-only push is: exit 1" "$HRC" "1"
has "invalid 2: ... with the refusing line" "$HOUT" "$REFUSE"
before="$(g rev-parse HEAD)"
printf 'feat: clean\n' > "$TMP/inv-m2.txt"
cm "$KP" --allow-empty -F "$TMP/inv-m2.txt"
expect "invalid 2: commit-msg over a clean message: the commit fails" "$CRC" "1"
expect "invalid 2: ... and HEAD is unchanged" "$(g rev-parse HEAD)" "$before"
has "invalid 2: ... with the refusing line" "$COUT" "$REFUSE"
has "invalid 2: ... and the nothing-was-checked line" "$COUT" \
  'keel guard: the leak guard is on and the keel on PATH cannot check a message, so nothing was checked. Commit refused.'

# ---- invalid 3: keel guard status says the scans refuse --------------------------------------------
ginst status
has "invalid 3: on, two invalid patterns" "$GOUT" \
  "leak guard: on, but 2 deny list pattern(s) are not valid, so scans refuse. See 'keel scan --leaks-message <file>'"
rm -f "$W/.git/hooks/commit-msg"
ginst status
has "invalid 3: ... with commit-msg missing, the commit-msg line" "$GOUT" \
  "leak guard: on, but commit-msg is missing or not keel's."
lacks "invalid 3: ... and not the invalid pattern line" "$GOUT" 'are not valid'
ginst install --leak-guard
DF="$H/deny.txt"
ginst status
has "invalid 3: the three-pattern list still reads loaded" "$GOUT" 'leak guard: on, deny list loaded (3 patterns)'

# ---- invalid 4: the document says so -------------------------------------------------------------------
section="$(awk '/^keel scan --leaks </{f=1} /^keel plan status/{f=0} f' "$DOC")"
has "invalid 4: the install document describes the refusal" "$section" 'not a valid pattern'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
