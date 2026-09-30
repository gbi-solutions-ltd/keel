# Idea: CI platform coverage, the macOS required check and a Windows job

| | |
|---|---|
| Raised by | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md`, "Not in this plan" rows 3 and 5 ("Make the macOS job required" and "A Windows CI job"), 2026-09-25 |
| Status | paused pending two questions (below): a week of green `Tests on macOS` runs, and what `setup-deployment` prices a Windows job at |
| Recommendation | Undecided pending two named questions, one per row. No build or design follows from either answer yet |
| Next | Row (a): nothing but a human check, once seven days of green runs are countable. Row (b): `setup-deployment`, already named by the plan |

## The problem

The maintainer decided two platform-coverage follow-ups on 2026-09-25 but has not yet acted on
either: the macOS test job runs on every push and pull request without gating any merge, and the
platform that produced two real, shipped bugs, Windows, has no CI job of its own at all.

**Evidence.** The macOS job, `test-macos` in `.github/workflows/ci.yml:43-53`, first ran on pull
request #72 (2026-09-26, run 36265854757) and passed in 4m41s; its runner had neither `timeout`
nor `gtimeout`. That is one green run, the first day of the week the maintainer's decision
requires before it can become a required status check. Separately, commit `9c68003` fixed two
Windows-only bugs (a `python3` shim
from Windows' App Execution Alias reading as present when it cannot run, and a trailing CR on
`python3`'s stdout defeating path comparisons) that had shipped and gone undetected because nothing
in CI ran on Windows; they were found by manual testing against the public fork on 2026-09-07, not
by any automated signal (`docs/ideas/windows-python3-detection-is-wrong.md:8-10`).

## What was asked for

The 2026-09-25 plan's decision table asked and answered one of the two questions directly: "Should
the macOS job be a required check?", answered "Advisory first; required after a week of green runs"
(`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:36`). The other was named
but left open: "A Windows CI job", with the reasoning "a Git Bash job is possible and its cost is
unknown" and the next step named as `setup-deployment`
(`docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1922`).

## The case against

**Strongest argument for not deciding either row right now.** Neither row has the fact its own
decision depends on. The macOS job's required-check question depends on a week of green runs, and
its first real run, on PR #72 (2026-09-26), happened after the plan that set that condition had
already closed; nobody has counted a single day of that week, let alone seven, so acting today
would mean picking an answer before the measurement the decision itself names exists. The Windows
job's question depends on `setup-deployment` pricing a Git Bash runner, which has not been done,
and on whether the known defect surface is already closed: the two bugs that motivated wanting
Windows coverage at all, the App Execution Alias shim and the trailing CR, are now both covered by
targeted regression tests using a stub `python3` that reproduces the exact failure shape, not a
live Windows run. A live job might buy detection for an unknown class of Windows-only bug, or it
might mostly re-prove what the stub tests already prove more cheaply. Deciding either row now would
write down an answer where the plan's own "Not in this plan" table deliberately withheld one, for
the same reason it withheld the other five rows there: a decision before it is work.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Free. The macOS job stays advisory forever; Windows stays covered only by stub tests | The maintainer already decided, 2026-09-25, that the macOS check should become required once the evidence exists. Doing nothing forever contradicts a decision already made, not an open one |
| Do it manually | A person watches `Tests on macOS` for a calendar week, then edits branch protection by hand; a person occasionally runs the suite on a real Windows machine before a release | Close to the actual next step for the macOS row. For Windows it repeats the exact gap that let the original two bugs ship: they were found by someone testing by hand, on 2026-09-07, after the code had already shipped |
| Buy it | A paid cross-platform CI or test-grid vendor | GitHub Actions already offers `windows-latest` and `macos-latest` runners natively; nothing in either row needs a capability GitHub Actions lacks |
| Build something smaller | See the variants below | Naming the smaller options separately is the point of the next table |

**Variants of building it**

| Variant | What it is | Note |
|---|---|---|
| Flip branch protection now, without waiting | Add `Tests on macOS` to the required checks for `main` today | Contradicts the maintainer's own 2026-09-25 decision to wait for a week of green runs |
| A full Windows job mirroring `test-macos`: the whole suite, on every push and pull request | `runs-on: windows-latest`, `tests/run-tests.sh` under Git Bash | What "A Windows CI job" in "Not in this plan" row 5 names; cost unmeasured |
| A narrower Windows job running only the two regression tests added for `9c68003` | A couple of targeted test IDs under Git Bash, not the full suite | Smaller than the full job; still needs `setup-deployment` to say whether Git Bash on `windows-latest` can run `tests/test-keel.sh`'s harness at all |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A week of green `Tests on macOS` runs is a meaningful signal that the job is stable enough to gate merges on | Failures, if any, come from real test problems rather than platform flakiness (the job's own first step already isolates one known platform difference, the absence of `timeout`/`gtimeout`) | Read seven days of run history once it exists | No. One run exists, PR #72 on 2026-09-26, and it passed |
| The two bugs `9c68003` fixed are the main class of defect a Windows job would catch | No further Windows-only failure mode exists beyond `python3` detection and CRLF stripping | Only a real run of the suite under Git Bash on Windows would show this; a stub test can only prove what it was written to reproduce | No |
| `setup-deployment` can price a Git Bash job cheaply enough to be worth running | `windows-latest` runners can execute `tests/run-tests.sh` and `tests/test-keel.sh` without a rewrite of either | Run `setup-deployment` and read its finding | No, not yet run |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The macOS job exists, runs on every push to `main` and every pull request, and is advisory by explicit design | `.github/workflows/ci.yml:36-38` (comment), `.github/workflows/ci.yml:43-53` (job) | Becoming required is a branch-protection setting change, not a code change; nothing here is `bin/keel`'s to build |
| The maintainer decided the required-check question on 2026-09-25: "Advisory first; required after a week of green runs" | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:36`, restated at `:1912` | The decision already exists; only the evidence, seven green days, is missing |
| Task 9's own execution note recorded that the job's result "needs...the pull request that carries this plan's commits, and what it reported," and that nothing had been pushed when the plan closed | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1741-1744` | Confirms the green-run count had not started when the plan landed |
| `docs/snapshot.md`'s own correction, written 2026-09-26, still says the job's "first run awaits a push" | `docs/snapshot.md#its first run awaits a` | That correction predates PR #72; it is one data point stale, which this record does not resolve since the run's outcome is not known here |
| Two real Windows bugs shipped and were found only by manual testing against the public fork, 2026-09-07, well after the affected `python3` detection code had been in place | `docs/ideas/windows-python3-detection-is-wrong.md:8-10` | The cost of having no Windows signal is not hypothetical; it already happened once |
| Both bugs now have targeted regression tests using a stub `python3` that reproduces the exact failure shape (exit 49 from the App Execution Alias shim, a trailing CR on stdout), not a real Windows run | `` `tests/test-keel.sh#App Execution Alias puts a python3.exe on PATH even when Python is not installed` ``, `` `tests/test-keel.sh#json_load strips a CRLF-emitting python3's trailing CR before caching` ``, `` `tests/test-keel.sh#the artifacts path check strips a CRLF-emitting python3's trailing CR before comparing` `` | Weakens, but does not settle, the case for a live job: the two known bugs are covered; a live job's value is in catching an unknown bug, which by definition nothing here can point at |
| The plan itself names the Windows job's cost as unknown and its next step as `setup-deployment`, not a decision either way | `docs/plans/2026-09-25-close-the-enforcement-gaps-from-the-snapshot.md:1922` | The plan's authors treated this as open, not as a considered no |

