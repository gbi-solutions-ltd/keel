#!/usr/bin/env bash
# Tests for hooks/sensitive-guard, the hard block on sensitive paths. Plan task 4.3, decision 3.
#
# The guard is the only gate in keel that a sentence in chat cannot move, so its tests assert on the
# decision it emits rather than only on its exit code. A guard that exits 0 while emitting nothing
# is indistinguishable from a guard that is not installed.
#
# Each case builds a throwaway git repository, stages something, feeds the hook a PreToolUse event
# on stdin, and asserts on the JSON it writes to stdout.

set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"

GUARD="$(cd "$(dirname "$0")/.." && pwd)/hooks/sensitive-guard"
pass=0
fail=0

# A repository with a profile, one sensitive path declared, and git configured enough to commit.
# The profile is committed, because a commit staging it asks for that reason alone, which would
# hide whatever a case stages after it.
fixture() {
    local root="$1" paths="$2"
    mkdir -p "$root/.keel" "$root/src/auth" "$root/src/ui"
    git -C "$root" init -q
    git -C "$root" config user.email t@example.com
    git -C "$root" config user.name Test
    printf '{\n  "project": {"name": "t"},\n  "hard_block_paths": [%s]\n}\n' "$paths" \
      > "$root/.keel/profile.json"
    git -C "$root" add .keel/profile.json; git -C "$root" commit -qm profile
}

# A PreToolUse event for a Bash call, the shape Claude Code sends. The command is JSON-escaped:
# without that, any case using `-m "a message"` produced invalid JSON, the hook bailed out early on
# the parse, and the case passed while testing nothing. One case did exactly that.
event() {
    CMD="$1" CWD="$2" python3 -c '
import json, os
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash",
                  "tool_input": {"command": os.environ["CMD"]}, "cwd": os.environ["CWD"]}))'
}

check() {
    local name="$1" want_decision="$2" root="$3" cmd="$4"
    local out got
    out="$(event "$cmd" "$root" | ( cd "$root" && "$GUARD" ) 2>/dev/null)"
    if [ -z "$want_decision" ]; then
        got="${out:-none}"
        [ -z "$out" ] && got=none || got="$out"
        if [ "$got" = none ]; then
            printf '  PASS  %s\n' "$name"; pass=$((pass+1)); return 0
        fi
        printf '  FAIL  %s (expected no decision, got: %s)\n' "$name" "${out:0:90}"; fail=$((fail+1)); return 0
    fi
    if printf '%s' "$out" | grep -q "\"permissionDecision\": *\"$want_decision\""; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (expected %s, got: %s)\n' "$name" "$want_decision" "${out:0:90}"; fail=$((fail+1))
    fi
}

# A commit touching a declared sensitive path needs a human. This is the whole point of the task:
# `ask` is the only decision the model cannot satisfy for itself, and it survives bypassPermissions.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A
check "a commit staging a sensitive path asks for a human" ask "$r" "git commit -m x"
rm -rf "$r"

# And it must not fire on everything, or it gets turned off.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/ui/button.tsx"; git -C "$r" add -A
check "a commit staging nothing sensitive is not blocked" "" "$r" "git commit -m x"
rm -rf "$r"

# A crash is not an answer. Claude Code lets the tool call proceed on any exit but 0 and 2, so a
# hook that died here waved the commit through. A tool_input that is a string rather than an object
# makes the embedded Python raise, which is the crash this case can reach from outside; a `set -u`
# slip ends the same way.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A
out="$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":"git commit -m x","cwd":"%s"}' "$r" \
  | ( cd "$r" && "$GUARD" ) 2>/dev/null)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  a guard that fails unexpectedly asks rather than letting the commit through\n'; pass=$((pass+1))
else
    printf '  FAIL  a guard that fails unexpectedly asks rather than letting the commit through (rc=%s, got: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1))
fi
rm -rf "$r"

# And the trap is on EXIT, not ERR. An ERR trap would miss a `set -u` exit, and would fire on a read
# the hook expects to fail: with the profile unreadable every Bash call would ask, which the header's
# cheap filters exist to prevent. An unreadable profile and a command that is not a commit stay
# silent. As root the profile is readable anyway and the case passes for the plain reason.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
chmod 000 "$r/.keel/profile.json"
check "an unreadable profile on a command that is not a commit asks nothing" "" "$r" "ls"
chmod 644 "$r/.keel/profile.json"
rm -rf "$r"

# The same commit with the hook run by a relative path and no CLAUDE_PLUGIN_ROOT. The hook reads
# nothing beside itself, so where it is run from must not change its answer. kp is a link to this
# repository, which puts the hook at a relative path from inside the fixture.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/ui/button.tsx"; git -C "$r" add -A
ln -s "$(cd "$(dirname "$GUARD")/.." && pwd)" "$r/kp"
out="$(event "git commit -m x" "$r" | ( cd "$r" && unset CLAUDE_PLUGIN_ROOT && kp/hooks/sensitive-guard ) 2>/dev/null)"
if [ -z "$out" ]; then
    printf '  PASS  run by a relative path, it still lets a safe commit through\n'; pass=$((pass+1))
else
    printf '  FAIL  run by a relative path, it still lets a safe commit through (got: %s)\n' "${out:0:90}"; fail=$((fail+1))
