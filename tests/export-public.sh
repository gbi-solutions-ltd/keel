#!/usr/bin/env bash
# Write the public subset of this repository to a directory.
#
# The public repository is a fresh tree with one commit and no history, because this repository's
# history carries client identifiers in six files and two commit messages and cannot be published.
# Sweeping every commit found all 27 deny patterns reachable. See docs/runbooks/going-public.md.
#
# Tracked files only, via git ls-files, so nothing untracked, ignored or local can be carried out by
# accident. That is the property that matters most here: an `rsync --exclude` of the working tree
# would carry whatever happened to be lying in it.
#
# The exclusions are the exposure, not a tidy-up:
#
#   docs/audits/            the security posture of real services, named. 838 lines across five files
#   .claude/                this repository's own editor settings
#   .keel/handoff.md        already gitignored, excluded belt and braces
#
# IMPLEMENTATION-PLAN.md was on that list and came off it, which is worth recording because it is the
# only exclusion that was ever tested and reversed. It was excluded for naming both pilot
# repositories. Once those were genericised the file swept clean against every deny pattern, and
# excluding it broke three README links, so the honest fix was to publish it rather than to edit
# README around a gap. Verified by running the suite inside the export: that is what caught it.
#
# Everything else ships, including docs/ 01 to 07, standards, decisions, ideas, plans and runbooks.
# That is deliberate and it is wider than "just the plugin": those documents are the reasoning that
# makes the tree worth reading, every rule in them states the failure that produced it, and the sweep
# says they carry no client identifier. The decision and its reasoning are in
# docs/plans/2026-08-17-go-public.md under "The manifest".
#
# Usage: tests/export-public.sh <empty-or-absent-directory>
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

dest="${1:-}"
[ -n "$dest" ] || { printf 'usage: tests/export-public.sh <dir>\n' >&2; exit 2; }
if [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    printf 'refusing to write into a non-empty directory: %s\n' "$dest" >&2
    exit 2
fi
mkdir -p "$dest" || exit 2

excluded() {
    case "$1" in
        docs/audits/*|.claude/*|.keel/handoff.md) return 0 ;;
        *) return 1 ;;
    esac
}

n=0
skipped=0
while IFS= read -r f; do
    if excluded "$f"; then skipped=$((skipped+1)); continue; fi
    mkdir -p "$dest/$(dirname "$f")"
    cp -p "$f" "$dest/$f"
    n=$((n+1))
done < <(git ls-files)

printf 'exported %s files to %s, skipped %s\n' "$n" "$dest" "$skipped"
printf 'excluded: docs/audits, .claude, .keel/handoff.md\n'
