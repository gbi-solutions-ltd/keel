#!/usr/bin/env bash
# shellcheck disable=SC2016  # commands are single-quoted, so $TMPDIR and $wt reach the hook
# Tests for hooks/review-guard, which refuses a keel reviewer the git commands that would change the
# author's checkout or the state every worktree shares. Task 1 of
# docs/plans/2026-10-17-reviewer-git-guard.md, behaviours 2 to 6, one case per example there.
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

# A PreToolUse event for one Bash call, in the shape the 2026-10-17 probe logged. An agent type of
# `-` leaves agent_id and agent_type out, which is what a call from the main session looks like.
# Built with json.dumps, because a command carrying quotes or newlines is invalid JSON written by
# hand, and the hook would then refuse it as unreadable while the case passed for the wrong reason.
event() {
    AT="$1" CMD="$2" CWD="$3" python3 -c '
import json, os
ev = {"session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Bash",
      "tool_input": {"command": os.environ["CMD"]}, "cwd": os.environ["CWD"]}
if os.environ["AT"] != "-":
    ev["agent_id"] = "a1"
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
trap 'rm -rf "$repo" "$tmprepo" "$shim" ${pyfail:+"$pyfail"}' EXIT

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

# --- behaviour 2: nobody but a keel reviewer is touched -----------------------------------------
# The main session's calls carry no agent_type at all, and it must never be blocked: it is the
# author and the coordinator.
allow "the main session's git stash is untouched"          -                   'git stash' "$repo"
allow "a general-purpose agent's git stash is untouched"   general-purpose     'git stash' "$repo"
allow "keel-fanout's git stash is untouched"               keel:keel-fanout    'git stash' "$repo"

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
# only when that input says the agent type is a keel reviewer: it cannot tell a reviewer from
# anyone else otherwise, and must not block the main session.
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
run '{"agent_type":"keel:keel-reviewer","tool_input":{"command":"git stash"' "$repo"
expect_deny "unparseable input naming the reviewer refuses git stash"
reason_has  "and says it could not read its input" 'could not read its input'
run '{"agent_type":"keel:keel-reviewer","tool_input":{"command":"git diff"' "$repo"
expect_allow "unparseable input naming the reviewer allows git diff"
run '{"tool_input":{"command":"git stash"' "$repo"
expect_allow "unparseable input not naming the reviewer is untouched"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