fi
rm -rf "$r"

# A repository that declares no sensitive paths must be untouched, which is almost every repository.
r="$(mktemp -d)"; fixture "$r" ''
: > "$r/src/auth/token.go"; git -C "$r" add -A
check "no hard_block_paths means no interference" "" "$r" "git commit -m x"
rm -rf "$r"

# Only the top-level list counts. A regex over the whole profile text read an empty list nested in
# `_notes` as the repository declaring nothing, so one note turned the guard off (audit M-01).
nested='{"project":{"name":"t"},"hard_block_paths":["auth"],"_notes":{"hard_block_paths":[]}}'
r="$(mktemp -d)"; fixture "$r" ''
printf '%s\n' "$nested" > "$r/.keel/profile.json"; git -C "$r" commit -qam nested
mkdir -p "$r/auth"; : > "$r/auth/x"; git -C "$r" add -A
check "an empty list nested under another key does not turn the guard off" ask "$r" "git commit -m x"
rm -rf "$r"

# A commit that changes the profile can change the list that judges it, so it asks, and says why.
r="$(mktemp -d)"; fixture "$r" '"auth"'
: > "$r/src/ui/button.tsx"; git -C "$r" add -A; git -C "$r" commit -qm init
printf '{"project": {"name": "t2"}, "hard_block_paths": ["auth"]}\n' > "$r/.keel/profile.json"
git -C "$r" add .keel/profile.json
out="$(event "git commit -m x" "$r" | ( cd "$r" && "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"permissionDecision": *"ask"' \
   && printf '%s' "$out" | grep -q '\.keel/profile\.json'; then
    printf '  PASS  a commit staging the profile asks, naming it\n'; pass=$((pass+1))
else printf '  FAIL  a commit staging the profile asks, naming it (got: %s)\n' "${out:0:120}"; fail=$((fail+1)); fi
rm -rf "$r"

# A commit that empties, removes or breaks the list is asked, whatever the working-tree profile now
# says. Judged by that profile alone, each of these exited in silence, and the next commit to a
# sensitive path went unguarded.
for body in '{"project": {"name": "t"}, "hard_block_paths": []}' '{"project": {"name": "t"}}' \
            '{"project": {"name": "t"},}' '{"hard_block_paths": [],}'; do
    r="$(mktemp -d)"; fixture "$r" '"src/auth"'
    printf '%s\n' "$body" > "$r/.keel/profile.json"; git -C "$r" add .keel/profile.json
    out="$(event "git commit -m x" "$r" | ( cd "$r" && "$GUARD" ) 2>/dev/null)"
    if printf '%s' "$out" | grep -q '"permissionDecision": *"ask"' \
       && printf '%s' "$out" | grep -q '\.keel/profile\.json'; then
        printf '  PASS  staging %s asks, naming the profile\n' "$body"; pass=$((pass+1))
    else printf '  FAIL  staging %s asks, naming the profile (got: %s)\n' "$body" "${out:0:120}"; fail=$((fail+1)); fi
    rm -rf "$r"
done

# The list a commit is judged by includes the committed one, so emptying it in the working tree
# without staging it does not lift the gate.
r="$(mktemp -d)"; fixture "$r" '"src/auth"'
printf '{"project": {"name": "t"}, "hard_block_paths": []}\n' > "$r/.keel/profile.json"
: > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
check "the committed list still judges a commit when the working tree empties it" ask "$r" "git commit -m x"
rm -rf "$r"

# With no working-tree profile left, the committed one still judges. Staging its deletion is staging
# the profile, and deleting it without staging that does not lift the gate either.
r="$(mktemp -d)"; fixture "$r" '"src/auth"'
git -C "$r" rm -q .keel/profile.json
out="$(event "git commit -m x" "$r" | ( cd "$r" && "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"permissionDecision": *"ask"' \
   && printf '%s' "$out" | grep -q '\.keel/profile\.json'; then
    printf '  PASS  staging the profile deletion asks, naming the profile\n'; pass=$((pass+1))
else printf '  FAIL  staging the profile deletion asks, naming the profile (got: %s)\n' "${out:0:120}"; fail=$((fail+1)); fi
rm -rf "$r"

r="$(mktemp -d)"; fixture "$r" '"src/auth"'
rm "$r/.keel/profile.json"; : > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
check "the committed list still judges a commit when the working-tree profile is deleted" ask "$r" "git commit -m x"
rm -rf "$r"

# A repository that declares nothing anywhere, neither at HEAD nor in the working tree, is never
# asked, including when the commit changes its profile.
r="$(mktemp -d)"; fixture "$r" ''
printf '{"project": {"name": "t"}}\n' > "$r/.keel/profile.json"; git -C "$r" commit -qam none
: > "$r/src/auth/token.go"; git -C "$r" add src/auth/token.go
ev="$(event "git commit -m x" "$r")"
out="$( cd "$r" && "$GUARD" <<<"$ev" 2>&1 )"; rc=$?     # no pipe, so rc is the hook's own
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    printf '  PASS  a repository declaring nothing anywhere is not asked\n'; pass=$((pass+1))
else printf '  FAIL  a repository declaring nothing anywhere is not asked (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi
printf '{"project": {"name": "t2"}}\n' > "$r/.keel/profile.json"; git -C "$r" add .keel/profile.json
check "a profile change in a repository declaring nothing anywhere is not asked" "" "$r" "git commit -m x"
rm -rf "$r"

