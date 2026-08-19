#!/usr/bin/env bash
# Refuse to ship project-specific identifiers in a generic plugin.
#
# keel installs into every project. A client name, a partner name, a specific repository name,
# or a developer's absolute path inside a skill is confusing before it is anything else: a reader
# assumes the name means something to keel. It also discloses who we work with, in a repository
# that may not stay private.
#
# Examples in skills should use obviously generic names, so nobody mistakes them for real systems:
# `payments-api`, "a partner bank", `PROD-042-requirements.md`.
#
# Usage: tests/no-internal-leaks.sh   (from the repository root)
# Exits 0 when clean, 1 on any match.
#
# NOTE, BEFORE THIS REPOSITORY IS EVER MADE PUBLIC: the deny list below is itself the disclosure.
# It is the one file that enumerates who we work with, and it necessarily contains the names in
# order to search for them. Fine while the repository is private. Before publishing, move DENY into
# a file outside the public tree and have this script read it, falling back to the generic patterns
# (paths, document identifiers) when it is absent. Recorded against decision 2 in
# docs/07-open-decisions.md.

# The `condition && report_pass || report_fail` idiom is used throughout. It is safe here, and only
# here, because every reporting helper returns 0 explicitly: see the `return 0` on each below. That
# makes the invariant shellcheck cannot see a stated fact in the code rather than an assumption.
# shellcheck disable=SC2015
set -uo pipefail

errors=0
report() { printf 'FAIL  %s\n' "$1"; errors=$((errors+1)); return 0; }

# Generic patterns. These stay in the tree because they disclose nothing: a developer's absolute path
# helps nobody else and dates the moment they change laptop.
DENY=( '/Users/[a-z]' '/home/[a-z]' )

# Client and partner identifiers are loaded from a file outside this tree, because the list is itself
# the disclosure. It was the one file that enumerated who we work with, and it must contain the names
# in order to search for them, so the guard against disclosure had become the disclosure. Decision 2
# in docs/07-open-decisions.md required this before any public release, and 2026-08-17 is that release.
#
# One pattern per line, ERE, `#` comments and blank lines ignored. Absent is a legitimate state: a CI
# runner on a fork has no list, exactly as it has no marketplace registered. When it is absent the
# generic patterns above still run, so the scan degrades rather than going quiet, and either way the
# mode is printed before any finding.
#
# What is not covered, and the format that would fix it. tests/test-no-leaks.sh proves the mechanism
# with invented names; it can no longer prove that every pattern in the real list still matches
# something, because it no longer has the real list. Giving this file a `pattern<TAB>sample` format
# would restore that check whenever it is present, and it is the better end state. It was not built
# here because the mechanism came first.
DENY_FILE="${KEEL_DENY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/keel/internal-deny-list.txt}"
deny_mode="generic patterns only, no internal deny list at $DENY_FILE"
if [ -f "$DENY_FILE" ]; then
    loaded=0
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ''|\#*) continue ;; esac
        DENY+=( "$line" )
        loaded=$((loaded+1))
    done < "$DENY_FILE"
    deny_mode="internal deny list loaded from $DENY_FILE ($loaded patterns)"
fi

# Decision 2 in docs/07-open-decisions.md keeps GBi-specific content inside named reference files,
# so a public release is deleting five files rather than auditing twenty. Nothing enforced it, and
# by 2026-08-17 the name had spread to eight more files, four of them SKILL.md bodies the decision
# says must never carry it inline. A decision with no check is a decision that has already drifted.
#
# Scoped to skills/, templates/ and output-styles/, which are what ships into a consuming project.
# README, docs/, CHANGELOG and the tests name GBi correctly and are not part of the extraction.
#
# `.claude-plugin/` is shipped and is deliberately NOT in scope, which is a judgement rather than an
# oversight: `owner.name` and `author.name` in those manifests are the marketplace owner, so the
# organisation is legitimately named there and a blanket rule would reject correct output. Their
# descriptions were checked by hand on 2026-08-17, when one still advertised "GBi internal AI
# engineering tooling" on a repository about to become public.
#
# output-styles/ was missing from that list when this rule was first written, which is the second
# time that directory has acquired a quietly different standard: tests/test-validate-skills.sh
# already carries a note about the first. The three ship together and validate-skills.sh has always
# treated them as one set, so this one does too.
#
# Deliberately not a DENY entry: DENY drives the coverage assertion in tests/test-no-leaks.sh, which
# fires every pattern from one sample under docs/, and this rule ignores docs/ by design.
#
# The pattern is `\bGBi`, the branded form in prose, and not `gbi-solutions`. The latter is correct
# inside templates/profile.schema.json and templates/keel-profile.example.json, which carry the
# canonical schema URL. That coupling is recorded in docs/runbooks/going-public.md instead.
#
# **Closed 2026-08-17 by removing what it was managing.** The allowlist held five reference files, on
# the theory that publishing would then be a deletion rather than an audit of twenty. Publishing
# turned out to need neither: all five are generic once the organisation's name comes out of their
# prose. So there is no allowlist and the rule is simply that shipped content names no organisation,
# which is stronger than decision 2 asked for and simpler to keep.

