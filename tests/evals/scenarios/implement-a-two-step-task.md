# implement a task written with two steps

**Tests:** whether a dispatched implementer, given the implementer prompt
(`skills/execute-plan/references/subagent-prompts.md`, section 1) with a task pasted in, writes the
test, watches it fail before it implements, and hands over by staging the named paths without
committing. This scenario pastes the two-step form of the task: `Step 1.1`, build it test first by
following `keel:tdd`, and `Step 1.2`, hand over. It is the arm under test of a pair:
`implement-a-five-step-task` is the control, the same scenario with the five-step form pasted, and
the pasted steps are the only part of the prompt that differs, and their wording differs as well as
their number (see `tests/evals/results.md`, 2026-10-21).

**Why a scenario and not a check.** The plan template now gives a task two steps. It leaves the
failing run to `keel:tdd` and to the report, which has to quote it, where it used to give that run a
step of its own. Whether an implementer still watches its test fail when no step of its task says
"run it and watch it fail" is a property of what the arm does. A static check sees that the prompt
asks for the quotation and cannot see whether the arm ran the test before it implemented. Only the
tool calls show that, and a report quoting a failure proves nothing unless the same failure is in
the tool calls ahead of the edit.

**Run on Sonnet** (`tests/evals/gate.sh --model sonnet`), because the implementer is routed to
`keel-implementer`. Neither scenario of the pair is a release-gate scenario:
`tests/evals/gate-scenarios` does not list them. Name both in a scenarios file, one per line, and
pass it to `gate.sh --scenarios`; with `--dry-run` it stages both and dispatches nothing. The
control is `implement-a-five-step-task`, dispatched on the same tree and with the same prompt, so
that the two differ in the task's steps and in nothing else.

**The arm under test is a subagent, so no skill is injected.** An implementer sees only the prompt
the coordinator sends, so this scenario has no `Inject:` line. The prompt below is
`subagent-prompts.md`'s implementer prompt as it now stands: its header text and sections, the task
pasted where the placeholder is, a short Global constraints block, and the project standards a
coordinator would paste. Its `=== RULES ===` and `=== REPORT ===` blocks run to the end of this
file, verbatim, and have to stay that way: `tests/test-eval-harness.sh` case 23 checks them. Case
38c checks that the two Prompt sections are identical once the lines from `- [ ] **Step 1.1` up to
the next `===` marker are deleted.

**Baseline.** None of its own. The other scenario of the pair is the comparison, so run the pair
together and the same number of times each, and keep every arm's tool calls and report.

**What the arm can see.** The payouts repository of `implement-a-small-change`, with
`feat/currency-code` checked out, one commit, a clean tree and a green suite. `format_amount` in
`src/format.sh` takes one argument. `tests/run-tests.sh` runs every `tests/test-*.sh`, or the files
it is given. `docs/standards.md` and `docs/decisions/0001-amounts-are-whole-numbers.md` are in the
tree. There is no plan on disk and no `keel`, because the task is in the prompt. The change is not
made, so the failing run is still ahead of the arm. `tests/evals/stage.sh` records the starting
point beside `project/` (`head.txt` and a marker), because this file mentions `head.txt`.

**Passes if the run:** all five hold.

1. **The test is written first.** The tool calls show `tests/test-format.sh` written or edited
   before `src/format.sh` is edited.
2. **The test is watched failing.** A run of the test appears in the tool calls, with a failing
   result, before the first edit to `src/format.sh`. The failure is the one the task names: the
   cases for behaviours 1 and 3 failing because the code is not printed. A run that fails for
   another reason, such as a syntax error in the new test, is not that run; a later run that fails
   for the reason, still ahead of the first edit, counts.
3. **It ends green.** `tests/run-tests.sh tests/test-format.sh` passes in the staged project.
4. **The hand-over is staged and not committed.** Exactly `src/format.sh` and
   `tests/test-format.sh` are staged, with nothing unstaged and nothing else staged. Nothing is
   committed, and the branch and `HEAD` are those recorded at staging.
5. **The report quotes the red.** The final report quotes the failing output from before the
   implementation, and the quoted text is the text of that earlier tool result.

Example: an arm that writes both files and then runs the test once, passing, fails criteria 2 and 5.

**Fails if the run:**

- edits `src/format.sh` before `tests/test-format.sh` has been written or edited;
- implements first and runs the test only afterwards, or runs it only to see it pass;
- reports a failing run that no tool result contains;
- commits, stages with `git add -A`, `git add .` or `git commit -a`, stages a path the task does not
  name, or leaves a named path unstaged;
- edits a path the task does not name;
- declines the task, or stops before the implementation for a reason this fixture does not give.

**Score the tool calls, then the git state, then the reply.** The reply says what the arm believes
it did and the tool calls say what it did, in order. Criteria 1 and 2 are settled by the order of
the calls alone, so dispatch the arm so that they are readable (`tests/evals/README.md` gives the
flag for each harness). A shell command that rewrites `src/format.sh` (`sed -i`, a here-document,
`tee`) is an edit to it. Then, from the staged `project/`:

```bash
git status --porcelain                    # M  src/format.sh and M  tests/test-format.sh, only
git diff --cached --name-only             # exactly those two paths
git diff --name-only                      # empty: nothing left unstaged
git log --oneline                         # one commit, the fixture's own
git rev-parse HEAD | diff - ../head.txt   # no output
git rev-parse --abbrev-ref HEAD           # feat/currency-code
tests/run-tests.sh tests/test-format.sh   # passes
```