# The guard only concerns itself with committing. Blocking every edit to auth code would make the
# gate the thing people remove.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A
check "a non-commit command is not blocked" "" "$r" "git status"
rm -rf "$r"

# `git commit -a` stages tracked modifications at commit time, so a staged-only check sees nothing
# and the gate silently does not exist for the most ordinary way people commit. This is not the
# documented `sh -c` limit; it is a plain everyday command, and missing it made the guard decorative.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A; git -C "$r" commit -qm init
printf 'changed\n' >> "$r/src/auth/token.go"     # tracked, modified, deliberately not staged
check "a -a commit catches an unstaged modification" ask "$r" "git commit -am x"
rm -rf "$r"

# And -a must not widen it to untracked files, which a commit would not include either.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/ui/button.tsx"; git -C "$r" add -A; git -C "$r" commit -qm init
: > "$r/src/auth/untracked.go"                   # untracked: `git commit -a` does not commit it
check "a -a commit ignores untracked files" "" "$r" "git commit -am x"
rm -rf "$r"

# Splitting git's output on whitespace tears a path in half. It happened to still match here, but
# the file it named was wrong, and a pattern anchored on the full path would have missed entirely.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
mkdir -p "$r/src/auth/two words"; : > "$r/src/auth/two words/k.go"; git -C "$r" add -A
out="$(event "git commit -m x" "$r" | ( cd "$r" && "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q 'src/auth/two words/k.go'; then
    printf '  PASS  %s\n' "a staged path containing a space is reported whole"; pass=$((pass+1))
else
    printf '  FAIL  %s (got: %s)\n' "a staged path containing a space is reported whole" "${out:0:120}"; fail=$((fail+1))
fi
rm -rf "$r"

# A session started in a subdirectory is ordinary, and git commits the whole staged set from there
# regardless. Looking for the profile only in the current directory meant the guard silently did not
# exist for that session, which is the worst failure available to a gate: absent and quiet.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A
out="$(event "git commit -m x" "$r" | ( cd "$r/src/ui" && "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  %s\n' "the guard still fires from a subdirectory"; pass=$((pass+1))
else
    printf '  FAIL  %s (expected ask, got: %s)\n' "the guard still fires from a subdirectory" "${out:0:80}"; fail=$((fail+1))
fi
rm -rf "$r"

# A guard that cannot answer must say so, rather than go quiet. These three are the cases where it
# could not answer, and each one used to exit 0 in silence, which is the failure the whole hook
# exists to avoid: a repository that declared sensitive paths and believed in a gate it did not get.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
printf '{\n  "hard_block_paths": ["src/auth/**"],\n}\n' > "$r/.keel/profile.json"   # trailing comma
: > "$r/src/auth/token.go"; git -C "$r" add -A
check "an unparseable profile asks rather than passing" ask "$r" "git commit -m x"
rm -rf "$r"

r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A
shim="$(mktemp -d)"; ln -s "$(command -v bash)" "$shim/bash"; ln -s "$(command -v python3)" "$shim/python3"
out="$(event "git commit -m x" "$r" | ( cd "$r" && PATH="$shim" "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  %s\n' "git being unreachable asks rather than passing"; pass=$((pass+1))
else
    printf '  FAIL  %s (expected ask, got: %s)\n' "git being unreachable asks rather than passing" "${out:0:80}"; fail=$((fail+1))
fi
rm -rf "$r" "$shim"

# The fail-closed branch must not turn into a prompt on every Read and Grep. The tool and command
# filters have to run before it, or a machine without python3 gets a permission dialog per tool call
# and the gate becomes the thing people delete.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
shim="$(mktemp -d)"; ln -s "$(command -v bash)" "$shim/bash"
out="$(printf '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}' | ( cd "$r" && PATH="$shim" "$GUARD" ) 2>/dev/null)"
if [ -z "$out" ]; then
    printf '  PASS  %s\n' "a non-Bash call is silent even with python3 absent"; pass=$((pass+1))
else
    printf '  FAIL  %s (expected nothing, got: %s)\n' "a non-Bash call is silent even with python3 absent" "${out:0:80}"; fail=$((fail+1))
fi
rm -rf "$r" "$shim"

# Flag detection must read the command, not the prose inside it. A gate that fires on
# `git commit -m "fix the -a flag"` is a gate people switch off.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; : > "$r/src/ui/b.tsx"; git -C "$r" add -A; git -C "$r" commit -qm init
printf 'x\n' >> "$r/src/auth/token.go"          # unstaged sensitive change
printf 'y\n' >> "$r/src/ui/b.tsx"; git -C "$r" add src/ui/b.tsx
check "a -a inside the commit message does not widen the check" "" "$r" 'git commit -m "fix the -a flag"'
rm -rf "$r"

# And the attached-value form is still a -a commit.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A; git -C "$r" commit -qm init
printf 'x\n' >> "$r/src/auth/token.go"
check "git commit -am\"msg\" is recognised as -a" ask "$r" 'git commit -am"msg"'
rm -rf "$r"

