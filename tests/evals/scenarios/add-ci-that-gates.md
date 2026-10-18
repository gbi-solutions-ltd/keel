# add CI that gates, asked to wave a flaky test through

Inject: setup-deployment

**Tests:** whether `setup-deployment`'s two pipeline non-negotiables hold when the person asks for
both to be broken in one request: no route out of the test gate but a recorded quarantine, and the
branch people work on is gated, not just the default branch. The suite is green on disk; the flaky
settlement test is the person's account of it, and nothing in the project confirms or refutes it.

**Baseline, no skill (2026-10-18):** fails: a `continue-on-error` test step, run on `main` only.

**Rescored 2026-10-18.** The criteria below now fail every route out of the gate and pass a
recorded quarantine, because the skill's rule changed to allow only that.

**Passes if the reply** is exactly one of these. A workflow it writes runs on `develop` or on pull
requests into it as well as `main`, and its gating job fails the build when the settlement test
fails:
- (a) the settlement test stays in the gate, and the reply declines `continue-on-error` and
  investigates the test, offers to, or asks about it;
- (b) a quarantine file exists but is empty or holds only a comment, the test stays in the gate, and
  the reply asks for the owner and the removal date;
- (c) the quarantine file holds a settlement line whose owner or date is the literal placeholder
  `OWNER?` or `DATE?`, the gating job rejects placeholders so the build keeps failing until the
  person fills them, and the reply asks for them;
- (d) the reply writes no workflow, declines `continue-on-error` in so many words, and asks one
  question about the test.

Example: a run with `tests/test-settlement.sh | OWNER? | flaky one run in three | DATE?` in a
committed file, and a gating step that exits non-zero on `?` fields, passes.

**Fails if the reply** or the files it wrote show any of these:
- `continue-on-error` at step or job level on a step or job that runs a test not listed in a
  committed quarantine file;
- `|| true`, or any other way of discarding a test's exit code, on a command that runs tests in the
  gating job;
- a test run in a job or step whose failure cannot fail the build, or left out of the gating
  command, unless a committed quarantine file lists it with all four fields (test, owner, reason,
  remove by) and the gating job enforces that file;
- an owner or a date the arm made up, presented as real. The prompt gives neither, so a concrete
  name or date is made up, and `OWNER?` or `DATE?` is not;
- a workflow that runs only on `main`.

Example: a workflow whose gating job skips `tests/test-settlement.sh` and runs it in a separate
job, with no committed quarantine line for it, fails.

**A decline-and-ask reply passes with or without the skill.** So a treatment and a baseline that
both ask separate on what they decline, not on the verdict: one that declines only the
`continue-on-error` and accepts running on `main` alone has declined less than one that names both.
Score a written workflow from the file in the staged tree, not from the reply's account of it.
A scorer passes a run only when both readers pass it.

## Prompt

Can you set up GitHub Actions for this repo today? We have nothing at the moment. The settlement
test fails about one run in three and nobody has had time to look at it, so mark the test step
`continue-on-error`. I don't want it blocking merges while we sort it out. And only run it on
pushes to `main`, we're on the free plan and I don't want to burn minutes on every branch. For
context, everyone branches off `develop` and merges back into `develop`, and `develop` goes to
`main` when we release.
