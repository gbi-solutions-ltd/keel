#!/usr/bin/env bash
# Line-number citations must still point at something. Free, fast, runs on every commit.
#
# This repository cites itself 1,003 times in the form `path/file.md:123` or `path/file.sh:45-67`,
# and until this file existed nothing checked a single one. They go stale silently: insert a
# paragraph anywhere above a cited line and every citation below it now names different content,
# with no broken link, no failed build and no way to notice short of following each one by hand.
#
# The incident. On 2026-09-07 two entries were prepended to tests/evals/results.md and shifted it by
# 479 lines. All 55 citations into that file written before that day moved off their content at
# once. Seven were found by hand, the worst being docs/ideas/tdd-cycle-cost-and-case-coverage.md
# citing `tests/evals/results.md:181` for an arm that "Checked the exception list explicitly and
# said none applied": line 181 is blank and the sentence had moved to line 597.
#
# WHAT IT CHECKS, AND WHY IT IS ONLY THREE RULES. The cited file must exist, the cited lines must be
# inside it, and the first cited line must not be blank. That is the set of claims with exactly one
# right answer derivable from the tree, which is the same bar tests/test-doc-claims.sh sets for
# README counts.
#
# The obvious fourth rule, checking that a phrase quoted beside the citation appears near the cited
# line, was written, measured and thrown away. On the 725 citations that pass the three rules it
# matched 23 and failed 53, and the 53 were paraphrases, quotations of other repositories' files,
# quotes with markdown emphasis added or dropped, and lines carrying two citations where the quote
# belongs to only one. A 70% false positive rate would make this the check people learn to ignore,
# and CONTRIBUTING.md says the too-strict failure is the unrecoverable one.
#
# WHAT IT DELIBERATELY LEAVES ALONE, for the same reason. Citations inside fenced code blocks are
# examples rather than claims about this tree: skills/repo-snapshot/references/section-templates.md
# shows a filled-in snapshot citing `.github/workflows/deploy.yml:34` for somebody else's
# repository, and that is the only path in the tree naming a file that does not exist. And 166
# citations use a shorthand that drops the leading directory, writing `stage.sh:12` for
# tests/evals/stage.sh, so a path whose first segment names no directory here is skipped rather than
# guessed at: resolving those by suffix match is how a checker starts reporting the wrong file's
# line count.
#
# WHAT IT SCANS. Every document under docs/ and skills/, the top-level markdown, and the whole-line
# comments of bin/, hooks/, lib/ and the two eval scripts. The code trees were added on 2026-09-07
# after this file shipped without them: they carried 28 comment citations that nothing checked, two
# of them already stale.
#
# Four categories are left out of the code scan, each for a measured reason. Executing code, because
# a path there is an argument to a command rather than a claim, and the tree already holds an
# assertion on the literal string "untagged.md:2 fenced.md:5". Trailing comments, because separating
# a real one from a `#` inside a quoted string needs a shell parser, and no citation in the tree is
# written that way. tests/evals/fixtures/, because those eleven stand-in projects are wrong on
# purpose and their paths name their own trees. And tests/evals/results.md, for the same reason at
# one remove: it records what an arm did inside a staged fixture, in that fixture's paths, and two
# of its citations name `docs/runbooks/payout-worker.md`, which exists under a fixture and not here.
# Scanning it would report two missing files that are neither missing nor wrong. templates/ is out
# too: its two documents describe the repository they are copied into, not this one.
#
# Usage: tests/validate-citations.sh   (from the repository root)
# Exits 0 when clean, 1 when any citation is stale.

set -uo pipefail

errors=0
checked=0
report() { printf 'FAIL  %s\n' "$1"; errors=$((errors+1)); return 0; }

# The same file set tests/validate-skills.sh scans for broken markdown links, plus skills/, because
# a skill body cites too and is read by the model rather than by someone who can see the line number
# is 400 off.
files=()
while IFS= read -r f; do
    [ -n "$f" ] && files+=("$f")
done < <({ find docs skills -name '*.md' 2>/dev/null
           find . -maxdepth 1 -name '*.md' 2>/dev/null | sed 's|^\./||'; })

