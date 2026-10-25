#!/usr/bin/env bash
# Stage the release-gate treatment arms, one directory each, and write the script that dispatches
# them. This script runs no claude, with or without --dry-run.
#
# Usage: tests/evals/gate.sh [--runs N] [--scenarios FILE] [--model ID] [--dry-run] OUT
#
# Why this is a script and not a paragraph: the dispatch loop lived pasted in
# docs/runbooks/cutting-a-release.md, where no test could reach it, and it had produced two gates
# from a scratch directory. A committed script is tested by tests/test-eval-harness.sh and is the
# first piece of a release command.
#
# Why it stages and does not dispatch (L-01 of docs/audits/2026-10-18-security.md): arms run with
# bypassPermissions and search the machine with `find /`, so they are dispatched only from a
# workspace where nothing else is within reach, and a script inside the checkout cannot be that
# place, because the checkout is the first thing within reach. So the dispatch half is written into
# OUT as dispatch.sh, which is run from a disposable workspace after the checkout is no longer
# there, and which refuses to dispatch while a copy of isolation-check.sh finds anything
# keel-shaped outside the staged directories.
#
# What that check does not see: it matches keel-shaped names (skill trees, scenario files, a keel
# plugin manifest, leftover staged directories), not credentials, other repositories or text that
# quotes the criteria. Those are kept out of reach by where the gate is run, which the check cannot
# prove, and a clean result is the absence of those shapes and nothing more. The credential claude
# runs on is in the workspace too, and every arm inherits the environment under bypassPermissions
# and can read it, so a gate runs on a scoped, revocable key and not on a personal one.
#
# What it writes, all under OUT and none of it inside a staged directory, because the staged
# directory is the arm's world and an arm that finds its own results beside its work is a
# difference in treatment:
#
#   OUT/<scenario>.<run>.dir     the staged directory's path, kept so an unfinished gate is resumed
#                                by reading the artifacts rather than by paying for the arms twice
#   OUT/dispatch.sh              the dispatch: it carries this script's model and flags and no path
#                                to the repository or to OUT, and it writes the three files below
#   OUT/isolation-check.sh       a copy of tests/evals/isolation-check.sh, run by dispatch.sh
#   OUT/scenario-names.txt       every scenario's name, one per line, which the check turns into
#                                <scenario>.md patterns; the dispatch cannot read the repository
#
# and dispatch.sh writes, beside them:
#
#   OUT/<scenario>.<run>.jsonl   the arm's stream-json output; its final `result` record carries
#                                the model and the cost
#   OUT/<scenario>.<run>.err     the arm's stderr
#   OUT/exits.txt                one line per arm, `<scenario>.<run> exit=<code>`
#
# The three files are written after staging whether or not a stage failed, so an unfinished gate is
# dispatched from what did stage. The exit code is 1 when a stage failed and 0 otherwise.
#
# --runs N stages every scenario N times, each in its own staged directory, because a pass rate
# needs more than one run and two runs sharing a directory race on the same files.
# --scenarios FILE replaces tests/evals/gate-scenarios, so a test can make one stage fail. A line is
# a scenario name, or a comment when its first non-blank character is `#`. A name may hold only
# lowercase letters, digits and hyphens, because it becomes a file name under OUT: `../escape` would
# write outside OUT, and a name that is not a scenario is a stage failure that stages nothing.
# --dry-run also prints each dispatch command, which it would be wrong to read as the dispatch: the
# line is for a person to read or paste, and each ends `< /dev/null` as the real dispatch does.
#
# Scoring stays reading (tests/evals/README.md, "Scoring is deliberately human"); this script
# stages and writes the dispatch and nothing else.
#
# Portable to the bash 3.2 and BSD userland a Mac ships: no realpath -m, no mapfile, no GNU flags,
# and no expansion of a possibly empty array under `set -u`, which bash 3.2 treats as unbound. The
# script it writes is held to the same.

set -uo pipefail; unset CDPATH  # a cd that finds its directory through CDPATH prints it

