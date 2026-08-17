#!/usr/bin/env bash
# Tests that bin/keel works from a copy holding only tracked files, which is what a marketplace
# install produces. README and docs/03-install-and-distribution.md tell a user the plugin alone is
# enough; this is the check behind that claim.
#
# `git archive HEAD` rather than `cp -R`, deliberately. A recursive copy carries untracked files
# across, so a file that is on disk and not in the repository would make this pass while the thing
# it tests fails for everyone else. It also means this tests the committed tree, which is exactly
# what the marketplace ships: uncommitted work in progress is invisible here, and that is correct.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0

ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL  %s (%s)\n' "$1" "$2"; fail=$((fail+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if ! git -C "$ROOT" archive HEAD | tar -x -C "$tmp"; then
    printf 'could not archive HEAD; is this a git checkout?\n' >&2
    exit 1
fi

# The whole point: HERE resolves, lib/ and VERSION are found, and the guard at bin/keel:35 stays
# quiet. A copy missing any sourced file prints "incomplete install" and exits 1.
out="$("$tmp/bin/keel" version 2>&1)"
if [ "$out" = "$(cat "$ROOT/VERSION")" ]; then
    ok "version, from a tracked-files-only copy"
else
    bad "version, from a tracked-files-only copy" "got: ${out:0:120}"
fi

# version alone only proves the sources loaded. init proves templates/ and lib/detect-stack.sh
# resolve from the copy too, which is where a pruned install would actually bite.
proj="$tmp/proj"
mkdir -p "$proj"
git -C "$proj" init -q
git -C "$proj" config user.email t@example.com
git -C "$proj" config user.name Test
out="$( cd "$proj" && "$tmp/bin/keel" init -y 2>&1 )"
if [ -f "$proj/.keel/profile.json" ]; then
    ok "init writes a profile, from that copy"
else
    bad "init writes a profile, from that copy" "${out:0:160}"
fi

# The claim these documents used to carry, guarded so it cannot come back by copy and paste. A
# plugin's bin/ IS added to the PATH the Bash tool uses; checked 2026-08-16 against the plugins
# reference and against a live session. The narrower true statement, that this PATH is not the
# login shell's, belongs in the documents and is not matched here.
#
# ITS LIMIT: this matches the phrase, not the assertion, so it cannot tell a live claim from a
# document explaining that the claim was superseded. It fired on exactly that during task 2. The
# fix is to paraphrase the history rather than to loosen the pattern: a guard that allows the
# sentence back in any form is not a guard.
for doc in README.md docs/03-install-and-distribution.md; do
    if grep -qi 'plugins do not extend\|does not put .keel. on your PATH\|which the plugin install does not do' "$ROOT/$doc"; then
        bad "no false PATH claim in $doc" "found the superseded claim"
    else
        ok "no false PATH claim in $doc"
    fi
done

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
