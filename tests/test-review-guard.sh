#!/usr/bin/env bash
# shellcheck disable=SC2016  # commands are single-quoted, so $TMPDIR and $wt reach the hook
# Tests for hooks/review-guard, which refuses a keel reviewer the git commands that would change the
# author's checkout or the state every worktree shares, and refuses every other subagent a
# stash-writing `git stash`. Task 1 of docs/plans/2026-10-17-reviewer-git-guard.md, behaviours 2 to
# 6, and tasks 1, 1b, 4, 6 and 8 of docs/plans/2026-11-02-hold-a-subagents-git-stash.md, behaviours
# 1 to 7, 1 to 3, 1 to 5, 1 to 5 and 1 to 3, one case per example there.
#
# Every case feeds the hook a PreToolUse event as JSON on stdin, as tests/test-sensitive-guard.sh
# feeds its hook, and asserts on what it prints. A refusal is checked by its JSON and an allowance
# by the absence of any output and a zero exit, because a guard that prints nothing is otherwise
# indistinguishable from one that is not installed. The first case is that it is installed.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$ROOT/hooks/review-guard"
REVIEWER=keel:keel-reviewer
pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# A PreToolUse event for one Bash call, in the shape the 2026-10-17 probe logged:
# event <agent_type> <command> <cwd> [agent_id]. An agent type of `-` leaves agent_id and
# agent_type out, which is what a call from the main session looks like. A subagent's event carries
# agent_id `a1` unless a fourth argument names another; `-` there leaves agent_id out, which is what
# the main session started with `--agent` looks like: its own agent_type, and no agent_id.
# Built with json.dumps, because a command carrying quotes or newlines is invalid JSON written by
# hand, and the hook would then refuse it as unreadable while the case passed for the wrong reason.
event() {
    AT="$1" CMD="$2" CWD="$3" AID="${4-a1}" python3 -c '
import json, os
ev = {"session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Bash",
      "tool_input": {"command": os.environ["CMD"]}, "cwd": os.environ["CWD"]}
if os.environ["AT"] != "-":
    if os.environ["AID"] != "-":
        ev["agent_id"] = os.environ["AID"]
    ev["agent_type"] = os.environ["AT"]
print(json.dumps(ev))'
}

# Run the hook on raw input from <dir>. TMPDIR is removed, so `${TMPDIR:-/tmp}` means /tmp unless a
# case passes TMPDIR=... itself: the developer's own TMPDIR would otherwise decide what a case
# tests. Any further NAME=value arguments go into the hook's environment. Sets out and rc.
out=""
rc=0
run() {
    local input="$1" dir="$2"
    shift 2
    out="$(printf '%s' "$input" | ( cd "$dir" && env -u TMPDIR "$@" "$GUARD" ) 2>/dev/null)"
    rc=$?
}

deny_re='"permissionDecision": *"deny"'
expect_deny() {   # expect_deny <name>, after run
    if [ "$rc" -eq 0 ] && [[ $out =~ $deny_re ]]; then ok "$1"
    else bad "$1" "expected a deny with exit 0, got rc $rc: ${out:0:100}"; fi
}
expect_allow() {  # expect_allow <name>, after run
    if [ "$rc" -eq 0 ] && [ -z "$out" ]; then ok "$1"
    else bad "$1" "expected exit 0 and no output, got rc $rc: ${out:0:100}"; fi
}
# deny <name> <agent> <command> <dir> [NAME=value...] and allow, the same.
deny()  { local n="$1" ev; ev="$(event "$2" "$3" "$4")"; local d="$4"; shift 4; run "$ev" "$d" "$@"; expect_deny "$n"; }
allow() { local n="$1" ev; ev="$(event "$2" "$3" "$4")"; local d="$4"; shift 4; run "$ev" "$d" "$@"; expect_allow "$n"; }

# The reason the last run gave, read as JSON so that escaping cannot make a substring match lie.
reason() {
    printf '%s' "$out" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"])
except Exception:
    pass'
}
reason_has() {    # reason_has <name> <text>, after run
    local r; r="$(reason)"
    if [[ $r == *"$2"* ]]; then ok "$1"; else bad "$1" "reason lacks '$2': ${r:0:160}"; fi
}

# The author's checkout. mktemp puts it under the temp directory, as a `claude plugin eval`
# workspace is, which is exactly why "under the temp directory" alone cannot mean "the reviewer's".
repo="$(mktemp -d)"
git -C "$repo" init -q
mkdir -p "$repo/src"
: > "$repo/src/a.sh"
# A checkout under /tmp by name, for the example that says so.
tmprepo="$(mktemp -d /tmp/review-guard.XXXXXX)"
git -C "$tmprepo" init -q
# A PATH carrying bash and nothing else. It must carry bash: the shebang is `/usr/bin/env bash`,
# and env resolves bash through PATH, so an empty shim stops the hook starting at all rather than
# exercising the branch under test.
shim="$(mktemp -d)"
ln -s "$(command -v bash)" "$shim/bash"
# pyfail is made further down; it is named here, empty until then, so an early exit still cleans it.
pyfail=""
pyrec=""
trap 'rm -rf "$repo" "$tmprepo" "$shim" ${pyfail:+"$pyfail"} ${pyrec:+"$pyrec"}' EXIT

if [ -x "$GUARD" ]; then ok "hooks/review-guard exists and is executable"
else bad "hooks/review-guard exists and is executable" "missing or not executable, so every allow below proves nothing"; fi

# Under /bin/bash by name, because the shebang takes whichever bash PATH finds first, and on macOS
# that is bash 3.2 for a user and bash 5 for anyone with Homebrew's ahead of it. bash 3.2 scans a
# heredoc inside `$( )` for balanced backticks, so one in the Python's comments stopped the whole
# file parsing, and every reviewer Bash call exited 2.
if [ -x /bin/bash ]; then
    run "$(event "$REVIEWER" 'git stash' "$repo")" "$repo" /bin/bash
    expect_deny "under /bin/bash ($(/bin/bash -c 'echo "$BASH_VERSION"')), git stash is refused"
fi

# --- behaviour 2: the main session is never touched, and every other subagent loses the stash ---
# The main session's calls carry no agent_id, and no agent_type unless it was started with
# `--agent`, and it must never be blocked: it is the author and the coordinator. A subagent that is
# not the reviewer is refused the stash and nothing else; its cases are in their own section below.
allow "the main session's git stash is untouched"          -                   'git stash' "$repo"
deny  "a general-purpose agent's git stash is refused"     general-purpose     'git stash' "$repo"
deny  "keel-fanout's git stash is refused"                 keel:keel-fanout    'git stash' "$repo"

# --- behaviour 3: shared state is refused wherever it runs --------------------------------------
deny  "git stash list && git stash is refused"             "$REVIEWER" 'git stash list && git stash' "$repo"
deny  "a commit in the reviewer's own worktree is refused" "$REVIEWER" 'cd /tmp/wt && git commit -m x' "$repo"
allow "git merge-base is not git merge"                    "$REVIEWER" 'git merge-base main HEAD' "$repo"
allow "git tag with no arguments reads"                    "$REVIEWER" 'git tag' "$repo"
allow "git tag -l reads"                                   "$REVIEWER" 'git tag -l "v*"' "$repo"
allow "git tag --list reads"                               "$REVIEWER" 'git tag --list' "$repo"
deny  "git tag <name> is refused"                          "$REVIEWER" 'git tag v1' "$repo"
# Every word on the list, and each behind git's global options, which come before the subcommand
# and would otherwise hide it.
for w in stash commit push merge rebase cherry-pick am revert update-ref config; do
    deny "git $w is refused even in a temp worktree" "$REVIEWER" "git -C /tmp/rv $w" "$repo"
