# Idea: three unfixed defects in the CI workflow `write_ci` generates

| | |
|---|---|
| Raised by | The 2026-09-25 plan's "Not in this plan" row 6 (existing `master` repos), its task 6 execution note under "Not taken" (the yarn 1 audit command), and the 2026-09-26 security audit and code review (the unquoted branch name, and the `actions/checkout` tag versus keel's own pinned commit). Consolidated here at the maintainer's request to track the decisions the 2026-09-25 plan deliberately deferred. |
| Status | agreed, not built. Open question 1 answered 2026-09-27 |
| Recommendation | Build something smaller: the three fixes now, and a `doctor` check for a stale `branches: [main]` once it is designed. See below. |
| Next | `tdd`, for the three fixes. `write-prd`, for the `doctor` check |

## The problem

`write_ci` (`bin/keel`, function `write_ci`) generates a workflow file with three separate defects
that make the generated CI silently not run, or run and fail, for a reason unrelated to the code it
is testing, and nothing else in keel (not `doctor`, not a test) catches any of the three.

**Evidence.** No live incident is on record for any of the three. Each is a finding from reading
the code, and, for the branch name, from testing git's and YAML's actual behavior directly this
session (2026-09-26). Dated references: the 2026-09-25 plan's row 6
(`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1923`); that plan's task 6
execution note (`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1182`); and
the 2026-09-26 security audit (`docs/audits/2026-09-26-security.md` lines 115 and 74). Unknown, and
nobody could name a project that has actually hit one of these.

## What was asked for

One record covering three defects in `write_ci`: (a) an existing `master` repository initialised
before 2026-09-25 keeps `branches: [main]` forever, because `init` never rewrites an existing
workflow; (b) the branch name is written into the YAML unquoted (`branches: [%s]`), so branch names
git allows, such as `a]b`, `{x}`, `!x`, `&x`, or `a,b`, make the workflow invalid or silently wrong;
(c) `write_ci` still maps a `yarn.lock` to `yarn npm audit`, a command that exists only on yarn 2+,
even though the lockfile detector elsewhere in keel already excludes yarn 1. Also flagged for the
same record: generated CI pins `actions/checkout` by the tag `@v4`, while keel's own CI now pins it
to a commit.

## The case against