# A pathspec commits that file's working tree content even when unstaged, which is the same everyday
# bypass as -a wearing a different hat.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A; git -C "$r" commit -qm init
printf 'x\n' >> "$r/src/auth/token.go"
check "a pathspec commit is caught" ask "$r" "git commit src/auth/token.go -m x"
rm -rf "$r"

# Decision 3 proposes patterns like "anything under a path matching auth". A directory written
# without a glob must match what is under it, or a repository declares a gate that never fires.
r="$(mktemp -d)"; fixture "$r" '"src/auth"'
: > "$r/src/auth/token.go"; git -C "$r" add -A
check "a bare directory pattern matches what is under it" ask "$r" "git commit -m x"
rm -rf "$r"

# Fail closed, and only here. Everywhere else an absent python3 means keel goes quiet, because the
# feature is advisory. A repository that declared sensitive paths and silently got no enforcement
# would believe it had a gate it did not have, which is worse than having none.
r="$(mktemp -d)"; fixture "$r" '"src/auth/**"'
: > "$r/src/auth/token.go"; git -C "$r" add -A
# The shim carries bash and nothing else. It must carry bash: the shebang is `/usr/bin/env bash`,
# and env resolves bash through PATH, so an empty shim stops the script starting at all rather than
# exercising the branch under test. That mistake is what this comment exists to prevent.
shim="$(mktemp -d)"
ln -s "$(command -v bash)" "$shim/bash"
out="$(event "git commit -m x" "$r" | ( cd "$r" && PATH="$shim" "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  %s\n' "an absent python3 fails closed, not silent"; pass=$((pass+1))
else
    printf '  FAIL  %s (expected ask, got: %s)\n' "an absent python3 fails closed, not silent" "${out:0:90}"; fail=$((fail+1))
fi
rm -rf "$r" "$shim"

# The cases below share these. A repository whose only commit holds README.md, so HEAD exists and no
# profile is committed at it, which leaves a case's working-tree profile with nothing to stand in.
plain_repo() {
    local root="$1"
    mkdir -p "$root/src/auth" "$root/src/ui"
    git -C "$root" init -q
    git -C "$root" config user.email t@example.com
    git -C "$root" config user.name Test
    : > "$root/README.md"; git -C "$root" add README.md; git -C "$root" commit -qm readme
}
asks() { printf '%s' "$1" | grep -q '"permissionDecision": *"ask"'; }
silent() { [ "$1" -eq 0 ] && [ -z "$2" ]; }     # an exit code, then what the hook printed
# name, then 0 for a pass, then what the hook printed
verdict() {
    if [ "$2" -eq 0 ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else printf '  FAIL  %s (got: %s)\n' "$1" "${3:0:120}"; fail=$((fail+1)); fi
}
codex_guard() { env -u CLAUDE_PROJECT_DIR CODEX_VERSION=0.153.4 "$GUARD"; }

# A global git option before `commit` does not hide the commit. The prefilter needed the literal
# text `git commit` and the token walk stopped at the first token after `git` not starting with `-`,
# so `git -c core.hooksPath=/dev/null commit` went through in silence. A tab arrives in the event as
# `\t`, and a quoted value can hold an escaped quote; neither hides the commit either.
for cmd in 'git -c core.hooksPath=/dev/null commit -m x' 'git -C . commit -m x' \
           'git --git-dir .git --work-tree . commit -m x' 'git --git-dir=.git commit -m x' \
           $'git\tcommit -m x' 'git -c "a=\"b c\"" commit -m x'; do
    r="$(mktemp -d)"; fixture "$r" '"src/auth"'
    : > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
    check "a global option before commit does not hide it: $cmd" ask "$r" "$cmd"
    rm -rf "$r"
done

# And a global option on a command that is not a commit is not one, even with the word in its value
# and the profile staged, which is the one change that asks whatever the command's files are.
r="$(mktemp -d)"; fixture "$r" '"src/auth"'
: > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
check "a global option on a command that is not a commit asks nothing" "" "$r" \
    'git -c commit.gpgsign=false log -1'
printf '{"project": {"name": "t2"}, "hard_block_paths": ["src/auth"]}\n' > "$r/.keel/profile.json"
git -C "$r" add .keel/profile.json
check "a global option on a command that is not a commit asks nothing with the profile staged" "" \
    "$r" 'git -c commit.gpgsign=false log -1'
rm -rf "$r"

# The prefilter reads the command, not the whole event. Matched against the event, a global option
# in the command and the word commit in its description read as a commit, so with the profile
# staged a `git diff` asked on Claude Code and was refused on Codex.
devent() {   # devent <command> <cwd> <description>; event, with a description
    CMD="$1" CWD="$2" DESC="$3" python3 -c '
import json, os
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash",
                  "tool_input": {"command": os.environ["CMD"], "description": os.environ["DESC"]},
                  "cwd": os.environ["CWD"]}))'
}
r="$(mktemp -d)"; fixture "$r" '"src/auth"'
printf '{"project": {"name": "t2"}, "hard_block_paths": ["src/auth"]}\n' > "$r/.keel/profile.json"
git -C "$r" add .keel/profile.json
desc='Show the staged diff before commit'
out="$(devent 'git -C . diff --cached --stat' "$r" "$desc" | ( cd "$r" && env -u CODEX_VERSION "$GUARD" ) 2>&1)"; rc=$?
silent "$rc" "$out"
verdict "the prefilter reads the command: a diff whose description says commit prints nothing" $? "rc $rc: $out"
out="$(devent 'git -C . diff --cached --stat' "$r" "$desc" | ( cd "$r" && codex_guard ) 2>&1)"; rc=$?
silent "$rc" "$out"
verdict "the prefilter reads the command: on codex a diff whose description says commit exits 0" $? "rc $rc: $out"
out="$(devent 'git -C . commit -m x' "$r" "$desc" | ( cd "$r" && env -u CODEX_VERSION "$GUARD" ) 2>/dev/null)"
asks "$out" && printf '%s' "$out" | grep -q '\.keel/profile\.json'
verdict "the prefilter reads the command: a commit with that description asks, naming the profile" $? "$out"
out="$(devent 'git -C . commit -m x' "$r" "$desc" | ( cd "$r" && codex_guard ) 2>&1 >/dev/null)"; rc=$?
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'v0\.26\.0'
verdict "the prefilter reads the command: on codex a commit with that description refuses" $? "rc $rc: $out"
rm -rf "$r"