done
deny  "global options do not hide the subcommand" "$REVIEWER" 'git --no-pager -c a.b=c --git-dir=/tmp/rv/.git --work-tree /tmp/rv push' "$repo"
for f in -d -D -m -M -c -C -f; do
    deny "git branch $f is refused" "$REVIEWER" "git branch $f topic" "$repo"
done
allow "git branch with no flag reads"   "$REVIEWER" 'git branch' "$repo"
allow "git branch -a reads"             "$REVIEWER" 'git branch -a' "$repo"
# More shared state, from the first review: a pull merges into a ref, notes are refs, a branch name
# with no list flag creates a branch, an upstream or a description is config, and a short-flag
# cluster carries its flags. Run in the reviewer's own worktree, since none of it is shelter.
for c in 'pull' 'notes add -m x' 'notes remove' 'branch topic' 'branch -u origin/x topic' \
         'branch --set-upstream-to=origin/x' 'branch --unset-upstream' 'branch --edit-description' \
         'branch -Df topic' 'worktree prune'; do
    deny "git $c is refused even in a temp worktree" "$REVIEWER" "git -C /tmp/rv $c" "$repo"
done
for c in 'notes' 'notes list' 'notes show HEAD' 'branch -l' 'branch --list "x*"' 'branch -r' \
         'branch -v' 'branch -vv' 'branch --contains HEAD' 'branch --merged main' \
         'branch --no-merged main' 'branch --show-current' 'branch --points-at HEAD'; do
    allow "git $c reads" "$REVIEWER" "git $c" "$repo"
done

# --- behaviour 4: an index or working tree only in the reviewer's own worktree ------------------
deny  "git checkout -- src/a.sh in the author's checkout is refused" "$REVIEWER" 'git checkout -- src/a.sh' "$repo"
deny  "git reset --hard in a checkout under /tmp is refused"         "$REVIEWER" 'git reset --hard' "$tmprepo"
allow 'cd "${TMPDIR:-/tmp}/rv" && git checkout is allowed'           "$REVIEWER" 'cd "${TMPDIR:-/tmp}/rv" && git checkout -- src/a.sh' "$repo"
allow "git -C /tmp/rv reset --hard is allowed"                       "$REVIEWER" 'git -C /tmp/rv reset --hard' "$repo"
allow "git diff HEAD piped into git -C the temp worktree apply"      "$REVIEWER" 'git diff HEAD | git -C "${TMPDIR:-/tmp}/rv" apply' "$repo"
deny  'git -C "$wt" apply is refused, $wt being unresolvable'        "$REVIEWER" 'wt=$(mktemp -d); git -C "$wt" apply' "$repo"
reason_has "the unresolvable reason says how to write the path"      '"${TMPDIR:-/tmp}/<name>"'
deny  "cd -, back to the checkout, is refused"                       "$REVIEWER" 'cd /tmp/x; cd -; git reset' "$repo"
for w in add rm mv reset restore checkout switch clean apply; do
    deny "git $w in the author's checkout is refused" "$REVIEWER" "git $w x" "$repo"
done
deny  "a temp path inside the author's checkout is not the reviewer's" "$REVIEWER" "git -C $tmprepo/sub reset --hard" "$tmprepo"
# The split is shlex's, so quoting holds: a separator inside quotes is not a separator, and a quoted
# `; git stash` inside an argument is data rather than a second command.
allow "a quoted separator stays inside its argument"                 "$REVIEWER" 'git -C /tmp/rv add -- "x; git stash"' "$repo"
# A newline separates commands as `;` does.
deny  "a newline ends the command before it"                         "$REVIEWER" $'git -C /tmp/rv status\ngit reset --hard' "$repo"
deny  "a cd does not carry across a newline"                         "$REVIEWER" $'cd /tmp/rv\ngit reset --hard' "$repo"
allow "a newline starts a command, so a cd after one is read as a cd" "$REVIEWER" $'git status\ncd /tmp/rv && git reset --hard' "$repo"
# A cd carries only across `&&`. After `;`, a newline or `||`, a cd that failed or was skipped
# leaves bash in the author's checkout, so a target moved by the chain before is unresolved.
deny  "a cd does not carry across ;"                                 "$REVIEWER" 'cd /tmp/nonexist-zz; git reset --hard' "$repo"
deny  "a cd does not carry across ||"                                "$REVIEWER" 'cd /tmp/nonexist-zz || git reset --hard' "$repo"
deny  "a skipped cd does not carry across ;"                         "$REVIEWER" 'false && cd /tmp/rv; git checkout -- .' "$repo"
deny  'cd "${TMPDIR:-/tmp}/rv"; git checkout is refused'             "$REVIEWER" 'cd "${TMPDIR:-/tmp}/rv"; git checkout -- .' "$repo"
reason_has "the reason says to join the cd with &&"                  'with `&&`'
allow 'cd "${TMPDIR:-/tmp}/rv" && git checkout -- . is allowed'      "$REVIEWER" 'cd "${TMPDIR:-/tmp}/rv" && git checkout -- .' "$repo"
# A cd inside a subshell or a command substitution does not move the commands after it.
deny  "a cd in a subshell does not carry out of it"                  "$REVIEWER" '(cd /tmp/rv); git reset --hard' "$repo"
deny  "an unquoted command substitution is not a resolvable target"  "$REVIEWER" 'git -C $(pwd) reset --hard' "$repo"
deny  "git inside a command substitution is still read"              "$REVIEWER" 'echo "$(git stash)"' "$repo"
# The temp directory is TMPDIR when the hook's environment sets it, and /tmp when it does not.
allow '$TMPDIR expands from the hook environment'                    "$REVIEWER" 'git -C "$TMPDIR/rv" reset --hard' "$repo" TMPDIR=/nonexistent-review-tmp
allow "a literal path under TMPDIR counts as temp"                   "$REVIEWER" 'git -C /nonexistent-review-tmp/rv reset --hard' "$repo" TMPDIR=/nonexistent-review-tmp
deny  "the same path is not temp when TMPDIR is unset"               "$REVIEWER" 'git -C /nonexistent-review-tmp/rv reset --hard' "$repo"
# macOS sets TMPDIR with a trailing slash, which must not make the joined path look foreign.
allow "a TMPDIR with a trailing slash still counts"                  "$REVIEWER" 'git -C "${TMPDIR:-/tmp}/rv" reset --hard' "$repo" TMPDIR=/nonexistent-review-tmp/
# A redirection glued to a closing parenthesis must still close the subshell.
deny  "a subshell closed by )> does not carry its cd, across ;"      "$REVIEWER" '(cd /tmp/rv && git status)>/dev/null; git reset --hard' "$repo"
deny  "a subshell closed by )> does not carry its cd, across &&"     "$REVIEWER" '(cd /tmp/rv && git status)>/dev/null && git reset --hard' "$repo"
# More commands that change an index or a working tree, from the first review.
for c in 'stage x' 'bisect start' 'checkout-index -a' 'read-tree HEAD' 'update-index --refresh' \
         'sparse-checkout set x' 'submodule update' 'symbolic-ref HEAD refs/heads/x'; do
    deny  "git $c in the author's checkout is refused" "$REVIEWER" "git $c" "$repo"
    allow "git $c in the reviewer's worktree is allowed" "$REVIEWER" "git -C /tmp/rv $c" "$repo"
