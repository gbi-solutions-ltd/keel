#!/usr/bin/env bash
# Tests for validate-citations.sh.
#
# The citation checker is the one check in this repository whose failure mode is being too strict,
# so the cases below are half about what it catches and half about what it must leave alone.
# CONTRIBUTING.md calls the too-strict failure the unrecoverable one: a check that cries wolf over
# an illustrative path in a template teaches people to ignore it, and then the real stale citation
# goes past unread as well. Cases 7 to 9 and 12 are that half, and they are not padding.
#
# The incident. On 2026-09-07 two entries were prepended to tests/evals/results.md, shifting it by
# 479 lines, and every citation into that file written before that day moved off its content in
# total silence. Seven were found by hand. The worst was
# docs/ideas/tdd-cycle-cost-and-case-coverage.md, which cited `tests/evals/results.md:181` for an
# arm that "Checked the exception list explicitly and said none applied": line 181 is blank and the
# sentence had moved to line 597, 416 lines away. Case 4 reproduces that exact shape in a fixture
# rather than asserting against the live tree, because the live tree gets fixed and the assertion
# would then pin nothing.
#
# Each case builds a throwaway tree in a temp dir, runs the checker against it, and asserts on the
# exit code. Run from the repo root.

# Single quotes are deliberate throughout: these printf and heredoc strings must emit literal
# backticks, which is how every citation in this repository is written.
# shellcheck disable=SC2016

set -uo pipefail

CHECKER="$(cd "$(dirname "$0")/.." && pwd)/tests/validate-citations.sh"
pass=0
fail=0

# A tree whose every citation points at real content, in each of the shapes the real repository
# uses: a repo-root path from a doc, a path relative to the citing file from a skill, and a range.
fixture_valid() {
    local root="$1"
    mkdir -p "$root/docs/ideas" "$root/skills/example/references" "$root/tests/evals" "$root/hooks"

    cat > "$root/tests/evals/results.md" <<'RESULTS'
# Eval results

## An entry

A paragraph belonging to the first entry.
Checked the exception list explicitly and said none applied.

## A second entry

The last line of the file.
RESULTS

    cat > "$root/docs/ideas/example.md" <<'DOC'
# An idea

That mechanism has been exercised under pressure and held: `tests/evals/results.md:6` records an
arm that "Checked the exception list explicitly and said none applied".

The surrounding entry is at `tests/evals/results.md:3-6`.

The same claim by phrase: `tests/evals/results.md#Checked the exception list explicitly`.

The hook settles it at `hooks/example-hook:4`.
DOC

    cat > "$root/skills/example/SKILL.md" <<'SKILL'
---
name: example
description: Use when a test needs a skill that cites a sibling reference.
---

# Example

The rule is at `references/thing.md:3`.
SKILL

    cat > "$root/skills/example/references/thing.md" <<'THING'
# Thing

The rule this file exists to state.
THING

    printf '# Readme\n\nThe entry is at `tests/evals/results.md:6`.\n' > "$root/README.md"
    printf '# Contributing\n\nThe entry is at `tests/evals/results.md:6`.\n' > "$root/CONTRIBUTING.md"

    # A shell test and an extensionless hook, each carrying the two shapes the code trees carry: a
    # citation in a header comment, which is a claim, and a path inside executing code, which is an
    # argument to a command.
    cat > "$root/tests/test-example.sh" <<'CODE'
#!/usr/bin/env bash
# The arm that earned this case is at `tests/evals/results.md:6`.
set -uo pipefail
sed -n '6p' tests/evals/results.md
CODE

    cat > "$root/hooks/example-hook" <<'HOOK'
#!/usr/bin/env bash
# The assumption this hook settles is recorded at `tests/evals/results.md:6`.

set -uo pipefail
exit 0
HOOK
}