# `--list-patterns` prints the deny list, one entry per line, and exits.
#
# It exists so tests/test-no-leaks.sh can assert that every pattern is still exercised by a sample,
# rather than parsing this file. A pattern nobody tests is a pattern that can stop matching without
# anyone noticing: the regexes here are hand written, and a rename or an escaping change turns one
# into dead weight silently. The test fails if any entry is never triggered.
if [ "${1:-}" = "--list-patterns" ]; then
    printf '%s\n' "${DENY[@]}"
    exit 0
fi

# Which mode this run is in, before any finding. A scanner that silently degrades to half its rules
# and still prints OK is worse than one that fails, and nothing else would tell the reader. Printed
# after --list-patterns so that stays machine readable.
printf 'mode  %s\n' "$deny_mode"

# Files this scanner should not read: itself and its tests, which must contain the patterns in
# order to test for them.
skip_file() {
    case "$1" in
        tests/no-internal-leaks.sh|tests/test-no-leaks.sh) return 0 ;;
        *) return 1 ;;
    esac
}

# Everything tracked, or everything present when not in a repo (so it works on a fixture).
list_files() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git ls-files
    else
        find . -type f -not -path './.git/*' | sed 's|^\./||'
    fi
}

# One grep per pattern over the whole candidate list, not one grep per pattern per file. The
# original did the latter: files times 27 DENY patterns, about 6,400 grep processes and 37 seconds
# on this repository. The candidate list (skip_file and the binary filter below, both unchanged) is
# built once here instead of being recomputed for every pattern.
CANDIDATES="$(mktemp)"; GBI_CANDIDATES="$(mktemp)"
trap 'rm -f "$CANDIDATES" "$GBI_CANDIDATES"' EXIT

while IFS= read -r f; do
    [ -n "$f" ] || continue
    skip_file "$f" && continue
    [ -f "$f" ] || continue
    # Skip binaries.
    LC_ALL=C grep -qI . "$f" 2>/dev/null || continue
    printf '%s\n' "$f" >> "$CANDIDATES"
    case "$f" in
        skills/*|templates/*|output-styles/*) printf '%s\n' "$f" >> "$GBI_CANDIDATES" ;;
    esac
done < <(list_files)

# Not `grep ... | head -1`. head exits after one line, grep dies on SIGPIPE with 141, and
# `set -o pipefail` makes that the pipeline's status, so a branch guarded that way would be skipped
# while a real finding exists: a file with more matches than a pipe buffer scanned clean. Reproduces
# from about 5,000 matching lines. Nothing below pipes a grep into anything that can exit early:
# each pattern's full output is captured through process substitution, and the loop keeps only the
# first match per file per pattern in-shell, by skipping repeats of the filename it just reported.
if [ -s "$CANDIDATES" ]; then
    for pat in "${DENY[@]}"; do
        prev_f=""
        while IFS= read -r hit; do
            [ -n "$hit" ] || continue
            f="${hit%%:*}"; rest="${hit#*:}"
            [ "$f" = "$prev_f" ] && continue
            prev_f="$f"
            line="${rest%%:*}"; text="${rest#*:}"
            report "$f: project-specific identifier matching '$pat' -> $line: $(printf '%s' "$text" | cut -c1-70)"
        done < <(tr '\n' '\0' < "$CANDIDATES" | xargs -0 grep -nHE -- "$pat" 2>/dev/null)
    done
fi

# The GBi check, scoped to skills/, templates/ and output-styles/: see the header comment above for
# why. Pulled out of the per-file loop for the same reason as the DENY patterns above: one grep over
# the subset rather than one grep per file in it. Same first-match-per-file, same no-head-under-
# pipefail reasoning.
if [ -s "$GBI_CANDIDATES" ]; then
    prev_f=""
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        f="${hit%%:*}"; rest="${hit#*:}"
        [ "$f" = "$prev_f" ] && continue
        prev_f="$f"
        line="${rest%%:*}"; text="${rest#*:}"
        report "$f: names GBi. Shipped content carries no organisation name: decision 2 required it extractable, and 2026-08-17 removed the last of it -> $line: $(printf '%s' "$text" | cut -c1-70)"
    done < <(tr '\n' '\0' < "$GBI_CANDIDATES" | xargs -0 grep -nHE -- '\bGBi' 2>/dev/null)
fi

if [ "$errors" -eq 0 ]; then
    printf 'OK    no project-specific identifiers\n'
    exit 0
fi
printf '\n%s leak(s). Replace with a generic name: payments-api, "a partner bank", PROD-042-requirements.md\n' "$errors"
exit 1