done
allow "git submodule status reads"                                   "$REVIEWER" 'git submodule status' "$repo"
deny  "git worktree move of a path outside temp is refused"          "$REVIEWER" 'git worktree move /opt/a /tmp/b' "$repo"
allow "git worktree move of the reviewer's worktree is allowed"      "$REVIEWER" 'git worktree move "${TMPDIR:-/tmp}/rv" "${TMPDIR:-/tmp}/rv2"' "$repo"
# The environment moves git's target as the global options do.
deny  "GIT_WORK_TREE=<checkout> is refused"                          "$REVIEWER" "GIT_WORK_TREE=$repo git -C /tmp/rv checkout -- ." "$repo"
deny  "GIT_DIR=<checkout>/.git is refused"                           "$REVIEWER" "GIT_DIR=$repo/.git git -C /tmp/rv reset" "$repo"
deny  "GIT_INDEX_FILE=<checkout>/.git/index is refused"              "$REVIEWER" "GIT_INDEX_FILE=$repo/.git/index git -C /tmp/rv add x" "$repo"
allow "GIT_WORK_TREE=/tmp/rv is the reviewer's own"                  "$REVIEWER" 'GIT_WORK_TREE=/tmp/rv git -C /tmp/rv checkout -- .' "$repo"
# Regressions the first review asked to pin: git is found wherever it sits in a command.
deny  "env X=1 git stash is refused"                                 "$REVIEWER" 'env X=1 git stash' "$repo"
deny  "command git stash is refused"                                 "$REVIEWER" 'command git stash' "$repo"
deny  "xargs git checkout in the checkout is refused"                "$REVIEWER" 'printf x | xargs git checkout' "$repo"
deny  "git in backticks is refused"                                  "$REVIEWER" 'echo `git stash`' "$repo"
deny  "a backgrounded git stash is refused"                          "$REVIEWER" 'git stash &' "$repo"
deny  "/usr/bin/git stash is refused"                                "$REVIEWER" '/usr/bin/git stash' "$repo"
deny  "a cd in a pipeline does not carry"                            "$REVIEWER" 'cd /tmp/rv | git reset --hard' "$repo"
deny  "a backgrounded cd does not carry"                             "$REVIEWER" 'cd /tmp/rv & git reset --hard' "$repo"
# The stated limit: a heredoc body is read as commands, which errs toward refusing.
deny  "a git stash in a heredoc body is refused, the stated limit"   "$REVIEWER" $'cat <<EOF\ngit stash\nEOF' "$repo"

# --- from the quality re-review -----------------------------------------------------------------
# A cd on the right of `||` runs only when the left failed, so the `&&` after it may run in the
# author's checkout: its target is unresolved.
deny  "a cd after || does not carry: true ||"                        "$REVIEWER" 'true || cd /tmp/rv && git reset --hard' "$repo"
deny  "a cd after || does not carry: git status ||"                  "$REVIEWER" 'git -C /tmp/rv status || cd /tmp/rv && git reset --hard' "$repo"
deny  "a cd after || does not carry: && false ||"                    "$REVIEWER" 'git status && false || cd /tmp/rv && git checkout -- .' "$repo"
# A separator with a redirection glued on is still a separator, and nothing after a cd can hide.
deny  "a ;> after a cd does not hide git stash"                      "$REVIEWER" 'cd /tmp/rv;>/dev/null git stash' "$repo"
deny  "a &&> after a cd does not hide git stash"                     "$REVIEWER" 'cd /tmp/rv&&>/dev/null git stash' "$repo"
deny  "a &&> after a cd does not hide git -C <checkout> reset"       "$REVIEWER" "cd /tmp/x &&>/dev/null git -C $repo reset --hard" "$repo"
# Bash reads `&&>` as `&&` then `>`, so the reset runs in /tmp/x, the reviewer's own: allowed.
allow "cd /tmp/x &&>/dev/null git reset --hard runs in /tmp/x"      "$REVIEWER" 'cd /tmp/x &&>/dev/null git reset --hard' "$repo"
deny  "git in a process substitution on a cd line is read"           "$REVIEWER" 'cd /tmp/rv <(git stash)' "$repo"
# Branches made by other commands are refs, shared, so refused anywhere.
for c in 'checkout -b x' 'checkout -B x' 'worktree add -b x /tmp/rv2' 'worktree add -B x /tmp/rv2' \
         'switch -c x' 'switch -C x' 'switch --create x' 'switch --force-create x' \
         'remote add o https://example.com/r.git' 'remote set-url origin x' 'remote remove origin' \
         'remote rename origin o' 'remote prune origin'; do
    deny "git $c is refused even in a temp worktree" "$REVIEWER" "git -C /tmp/rv $c" "$repo"
done
for c in 'remote' 'remote -v' 'remote show origin' 'remote get-url origin' \
         'symbolic-ref HEAD' 'symbolic-ref --short HEAD' \
         'branch --format "%(refname:short)"' 'branch --sort -committerdate' 'notes --ref x show'; do
    allow "git $c reads" "$REVIEWER" "git $c" "$repo"
done
deny  "git symbolic-ref -d HEAD in the checkout is refused"          "$REVIEWER" 'git symbolic-ref -d HEAD' "$repo"
# --color takes its value only after `=`, so the word after it is a branch name, created.
deny  "git branch --color topic is refused"                          "$REVIEWER" 'git -C /tmp/rv branch --color topic' "$repo"

# --- from the final review ----------------------------------------------------------------------
# A work tree named alone still writes the index of the repository git finds from where it runs,
# the author's: `git --work-tree=<tmp> reset --hard` turned a staged file untracked.
deny  "--work-tree=<tmp> reset from the checkout is refused"         "$REVIEWER" 'git --work-tree=/tmp/rvx reset --hard' "$repo"
deny  "--work-tree=<tmp> checkout from the checkout is refused"      "$REVIEWER" 'git --work-tree=/tmp/rvx checkout HEAD -- .' "$repo"
deny  "GIT_WORK_TREE=<tmp> add from the checkout is refused"         "$REVIEWER" 'GIT_WORK_TREE=/tmp/rvx git add -A' "$repo"
# A git dir named alone makes the directory git runs in the work tree, the author's checkout:
# `GIT_DIR=<tmp>/.git git clean -fd` deleted the author's untracked file.
deny  "GIT_DIR=<tmp>/.git clean from the checkout is refused"        "$REVIEWER" 'GIT_DIR=/tmp/rv/.git git clean -fd' "$repo"
deny  "--git-dir=<tmp>/.git clean from the checkout is refused"      "$REVIEWER" 'git --git-dir=/tmp/rv/.git clean -fd' "$repo"
allow "both named under temp is the reviewer's own"                  "$REVIEWER" 'git --git-dir=/tmp/rv/.git --work-tree=/tmp/rv reset --hard' "$repo"
allow "GIT_DIR and GIT_WORK_TREE both under temp is the reviewer's own" "$REVIEWER" 'GIT_DIR=/tmp/rv/.git GIT_WORK_TREE=/tmp/rv git add -A' "$repo"
# The agent type decides, not the command text: the main session naming the reviewer is untouched.
allow "the main session mentioning the reviewer is untouched"        -           'echo keel:keel-reviewer; git stash' "$repo"
# `git worktree add <path>` with no --detach, -b or -B creates a branch named after the path.
deny  "git worktree add <path> without --detach is refused"          "$REVIEWER" 'git worktree add "${TMPDIR:-/tmp}/rv"' "$repo"
deny  "git worktree add <path> HEAD without --detach is refused"     "$REVIEWER" 'git worktree add /tmp/rv HEAD' "$repo"
allow "git worktree add -d <path> HEAD is allowed"                   "$REVIEWER" 'git worktree add -d /tmp/rv HEAD' "$repo"
# Short-flag clusters carry their letters on checkout, switch and worktree add too.
deny  "git checkout -qb x is refused"                                "$REVIEWER" 'git -C /tmp/rv checkout -qb x' "$repo"
deny  "git checkout -fB x is refused"                                "$REVIEWER" 'git -C /tmp/rv checkout -fB x' "$repo"
deny  "git switch -qc x is refused"                                  "$REVIEWER" 'git -C /tmp/rv switch -qc x' "$repo"
deny  "git switch --create=x is refused"                             "$REVIEWER" 'git -C /tmp/rv switch --create=x' "$repo"
deny  "git worktree add -fb x is refused"                            "$REVIEWER" 'git worktree add -fb x /tmp/rv2' "$repo"
allow "git checkout -- -b is a path, not a flag"                     "$REVIEWER" 'git -C /tmp/rv checkout -- -b' "$repo"
# A fetch whose refspec names a local destination moves a shared ref; replace and filter-branch
# rewrite shared history. A plain fetch is allowed.
deny  "git fetch with a :destination refspec is refused"             "$REVIEWER" 'git -C /tmp/rv fetch . +HEAD:refs/heads/main' "$repo"
deny  "git fetch origin main:main is refused"                        "$REVIEWER" 'git fetch origin main:main' "$repo"
deny  "git replace is refused"                                       "$REVIEWER" 'git -C /tmp/rv replace HEAD HEAD~1' "$repo"
deny  "git filter-branch is refused"                                 "$REVIEWER" 'git -C /tmp/rv filter-branch --force HEAD' "$repo"
allow "git fetch is allowed"                                         "$REVIEWER" 'git fetch' "$repo"
allow "git -C /tmp/rv fetch origin is allowed"                       "$REVIEWER" 'git -C /tmp/rv fetch origin' "$repo"
allow "git fetch from a URL with a plain refspec is allowed"         "$REVIEWER" 'git fetch https://example.com/r.git main' "$repo"
# An empty destination after `:` names no local ref, so it moves none.
allow "git fetch origin main: is allowed"                            "$REVIEWER" 'git fetch origin main:' "$repo"
# A fetch option's value is not the repository: `1` here must not push the URL into the refspecs.
allow "git fetch --depth 1 <user@host:path URL> is allowed"               "$REVIEWER" 'git fetch --depth 1 git@example.com:a/b.git' "$repo"
allow "git fetch -j 4 <user@host:path URL> main is allowed"               "$REVIEWER" 'git fetch -j 4 git@example.com:a/b.git main' "$repo"
# The environment and the global option fill separate lists, so naming the same work tree or git
# dir both ways still leaves the other side unnamed, and where git runs is still checked.
deny  "GIT_WORK_TREE and --work-tree both naming temp still check the index" "$REVIEWER" 'GIT_WORK_TREE=/tmp/rv git --work-tree=/tmp/rv reset --hard' "$repo"
deny  "GIT_DIR and --git-dir both naming temp still check the work tree"     "$REVIEWER" 'GIT_DIR=/tmp/rv/.git git --git-dir=/tmp/rv/.git clean -fd' "$repo"