**Strongest argument.** All three defects need an unusual precondition before they bite: a git
branch name that contains punctuation with no letter, digit, or dash meaning, which no reported
project has used and no common convention (`feature/x`, `JIRA-123`, `release/1.2`) produces; a
project still on yarn 1 classic, when yarn 2 has been the yarn default since 2020 and
`detect_verify` already refuses to touch it; and a `master`-named repository that was `keel
init`'d before 2026-09-25 and has neither re-run `init` destructively nor noticed its own CI
staying quiet for the better part of a year. Nobody administering keel can name a project where
any of the three has actually happened. Fixing latent, unobserved generator output ahead of any
evidence it recurs is exactly the trade the 2026-09-25 plan's own row 6 already declined, choosing
instead to wait for a release note or a sign that it is common.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | All three stay live; each surfaces only when its rare precondition lines up, at which point CI goes quiet or red for a reason unrelated to the code under test | Nothing in keel today would tell anyone whether this is already happening, so the cost of "nothing" cannot be checked either |
| Do it manually (a release note, then a hand fix per project when hit) | A changelog or release-note line, plus a manual edit to the generated workflow whenever someone notices | Already the plan's own stated fallback for item (a) alone; it does nothing for (b) or (c), which were never flagged as needing a manual workaround |
| Buy it | Not applicable | No third party generates or maintains the workflow file `write_ci` writes |
| Build something smaller | Fix (b), (c), and the checkout pin, three single-cause changes with the root cause already found and, for two of them, an existing in-repo pattern to copy; leave (a) exactly where row 6 left it | Matches the evidence: (a) is a decision already deferred pending a trigger that has not fired, the other three are plain bugs with no such gate |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| Git branch names containing `]`, `{`, `!`, `&`, or `,` occur in real repositories keel inits | A team's naming convention, or an automated process, produces one | Nothing in `write_ci` or `doctor` logs or rejects such a name today, so there is no telemetry either way | No. Git's and YAML's behavior on these names was checked directly; no reported instance was found |
| Yarn 1 (classic) lockfiles still reach `keel init` | A project's `yarn.lock` has no `__metadata:` block | `detect_verify`'s own yarn branch already tests for exactly this (`lib/detect-stack.sh:614-621`), so the gap is provably reachable even though it is not observed | Yes, code-verified; no failing run was named |
| Pre-2026-09-25 `master` repositories that hit the old `branches: [main]` bug still exist and are still pushed to | Someone ran `keel init` on a `master`-default repo before task 3 landed and has not re-run `init` destructively since | Nothing reads the generated workflow against the current profile branch to say so | No, unverified either way |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| `write_ci` only runs when nothing already declares a CI platform; an existing workflow file is never touched again, `--force` included | `bin/keel#Only where nothing declares a CI platform yet` (the guard around the call to `write_ci`) | (a) is permanent for any repo that already has a workflow. A code fix here needs a rewrite mechanism, which is a design question, not a bug fix |
| The 2026-09-25 plan already named this as deferred, not decided | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1923` | (a) was scoped as "a note in the release, or a doctor check if it turns out to be common." Neither exists yet |
| `docs/snapshot.md`'s own correction for this recommendation confirms the same limit | `docs/snapshot.md#workflow already written is not rewritten.` | Independent, dated confirmation that (a) is unresolved by design, not an oversight |
| The branch name is interpolated into a YAML flow sequence with no quoting or escaping | `bin/keel#branches: [%s]` | (b) is confirmed at the source: nothing quotes `$branch` before it is written |
| Git accepts branch names YAML cannot round-trip: `a]b` and `!x` fail to parse at all (`Psych::SyntaxError`, verified with `ruby -ryaml` against the exact generated line, this session); `&x` parses as a YAML anchor on a null scalar, so the filter becomes `branches: [null]`; `a,b` silently becomes two branch filters, `["a", "b"]`, instead of one literal name | Tested directly this session, 2026-09-26, against git's `check-ref-format` and Ruby's Psych parser | (b) is real and reproducible, not theoretical. The effect ranges from GitHub Actions rejecting the workflow outright to a filter that quietly matches the wrong branches |
| The 2026-09-26 security audit already named this exact gap | `docs/audits/2026-09-26-security.md` line 115 ("`write_ci` writes the branch name into YAML unquoted") | (b) was seen and dated, and deliberately not fixed in that pass |
| `write_ci`'s package-manager-to-audit mapping keys only on `stack.package_manager`, which reads `yarn` for any `yarn.lock` regardless of version | `bin/keel#yarn) audit='yarn npm audit --severity high' ;;`; the lockfile-agnostic package manager read at `lib/detect-stack.sh:208` | (c) is confirmed: nothing here mirrors the yarn-2-plus guard `detect_verify` already uses elsewhere |
| `detect_verify`'s own yarn branch requires a `__metadata:` line before treating a lockfile as yarn 2+, specifically because yarn 1 has no `yarn npm` subcommand | `lib/detect-stack.sh:614-621` | The fix for (c) needs no new design: it applies a guard that already exists one function over |
| Task 6's own execution note names this exact gap and marks it not taken | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1182` ("`write_ci`'s own yarn mapping still writes `yarn npm audit` for a yarn 1 project (pre-existing)") | (c) is a named, dated, pre-existing gap, not a new discovery |
| No test in `tests/test-keel.sh` exercises a branch name with YAML-significant punctuation, and none exercises a `yarn.lock` with no `__metadata:` reaching `write_ci`'s audit step | `tests/test-keel.sh#generated CI runs on the default branch the profile records` (only well-formed branch names are asserted anywhere near `write_ci`) | Neither (b) nor (c) has regression coverage today. A fix landed with no failing test first would be the exact gap `tdd` exists to close |
| Generated CI still pins `actions/checkout` by the movable tag `@v4`; keel's own hand-authored CI was moved to a pinned commit for the same class of finding | `bin/keel#actions/checkout@v4`; `docs/audits/2026-09-26-security.md` line 74 ("every `actions/checkout` is pinned to the v4.4.0 commit") | A fourth, related gap: the fix L-02 already applied to keel's own pipeline was never carried into the pipeline `write_ci` hands to every other project |

## Open questions

1. ~~For (a): should a stale `branches: [main]` on a `master`-default repo become a release note, a
   one-time notice easy to miss, or a `doctor` check, which needs a design for how `doctor` reads
   and compares the generated workflow against the profile without over-matching a file someone has
   since hand-edited?~~ **Answered 2026-09-27 by Bernard, asked as a choice: a `doctor` check.** The
   design it needs, reading the workflow without flagging a hand-edited file, is still to do.
2. Should the checkout pin be treated as part of this record's smaller build, since it is cheap and
   the commit to pin to is already decided (L-02), or should it be its own idea since it was raised
   as security hardening rather than a functional defect? Treated here as in scope, since the fix is
   one line and the decision (which commit) is already made.

## Recommendation

Build something smaller: quote the branch name `write_ci` interpolates into YAML, restrict its
yarn-audit mapping to yarn 2+ lockfiles the same way `detect_verify` already does, and pin its
`actions/checkout` step to the commit L-02 already chose for keel's own CI. For existing
`master`-default repositories, add a `doctor` check that reports a stale `branches: [main]` (open
question 1, answered 2026-09-27) rather than rewriting the workflow.

The first three are single-cause, already-diagnosed, low-risk changes, two of which copy a pattern
or a decision that already exists elsewhere in the repository. The fourth, detecting the stale
branch in a workflow file a person may have since hand-edited, still needs a design.

Next: `tdd` for the three fixes, each starting from a failing test (a branch name with YAML-special
punctuation, a yarn 1 fixture, and a pinned-checkout assertion). `write-prd` for the `doctor`
check.

## Not decided here

No design yet for how the `doctor` check detects and warns about a stale, pre-2026-09-25
`branches: [main]` workflow; that belongs to the `write-prd`. No design for whether `write_ci` should escape YAML-special characters
generally, beyond the specific ones git allows and this record checked. No stance on whether the
other generated setup actions (`setup-node@v4`, `setup-python@v5`, `setup-go@v5`) should also move
to pinned commits; L-02 and this record only ever discussed `checkout`.