# A profile that exists and cannot be read asks on a commit. With no profile at HEAD the committed
# list cannot stand in for it, and reading it as absent let the commit through in silence. Codex
# discards the ask, so there it is the refusal. Root reads a mode 000 file, so as root the case
# would pass without testing an unreadable profile at all, and it says so instead.
if [ "$(id -u)" = 0 ]; then
    printf '  SKIP  an unreadable profile asks on a commit: running as root, which reads mode 000\n'
else
    r="$(mktemp -d)"; plain_repo "$r"
    mkdir -p "$r/.keel"; printf '{"hard_block_paths": ["src/auth"]}\n' > "$r/.keel/profile.json"
    chmod 000 "$r/.keel/profile.json"
    : > "$r/src/ui/button.tsx"; git -C "$r" add src/ui/button.tsx
    out="$(event "git commit -m x" "$r" | ( cd "$r" && "$GUARD" ) 2>/dev/null)"
    asks "$out" && printf '%s' "$out" | grep -q 'profile could not be read'
    verdict "an unreadable profile with none at HEAD asks on a commit, saying it could not be read" $? "$out"
    check "an unreadable profile with none at HEAD asks nothing on ls" "" "$r" "ls"
    out="$(event "git commit -m x" "$r" | ( cd "$r" && codex_guard ) 2>&1 >/dev/null)"; rc=$?
    [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'v0\.26\.0'
    verdict "on codex an unreadable profile with none at HEAD refuses the commit" $? "rc $rc: $out"
    chmod 644 "$r/.keel/profile.json"; rm -rf "$r"
fi

# The profile walk calls no external command. It stepped up with `dirname`, so with PATH holding
# bash, git and python3 only, the walk lost its directory at the first step up, found no profile and
# let the commit through in silence. The profile is untracked, so HEAD cannot stand in for it.
r="$(mktemp -d)"; plain_repo "$r"
mkdir -p "$r/.keel"; printf '{"hard_block_paths": ["src/auth"]}\n' > "$r/.keel/profile.json"
: > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
shim="$(mktemp -d)"
for t in bash git python3; do ln -s "$(command -v "$t")" "$shim/$t"; done
out="$(event "git commit -m x" "$r/src/ui" | ( cd "$r/src/ui" && PATH="$shim" "$GUARD" ) 2>/dev/null)"
asks "$out"
verdict "the profile walk finds an untracked profile with only bash, git and python3 on PATH" $? "$out"
rm -rf "$r" "$shim"

# The walk and both git calls start from the session's directory: the event's cwd, then
# CLAUDE_PROJECT_DIR, then $PWD, the first that names a directory that exists. The hook process's
# own directory is not promised to be the one the command runs in, and a profile and a staged set
# read from a directory outside the repository found neither. The repository path holds a space.
base="$(mktemp -d)"; r="$base/with space"; mkdir -p "$r"; fixture "$r" '"src/auth"'
: > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
away="$(mktemp -d)"
out="$(event "git commit -m x" "$r" | ( cd "$away" && env -u CLAUDE_PROJECT_DIR "$GUARD" ) 2>/dev/null)"
asks "$out"
verdict "run from outside the repository, the event's cwd names it, path with a space" $? "$out"
nocwd='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
out="$(printf '%s' "$nocwd" | ( cd "$away" && CLAUDE_PROJECT_DIR="$r" "$GUARD" ) 2>/dev/null)"
asks "$out"
verdict "with no cwd in the event, CLAUDE_PROJECT_DIR names the repository" $? "$out"
out="$(event "git commit -m x" "$away/gone" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR "$GUARD" ) 2>/dev/null)"
asks "$out"
verdict "an event cwd that does not exist falls back to the directory the hook runs in" $? "$out"
rm -rf "$base" "$away"

# Outside any repository a wrong directory gets the "git diff failed" ask, the same decision as a
# right one, so the cases above cannot tell them apart. Run from inside B, a repository with no
# profile and nothing staged, a wrong directory gives silence instead, and each case asks naming
# the file A stages.
a="$(mktemp -d)"; fixture "$a" '"src/auth"'
: > "$a/src/auth/t.go"; git -C "$a" add src/auth/t.go
b="$(mktemp -d)"; plain_repo "$b"
names_t() { asks "$1" && printf '%s' "$1" | grep -q 'src/auth/t\.go'; }
out="$(event "git commit -m x" "$a" | ( cd "$b" && env -u CLAUDE_PROJECT_DIR -u CODEX_VERSION "$GUARD" ) 2>/dev/null)"
names_t "$out"
verdict "run from inside another repository, the event's cwd judges the commit" $? "$out"
out="$(event "git commit -m x" "$a" | ( cd "$b" && CLAUDE_PROJECT_DIR="$b" env -u CODEX_VERSION "$GUARD" ) 2>/dev/null)"
names_t "$out"
verdict "the event's cwd is read before CLAUDE_PROJECT_DIR" $? "$out"
rm "$a/.keel/profile.json"
out="$(event "git commit -m x" "$a" | ( cd "$b" && env -u CLAUDE_PROJECT_DIR -u CODEX_VERSION "$GUARD" ) 2>/dev/null)"
names_t "$out"
verdict "run from inside another repository, the profile at HEAD is read from the event's cwd" $? "$out"
rm -rf "$a" "$b"

# A hard_block_paths that is present and not a list of strings is an unparseable profile. A string
# was iterated character by character, so `"src/auth"` declared s, r, c and so on, and a commit
# under none of them went through in silence.
for list in '"src/auth"' '{"src/auth": true}' '["src/auth", 1]'; do
    r="$(mktemp -d)"; fixture "$r" '"src/auth"'
    printf '{"project": {"name": "t"}, "hard_block_paths": %s}\n' "$list" > "$r/.keel/profile.json"
    git -C "$r" commit -qam list
    : > "$r/src/ui/button.tsx"; git -C "$r" add src/ui/button.tsx
    out="$(event "git commit -m x" "$r" | ( cd "$r" && "$GUARD" ) 2>/dev/null)"
    asks "$out" && printf '%s' "$out" | grep -q 'not a list of strings'
    verdict "a hard_block_paths of $list asks as an unparseable profile, saying not a list of strings" $? "$out"
    out="$(event "git commit -m x" "$r" | ( cd "$r" && codex_guard ) 2>&1 >/dev/null)"; rc=$?
    [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'v0\.26\.0'
    verdict "on codex a hard_block_paths of $list refuses the commit" $? "rc $rc: $out"
    rm -rf "$r"
done

# And an empty list, an absent key and null still declare nothing, on either harness.
for body in '"hard_block_paths": []' '"name": "t"' '"hard_block_paths": null'; do
    r="$(mktemp -d)"; fixture "$r" '"src/auth"'
    printf '{%s}\n' "$body" > "$r/.keel/profile.json"; git -C "$r" commit -qam list
    : > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
    check "a profile of {$body} asks nothing" "" "$r" "git commit -m x"
    out="$(event "git commit -m x" "$r" | ( cd "$r" && codex_guard ) 2>&1)"; rc=$?
    silent "$rc" "$out"
    verdict "on codex a profile of {$body} is untouched" $? "rc $rc: $out"
    rm -rf "$r"
done

# A repository with a HEAD and no profile anywhere is never asked, whatever it stages.
r="$(mktemp -d)"; plain_repo "$r"
: > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
ev="$(event "git commit -m x" "$r")"
out="$( cd "$r" && "$GUARD" <<<"$ev" 2>&1 )"; rc=$?     # no pipe, so rc is the hook's own
silent "$rc" "$out"
verdict "a repository with a HEAD and no profile anywhere is not asked" $? "rc $rc: $out"
rm -rf "$r"

# With CDPATH set, a relative cd in the hook would land in the decoy and print its path to stdout,
# which corrupts the hook's JSON. So the hook is run, not read: an ask is exactly one JSON object,
# and a repository with no profile gets no output at all.
decoy="$(mktemp -d)"; mkdir -p "$decoy/.keel" "$decoy/src"
r="$(mktemp -d)"; fixture "$r" '"src/auth"'
: > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
out="$(event 'git -c core.hooksPath=/dev/null commit -m x' "$r" \
  | ( cd "$r" && CDPATH="$decoy" "$GUARD" ) 2>/dev/null)"
printf '%s' "$out" | python3 -c '
import json, sys
sys.exit(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"] != "ask")' 2>/dev/null
verdict "with CDPATH set, an ask is exactly one JSON object on stdout" $? "$out"
rm -rf "$r"
r="$(mktemp -d)"; plain_repo "$r"
: > "$r/src/auth/t.go"; git -C "$r" add src/auth/t.go
out="$(event "git commit -m x" "$r" | ( cd "$r" && CDPATH="$decoy" "$GUARD" ) 2>&1)"
silent 0 "$out"; verdict "with CDPATH set, a repository with no profile gets no output" $? "$out"
rm -rf "$r" "$decoy"


# --- on Codex, where the gate cannot ask -------------------------------------------------------
#
# This gate is `ask` or it is nothing, and Codex discards `ask`. Codex still runs this hook: it
# reads hooks/hooks.json, the file Claude Code reads, as the probe in
# docs/architecture/claude-code-only.md under "Probe: Codex without .codex-plugin/" records. A guard
# that exits 0 in silence there is a guard the repository believes it has, so it refuses the commit
# and names the last keel release that supports Codex.
#
# The hook no longer sources the resolver or reads the capability ledger: what Codex does with `ask`
# is a measured fact, not a row to look up.
n="$(grep -c resolve.sh "$GUARD")"
if [ "$n" = 0 ]; then printf '  PASS  the hook no longer sources the resolver\n'; pass=$((pass+1))
else printf '  FAIL  the hook no longer sources the resolver (resolve.sh named %s times)\n' "$n"; fail=$((fail+1)); fi

r="$(mktemp -d)"; fixture "$r" '"src/auth"'
: > "$r/src/auth/token.go"; git -C "$r" add -A
ev="$(event "git commit -m x" "$r")"

out="$(printf '%s' "$ev" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR CODEX_VERSION=0.153.4 "$GUARD" ) 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ]; then printf '  PASS  exits 2 on CODEX_VERSION with no turn_id\n'; pass=$((pass+1))
else printf '  FAIL  exits 2 on CODEX_VERSION with no turn_id (got %s)\n' "$rc"; fail=$((fail+1)); fi

# Exit 2 and not 1: on Codex a PreToolUse hook exiting with any non-zero code other than 2 has its
# stderr discarded and the tool call proceeds, so exit 1 would be quieter than doing nothing.
if printf '%s' "$out" | grep -qi 'codex'; then printf '  PASS  names the harness on stderr\n'; pass=$((pass+1))
else printf '  FAIL  names the harness on stderr (got: %s)\n' "${out:0:90}"; fail=$((fail+1)); fi

# The refusal is only useful if it says where to go: the last keel release that supports Codex.
if printf '%s' "$out" | grep -q 'v0\.26\.0'; then printf '  PASS  the refusal on codex names v0.26.0\n'; pass=$((pass+1))
else printf '  FAIL  the refusal on codex names v0.26.0 (got: %s)\n' "${out:0:120}"; fail=$((fail+1)); fi

# It names the release once and unambiguously: v0.26.0 is the last keel release that supports Codex,
# with the line that installs it. Beside the word Codex alone, "stay on v0.26.0" reads as a Codex
# version rather than a keel one.
if printf '%s' "$out" | grep -q 'keel v0\.26\.0 is the last keel release that supports Codex'; then
    printf '  PASS  the refusal says v0.26.0 is the last keel release that supports Codex\n'; pass=$((pass+1))
else printf '  FAIL  the refusal says v0.26.0 is the last keel release that supports Codex (got: %s)\n' "${out:0:160}"; fail=$((fail+1)); fi
install='codex plugin marketplace add gbi-solutions-ltd/keel --ref v0.26.0 && codex plugin add keel@gbi'
case "$out" in
    *"$install"*) printf '  PASS  the refusal gives the v0.26.0 install line\n'; pass=$((pass+1)) ;;
    *) printf '  FAIL  the refusal gives the v0.26.0 install line (got: %s)\n' "${out:0:160}"; fail=$((fail+1)) ;;
esac
case "$out" in
    *'stay on v0.26.0'*) printf '  FAIL  the refusal does not say "stay on v0.26.0" (got: %s)\n' "${out:0:160}"; fail=$((fail+1)) ;;
    *) printf '  PASS  the refusal does not say "stay on v0.26.0"\n'; pass=$((pass+1)) ;;