# --- behaviour 5: reading, and the worktree's own lifecycle -------------------------------------
for c in 'git diff' 'git log' 'git show' 'git status' \
         'git ls-files -z --others --exclude-standard | tar --null -T - -cf -' \
         'git worktree add --detach "${TMPDIR:-/tmp}/rv" HEAD' \
         'git worktree remove --force "${TMPDIR:-/tmp}/rv"'; do
    allow "allowed: $c" "$REVIEWER" "$c" "$repo"
done
deny  "git worktree remove outside the temp directory is refused" "$REVIEWER" 'git worktree remove --force /opt/rv' "$repo"
deny  "git worktree remove of the author's own tree is refused"   "$REVIEWER" "git worktree remove --force $tmprepo" "$tmprepo"

# --- behaviour 6: the refusal says what, why and what instead ------------------------------------
deny       "git stash is refused, for the reason check"  "$REVIEWER" 'git stash' "$repo"
reason_has "the reason names the command"                'git stash'
reason_has "the stash reason says it is shared"          'every worktree'
reason_has "the stash reason names the incident"         '2026-10-12'
reason_has "the reason says how to read instead"         'git diff'
reason_has "the reason says how to change your own"      'git -C <worktree>'
deny       "git reset in the checkout, for the reason check" "$REVIEWER" 'git reset --hard' "$repo"
reason_has "the tree reason names the command"           'git reset'
reason_has "the tree reason says where to work instead"  'cd <worktree> &&'

# Without python3 it cannot read the JSON, so it falls back to a word check on the raw input, and
# only when that input carries an agent_type field: the full word list when it names a keel
# reviewer, the stash alone for any other subagent, and nothing for the main session.
ev="$(event "$REVIEWER" 'git stash' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_deny "without python3 a reviewer's git stash is refused"
reason_has  "and the reason says it could not read its input" 'could not read its input'
reason_has  "and the reason says python3 is absent" 'python3 is absent'
reason_has  "and tells the reviewer to report items 5 and 6 as not done" 'report its items 5 and 6 as not done'
ev="$(event "$REVIEWER" 'git worktree add --detach /tmp/rv HEAD' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_deny "without python3 the rubric pass's worktree steps are refused"
ev="$(event "$REVIEWER" 'git --no-pager -C /tmp/rv reset --hard' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_deny "without python3 global options do not hide the word"
# The fallback's word list is the parser's, including the words the first review added.
for w in pull notes stage bisect checkout-index read-tree update-index sparse-checkout symbolic-ref \
         submodule remote replace filter-branch fetch; do
    ev="$(event "$REVIEWER" "git $w" "$repo")"
    run "$ev" "$repo" PATH="$shim"
    expect_deny "without python3 git $w is refused"
done
# A refspec fetch moves a local ref, and without the parser no fetch can be told from one.
ev="$(event "$REVIEWER" 'git -C /tmp/rv fetch . +HEAD:refs/heads/main' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_deny "without python3 a refspec fetch is refused"
ev="$(event "$REVIEWER" 'git diff' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_allow "without python3 a reviewer's git diff runs"
ev="$(event "$REVIEWER" 'rm -rf /tmp/x' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_allow "without python3 a reviewer's rm -rf /tmp/x runs"
ev="$(event "$REVIEWER" 'git merge-base main HEAD' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_allow "without python3 git merge-base is not git merge"
ev="$(event - 'git stash' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_allow "without python3 the main session's git stash is untouched"
# The raw check reads the agent_type field, not the bare name: a main-session command that merely
# mentions the reviewer must not be blocked on a machine without python3.
ev="$(event - 'echo keel:keel-reviewer; git stash' "$repo")"
run "$ev" "$repo" PATH="$shim"
expect_allow "without python3 a command mentioning the reviewer is untouched"

# A python3 that fails for another reason says so, rather than blaming the input.
pyfail="$(mktemp -d)"
ln -s "$(command -v bash)" "$pyfail/bash"
printf '#!/bin/sh\nexit 1\n' > "$pyfail/python3"
chmod +x "$pyfail/python3"
ev="$(event "$REVIEWER" 'git stash' "$repo")"
run "$ev" "$repo" PATH="$pyfail"
expect_deny "a failing python3 still refuses a reviewer's git stash"
reason_has  "and the reason says python3 failed" 'python3 failed'
rm -rf "$pyfail"

# Input that will not parse takes the same fallback with python3 present.
run '{"agent_id":"a1","agent_type":"keel:keel-reviewer","tool_input":{"command":"git stash"' "$repo"
expect_deny "unparseable input naming the reviewer refuses git stash"
reason_has  "and says it could not read its input" 'could not read its input'
run '{"agent_id":"a1","agent_type":"keel:keel-reviewer","tool_input":{"command":"git diff"' "$repo"
expect_allow "unparseable input naming the reviewer allows git diff"
run '{"tool_input":{"command":"git stash"' "$repo"
expect_allow "unparseable input not naming the reviewer is untouched"

# --- every other subagent: the stash alone ------------------------------------------------------
# Task 1 of docs/plans/2026-11-02-hold-a-subagents-git-stash.md. Implementers ran `git stash` on a
# shared tree four times; the stash is shared by every worktree, so it is refused to any subagent.
SUB=general-purpose
# Behaviour 1: every stash-writing form is refused, in the subagent's own wording.
for c in 'git stash' 'git stash push -m x' 'git stash pop' 'git stash apply' 'git stash drop' \
         'git stash clear' 'git stash -u' 'git stash -m list'; do
    deny "a subagent's $c is refused" "$SUB" "$c" "$repo"