## Open questions

1. Has `Tests on macOS` had seven consecutive green runs, counting from PR #72 (2026-09-26)
   onward? A yes converts row (a) from "wait" to "the maintainer adds it to branch protection,"
   with no further shaping needed.
2. What does `setup-deployment` find when it prices a Git Bash job on `windows-latest`? This is
   the plan's own named next step for row (b) and would turn "undecided" into an actual
   recommendation.
3. Beyond the two bugs `9c68003` fixed, is there a known or suspected class of Windows-only
   failure the stub tests cannot reach? Unknown, and nobody could name one, as of this record. If
   that stays true after `setup-deployment` looks, it becomes part of the case against a live job
   rather than an open question.

## Recommendation

Undecided pending the two questions above, one per row. Neither row's decision depends on more
shaping, a PRD, or a design: row (a) is already agreed and needs only its own evidence, a week of
green runs, to exist before the maintainer flips a GitHub setting; row (b) is already routed to
`setup-deployment` to price before anyone decides whether to build it. What happens next: re-open
this record once seven days of `Tests on macOS` runs are countable from PR #72 onward, and once
`setup-deployment` reports what a Git Bash job would cost.

## Not decided here

Whether a Windows job, if built, runs the whole suite or the narrower regression-only variant.
Whether a future Windows job would follow the same advisory-then-required timeline as the macOS
job. Any figure for what a `windows-latest` runner costs relative to `ubuntu-latest` or
`macos-latest`; none was measured or found in this repository's own docs, so none is asserted here.
