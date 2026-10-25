#!/usr/bin/env bash
# List what an eval arm searching this machine could find outside its staged directory.
#
# Usage: tests/evals/isolation-check.sh [--names <file>] <staged dir>...
#        exit 0 and `OK    nothing keel-shaped outside the staged dirs`, or exit 1 and one path
#        per line
#
# Why this exists: arms search with `find /` and not the `../skills/` path their prompt names
# (tests/evals/results.md, 2026-10-18, "the prune-to-the-target arms", follow-up 5). Staging
# outside the repository therefore does not isolate an arm while another copy of keel, an older
# staged directory or an unpacked archive sits elsewhere on the machine: whatever `find /` can reach
# is a copy the arm can read, the scenario's pass criteria included. This lists what it could find,
# so it is deleted before dispatch and not after a result is already recorded.
#
# What it reports, anywhere under the root:
#
#   - a directory D where D/skills/<s>/SKILL.md exists for review-code, repo-snapshot, write-plan
#     or execute-plan, the skill directory exactly one level below D/skills: a skill tree, a clone
#     or a snapshot. D is printed, not the file.
#   - a directory named skills/<s>/references for one of those four: a staged copy or a leftover
#   - a directory whose name starts keel-eval-: a leftover staged directory
#   - any tests/evals/scenarios directory
#   - a file named <scenario>.md. The names come from --names <file>, one per line, or from
#     scenarios/*.md beside this script when that directory exists; with neither, the rule is
#     skipped and a line on stderr says so, so a copy run from outside the repository is given
#     --names
#   - a .claude-plugin/plugin.json whose top-level "name" is "keel". That is the first "name" key
#     in the file, where a plugin's own name is written: a plugin by an author named keel, or one
#     that lists a keel dependency, carries the word further down and is not keel
#
# Anything under a staged directory given as an argument is the arm's own and is not reported.
# Both sides are resolved with pwd -P first, so a /tmp that is really /private/tmp (macOS) does not
# make a staged directory look like a stranger.
#
# It fails closed on a staged directory it did not cover. A staged directory under the search root
# always matches a rule above, by its keel-eval- name or by the skills/<s>/references inside it, so
# a walk that found nothing in or at one did not walk it: it was pruned, or the root is not the
# machine it was staged on. A clean result over a directory the walk never saw says nothing, so the
# check prints which one and exits 2 instead.
#
# What it cannot see: it matches NAMES, not contents. A transcript, an archive, or a note that
# quotes criteria text is not found, and neither is a copy whose files were renamed. A clean exit is
# the absence of the shapes above, not a proof that nothing is readable, which is why the arm's own
# tool calls are still read for paths outside its staged directory after a run.
#
# KEEL_ISOLATION_ROOT replaces / as the search root, so a test plants a tree in a temp directory and
# the real machine is never searched. /proc, /sys and /dev under the root are pruned: nothing keel
# lives there and walking them is slow and noisy. So is System/Volumes/Data, for a different reason:
# on macOS 10.15 and later the data volume is mounted at that path as well as at the usual places,
# and `find /` walks it a second time. Every hit would then appear twice, once under its real path
# and once under System/Volumes/Data, and a staged dir would be reported under its second name,
# which is_staged does not recognise as the argument it was given.
#
# find's exit status is ignored on purpose. A whole-machine search meets directories it may not
# read, and find exits non-zero for each, so its status says nothing about whether it found
# anything. Its stderr is discarded for the same reason. There is no `set -e` and no pipefail, and
# the exit status is 1 only when a path was printed.
#
# Portable to the bash 3.2 and BSD userland a Mac ships: no mapfile, no realpath, no GNU flags.

set -u; unset CDPATH  # a cd that finds its directory through CDPATH prints it

usage() {
    printf 'usage: tests/evals/isolation-check.sh [--names <file>] <staged dir>...\n' >&2
    exit 2
}

here="$(cd "$(dirname "$0")" && pwd -P)" || exit 2
names_file=""
staged=""
while [ $# -gt 0 ]; do
    case "$1" in
        --names) [ $# -ge 2 ] || usage; names_file="$2"; shift 2 ;;
        --) shift; break ;;
        -*) usage ;;
        *) break ;;
    esac
done
for arg in "$@"; do
    resolved="$(cd "$arg" 2>/dev/null && pwd -P)" || {
        printf 'isolation-check: not a directory: %s\n' "$arg" >&2; exit 2; }
    staged="$staged$resolved"$'\n'
done

root="${KEEL_ISOLATION_ROOT:-/}"
root="$(cd "$root" 2>/dev/null && pwd -P)" || {
    printf 'isolation-check: cannot enter the search root: %s\n' "${KEEL_ISOLATION_ROOT:-/}" >&2
    exit 2; }
# "" for /, so "$prefix/proc" is /proc and not //proc
prefix="${root%/}"