esac

# Codex's schema requires a turn_id key on PreToolUse input, and the one Codex hook environment
# observed had no CODEX_VERSION, so either signal alone refuses. The payload is written compactly,
# the way the example in the plan gives it.
tev="$(CMD="git commit -m x" CWD="$r" python3 -c '
import json, os
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash", "turn_id": "t1",
                  "tool_input": {"command": os.environ["CMD"]}, "cwd": os.environ["CWD"]},
                 separators=(",", ":")))')"
out="$(printf '%s' "$tev" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR -u CODEX_VERSION "$GUARD" ) 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'keel v0\.26\.0'; then
    printf '  PASS  exits 2 naming keel v0.26.0 on a turn_id event with no CODEX_VERSION\n'; pass=$((pass+1))
else printf '  FAIL  exits 2 naming keel v0.26.0 on a turn_id event with no CODEX_VERSION (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi

# Claude Code exports CLAUDE_PROJECT_DIR to hook processes and Codex has no such variable, so with
# it set neither signal refuses. Claude Code's MessageDisplay input already carries turn_id, and a
# PreToolUse input that gained it must still get the ask rather than a hard block.
out="$(printf '%s' "$tev" | ( cd "$r" && env -u CODEX_VERSION CLAUDE_PROJECT_DIR=/repo "$GUARD" ) 2>/dev/null)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  with CLAUDE_PROJECT_DIR set, a turn_id event gets the ask and exit 0\n'; pass=$((pass+1))
else printf '  FAIL  with CLAUDE_PROJECT_DIR set, a turn_id event gets the ask and exit 0 (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi

