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
expect "15: one binary test and one grep per pattern, 6 calls, not one per file" \
  "$(wc -l < "$TMP/grep.log" | tr -d ' ')" "6"

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

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