check() {
    local name="$1" expected="$2" root="$3"
    ( cd "$root" && "$CHECKER" >/dev/null 2>&1 )
    local actual=$?
    if [ "$actual" -eq "$expected" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (expected exit %s, got %s)\n' "$name" "$expected" "$actual"; fail=$((fail+1))
    fi
}

run() {
    local name="$1" expected="$2" mutate="$3"
    local root; root="$(mktemp -d)"
    fixture_valid "$root"
    "$mutate" "$root"
    check "$name" "$expected" "$root"
    rm -rf "$root"
}

noop() { :; }

# Case 1. The baseline. Every other case is a one-line mutation of this tree, so if this one ever
# goes red the rest of the file is asserting nothing about the mutation it names.
run "a tree whose citations all point at content passes" 0 noop

# Case 2. The cited file was deleted or renamed. The path is repo-root anchored, so the checker can
# tell the difference between a path that is wrong and a path it cannot resolve.
m_missing_file() { sed -i.bak 's|tests/evals/results.md:6`|docs/gone.md:6`|' "$1/docs/ideas/example.md"; }
run "a citation into a file that does not exist is rejected" 1 m_missing_file

# Case 3. The cited file shrank below the citation.
m_past_end() { sed -i.bak 's|tests/evals/results.md:6`|tests/evals/results.md:900`|' "$1/docs/ideas/example.md"; }
run "a citation past the last line of the cited file is rejected" 1 m_past_end

# Case 4. The 2026-09-07 incident, reproduced. Line 2 of the fixture's results.md is blank, the way
# line 181 of the real one is. A citation pointing at whitespace is always wrong: whatever it was
# written to name, it is not there now.
m_blank_line() { sed -i.bak 's|tests/evals/results.md:6`|tests/evals/results.md:2`|' "$1/docs/ideas/example.md"; }
run "a citation at a blank line is rejected" 1 m_blank_line

# Case 5. The same shrinkage, in the range form. The end of a range is the bound to check: a range
# whose end runs off the file is wrong even when its start still lands on content.
m_range_past_end() { sed -i.bak 's|tests/evals/results.md:3-6`|tests/evals/results.md:3-900`|' "$1/docs/ideas/example.md"; }
run "a range whose end is past the last line is rejected" 1 m_range_past_end

# Case 6. A range is checked at its first line, not every line, because a real range spans
# paragraphs and the blank between them is content. Only its start has to land on something.
m_range_starts_blank() { sed -i.bak 's|tests/evals/results.md:3-6`|tests/evals/results.md:2-6`|' "$1/docs/ideas/example.md"; }
run "a range starting at a blank line is rejected" 1 m_range_starts_blank

# Case 6a. The phrase form. A line number into a file that changes often dies within about one
# task, measured on the branch that added this rule: one insertion of 47 lines into bin/keel moved
# 32 citations that resolved correctly before it, and every rule this checker had reported OK. A
# phrase goes red when the text it names is gone, which is the claim a reader actually wants.
m_phrase_gone() {
    sed -i.bak 's|results.md#Checked the exception list explicitly|results.md#A sentence nobody wrote|' \
      "$1/docs/ideas/example.md"
}
run "a phrase citation whose text is not in the cited file is rejected" 1 m_phrase_gone

# Case 6b. The must-not-reject half. An anchor is part of a markdown link, not a citation, and three
# places in the real tree write `references/x.md#a-heading` while explaining exactly that. A rule
# that reads those as claims about this tree reports its own documentation as broken, which is how a
# checker gets ignored.
m_anchor_example() {
    printf 'A link of the form `references/x.md#a-heading` names a file and an anchor.\n' \
      >> "$1/docs/ideas/example.md"
}
run "an anchor-shaped example naming no repository directory is ignored" 0 m_anchor_example

# Case 6c. A phrase carrying a pipe cannot be printed into docs/profile-keys.md, which renders these
# citations inside a markdown table, so the pipe would end the cell and the row would lose its
# columns. Caught here rather than in the generator, because the generator has no way to say which
# marker did it.
m_phrase_with_pipe() {
    sed -i.bak 's|results.md#Checked the exception list explicitly|results.md#Checked \| the list|' \
      "$1/docs/ideas/example.md"
}
run "a phrase containing a pipe is rejected" 1 m_phrase_with_pipe

# Case 6d. A phrase citation into a file that does not exist is the same finding as a line one.
m_phrase_missing_file() {
    sed -i.bak 's|tests/evals/results.md#Checked|docs/gone.md#Checked|' "$1/docs/ideas/example.md"
}
run "a phrase citation into a file that does not exist is rejected" 1 m_phrase_missing_file

# Case 6e. A path with no file extension. bin/keel is the most cited file in the real repository and
# has no extension, so until this rule every one of its 351 citations was invisible to this checker
# while the summary line said "954 citations checked". 420 citations in that tree point at such a
# file. The regex required a dot and an extension, and neither bin/keel nor anything under hooks/
# has one.
m_extensionless_blank() {
    sed -i.bak 's|hooks/example-hook:4|hooks/example-hook:3|' "$1/docs/ideas/example.md"
}
run "a citation at a blank line of a file with no extension is rejected" 1 m_extensionless_blank

m_extensionless_past_end() {
    sed -i.bak 's|hooks/example-hook:4|hooks/example-hook:900|' "$1/docs/ideas/example.md"
}
run "a citation past the end of a file with no extension is rejected" 1 m_extensionless_past_end

# Case 6f. The must-not-reject half of the same rule. A bare word and a number is not a citation: a
# time, a ratio and a version all have that shape, and prose is full of them. The regex matches
# `70/30:1` because it cannot tell, and the resolution below drops it because "70" is not a
# directory in this tree. Both halves are the rule.
m_not_a_citation() {
    printf 'The run took 10:30 and the split was 70/30:1 by volume.\n' >> "$1/docs/ideas/example.md"
}
run "a colon and a number that names no file is ignored" 0 m_not_a_citation

# Case 6g. An inverted range, which is what a mechanical repair produces when it rewrites the start
# of a range and leaves the end. a881010 on this branch turned `bin/keel:77-78` into `bin/keel:100-78`
# and `CONTRIBUTING.md:132-136` into `CONTRIBUTING.md:138-136`, and this checker said OK on both:
# 78 is inside the file and line 100 is not blank, so every rule it had was satisfied.
m_inverted_range() {
    sed -i.bak 's|tests/evals/results.md:3-6|tests/evals/results.md:6-3|' "$1/docs/ideas/example.md"
}
run "a range whose start is after its end is rejected" 1 m_inverted_range

# Case 6h. The other must-not-reject half of the extensionless rule. A path with no extension that
# does not resolve is shorthand or a fixture name, not a rename. Six of these arrived on the first
# run of the rule above: three `docs/03:177` shorthands naming numbered documents, and three
# quotations of a validator fixture called bin/reader that exists only inside a temp tree.
m_extensionless_shorthand() {
    printf '\nDoc 03 says it at `docs/03:177`, and the fixture is `code:bin/reader:0`.\n' \
      >> "$1/docs/ideas/example.md"
}
run "an extensionless path that does not resolve is ignored" 0 m_extensionless_shorthand

# Case 6i. A line number into a file that changes often, from a document that says what is true now.
# bin/keel took 47 lines in one commit on the branch that added this rule, and 32 citations that
# were correct before it were not afterwards. The rule does not apply to the records that say what
# was true on a date: repairing a pointer in one is allowed and rewriting its claims is not, so a
# rule that failed the build over a plan's citation would be asking for the forbidden repair.
m_hot_line_in_live_doc() {
    mkdir -p "$1/bin"
    printf '#!/usr/bin/env bash\n# A comment.\necho hi\n' > "$1/bin/keel"
    printf 'The CLI does it at `bin/keel:2`.\n' >> "$1/README.md"
}
run "a line-number citation into bin/keel from a live document is rejected" 1 m_hot_line_in_live_doc

m_hot_line_in_dated_record() {
    mkdir -p "$1/bin" "$1/docs/plans"
    printf '#!/usr/bin/env bash\n# A comment.\necho hi\n' > "$1/bin/keel"
    printf '# A plan\n\nThe CLI did it at `bin/keel:2` on 2026-09-01.\n' > "$1/docs/plans/a.md"
}
run "a line-number citation into bin/keel from a dated record is left alone" 0 m_hot_line_in_dated_record

m_hot_phrase_in_live_doc() {
    mkdir -p "$1/bin"
    printf '#!/usr/bin/env bash\n# A comment.\necho hi\n' > "$1/bin/keel"
    printf 'The CLI does it at `bin/keel#A comment.`.\n' >> "$1/README.md"
}
run "a phrase citation into bin/keel from a live document is accepted" 0 m_hot_phrase_in_live_doc

# Case 7. skills/repo-snapshot/references/section-templates.md carries
# `.github/workflows/deploy.yml:34` inside a fenced block, as an example of what a filled-in
# snapshot looks like for somebody else's repository. It is the only citation in the whole tree that
# names a path that does not exist, and failing it would have been the checker's first false
# positive on its first run. A fenced block is an example, not a claim about this tree.
m_fenced() {
    cat >> "$1/docs/ideas/example.md" <<'FENCED'

```
| `deploy.target` | gcp-cloud-run | detected from `.github/workflows/deploy.yml:34` |
```
FENCED
}
run "a citation inside a fenced code block is ignored" 0 m_fenced

# Case 8. docs/ideas/standards-that-bind.md discusses a hypothetical TypeScript project and writes
# `tsconfig.json:14-16` about it. There is no tsconfig.json here and there is not meant to be. A
# bare filename names no directory in this tree, so the checker cannot know what it points at and
# must not guess.
m_bare_shorthand() {
    printf '\nD-1 is real: `tsconfig.json:14-16` still has the flags.\n' >> "$1/docs/ideas/example.md"
}
run "a bare shorthand path naming no repository directory is ignored" 0 m_bare_shorthand

# Case 9. The commoner shorthand: 166 citations in this repository drop the leading directory and
# write `stage.sh:12` or `write-docs/SKILL.md:33`, meaning tests/evals/stage.sh and
# skills/write-docs/SKILL.md. Resolving those by guessing at a suffix match is how a checker starts
# reporting the wrong file's line count. A path whose first segment is not a directory in this tree
# is left alone.
m_slashed_shorthand() {
    printf '\nThe guidance is at `write-docs/SKILL.md:33`.\n' >> "$1/docs/ideas/example.md"
}
run "a slashed shorthand path naming no repository directory is ignored" 0 m_slashed_shorthand

# Case 10. README.md is in scope. tests/test-doc-claims.sh already exists because README claims go
# stale in silence, and its citations are no different.
m_stale_in_readme() { sed -i.bak 's|tests/evals/results.md:6`|tests/evals/results.md:2`|' "$1/README.md"; }
run "a stale citation in README.md is rejected" 1 m_stale_in_readme

# Case 11. Skill bodies cite too, and a skill is read by the model rather than by a person who can
# see the citation is off by 400 lines.
m_stale_in_skill() { sed -i.bak 's|references/thing.md:3`|references/thing.md:900`|' "$1/skills/example/SKILL.md"; }
run "a stale citation under skills/ is rejected" 1 m_stale_in_skill

# Case 12. A skill citing `references/thing.md:3` means its own references directory, not a
# top-level one. Resolving relative to the citing file is what keeps case 11's shape checkable at
# all, and getting it wrong would fail every reference citation in every skill.
m_relative_ok() { sed -i.bak 's|references/thing.md:3`|references/thing.md:1`|' "$1/skills/example/SKILL.md"; }
run "a citation relative to the citing file resolves against that file's directory" 0 m_relative_ok

# Case 13. The same resolution, going the other way, so case 12 cannot pass by the checker having
# quietly skipped relative paths altogether.
m_relative_blank() { sed -i.bak 's|references/thing.md:3`|references/thing.md:2`|' "$1/skills/example/SKILL.md"; }
run "a stale citation relative to the citing file is rejected" 1 m_relative_blank

# Case 14. The gap the first version of this checker shipped with. It scanned docs/, skills/ and the
# top-level markdown and nothing else, so the 28 citations sitting in comments under tests/, lib/,
# hooks/ and bin/ were checked by nobody. Two of them were stale on the day the gap was found:
# tests/test-eval-harness.sh cited results.md for a note about a staged tree having no skills/
# directory, and the cited line had moved onto a sentence about the coverage check. A comment is
# read by whoever is about to change the code, which is the worst audience to mislead.
m_stale_in_test_comment() {
    printf '# The arm is recorded at `tests/evals/results.md:2`.\n' >> "$1/tests/test-example.sh"
}
run "a stale citation in a shell comment is rejected" 1 m_stale_in_test_comment

# Case 15. And the reason the scan is comment lines only. A path in executing code is an argument to
# a command, not a claim about the tree: tests/test-harness-claims.sh asserts on the literal string
# "untagged.md:2 fenced.md:5", and tests/test-validate-citations.sh builds every fixture in this
# file out of citations that are deliberately wrong. Flagging those is the false positive that ends
# with the check being switched off, which CONTRIBUTING.md calls the unrecoverable failure.
m_citation_in_executing_code() {
    printf '[ "$got" = "tests/evals/results.md:900" ] || exit 1\n' >> "$1/tests/test-example.sh"
}
run "a citation-shaped path in executing code is not flagged" 0 m_citation_in_executing_code

# Case 16. hooks/done-guard, hooks/session-start and bin/keel carry no extension, so a scan built
# out of `*.sh` misses them. hooks/done-guard cites docs/ideas/verification-backed-done.md for the
# assumption it was written to settle.
m_stale_in_hook_comment() {
    printf '# The assumption is recorded at `tests/evals/results.md:900`.\n' >> "$1/hooks/example-hook"
}
run "a stale citation in an extensionless hook comment is rejected" 1 m_stale_in_hook_comment

# Case 17. The two files of this checker are the only two in the tree whose subject is stale
# citations, so their worked examples have to be stale to be examples. validate-citations.sh quotes
# `tests/evals/results.md:181` in its header as the incident that earned it, and line 181 is blank
# and is meant to stay blank. This file quotes the same one and builds its fixtures out of six more.
# Scanning them made the checker report its own documentation as broken on its first run, which is
# both wrong and circular. The exclusion is these two paths written out in full and nothing else: a
# marker any file could carry would be the allow-list this repository already refused, on the
# grounds that it becomes the thing people learn to write instead of the fix.
m_checker_own_worked_examples() {
    printf '#!/usr/bin/env bash\n# The worst cited `tests/evals/results.md:2`, and line 2 is blank.\n' \
        > "$1/tests/validate-citations.sh"
    printf '#!/usr/bin/env bash\n# Case 4 reproduces a doc that cited `tests/evals/results.md:900`.\n' \
        > "$1/tests/test-validate-citations.sh"
}
run "the citation checker's own worked examples are not flagged" 0 m_checker_own_worked_examples

# Case 18. tests/evals/fixtures/ holds eleven stand-in projects that arms are turned loose on, and
# several are wrong on purpose: done-without-verifying ships a PLAN.md whose boxes are ticked and
# whose tests fail. A path in one of them names that project's tree, not this one, and being wrong
# is sometimes the scenario. The scan reaches tests/evals/run.sh and stage.sh and stops there.
m_stale_in_eval_fixture() {
    mkdir -p "$1/tests/evals/fixtures/example/tests"
    printf '#!/usr/bin/env bash\n# The bug this fixture plants is at `tests/evals/results.md:900`.\n' \
        > "$1/tests/evals/fixtures/example/tests/run-tests.sh"
}
run "a stale citation in an eval fixture script is not flagged" 0 m_stale_in_eval_fixture

# Case 19. And the same reason keeps tests/evals/results.md out. It is the eval log, and it records
# what an arm did inside a staged fixture tree, in that tree's paths. Two of its citations name
# `docs/runbooks/payout-worker.md`, which exists under the incident-diagnose-first fixture and
# nowhere else; this repository has a docs/ directory, so a checker reading them as claims about
# this tree reports two missing files that are not missing and are not wrong.
m_fixture_path_in_eval_log() {
    printf '\nEvery command it gave is the runbook, at `docs/runbooks/payout-worker.md:24-46`.\n' \
        >> "$1/tests/evals/results.md"
}
run "a citation into a staged fixture tree in the eval log is not flagged" 0 m_fixture_path_in_eval_log

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