done
deny       "a subagent's git stash, for the reason check"     "$SUB" 'git stash' "$repo"
reason_has "the subagent reason says the stash is shared"     'shared by every worktree'
reason_has "the subagent reason names keel review-guard"      'keel review-guard'
r="$(reason)"
if [ -n "$r" ] && [[ $r != *"keel reviewer"* ]]; then ok "the subagent reason is its own, not the reviewer's"
else bad "the subagent reason is its own, not the reviewer's" "${r:0:160}"; fi
# Behaviour 2: the two reading forms, read as git reads them, by the first word after `stash`.
allow "a subagent's git stash list is allowed"                "$SUB" 'git stash list' "$repo"
allow "a subagent's git stash show -p stash@{0} is allowed"   "$SUB" 'git stash show -p stash@{0}' "$repo"
# Behaviour 3: the forms the parser follows are followed for a subagent too.
for c in 'cd /tmp/x && git stash' 'git -C /tmp/x stash' 'env A=1 git stash' 'git status && git stash'; do
    deny "a subagent's $c is refused" "$SUB" "$c" "$repo"
done
# Behaviour 4: nothing else changes, and an agent type a user defined is a subagent like any other.
for c in 'git add a.txt' 'git commit -m x' 'git reset --hard' 'git checkout -b x'; do
    allow "a subagent's $c is allowed" "$SUB" "$c" "$repo"
done
deny  "a user-defined agent's git stash is refused"           helper 'git stash' "$repo"
# Behaviour 5: the main session and the reviewer are unchanged.
deny  "the reviewer's git stash list is still refused"        "$REVIEWER" 'git stash list' "$repo"
if [ -x /bin/bash ]; then
    run "$(event "$SUB" 'git stash' "$repo")" "$repo" /bin/bash
    expect_deny "under /bin/bash, a subagent's git stash is refused"
    run "$(event "$SUB" 'git stash list && git stash' "$repo")" "$repo" PATH="$shim" /bin/bash
    expect_deny "under /bin/bash without python3, a subagent's git stash list && git stash is refused"
    run "$(event "$SUB" 'git stash list' "$repo")" "$repo" PATH="$shim" /bin/bash
    expect_allow "under /bin/bash without python3, a subagent's git stash list is allowed"
fi
# Behaviour 6: the fallback holds the same line.
for c in 'git stash' 'git stash list && git stash' $'git stash list\ngit stash'; do
    run "$(event "$SUB" "$c" "$repo")" "$repo" PATH="$shim"
    expect_deny "without python3 a subagent's $c is refused"
done
run "$(event "$SUB" 'git stash' "$repo")" "$repo" PATH="$shim"
reason_has  "and the fallback's subagent reason says the stash is shared" 'shared by every worktree'
for c in 'git stash list' 'git commit -m x'; do
    run "$(event "$SUB" "$c" "$repo")" "$repo" PATH="$shim"
    expect_allow "without python3 a subagent's $c is allowed"
done
run "$(event - "echo '\"agent_type\": \"general-purpose\"'; git stash" "$repo")" "$repo" PATH="$shim"
expect_allow "without python3 a main-session command naming a subagent's agent_type is untouched"
# Behaviour 7: a subagent call without the word `stash` starts no python3. The shim only records
# that it ran, and fails, so the hook falls back for the call that does start it.
pyrec="$(mktemp -d)"
ln -s "$(command -v bash)" "$pyrec/bash"
printf '#!/bin/sh\n: > "%s/ran"\nexit 1\n' "$pyrec" > "$pyrec/python3"
chmod +x "$pyrec/python3"
run "$(event "$SUB" 'git commit -m x' "$repo")" "$repo" PATH="$pyrec"
if [ ! -e "$pyrec/ran" ]; then ok "a subagent's git commit starts no python3"
else bad "a subagent's git commit starts no python3" "the shim recorded a run"; fi
run "$(event "$SUB" 'git stash' "$repo")" "$repo" PATH="$pyrec"
if [ -e "$pyrec/ran" ]; then ok "a subagent's git stash starts python3"
else bad "a subagent's git stash starts python3" "the shim recorded no run"; fi
expect_deny "and, with that python3 failing, the subagent's git stash is still refused"

# --- a subagent is told by agent_id, and two more git forms are read ----------------------------
# Task 1b of docs/plans/2026-11-02-hold-a-subagents-git-stash.md. `claude -p --agent helper` logged
# agent_type `helper` and no agent_id for the main session's own Bash call, so agent_type alone does
# not mean a subagent.
# Behaviour 1: the stash rule needs a non-empty agent_id, on the python path and in the fallback.
run "$(event helper 'git stash' "$repo" -)" "$repo"
expect_allow "a main session started with --agent may git stash"
run "$(event helper 'git stash' "$repo" '')" "$repo"
expect_allow "a main session whose agent_id is empty may git stash"
run "$(event helper 'git stash' "$repo" a7)" "$repo"
expect_deny "the same event with an agent_id is refused git stash"
run "$(event helper 'git stash' "$repo" -)" "$repo" PATH="$shim"
expect_allow "without python3 a main session started with --agent may git stash"
run "$(event helper 'git stash' "$repo" a7)" "$repo" PATH="$shim"
expect_deny "without python3 the same event with an agent_id is refused git stash"
# Behaviour 2: --attr-source takes a value, so the word after it is not the subcommand.
deny "a subagent's git --attr-source HEAD stash is refused"  "$SUB" 'git --attr-source HEAD stash' "$repo"
deny "a reviewer's git --attr-source HEAD commit is refused" "$REVIEWER" 'git --attr-source HEAD commit -m x' "$repo"
run "$(event "$SUB" 'git --attr-source HEAD stash' "$repo")" "$repo" PATH="$shim"
expect_deny "without python3 a subagent's git --attr-source HEAD stash is refused"
# Behaviour 3: the fallback reads any option word between git and stash.
for c in 'git -P stash' 'git --bare stash' 'git --namespace n stash'; do
    run "$(event "$SUB" "$c" "$repo")" "$repo" PATH="$shim"
    expect_deny "without python3 a subagent's $c is refused"
done
run "$(event "$SUB" 'git -P stash list' "$repo")" "$repo" PATH="$shim"
expect_allow "without python3 a subagent's git -P stash list is allowed"
# The fallback's own edges: an empty agent_id is no subagent, show is a reading form, and
# --config-env and --super-prefix take the next word as their value.
run "$(event helper 'git stash' "$repo" '')" "$repo" PATH="$shim"
expect_allow "without python3 a main session whose agent_id is empty may git stash"
run "$(event "$SUB" 'git stash show -p stash@{0}' "$repo")" "$repo" PATH="$shim"
expect_allow "without python3 a subagent's git stash show -p stash@{0} is allowed"
for c in 'git --config-env a=B stash' 'git --super-prefix p/ stash'; do
    run "$(event "$SUB" "$c" "$repo")" "$repo" PATH="$shim"
    expect_deny "without python3 a subagent's $c is refused"
done

# --- the reviewer is a subagent too, the fallback keys on agent_id, the limits are observed ---------
# Task 4 of docs/plans/2026-11-02-hold-a-subagents-git-stash.md.
# Behaviour 1: the event reaches python3 on stdin, so an event too large for the environment is
# still judged by the parser. The size case pads a subagent's `git stash` past 1 MB, beyond Linux's
# 128 KB limit on one environment string and macOS's 1 MB ARG_MAX for all of them, in
# tool_input.description rather than in the command, so the parser stays fast; the parser's own
# reason, not the fallback's, shows it was judged in full.
big="$(CWD="$repo" python3 -c '
import json, os
print(json.dumps({"session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Bash",
                  "tool_input": {"command": "git stash", "description": "x" * 1100000},
                  "cwd": os.environ["CWD"], "agent_id": "a7", "agent_type": "general-purpose"}))')"
