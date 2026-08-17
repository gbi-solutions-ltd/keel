#!/usr/bin/env bash
# Tests for hooks/sensitive-guard, the hard block on sensitive paths. Plan task 4.3, decision 3.
#
# The guard is the only gate in keel that a sentence in chat cannot move, so its tests assert on the
# decision it emits rather than only on its exit code. A guard that exits 0 while emitting nothing
# is indistinguishable from a guard that is not installed.
#
# Each case builds a throwaway git repository, stages something, feeds the hook a PreToolUse event
# on stdin, and asserts on the JSON it writes to stdout.

set -uo pipefail

GUARD="$(cd "$(dirname "$0")/.." && pwd)/hooks/sensitive-guard"
pass=0
fail=0

# A repository with a profile, one sensitive path declared, and git configured enough to commit.
fixture() {
    local root="$1" paths="$2"
    mkdir -p "$root/.keel" "$root/src/auth" "$root/src/ui"
    git -C "$root" init -q
    git -C "$root" config user.email t@example.com
    git -C "$root" config user.name Test
    printf '{\n  "project": {"name": "t"},\n  "hard_block_paths": [%s]\n}\n' "$paths" \
      > "$root/.keel/profile.json"
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

# A repository that declares no sensitive paths must be untouched, which is almost every repository.
r="$(mktemp -d)"; fixture "$r" ''
: > "$r/src/auth/token.go"; git -C "$r" add -A
check "no hard_block_paths means no interference" "" "$r" "git commit -m x"
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

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