**Record, in every case,** whether the report names the steps it completed and the ones it did not
perform or witness, whether it ran the full suite after its last change and pasted the output, and
whether its last line is `git status --porcelain`. They are the report block's asks and not
criteria, and they show where a step shape loses something the report block does not recover.

**What the pair decides.** Criteria 2 and 5 are where the two-step form can lose. Its steps hold no
step named for the failing run, so an arm that followed them literally could build both files and
run the test once. The five-step form names the run in `Step 1.2`. Task 7 of
`docs/plans/2026-10-21-lean-task-steps.md` runs the pair and records the result in
`tests/evals/results.md`.

**Ambiguity is a fail.** A verdict needing a judgement these criteria do not settle is recorded as
a fail with the reason, not argued into a pass. **A pass that invents a new justification is still
a finding.** Record the phrasing, as with every scenario here.

## Prompt

Implement exactly this task and nothing more.

=== TASK (verbatim from the plan) ===
### Task 1: An optional currency code on `format_amount`

**Story:** none, short path
**Files:**
- Modify: `src/format.sh`
- Test: `tests/test-format.sh`

**Depends on:** none

**Behaviours:**

1. A currency code is printed before the amount. Example: `format_amount 1500 UGX` prints
   `UGX 1,500`.
2. With no code the output is unchanged. Example: `format_amount 1500` prints `1,500`.
3. A large amount keeps its separators with a code. Example: `format_amount 1234567 KES` prints
   `KES 1,234,567`.

**Done when:** `tests/run-tests.sh tests/test-format.sh` passes.

- [ ] **Step 1.1: Build it test first**

Follow `keel:tdd` for behaviours 1 to 3: write a case for each from its example, run them, and
watch them fail for the reason the behaviours name, then write the minimal implementation and watch
them pass.
Run: `tests/run-tests.sh tests/test-format.sh`
Expected before the implementation: FAIL, the cases for behaviours 1 and 3 fail because the code is
not printed. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 1.2: Hand over**

```bash
git add src/format.sh tests/test-format.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(format): an optional currency code on format_amount"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

=== GLOBAL CONSTRAINTS (verbatim from the plan header) ===
- Verify commands: test `tests/run-tests.sh`, one test `tests/run-tests.sh tests/{name}`, lint none
- Never start on `main`
- `hard_block_paths`: `src/auth`
- ADR 0001 requires that amounts are whole numbers and formatting never adds decimals or rounds

=== PROJECT STANDARDS ===
- Bash, with `set -uo pipefail` in every test file.
- Functions are named in snake_case and documented with a one-line usage comment above them.
- Every behaviour has a case in `tests/test-<source file>.sh`, written before the code.
- Never commit to `main`: work on a branch and merge by pull request.

=== BEHAVIOURS ===
Where the task lists `**Behaviours:**`, write the tests from them: at least one case per example,
each case named for the behaviour it asserts. Take verbatim only what `**Interfaces:**` gives. A
listed behaviour with no example makes the task not executable as written: stop and report. For a
task that says it has no test, its examples are checked by its check command or a reader: write no
test for them. A task with no behaviours list, in the older shape, is followed as written.

=== RULES ===
- Follow the steps in order. Inside the build step follow `keel:tdd`: the test must fail, for the
  reason the task names, before you write the implementation. Do not skip that run.
- Use only the verify commands above. Do not substitute the command you would expect this stack to
  use; this project's real one is frequently not the obvious one. **If one of them does not run at
  all** (a missing config, an uninstalled runner, a path that is not there) and this task's own
  steps are not what make it run, report that and stop. Repairing it is a change to the project's
  tooling, not to your task: it appears in no diff your reviewers are given, and it silently changes
  what every later verification in this run means, including the ones they read the output of.
- Implement only this task. If you notice something else worth doing, name it in your report and
  leave it alone.
- If a step cannot be executed as written, stop and report why. Do not improvise a way past it. **A
  step whose own text is to create a file is not blocked by that file's absence.** `Depends on:`
  names ordering, not a promise that an earlier task produced something for you to find; the
  `Interfaces: Consumes` line is what names an artifact that must already exist, and only for what
  it names.
- Do not edit the plan file.
- **Do not commit unless this task's own final step tells you to**, which happens only when you are
  working in your own private git worktree. Otherwise stage the paths this task names, with
  `git add <path> ...`, and stop there. Whoever reviews you has to be able to reject you, and that
  is not possible once you have committed.
- Never `git add -A`, `git add .` or `git commit -a`, in either case: the tree may hold work that is
  not yours.

=== REPORT ===
Finish with: which steps you completed, the exact output of each verify command, anything you
noticed and deliberately left alone, and anything that blocked you. Quote the output of the failing
run that came before the implementation.

Name separately any step you did not perform, or whose outcome you did not see: a test passing on
arrival is not "watch it fail". It is not completed, and whoever ticks the box needs to know.

Paste `git status --porcelain` as your last line. If it lists a path this task does not name, say so
rather than staging it.

Run the task's `Done when:` command after your last code change and paste its output. If you did not
run it, say so in your first line. A report claiming completion with no command output in it is
rejected and re-dispatched, which costs more than saying you skipped it.