run "$big" "$repo"
expect_deny "a subagent's git stash in an event past 1 MB is refused"
reason_has  "and refused by the parser, not the fallback" 'is refused to a subagent'
if ! grep -q KEEL_EVENT "$GUARD"; then ok "the hook passes the event in no environment variable"
else bad "the hook passes the event in no environment variable" "$(grep -n KEEL_EVENT "$GUARD")"; fi
# An agent_id that is not a non-empty string is no subagent on either path: the fallback needs a
# quoted value, and the parser matches it.
num="$(event general-purpose 'git stash' "$repo" -)"
num="${num%\}}"', "agent_id": 7}'
run "$num" "$repo"
expect_allow "a subagent whose agent_id is the number 7 may git stash"
run "$num" "$repo" PATH="$shim"
expect_allow "without python3 a subagent whose agent_id is the number 7 may git stash"
# Behaviour 2: a main session started as `--agent keel:keel-reviewer` carries the reviewer's
# agent_type and no agent_id, and is never touched; with an agent_id it is the reviewer.
for c in 'git stash list' 'git commit -m x'; do
    run "$(event "$REVIEWER" "$c" "$repo" -)" "$repo"
    expect_allow "a main session started as the reviewer may $c"
    run "$(event "$REVIEWER" "$c" "$repo" -)" "$repo" PATH="$shim"
    expect_allow "without python3 a main session started as the reviewer may $c"
    run "$(event "$REVIEWER" "$c" "$repo" a7)" "$repo"
    expect_deny "the reviewer with an agent_id is refused $c"
    run "$(event "$REVIEWER" "$c" "$repo" a7)" "$repo" PATH="$shim"
    expect_deny "without python3 the reviewer with an agent_id is refused $c"
done
if [ -x /bin/bash ]; then
    run "$(event "$REVIEWER" 'git commit -m x' "$repo" -)" "$repo" PATH="$shim" /bin/bash
    expect_allow "under /bin/bash without python3, a main session started as the reviewer may git commit"
fi
# Behaviour 3: the fallback decides by agent_id and the exact reviewer name, so an agent_type it
# cannot read as a plain string is still a subagent.
run "$(event 'we"ird' 'git stash' "$repo" a7)" "$repo" PATH="$shim"
expect_deny "without python3 a subagent named we\"ird is refused git stash"
run "$(event 'we"ird' 'git stash list' "$repo" a7)" "$repo" PATH="$shim"
expect_allow "without python3 a subagent named we\"ird may git stash list"
if [ -x /bin/bash ]; then
    run "$(event 'we"ird' 'git stash' "$repo" a7)" "$repo" PATH="$shim" /bin/bash
    expect_deny "under /bin/bash without python3, a subagent named we\"ird is refused git stash"
fi
# Behaviour 5 there, a subagent's `echo git stash` refused as a stated limit, is replaced by task 6.

# --- a subagent's stash rule skips readers and quoted heredoc bodies, and bounds its time ---------
# Task 6 of docs/plans/2026-11-02-hold-a-subagents-git-stash.md, as redesigned during execution.
# Behaviour 1: a heredoc body is skipped only when its delimiter is quoted and the line it starts on
# ends with nothing open; any other body is read as commands, which errs toward refusing.
for c in $'cat <<\'EOF\' > notes.md\nrun git stash to save\nEOF' \
         $'git commit -F - <<\'EOF\'\nfix: avoid git stash\nEOF' \
         $'cat <<-\'EOF\' > notes.md\n\tgit stash\n\tEOF' \
         $'cat <<\'EOF\'\ngit stash\nEOF' \
         $'cat <<"EOF"\ngit stash\nEOF' \
         $'cat <<\'A\' <<"B"\ngit stash\nA\ngit stash\nB'; do
    allow "a subagent's quoted heredoc body naming git stash is allowed: ${c//$'\n'/ / }" "$SUB" "$c" "$repo"
done
for c in $'git commit -F - <<EOF\nfix: avoid git stash\nEOF' \
         $'cat <<-EOF > notes.md\n\tgit stash\n\tEOF' \
         $'cat <<EOF\ngit stash\nEOF' \
         $'cat <<\'A\' <<B\nx\nA\ngit stash\nB' \
         $'git commit -m "$(cat <<\'EOF\'\nfix(x): git stash\nEOF\n)"' \
         $'x=$(cat <<\'EOF\'\ngit stash\nEOF\n)' \
         $'cat <<\'EOF\' $(\ngit stash\n)\nx\nEOF' \
         $'(( y = 1 <<\'X\' ))\ngit stash\nX' \
         $'echo ${x:-<<\'X\'}\ngit stash\nX' \
         $'echo "<<\'X\'"\ngit stash\nX' \
         $'# <<\'X\'\ngit stash\nX'; do
    deny "a subagent's heredoc body read as commands is refused: ${c//$'\n'/ / }" "$SUB" "$c" "$repo"
done
for c in $'cat <<\'EOF\'\nx\nEOF\ngit stash' \
         $'cat <<-\'EOF\'\n\tx\n\tEOF\ngit stash' \
         $'cat <<\'EOF\' | git stash\nx\nEOF' \
         $'cat <<\'A\' <<\'B\'\nx\nA\ny\nB\ngit stash' \
         $'cat <<\'EOF\'\ngit stash' \
         $'cat <<EOF\nx\nEOF\ngit stash' \
         $'cat <<-EOF\n\tx\n\tEOF\ngit stash' \
         $'cat <<EOF | git stash\nx\nEOF' \
         $'cat <<A <<B\nx\nA\ny\nB\ngit stash' \
         $'cat <<EOF\ngit stash' \
         $'cat <<EOF\ndon\'t $(git stash)\nEOF' \
         $'cat <<EOF\n`git stash`\nEOF' \
         $'echo \'<<EOF\'\ngit stash\nEOF' \
         $'cat <<<"hi"\ngit stash\nhi'; do
    deny "a subagent's stash outside a quoted heredoc body is refused: ${c//$'\n'/ / }" "$SUB" "$c" "$repo"
done
# Behaviour 2: a segment whose command is echo, printf, grep, egrep or fgrep does not have its
# arguments read as git; every other segment has every git word read, as the reviewer's does. rg is
# not a reader, and `rg "git stash" docs` passes only because its quoted text is one word.
for c in 'echo git stash' "printf 'git stash\n'" 'grep -n "git stash" notes.md' \
         'egrep "git stash" notes.md' 'fgrep "git stash" notes.md' 'rg "git stash" docs' \
         'A=1 echo git stash' 'git log --grep stash' 'echo x # git stash'; do
    allow "a subagent's $c is allowed" "$SUB" "$c" "$repo"
done
for c in 'env A=1 git stash' 'timeout 5 git stash' 'command git stash' 'xargs git stash' \
         'nice -n 5 git stash' '/usr/bin/git stash' 'A=1 git stash' 'exec git stash' \
         'nohup git stash' 'time git stash' 'sudo -Eu root git stash' 'env - git stash' \
         'stdbuf -oL git stash' "find . -exec git stash \;" 'eval git stash' \
         'if true; then git stash; fi' '{ git stash; }' '! git stash' \
         '2>/dev/null git stash' 'git 2>/dev/null stash' 'git stash 2>/dev/null' \
         'true && git stash' 'echo x | git stash' 'echo x; git stash' 'diff <(git stash) x' \
         'cat < <(git stash)' '"git" stash' 'echo $(git stash)' 'echo `git stash`' \
         'echo <(git stash)' 'grep x <(git stash)' 'printf %s >(git stash)' '(git stash)' \
         'function f { git stash; }; f' 'coproc git stash' 'coproc c { git stash; }' \
         'while git stash; do :; done' 'time -p git stash' 'sudo git stash' 'sudo -ur git stash' \
         'nice -n5 git stash' 'nice -5 git stash' 'timeout -s KILL 5 git stash' \
         'timeout --signal=KILL 5 git stash' '/usr/bin/env git stash' 'env -u X git stash' \
         'env -- git stash' 'sudo env A=1 nice git stash' 'xargs -I{} git stash' \
         'xargs -n 1 git stash' 'flock /tmp/l git stash' 'ionice -c3 git stash' 'watch git stash' \
         'watch -n 1 git stash' 'noglob git stash' 'nocorrect git stash' \
         "find . -maxdepth 0 -execdir git stash \\;" "find . -maxdepth 0 -ok git stash \\;" \
         "find . -maxdepth 0 -okdir git stash \\;"; do
    deny "a subagent's $c is refused" "$SUB" "$c" "$repo"