caller="$PWD"
cd "$(dirname "$0")/../.." || exit 1
repo="$(pwd -P)"

usage() {
    printf 'usage: tests/evals/gate.sh [--runs N] [--scenarios FILE] [--model ID] [--dry-run] OUT\n' >&2
    exit 2
}

# A path given relative is relative to where the person ran the script, not to the repository this
# script has just moved into.
absolute() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *)  printf '%s/%s\n' "$caller" "$1" ;;
    esac
}

runs=1
scenarios="$repo/tests/evals/gate-scenarios"
model=""
dry=0
out=""
while [ $# -gt 0 ]; do
    case "$1" in
        --runs)      [ $# -ge 2 ] || usage; runs="$2"; shift 2 ;;
        --scenarios) [ $# -ge 2 ] || usage; scenarios="$(absolute "$2")"; shift 2 ;;
        --model)     [ $# -ge 2 ] || usage; model="$2"; shift 2 ;;
        --dry-run)   dry=1; shift ;;
        --)          shift; break ;;
        -*)          printf 'unknown flag: %s\n' "$1" >&2; usage ;;
        *)           [ -z "$out" ] || usage; out="$(absolute "$1")"; shift ;;
    esac
done
if [ $# -gt 0 ]; then
    if [ -n "$out" ] || [ $# -ne 1 ]; then usage; fi
    out="$(absolute "$1")"
fi
[ -n "$out" ] || usage

# A count that is not a positive integer would loop forever or never, and either is a gate that
# silently ran the wrong number of arms.
# `printf --` below: a format that starts with `-` is read by the builtin as an option and lost.
case "$runs" in
    ''|*[!0-9]*|0|00*) printf -- '--runs wants a positive integer, got: %s\n' "$runs" >&2; exit 2 ;;
esac
[ -f "$scenarios" ] || { printf 'no such scenarios file: %s\n' "$scenarios" >&2; exit 2; }

# Refuse an OUT inside the repository, for the reason stage.sh refuses a staging directory there:
# an arm can find the scenario files from inside the tree.
#
# OUT is resolved WITHOUT being created first, because creating it and then checking would leave
# the refused directory behind. macOS has no `realpath -m`, so walk up to the nearest ancestor that
# exists, take its physical path with `cd -P` and `pwd -P` (which follow symlinks, the case a
# textual prefix check misses; a plain `cd` drops `<link>/..` textually and resolves it to the
# link's parent instead of through the link), and append the components that do not exist yet.
tail_path=""
probe="$out"
while [ ! -e "$probe" ]; do
    tail_path="/$(basename "$probe")$tail_path"
    probe="$(dirname "$probe")"
done
# A `..` in the part that does not exist yet cannot be resolved without creating it, and a textual
# check would be fooled by `nope/../..`, so it is refused rather than guessed at.
case "$tail_path/" in
    */../*) printf 'refusing an OUT with .. in a part that does not exist yet: %s\n' "$out" >&2; exit 2 ;;
esac
[ -d "$probe" ] || { printf 'OUT is not a directory: %s\n' "$probe" >&2; exit 2; }
probe_physical="$(cd -P "$probe" && pwd -P)"
# An existing directory that cannot be entered makes cd fail. An empty path would start the walk
# below at `dirname ""`, which is `.`, the repository: a refusal for the wrong reason.
[ -n "$probe_physical" ] || { printf 'cannot resolve %s\n' "$probe" >&2; exit 2; }
resolved="${probe_physical}${tail_path}"
# An OUT with any part named keel-eval-* is one the isolation check reports (it reports every
# directory so named, as a leftover staged directory), and the dispatch run from inside it, or from
# under a directory so named, would refuse itself. Both the spelling given and the resolved path are
# looked at, since a link can put the name in either. L-01: refused here, before anything is
# created, rather than found when a gate is paid for.
for chk in "$out" "$resolved"; do
    case "/$chk/" in
        */keel-eval-*)
            printf 'refusing an OUT with a part named keel-eval-*: the isolation check reports such a directory: %s\n' "$out" >&2
            exit 2 ;;
    esac