# Scenario names, one per line. A name outside lowercase letters, digits and hyphens is skipped
# with a line on stderr, because it becomes a find pattern and must not be a glob.
names=""
add_name() {
    case "$1" in
        '') ;;
        *[!abcdefghijklmnopqrstuvwxyz0123456789-]*)
            printf 'isolation-check: ignoring a name outside [a-z0-9-]: %s\n' "$1" >&2 ;;
        *) names="$names$1"$'\n' ;;
    esac
}
if [ -n "$names_file" ]; then
    [ -r "$names_file" ] || {
        printf 'isolation-check: cannot read %s\n' "$names_file" >&2; exit 2; }
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%"${line##*[![:space:]]}"}"
        line="${line#"${line%%[![:space:]]*}"}"
        case "$line" in '#'*) continue ;; esac
        add_name "$line"
    done < "$names_file"
else
    for f in "$here"/scenarios/*.md; do
        [ -e "$f" ] || continue
        add_name "$(basename "$f" .md)"
    done
fi
# The two ways to have no names are different problems, so the message names the one that happened:
# a --names file that was given and gave nothing usable (a missing one already exited above), or no
# --names and no scenarios/*.md beside this script, which is a copy run from outside the repository.
if [ -z "$names" ]; then
    if [ -n "$names_file" ]; then
        printf 'isolation-check: no usable names in %s; skipping the <scenario>.md rule\n' \
            "$names_file" >&2
    else
        printf '%s\n' \
            'isolation-check: no --names given and no scenarios/*.md beside this script;' \
            '  skipping the <scenario>.md rule' >&2
    fi
fi

# One pass over the root. The positional parameters are borrowed to build the expression, which
# keeps every name a separate word and needs no array, so it is safe under set -u on bash 3.2.
set -- \( -path "$prefix/proc" -o -path "$prefix/sys" -o -path "$prefix/dev" \
    -o -path "$prefix/System/Volumes/Data" \) -prune -o \( \
    -type f -path '*/skills/review-code/SKILL.md' \
    -o -type f -path '*/skills/repo-snapshot/SKILL.md' \
    -o -type f -path '*/skills/write-plan/SKILL.md' \
    -o -type f -path '*/skills/execute-plan/SKILL.md' \
    -o -type d -path '*/skills/review-code/references' \
    -o -type d -path '*/skills/repo-snapshot/references' \
    -o -type d -path '*/skills/write-plan/references' \
    -o -type d -path '*/skills/execute-plan/references' \
    -o -type d -name 'keel-eval-*' \
    -o -type d -path '*/tests/evals/scenarios' \
    -o -type f -path '*/.claude-plugin/plugin.json'
while IFS= read -r n; do
    [ -n "$n" ] && set -- "$@" -o -type f -name "$n.md"
done <<EOF
$names
EOF
set -- "$@" \) -print

hits="$(find "${prefix:-/}" "$@" 2>/dev/null)"

# True when $1 is a staged directory or inside one, at a path boundary: /a/v does not cover /a/vv.
is_staged() {
    local s
    while IFS= read -r s; do
        [ -n "$s" ] || continue
        case "$1" in "$s"|"$s"/*) return 0 ;; esac
    done <<EOF
$staged
EOF
    return 1
}

# Fail closed. Each staged dir under the root has to be one the walk reached: the dir itself or a
# path inside it is among the raw hits. See the header for why a real staged dir always is.
while IFS= read -r s; do
    [ -n "$s" ] || continue
    case "$s" in "$prefix"|"$prefix"/*) ;; *) continue ;; esac
    seen=0
    while IFS= read -r h; do
        case "$h" in "$s"|"$s"/*) seen=1; break ;; esac
    done <<EOF
$hits
EOF
    if [ "$seen" -eq 0 ]; then
        printf 'isolation-check: the walk did not cover %s\n' "$s" >&2
        printf '  it lies under %s and nothing in or at it was found, so it was pruned\n' \
            "${prefix:-/}" >&2
        printf '  or is not where it was staged; no result is given\n' >&2
        exit 2
    fi
done <<EOF
$staged
EOF

found=""
while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$(basename "$p")" in
        SKILL.md)    p="$(dirname "$(dirname "$(dirname "$p")")")" ;;
        plugin.json)
            # The first "name" key and its value. grep -o puts each match on its own line, so a
            # one-line file is read the same as a pretty-printed one.
            top="$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$p" 2>/dev/null | head -n 1)"
            case "$top" in
                '"name"'*'"keel"') ;;
                *) continue ;;
            esac ;;
    esac
    is_staged "$p" && continue
    found="$found$p"$'\n'
done <<EOF
$hits
EOF

if [ -n "$found" ]; then
    printf '%s' "$found" | sort -u
    exit 1
fi
printf 'OK    nothing keel-shaped outside the staged dirs\n'
exit 0