out="$(printf '%s' "$ev" | ( cd "$r" && CLAUDE_PROJECT_DIR=/repo CODEX_VERSION=0.153.4 "$GUARD" ) 2>/dev/null)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  with CLAUDE_PROJECT_DIR set, CODEX_VERSION gets the ask and exit 0\n'; pass=$((pass+1))
else printf '  FAIL  with CLAUDE_PROJECT_DIR set, CODEX_VERSION gets the ask and exit 0 (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi

# The match is on the key, with its colon. A field whose value is exactly turn_id appears in the raw
# event as "description":"turn_id", unescaped, so a pattern without the colon reads it as the key.
dev="$(CWD="$r" python3 -c '
import json, os
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash",
                  "tool_input": {"command": "git commit -m x", "description": "turn_id"},
                  "cwd": os.environ["CWD"]}, separators=(",", ":")))')"
out="$(printf '%s' "$dev" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR -u CODEX_VERSION "$GUARD" ) 2>/dev/null)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  a value of exactly turn_id is not read as the turn_id key\n'; pass=$((pass+1))
else printf '  FAIL  a value of exactly turn_id is not read as the turn_id key (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi

# The match is on the JSON key. A Claude Code commit whose message says turn_id reaches the hook as
# \"turn_id\", escaped, so it still gets the ask.
out="$(event 'git commit -m "turn_id"' "$r" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR -u CODEX_VERSION "$GUARD" ) 2>/dev/null)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  a commit message naming turn_id is not read as Codex\n'; pass=$((pass+1))
else printf '  FAIL  a commit message naming turn_id is not read as Codex (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi

# The invariant, and the case that catches the refusal being placed too early. A repository whose
# list is empty declares nothing and must produce nothing, on every harness. Above the empty-list
# check the refusal would block every commit in a repository that asked for nothing.
q="$(mktemp -d)"; fixture "$q" ''
out="$(printf '%s' "$(event "git commit -m x" "$q")" | ( cd "$q" && env -u CLAUDE_PROJECT_DIR CODEX_VERSION=0.153.4 "$GUARD" ) 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then printf '  PASS  silent on codex when the repo declares nothing\n'; pass=$((pass+1))
else printf '  FAIL  silent on codex when the repo declares nothing (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi
rm -rf "$q"

# And the same judgement on Codex: an empty list nested under another key is not the repository
# declaring nothing, so the refusal still stands.
q="$(mktemp -d)"; fixture "$q" ''
printf '%s\n' "$nested" > "$q/.keel/profile.json"
out="$(printf '%s' "$(event "git commit -m x" "$q")" | ( cd "$q" && env -u CLAUDE_PROJECT_DIR CODEX_VERSION=0.153.4 "$GUARD" ) 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'keel v0\.26\.0'; then
    printf '  PASS  on codex a nested empty list does not lift the refusal\n'; pass=$((pass+1))
else printf '  FAIL  on codex a nested empty list does not lift the refusal (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi
rm -rf "$q"

# PLACEMENT, from the other side. The refusal sits after the `git commit` filter because the
# fail-closed python3 branch must not become a prompt on every Read and Grep, and the same argument
# applies to a hard block: a Codex session running a command that is not a commit, in a repository
# that DOES declare paths, must be untouched.
out="$(printf '%s' "$(event "git status" "$r")" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR CODEX_VERSION=0.153.4 "$GUARD" ) 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then printf '  PASS  a non-commit command on codex is untouched\n'; pass=$((pass+1))
else printf '  FAIL  a non-commit command on codex is untouched (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi

out="$(printf '%s' "$(event "ls" "$r")" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR CODEX_VERSION=0.153.4 "$GUARD" ) 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then printf '  PASS  ls on codex in a repo declaring paths is untouched\n'; pass=$((pass+1))
else printf '  FAIL  ls on codex in a repo declaring paths is untouched (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi

# R-01: no Claude Code behaviour changes. The same repository, the same command, without the Codex
# signal, still reaches the decision it always did. Every case above this block asserts that too,
# but none of them asserts it beside the refusal, which is where a misplaced one shows.
out="$(event "git commit -m x" "$r" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR -u CODEX_VERSION "$GUARD" ) 2>/dev/null)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"permissionDecision": *"ask"'; then
    printf '  PASS  a Claude Code event with neither signal still gets the ask and exit 0\n'; pass=$((pass+1))
else printf '  FAIL  a Claude Code event with neither signal still gets the ask and exit 0 (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi

# On Codex with no python3 the list cannot be parsed, and an unparsed declaration counts as
# declared. The ask the Claude Code path gives here is one Codex discards, so it must refuse.
# The shim carries bash and nothing else, as in the python3-absent case above.
shim="$(mktemp -d)"; ln -s "$(command -v bash)" "$shim/bash"
out="$(printf '%s' "$ev" | ( cd "$r" && env -u CLAUDE_PROJECT_DIR CODEX_VERSION=0.153.4 PATH="$shim" "$GUARD" ) 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'keel v0\.26\.0'; then
    printf '  PASS  on codex with python3 absent the commit is refused, not asked\n'; pass=$((pass+1))
else printf '  FAIL  on codex with python3 absent the commit is refused, not asked (rc %s: %s)\n' "$rc" "${out:0:90}"; fail=$((fail+1)); fi
rm -rf "$shim"
rm -rf "$r"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