done
inside=0
case "$resolved" in
    "$repo"|"$repo"/*) inside=1 ;;
esac
# That compared spellings, and a case-insensitive volume (macOS APFS is one by default) has several
# spellings of one directory: ~/Keel/tests/out passes the comparison for a repository at ~/keel.
# So ask the filesystem too: walk up from the nearest existing ancestor and test each with -ef,
# which compares device and inode and so does not care how the path is spelled.
a="$probe_physical"
while [ "$inside" -eq 0 ]; do
    if [ "$a" -ef "$repo" ]; then inside=1; break; fi
    [ "$a" = "/" ] && break
    a="$(dirname "$a")"
done
if [ "$inside" -eq 1 ]; then
    printf 'refusing OUT inside the repository: %s\nan arm can find the scenario files from inside the tree; use a directory outside it.\n' "$out" >&2
    exit 2
fi

# Overwriting .dir files loses the paths of arms that were paid for and may be half scored.
# Read into a variable rather than piped into grep -q: under pipefail a find cut short by grep
# leaving at the first match fails the pipeline, and a miss here overwrites a paid gate.
existing=""
[ -d "$out" ] && existing="$(find "$out" -maxdepth 1 -name '*.dir' 2>/dev/null)"
if [ -n "$existing" ]; then
    printf 'OUT already holds .dir files: %s\nan unfinished gate is resumed from them; use a new directory.\n' "$out" >&2
    exit 2
fi

mkdir -p "$out" || exit 1

# Every flag here is load bearing; the reasons are in tests/evals/README.md ("Every flag there is
# load bearing") and are not repeated. stream-json --verbose rather than json, so the tool calls
# a rubric turns on can be read back, and its last record carries the same model and cost.
flags=(--setting-sources "" --disable-slash-commands --permission-mode bypassPermissions
       --output-format stream-json --verbose)

stage_total=0
stage_ok=0
failed=""
arms=""
r=1
while [ "$r" -le "$runs" ]; do
    while IFS= read -r s || [ -n "$s" ]; do
        s="${s%"${s##*[![:space:]]}"}"
        s="${s#"${s%%[![:space:]]*}"}"
        case "$s" in ''|'#'*) continue ;; esac
        name="$s.$r"
        stage_total=$((stage_total + 1))
        # The class is spelled out rather than written as ranges: in a UTF-8 locale a range can
        # match more than its ends name. Nothing is written for a refused name, because the name is
        # what would have chosen the file.
        case "$s" in
            *[!abcdefghijklmnopqrstuvwxyz0123456789-]*)
                printf 'STAGE FAILED: %s\n  not a valid scenario name (lowercase letters, digits and hyphens only)\n' "$name" >&2
                failed="$failed $name"
                continue ;;
        esac
        # stdin from /dev/null so staging cannot consume the scenarios file this loop is reading.
        dir="$(tests/evals/stage.sh "$s" 2>"$out/$name.stage-err" </dev/null)"
        # stage.sh prints the directory only after it has built project/ and exits non-zero without
        # printing on every failure, so a non-empty path is a whole stage. A second test for
        # "$dir/project" could not be reached with stage.sh as it is, and an unreachable guard
        # reads as a protection nobody has proved.
        if [ -n "$dir" ]; then
            printf '%s\n' "$dir" > "$out/$name.dir"
            rm -f "$out/$name.stage-err"
            stage_ok=$((stage_ok + 1))
            arms="$arms $name"
        else
            printf 'STAGE FAILED: %s\n' "$name" >&2
            sed 's/^/  /' "$out/$name.stage-err" >&2
            failed="$failed $name"
        fi
    done < "$scenarios"
    r=$((r + 1))
done

if [ "$stage_total" -eq 0 ]; then
    printf 'no scenarios in %s\n' "$scenarios" >&2
    exit 2
fi

summary="staged $stage_ok of $stage_total"
rc=0
if [ -n "$failed" ]; then
    summary="$summary, $((stage_total - stage_ok)) failed:$failed"
    rc=1
fi

# The scenario names go in a file because the dispatch runs from OUT with the checkout gone, and the
# isolation check needs them to find a copy of a scenario file by name (L-01: an arm that searches
# the machine reads the criteria it is scored by). A name outside [a-z0-9-] cannot be a scenario
# file's name, and the check skips it with a line, so nothing is filtered here.
: > "$out/scenario-names.txt" || { printf 'cannot write %s/scenario-names.txt\n' "$out" >&2; exit 1; }
for f in tests/evals/scenarios/*.md; do
    [ -e "$f" ] || continue
    basename "$f" .md >> "$out/scenario-names.txt"
done
cp tests/evals/isolation-check.sh "$out/isolation-check.sh" \
    || { printf 'cannot copy isolation-check.sh into %s\n' "$out" >&2; exit 1; }

# OUT/dispatch.sh. It holds no path to the repository or to OUT: it finds its own directory when it
# runs, so it works from a workspace that has no checkout, which is the point (L-01). The model and
# the flags are written into it with %q, one word each, so a space or an empty flag value survives;
# the model is added by branch, not by a ${model:+...} expansion, whose word splitting differs
# between bash 3.2 and later versions. The flags array is never empty, so expanding it under
# `set -u` is safe on bash 3.2. The body is a quoted heredoc, so nothing in it is expanded here.
{
    cat <<'HEADER'
#!/usr/bin/env bash
# Dispatch the staged release-gate arms (L-01 of docs/audits/2026-10-18-security.md): they run with
# bypassPermissions and search the machine, so run this from a disposable workspace that holds no
# keel checkout, no personal credentials beyond a scoped key for the gate, and no other
# repositories.
# It refuses, and dispatches nothing, while isolation-check.sh finds anything keel-shaped outside
# the staged directories, and it refuses a directory that already holds results, because a second
# run pays for the arms twice.
# That check matches names only, not credentials, other repositories or text that quotes criteria,
# so a clean result is not proof that nothing else is within reach.
HEADER
    printf 'flags=('
    for f in "${flags[@]}"; do
        printf ' %q' "$f"
    done
    if [ -n "$model" ]; then
        printf ' --model %q' "$model"
    fi
    printf ' )\n'
    cat <<'BODY'

set -uo pipefail; unset CDPATH  # a cd that finds its directory through CDPATH prints it

here="$(cd "$(dirname "$0")" && pwd -P)" || exit 2

# Checked first, so an absent claude is found before anything is read or searched.
if ! command -v claude >/dev/null 2>&1; then
    printf 'claude is not on PATH; no arm was dispatched\n' >&2
    exit 2
fi

# Then the state of this directory. Nothing is written on a refusal.
n=0
for f in "$here"/*.dir; do
    [ -f "$f" ] || continue
    # A .dir file is the directory an arm is run in; an empty one or a relative one names no place
    # this script can trust, so nothing is dispatched.
    case "$(cat "$f")" in
        /*) ;;
        *)  printf 'refusing: %s is empty or holds a path that is not absolute\n' "$f" >&2
            exit 2 ;;
    esac
    n=$((n + 1))
done
if [ "$n" -eq 0 ]; then
    printf 'refusing: %s holds no .dir file, so there is nothing to dispatch\n' "$here" >&2
    exit 2
fi
for f in "$here/exits.txt" "$here"/*.jsonl; do
    if [ -e "$f" ]; then
        printf 'refusing: %s already holds %s; a second run pays for the arms twice\n' \
            "$here" "$(basename "$f")" >&2
        exit 2
    fi
done

# Then the isolation check, over every staged directory. The positional parameters are borrowed to
# hold them, which keeps each path one word and needs no array.
printf 'isolation check: searching %s for anything keel-shaped outside the staged directories\n' \
    "${KEEL_ISOLATION_ROOT:-/}"
if [ -n "${KEEL_ISOLATION_ROOT:-}" ]; then
    printf 'warning: the isolation check searches only %s; KEEL_ISOLATION_ROOT is for tests only\n' \
        "$KEEL_ISOLATION_ROOT" >&2
fi
set --
for f in "$here"/*.dir; do
    [ -f "$f" ] || continue
    set -- "$@" "$(cat "$f")"
done
check="$(bash "$here/isolation-check.sh" --names "$here/scenario-names.txt" "$@" 2>&1)"
code=$?
if [ "$code" -ne 0 ]; then
    printf '%s\n' "$check" >&2
    printf 'isolation check failed (exit %s); no arm was dispatched\n' "$code" >&2
    exit 2
fi
printf '%s\n' "$check"

# Each arm runs with its own TMPDIR, the directory stage.sh made beside its project/. Four
# concurrent review-code arms on 2026-10-18 met at one fixed worktree path under the shared temp
# directory and one edited another's tree through it (tests/evals/results.md, "the prune-to-the-
# target arms", follow-up 2). The directory is created here if stage.sh did not, so an arm is never
# handed a TMPDIR that does not exist, and a failure to create it is the arm's recorded exit. The
# arm's stdin is /dev/null so nothing typed or piped into this script reaches an arm that can run
# any command.
run_claude() {
    mkdir -p "$dir/tmp" || return 1
    TMPDIR="$dir/tmp" claude -p "$(cat ../prompt.md)" "${flags[@]}" < /dev/null
}

for f in "$here"/*.dir; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .dir)"
    dir="$(cat "$f")"
    (
        cd "$dir/project" || { printf '%s exit=cd-failed\n' "$name" >> "$here/exits.txt"; exit 1; }
        run_claude > "$here/$name.jsonl" 2> "$here/$name.err"
        code=$?
        printf '%s exit=%s\n' "$name" "$code" >> "$here/exits.txt"
    ) &
    printf 'dispatched %-40s %s\n' "$name" "$dir"
done
wait

# Arm exits are recorded, and a non-zero one fails the script too: a script that returns 0 over
# arms that did not complete lets a caller read a partial gate as a whole one.
if [ -f "$here/exits.txt" ] && grep -qv ' exit=0$' "$here/exits.txt"; then
    printf 'some arms exited non-zero; see %s/exits.txt\n' "$here" >&2
    exit 1
fi
BODY
} > "$out/dispatch.sh" || { printf 'cannot write %s/dispatch.sh\n' "$out" >&2; exit 1; }
chmod +x "$out/dispatch.sh"

if [ "$dry" -eq 1 ]; then
    for name in $arms; do
        dir="$(cat "$out/$name.dir")"
        # The line is for a person to read or paste, so it is built from the same flags array the
        # dispatch is written from, not a retyped list that could drift from it, and every path and
        # flag goes through %q so a space in a path or an empty flag value survives the paste. The
        # $(cat ../prompt.md) is printed literally on purpose: the line must show what the arm is
        # given, not expand it. It ends `< /dev/null` as the dispatch does.
        qflags=""
        for f in "${flags[@]}"; do
            qflags="$qflags $(printf '%q' "$f")"
        done
        [ -n "$model" ] && qflags="$qflags --model $(printf '%q' "$model")"
        # The TMPDIR prefix is the one dispatch.sh sets, for the same reason: the line is what runs.
        # shellcheck disable=SC2016
        printf 'cd %q && TMPDIR=%q claude -p "$(cat ../prompt.md)"%s > %q 2> %q < /dev/null\n' \
            "$dir/project" "$dir/tmp" "$qflags" "$out/$name.jsonl" "$out/$name.err"
    done
    printf 'the lines above dispatch with no isolation check; dispatch.sh runs the check\n' >&2
fi

# The next step goes to stderr, where a person reads it and a script piping the summary does not.
printf 'next: run bash %q from a disposable workspace that holds no keel checkout, no personal credentials beyond a scoped key for the gate, and no other repositories\n' \
    "$out/dispatch.sh" >&2
printf '%s\n' "$summary"
exit "$rc"