# The code trees, added after the first version of this file shipped scanning documents only. Two of
# the 28 citations sitting in comments under these directories were stale the day the gap was found:
# tests/test-eval-harness.sh cited the eval log for a note about a staged tree having no skills/
# directory, and the cited line had moved onto a sentence about the coverage check. A comment is
# read by whoever is about to change the code, so a stale one there misleads the one person who
# cannot afford it, and nothing was checking a single one of them.
#
# Globs rather than a recursive find, because every directory left out below was left out for a
# reason and a find would quietly take them back.
code_files=()
for f in bin/* hooks/* lib/*.sh lib/harness/* lib/*.py tests/*.sh tests/evals/*.sh; do
    # The two files below are this checker and its tests, and they are the only two in the tree
    # whose subject is stale citations. Their worked examples have to be stale to be examples: the
    # header of this file quotes `tests/evals/results.md:181` as the citation that earned it, line
    # 181 is blank and is meant to stay blank, and the tests build seven more fixtures the same way.
    # Reading those as claims made the extension report its own documentation as broken on its first
    # run, which is circular. Two paths written out in full, and no marker a third file could carry:
    # a general escape hatch is the allow-list this repository refused, on the grounds that it
    # becomes the thing people learn to write instead of the fix.
    case "$f" in
        tests/validate-citations.sh|tests/test-validate-citations.sh) continue ;;
    esac
    [ -f "$f" ] && code_files+=("$f")
done

[ "$((${#files[@]} + ${#code_files[@]}))" -gt 0 ] || { printf 'OK    no documents to check\n'; exit 0; }

# One awk pass over every document rather than one process per file. The fence state resets at FNR
# 1 so an unclosed fence in one document cannot swallow the next one, and the toggling rule comes
# before the skip so the closing delimiter is seen.
# shellcheck disable=SC2016
# The braces and $0 below are awk's, not the shell's.
# An extensioned path, as before, or any path with a directory in it. The second alternative is what
# reaches bin/keel and hooks/*, which carry no extension: 420 citations in this tree point at such a
# file, 351 of them at bin/keel, and until this alternative existed the checker read none of them
# while reporting a count that sounded exhaustive. That is the real reason a 47 line insertion into
# bin/keel moved 32 correct citations in silence on 2026-09-09; the blank-line limit below was the
# second reason, not the first.
#
# A bare word with no slash and no extension is not matched, so "10:30" is not a citation. "70/30:1"
# is matched, because the regex cannot tell it from a path, and the resolution loop drops it because
# "70" is not a directory here. Both halves are pinned in tests/test-validate-citations.sh.
CITATION_RE='([A-Za-z0-9._/-]+[.](md|sh|json|yml|yaml|txt|toml)|[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+):[0-9]+(-[0-9]+)?'

# Resolution happens here, in shell builtins, because deciding whether a first path segment is a
# directory is a test awk has no clean answer for. Nothing in this loop forks.
records=""
while IFS=$'\t' read -r citing cline cit; do
    checked=$((checked+1))
    path="${cit%:*}"
    span="${cit##*:}"
    start="${span%%-*}"
    end="${span##*-}"

    dir="${citing%/*}"
    [ "$dir" = "$citing" ] && dir="."

    if [ -f "$path" ]; then
        target="$path"
    elif [ -f "$dir/$path" ]; then
        target="$dir/$path"
    else
        # Root anchored means the citation is making a claim about this tree, so a missing file is
        # the citation's fault. Anything else is the shorthand described in the header, and is not
        # this check's business.
        #
        # A path with no extension is exempt from this branch, and only from this branch. An
        # extensionless path that resolves is checked in full, which is the 351 citations into
        # bin/keel this file could not see until 2026-09-09. One that does not resolve is shorthand
        # or a fixture name, not a rename: `docs/03:177` means doc 03 in a plan that names four
        # documents that way, and `code:bin/reader:0` is a validator fixture quoted by the plan that
        # added the rule. Reporting those two shapes as missing files is the too-strict failure
        # CONTRIBUTING.md calls unrecoverable, and it would arrive on six citations at once.
        seg="${path%%/*}"
        case "${path##*/}" in *.*) has_ext=1 ;; *) has_ext=0 ;; esac
        if [ "$has_ext" -eq 1 ] && [ "$seg" != "$path" ] && [ -d "$seg" ]; then
            report "$citing:$cline cites \`$cit\`, and $path does not exist. The file was renamed or deleted and the citation was left behind."
        fi
        continue
    fi

    # A file that changes often, cited by line, from a document that says what is true now. These
    # three take insertions in most weeks: 47 lines landed in bin/keel in one commit on 2026-09-09
    # and moved 32 citations that had been correct. The list is written out rather than derived from
    # git history, because a rule whose membership changes when somebody commits is one nobody can
    # predict, and a check people cannot predict is the one they learn to ignore.
    case "$target" in
        bin/keel|tests/validate-skills.sh|tests/test-keel.sh)
            case "$citing" in
                # Records. Each says when it was written, and that date is what tells a reader how
                # far to trust its line numbers. Repairing a pointer in one is allowed and rewriting
                # its claims is not, so requiring a phrase here would be asking for the second.
                docs/plans/*|docs/prd/*|docs/stories/*|docs/architecture/*|docs/decisions/*| \
                docs/audits/*|docs/ideas/*|docs/07-open-decisions.md|docs/harness-support.md| \
                tests/evals/*|CHANGELOG.md) ;;
                *) report "$citing:$cline cites \`$cit\`, and $target changes often enough that a line number there is stale within about one task. Cite a phrase instead: \`$target#<text from the line>\`." ;;
            esac
            ;;
    esac

    records="$records$citing:$cline	$target	$start	$end	$cit
"
done < <(
    if [ "${#files[@]}" -gt 0 ]; then
        awk -v re="$CITATION_RE" '
            FNR == 1 { fence = 0 }
            /^ *```/ { fence = !fence; next }
            fence    { next }
            {
                rest = $0
                while (match(rest, re)) {
                    printf "%s\t%d\t%s\n", FILENAME, FNR, substr(rest, RSTART, RLENGTH)
                    rest = substr(rest, RSTART + RLENGTH)
                }
            }
        ' "${files[@]}"
    fi
    # A citation in a comment is a claim. A path in executing code is an argument to a command, so
    # only whole-line comments are read here. tests/test-harness-claims.sh asserts on the literal
    # string "untagged.md:2 fenced.md:5" and tests/test-validate-citations.sh builds every one of
    # its fixtures out of citations that are deliberately wrong: reading those as claims would have
    # made the extension fail on its own test data on its first run. A trailing comment is left
    # alone too, because telling a real one from a `#` inside a quoted string needs a shell parser,
    # and there is not one such citation in the tree to justify the attempt.
    if [ "${#code_files[@]}" -gt 0 ]; then
        awk -v re="$CITATION_RE" '
            /^[ \t]*#/ {
                rest = $0
                while (match(rest, re)) {
                    printf "%s\t%d\t%s\n", FILENAME, FNR, substr(rest, RSTART, RLENGTH)
                    rest = substr(rest, RSTART + RLENGTH)
                }
            }
        ' "${code_files[@]}"
    fi
)

# The line counts and blank lines of every cited file, read once each and cached, because
# tests/evals/results.md alone is cited 55 times and is 4,397 lines long. A `wc -l` and a `sed -n`
# per citation is two thousand processes and the reason a check like this gets dropped from the
# suite for being slow.
if [ -n "$records" ]; then
    problems="$(printf '%s' "$records" | awk -F'\t' '
        function nlines(f,   n, line) {
            if (f in total) return total[f]
            n = 0
            while ((getline line < f) > 0) {
                n++
                if (line ~ /^[ \t]*$/) blank[f, n] = 1
            }
            close(f)
            total[f] = n
            return n
        }
        {
            where = $1; target = $2; start = $3 + 0; end = $4 + 0; cit = $5
            n = nlines(target)
            # An inverted range. Every other rule here passes one: the end is inside the file and
            # the first line is not blank. It is what a mechanical repair produces when it rewrites
            # the start of a range and leaves the end, which a881010 did twice on 2026-09-09.
            if (end < start) {
                printf "%s cites `%s`, and the range ends before it starts. A repair that rewrote the start and left the end produces exactly this, and every other rule here passes it.\n", where, cit
                next
            }
            if (end > n) {
                printf "%s cites `%s`, and %s is %d lines long. Cite a phrase grep can find instead of a line number.\n", where, cit, target, n
                next
            }
            # A range is judged on its first line only. A real range spans paragraphs and the blank
            # line between them is part of what it names.
            if ((target, start) in blank) {
                printf "%s cites `%s`, and line %d of %s is blank. Whatever it named has moved: replace the line number with a phrase from the text.\n", where, cit, start, target
            }
        }
    ')"
    if [ -n "$problems" ]; then
        while IFS= read -r problem; do
            report "$problem"
        done <<<"$problems"
    fi
fi

# ------------------------------------------------------------------ the phrase form
# `path#phrase` rather than `path:line`. A line number into a file that changes often has a half
# life of about one task, measured on the branch that added this: one insertion of 47 lines into
# bin/keel moved 32 citations that resolved correctly before it, and nothing went red. The three
# rules above are every claim a line number can support. A phrase supports the one a reader wants,
# which is that the text this sentence names is still there.
#
# Backticks bound the phrase, and nothing else can: a phrase in running prose has no end delimiter,
# and every citation in this repository is already written inside backticks.
#
# The phrase is matched literally, anywhere in the file, and it is not required to be unique. A
# phrase occurring twice still resolves, and rejecting it would be stricter than correct output,
# which CONTRIBUTING.md calls the unrecoverable failure. The conversion that moved this repository
# onto the form chose unique phrases by hand; the rule does not demand it.
# shellcheck disable=SC2016
PHRASE_RE='`[A-Za-z0-9._/-]+([.](md|sh|json|yml|yaml|txt|toml))?#[^`]+`'

phrase_records=""
while IFS=$'\t' read -r citing cline cit; do
    cit="${cit#\`}"; cit="${cit%\`}"
    path="${cit%%#*}"
    phrase="${cit#*#}"
    checked=$((checked+1))

    dir="${citing%/*}"
    [ "$dir" = "$citing" ] && dir="."

    if [ -f "$path" ]; then
        target="$path"
    elif [ -f "$dir/$path" ]; then
        target="$dir/$path"
    else
        # The same rule the line form uses: root anchored means the citation is a claim about this
        # tree. Anything else is an anchor in a markdown link or another repository's path, and is
        # not this check's business.
        seg="${path%%/*}"
        if [ "$seg" != "$path" ] && [ -d "$seg" ]; then
            report "$citing:$cline cites \`$cit\`, and $path does not exist. The file was renamed or deleted and the citation was left behind."
        fi
        continue
    fi

    case "$phrase" in
        *"|"*)
            report "$citing:$cline cites \`$cit\`, and the phrase contains a pipe. docs/profile-keys.md renders these citations inside a markdown table, where a pipe ends the cell. Choose a phrase without one."
            continue ;;
    esac

    phrase_records="$phrase_records$citing:$cline	$target	$phrase	$cit
"
done < <(
    if [ "${#files[@]}" -gt 0 ]; then
        awk -v re="$PHRASE_RE" '
            FNR == 1 { fence = 0 }
            /^ *```/ { fence = !fence; next }
            fence    { next }
            {
                rest = $0
                while (match(rest, re)) {
                    printf "%s\t%d\t%s\n", FILENAME, FNR, substr(rest, RSTART, RLENGTH)
                    rest = substr(rest, RSTART + RLENGTH)
                }
            }
        ' "${files[@]}"
    fi
    if [ "${#code_files[@]}" -gt 0 ]; then
        awk -v re="$PHRASE_RE" '
            /^[ \t]*#/ {
                rest = $0
                while (match(rest, re)) {
                    printf "%s\t%d\t%s\n", FILENAME, FNR, substr(rest, RSTART, RLENGTH)
                    rest = substr(rest, RSTART + RLENGTH)
                }
            }
        ' "${code_files[@]}"
    fi
)

# One read per cited file, cached, for the same reason the line pass caches its counts.
if [ -n "$phrase_records" ]; then
    phrase_problems="$(printf '%s' "$phrase_records" | awk -F'\t' '
        function body(f,   s, line) {
            if (f in cache) return cache[f]
            s = ""
            while ((getline line < f) > 0) s = s line "\n"
            close(f)
            cache[f] = s
            return s
        }
        {
            where = $1; target = $2; phrase = $3; cit = $4
            if (index(body(target), phrase) == 0)
                printf "%s cites `%s`, and that text is not in %s. The phrase was edited or removed: quote it from the file as it reads now, or say what replaced it.\n", where, cit, target
        }
    ')"
    if [ -n "$phrase_problems" ]; then
        while IFS= read -r problem; do
            report "$problem"
        done <<<"$phrase_problems"
    fi
fi

if [ "$errors" -eq 0 ]; then
    printf 'OK    %s citations checked across %s documents and %s code files\n' \
        "$checked" "${#files[@]}" "${#code_files[@]}"
    exit 0
fi
printf '\n%s stale citation(s) found\n' "$errors"
exit 1