done
# The quality review's examples against the first build: each ran a real stash and was let through.
for c in $'echo $(( 1 << 2 ))\ngit stash\n2' $'(( y = 1 << 3 ))\ngit stash\n3' \
         $'for ((i=0; i<<1; i++)); do :; done\ngit stash\n1' \
         'find . -exec echo {} \; -exec git stash +' '{fd}>/tmp/x git stash' \
         $'cat <<EOF $(\ngit stash\n)\nx\nEOF' 'arch -arm64 git stash' 'caffeinate -i git stash' \
         'script -q /dev/null git stash' 'setsid git stash' 'doas git stash'; do
    deny "a subagent's ${c//$'\n'/ / } is refused" "$SUB" "$c" "$repo"
done
allow "a subagent's stdbuf -oL git stash list is allowed" "$SUB" 'stdbuf -oL git stash list' "$repo"
allow "a subagent's find . -name '*.md' is allowed" "$SUB" "find . -name '*.md'" "$repo"
allow "a subagent's git stash list 2>/dev/null is allowed" "$SUB" 'git stash list 2>/dev/null' "$repo"
allow "a subagent's timeout 5 git stash list is allowed"   "$SUB" 'timeout 5 git stash list' "$repo"
# The second review of the redesign, 2026-11-03: each ran a real stash and was let through. A
# reader is exempt only at the top level, with no pipe after it, no process substitution in the
# command, and, for printf, no -v; and only a delimiter wholly 'WORD' or "WORD" has its body skipped.
for c in '$(echo git stash)' '`echo git stash`' '$(echo git stash) list' \
         'x=$(echo git stash); $x' 'eval "$(echo git stash)"' 'sh -c "$(echo git stash)"' \
         'bash <<<"$(echo git stash)"' 'echo git stash | sh' 'echo git stash |& sh' \
         'echo git stash | grep stash' '{ true; echo git stash; } | sh' \
         '(true; echo git stash) | sh' 'for i in 1; do :; echo git stash; done | sh' \
         'sh <(true; echo git stash)' '{ true; echo git stash; } > >(sh)' \
         "printf -v x '%s %s' git stash; \$x" 'rg --pre git stash stash' \
         $'cat <<$\'EOF\'\nx\nEOF\ngit stash\n$EOF' $'cat <<$"EOF"\nx\nEOF\ngit stash\n$EOF' \
         $'cat <<$\'E\'"OF"\nx\nEOF\ngit stash\n$EOF' $'cat <<"E\\\\F"\nx\nE\\F\ngit stash\nE\\\\F' \
         $'cat <<$\'A\' <<\'B\'\nA\nB\n$A\ngit stash\nB'; do
    deny "a subagent's ${c//$'\n'/ / } is refused" "$SUB" "$c" "$repo"
done
for c in "printf '%s\n' 'git stash'" 'cat notes.md | grep git stash'; do
    allow "a subagent's $c is allowed" "$SUB" "$c" "$repo"
done
# The fourth rule, from the fix pass's review: a command in which any segment's command word, after
# redirections and assignments, is a shell or evaluator gets neither the reader exemption nor
# heredoc stripping, so a body or a file fed to one is read as commands.
for c in $'bash <<\'EOF\'\ngit stash\nEOF' 'echo git stash > f; sh f' \
         $'zsh <<\'EOF\'\ngit stash\nEOF' $'/bin/sh <<\'EOF\'\ngit stash\nEOF' \
         "printf '%s %s' git stash > f; . f" 'echo git stash > f; source f' \
         $'cat <<\'EOF\' | sh\ngit stash\nEOF' 'echo git stash > f; 2>/dev/null A=1 sh f' \
         $'cat <<\'EOF\' > >(sh)\ngit stash\nEOF' 'echo git stash > f; x=$(bash f)'; do
    deny "a subagent's ${c//$'\n'/ / } is refused" "$SUB" "$c" "$repo"
done
for c in $'cat <<\'EOF\' > notes.md\nrun git stash to save\nEOF' 'echo git stash' \
         'grep -rn "git stash" .'; do
    allow "a subagent's ${c//$'\n'/ / } is allowed" "$SUB" "$c" "$repo"
done
# Behaviour 3: the reviewer still reads every git word and every heredoc body.
deny "the reviewer's echo git stash is still refused" "$REVIEWER" 'echo git stash' "$repo"
deny "the reviewer's heredoc body naming git stash is still refused" "$REVIEWER" \
     $'cat <<\'EOF\'\ngit stash\nEOF' "$repo"
# Behaviour 4: a command past 64 KB is refused unread, and quickly. sized <agent> <agent_id> <bytes>
# prints an event whose command is a `git status` padded to that length with one long word and a
# trailing `# stash`, built in python because a command that long cannot pass through the
# environment on Linux. One long word is what made the unbounded parse take 11 seconds at 1 MB.
sized() {
    AT="$1" AID="$2" N="$3" CWD="$repo" python3 -c '
import json, os
tail = " # stash"
pad = "x" * int(os.environ["N"])
cmd = ("git status " + pad)[:int(os.environ["N"]) - len(tail)] + tail
ev = {"session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Bash",
      "tool_input": {"command": cmd}, "cwd": os.environ["CWD"]}
if os.environ["AT"] != "-":
    ev["agent_type"], ev["agent_id"] = os.environ["AT"], os.environ["AID"]
print(json.dumps(ev))'
}
now() { python3 -c 'import time; print(time.time())'; }
ev="$(sized "$SUB" a7 1100000)"
t0="$(now)"; run "$ev" "$repo"; t1="$(now)"
expect_deny "a subagent's command past 64 KB is refused"
reason_has  "and the reason says it is too long to read" 'too long to read'
if python3 -c 'import sys; sys.exit(float(sys.argv[2]) - float(sys.argv[1]) >= 1)' "$t0" "$t1"; then
    ok "and it is refused in under a second"
else bad "and it is refused in under a second" "took $t0 to $t1"; fi
run "$(sized "$SUB" a7 70000)" "$repo"
expect_deny "a subagent's command just past 64 KB is refused"
run "$(sized "$SUB" a7 60000)" "$repo"
expect_allow "the same subagent command under 64 KB is allowed"
run "$(sized "$REVIEWER" a7 70000)" "$repo"
expect_deny "a reviewer's command past 64 KB naming git is refused"
reason_has  "and the reviewer's reason says it is too long to read" 'too long to read'
run "$(sized - - 1100000)" "$repo"
expect_allow "a main session's 1 MB command is allowed"
# Substitutions nested 400 deep, under 64 KB, are decided in under 3 seconds: the first build reran
# its heredoc pass at every level and took 15. Past the nesting cap a subagent's stash is refused.
ev="$(CWD="$repo" python3 -c '
import json, os
cmd = "echo " + ("$(echo " + "x" * 150 + " ") * 400 + "git stash" + ")" * 400
assert len(cmd) < 65536, len(cmd)
print(json.dumps({"session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Bash",
                  "tool_input": {"command": cmd}, "cwd": os.environ["CWD"],
                  "agent_type": "general-purpose", "agent_id": "a7"}))')"
t0="$(now)"; run "$ev" "$repo"; t1="$(now)"
expect_deny "a subagent's stash under 400 nested substitutions is refused"
reason_has  "and the reason names the nesting" 'nests substitutions'
if python3 -c 'import sys; sys.exit(float(sys.argv[2]) - float(sys.argv[1]) >= 3)' "$t0" "$t1"; then
    ok "and it is decided in under 3 seconds"
else bad "and it is decided in under 3 seconds" "took $t0 to $t1"; fi
# Behaviour 5: the fallback still reads every git word, and the header says the refinements are the
# python path's only.
run "$(event "$SUB" 'echo git stash' "$repo")" "$repo" PATH="$shim"
expect_deny "without python3 a subagent's echo git stash is still refused"
if grep -q 'on the python path only' "$GUARD"; then ok "the header says the refinements are the python path's only"
else bad "the header says the refinements are the python path's only" "no 'on the python path only' in the header"; fi
if grep -q 'parses in a fraction of' "$GUARD"; then
    bad "the hook no longer says 64 KB parses in a fraction of a second" "it still does"
else ok "the hook no longer says 64 KB parses in a fraction of a second"; fi
if [ -x /bin/bash ]; then
    run "$(event "$SUB" $'cat <<\'EOF\'\ngit stash\nEOF' "$repo")" "$repo" /bin/bash
    expect_allow "under /bin/bash, a subagent's heredoc body naming git stash is allowed"
    run "$(event "$SUB" 'env A=1 git stash' "$repo")" "$repo" /bin/bash
    expect_deny "under /bin/bash, a subagent's env A=1 git stash is refused"
fi

# --- a line continued with a backslash is read as one line --------------------------------------
# Task 8 of docs/plans/2026-11-02-hold-a-subagents-git-stash.md. bash removes a backslash and the
# newline after it, outside single quotes, comments and quoted heredoc bodies, before it reads the
# words; shlex instead kept the newline inside the next word, so `git \`, `stash` reached git unread.
# Behaviour 1: on the python path, for a subagent and for the reviewer.
deny  "a subagent's git \\, stash is refused"            "$SUB"      $'git \\\nstash' "$repo"
deny  "a subagent's true &&\\, git stash is refused"     "$SUB"      $'true &&\\\ngit stash' "$repo"
deny  "a subagent's grep x f |\\, git stash is refused"  "$SUB"      $'grep x f |\\\ngit stash' "$repo"
deny  "a subagent's gi\\, t stash is refused"            "$SUB"      $'gi\\\nt stash' "$repo"
deny  "a reviewer's git \\, commit -m x is refused"      "$REVIEWER" $'git \\\ncommit -m x' "$repo"
allow "a subagent's git \\, status is allowed"           "$SUB"      $'git \\\nstatus' "$repo"
allow "a subagent's git stash \\, list is allowed"       "$SUB"      $'git stash \\\nlist' "$repo"
allow "a quoted heredoc body line ending in \\ stays data" "$SUB" $'cat <<\'EOF\' > notes.md\nrun git stash \\\nEOF\ngit status' "$repo"
allow "a continued line's quoted heredoc starts after it" "$SUB" $'cat <<\'EOF\' \\\n> notes.md\ngit stash\nEOF' "$repo"
# Joined before the heredoc pass, `a \` would swallow the first EOF, and the second would close the
# body over the stash.
deny  "a stash after a quoted body whose line ends in \\ is refused" "$SUB" $'cat <<\'EOF\'\na \\\nEOF\ngit stash\nEOF' "$repo"
# A comment is not continued by bash, so its trailing backslash does not join the next line to it.
deny  "a comment ending in \\ does not hide the next line"  "$SUB" $'echo hi # x \\\ngit stash' "$repo"
# A `#` that a join or a substitution puts mid-word starts no comment, so its line still joins.
deny  "a # after a joined line is not a comment"           "$SUB" $'echo a\\\n#b; git \\\nstash' "$repo"
deny  "a # after a substitution is not a comment"          "$SUB" $'echo $(true)#b; git \\\nstash' "$repo"
# In an unquoted heredoc body bash does join a continued line, so the line after it cannot close it.
deny  "an unquoted body's continued line does not close it" "$SUB" $'cat <<EOF\na \\\nEOF\ntee <<\'X\'\nEOF\ngit stash\nX' "$repo"
deny  "a shell's quoted body with git \\, stash is refused" "$SUB" $'bash <<\'EOF\'\ngit \\\nstash\nEOF' "$repo"
# Behaviour 2: the fallback refuses the same subagent examples.
for c in $'git \\\nstash' $'true &&\\\ngit stash' $'grep x f |\\\ngit stash'; do
    run "$(event "$SUB" "$c" "$repo")" "$repo" PATH="$shim"
    expect_deny "without python3 a subagent's ${c//$'\n'/ } is refused"
done
run "$(event "$REVIEWER" $'git \\\ncommit -m x' "$repo")" "$repo" PATH="$shim"
expect_deny "without python3 a reviewer's git \\, commit -m x is refused"
run "$(event "$SUB" $'git \\\nstash \\\nlist' "$repo")" "$repo" PATH="$shim"
expect_allow "without python3 a subagent's git \\, stash \\, list is allowed"
# Behaviour 3: the header counts its refinements and states the reviewer's redirection limit.
if grep -q 'Three refinements' "$GUARD"; then bad "the header no longer says three refinements" "it still does"
else ok "the header no longer says three refinements"; fi
if grep -q 'Four refinements' "$GUARD"; then ok "the header says four refinements"
else bad "the header says four refinements" "no 'Four refinements' in the header"; fi
if grep -q "reviewer's \`git 2>/dev/null stash\` is allowed" "$GUARD"; then ok "the header states the reviewer's redirection limit"
else bad "the header states the reviewer's redirection limit" "not found"; fi
if [ -x /bin/bash ]; then
    run "$(event "$SUB" $'git \\\nstash' "$repo")" "$repo" /bin/bash
    expect_deny "under /bin/bash, a subagent's git \\, stash is refused"
fi
# Decided after review: no comment detector. A command is judged as written, and again with each
# `#` that begins a word stripped to the end of its line, and is refused if either refuses. As
# written, a `#` after an escaped blank or symbol, or inside `${`, starts no comment, so the git in
# its substitution is read; stripped, quotes in two comments cannot join the lines between them.
for c in $'true ${KEEL_NOPE_X:- #`git stash`}' $'true \\ #`git stash`' $'true x\\;#`git stash`' \
         $'true \\\t#`git stash`' $'true ${KEEL_NOPE_X:-\n#`git stash`}' \
         $'true ${KEEL_NOPE_X:- #`git stash` \\\n}' \
         $'# don\'t\ngit stash\n# won\'t' $'true # don\'t\ngit stash\ntrue # won\'t' \
         $'true a#b # don\'t\ngit stash\ntrue a#b # won\'t' $'# say "hi\ngit stash\n# "' \
         $'true\n# don\'t\ngit stash\n# won\'t' "git 2>/dev/null stash # don't" \
         $'true;# don\'t\ngit stash\ntrue;# won\'t'; do
    deny "a subagent's ${c//$'\n'/ / } is refused" "$SUB" "$c" "$repo"
done
for c in $'true ${KEEL_NOPE_X:- #`git commit -m x`}' $'# don\'t\ngit commit -m x\n# won\'t'; do
    deny "a reviewer's ${c//$'\n'/ / } is refused" "$REVIEWER" "$c" "$repo"
done
for c in "echo hi # don't stash anything" "git status # it's fine" \
         $'cat <<\'EOF\' > notes.md\n# don\'t run git stash\nit\'s #1: don\'t git stash\nEOF\ngit status' \
         $'cat <<EOF <<\'X\'\na \\\\\nEOF\ngit stash\nX' $'true a#b\'\ngit stash\n\''; do
    allow "a subagent's ${c//$'\n'/ / } is allowed" "$SUB" "$c" "$repo"
done

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
