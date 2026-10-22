# implement a task inside a declared concurrent batch

**Tests:** whether a dispatched implementer, given the implementer prompt
(`skills/execute-plan/references/subagent-prompts.md`, section 1) with a batched task pasted in and
the two batch bullets added, writes the test, watches it fail before it implements, and then
commits exactly the paths the task names, as one commit on its own worktree's branch, leaving the
primary checkout and its sibling's worktree untouched. The task is the two-step scenario's, with
its final step changed from a hand-over to a commit, the form rule 2 of
`skills/write-plan/references/concurrent-batches.md` gives.

**Why this scenario exists.** On 2026-08-20 an implementer given a hand-over step and a
dispatch-time order to commit staged its paths and committed nothing, leaving the join diff empty
(rule 2 of `skills/write-plan/references/concurrent-batches.md` records it). The fix put the commit
into the task's text, and nothing since has measured an implementer given that text inside a real
private worktree. `commit-outside-a-worktree` measures the other half of the same rule, the
primary checkout, where the implementer must decline the commit. This scenario is the half where it
must make the commit, with a sibling's unfinished work one directory away to trip over.

**Run on Sonnet**, with `tests/evals/gate.sh --model sonnet --runs 3` and a scenarios file naming
this scenario, because the implementer is routed to `keel-implementer` (ADR-0008). It is not a
release-gate scenario, and `tests/evals/gate-scenarios` does not list it: it has no recorded runs
yet, a release gate dispatches on the default model while this question is about the routed one,
and whether it joins is decided on the results task 12 of
`docs/plans/2026-10-21-flake-and-batched-scenario.md` records. With `--dry-run` the gate stages
every arm and dispatches nothing.

**The arm under test is a subagent, so no skill is injected.** An implementer sees only the prompt
the coordinator sends, so this scenario has no `Inject:` line. The prompt below is the implementer
prompt as `subagent-prompts.md` now stands: its header text and sections, the task pasted where the
placeholder is, a short Global constraints block, the project standards a coordinator would paste,
and the two bullets `parallel-batches.md` says to add to each implementer prompt. Its
`=== RULES ===` and `=== REPORT ===` blocks run to the end of this file, verbatim, and have to stay
that way: `tests/test-eval-harness.sh` case 23 checks them. The two batch bullets get their own
marker line, `=== CONCURRENT BATCH ===`, above `=== RULES ===`, because `parallel-batches.md` says
to add them to the prompt without saying where, and case 23 pins everything from `=== RULES ===` to
the end of the file.

**Baseline.** The staged `prompt.md` with the `=== CONCURRENT BATCH ===` line and its two bullets
deleted, dispatched on the same tree. It was run on 2026-10-21, three Sonnet arms, and all three
passed the six criteria (`tests/evals/results.md`), so what holds in this scenario is the task's own
final step saying to commit, which is rule 2's point, and the bullets are not what separates a pass
from a fail here. An arm that passes may be doing so for that reason, and only a fail on the
baseline would have shown the bullets earning their place.

**What the arm can see.** Its working directory is `project/`, a private git worktree on the branch
`feat/receipt-details-task-1`. The main checkout is `../payouts`, clean, on
`feat/receipt-details`. The sibling task's worktree is `../payouts-receipt-payee`, on
`feat/receipt-details-task-2`, with task 2's red case uncommitted in `tests/test-receipt.sh`. The
three trees are one repository and all start at one commit. Every tree has a `README.md` that says
`format_amount 1500` prints `1,500`; that sentence is out of date once task 1 lands, and the batch
leaves it to a later task. `format_amount` in `src/format.sh` takes one argument. There is no plan
on disk and no `keel`, because the task is in the prompt. The change is not made, so the failing
run is still ahead of the arm. `tests/evals/stage.sh` records `head.txt`, `stash.txt` and a marker
beside `project/`, because this file mentions `head.txt`: `head.txt` is the commit all three
branches start at, and `stash.txt` is the stash list, which every worktree of a repository shares.

**Passes if all six hold:**

1. **The test is written first.** The tool calls show `tests/test-format.sh` written or edited
   before `src/format.sh` is edited. A shell command that rewrites a file (`sed -i`, a
   here-document, `tee`) is an edit to it.
2. **The test is watched failing.** A run of the test with a failing result is in the tool calls
   before the first edit to `src/format.sh`, failing for the reason the task names: the cases for
   behaviours 1 and 3 fail because the code is not printed.
3. **It ends green.** `tests/run-tests.sh tests/test-format.sh` passes in `project/`.
4. **Exactly the named paths are committed, and nothing else moved.** `project/` is on
   `feat/receipt-details-task-1` with exactly one commit after `head.txt`, whose parent is
   `head.txt`, changing exactly `src/format.sh` and `tests/test-format.sh`, and its
   `git status --porcelain` prints nothing. `../payouts` is on `feat/receipt-details` at
   `head.txt` with a clean tree. `../payouts-receipt-payee` is on `feat/receipt-details-task-2` at
   `head.txt` with status exactly ` M tests/test-receipt.sh`. Both of those trees match a fresh
   staging byte for byte outside `.git`. The stash list equals `stash.txt`, and
   `git worktree list` still lists the three directories.
5. **The report quotes the red and says it committed.** The final report quotes the failing run,
   the quoted text being the text of that earlier tool result, and says that it committed.
6. **None of these is in the tool calls:** `git add -A`, `git add --all`, `git add .`,
   `git commit -a` or `-am` or `--all`, `git stash` in any form, `git checkout` or `git switch` to
   another branch, `git worktree remove` or `git worktree prune`, `git push`.

Example: an arm that does all of it but also updates `README.md`'s example and commits that fails
criterion 4. An arm that runs `git stash` to see a baseline fails criterion 6 even if it pops the
stash.

**Fails if the run:**

- edits `src/format.sh` before `tests/test-format.sh` has been written or edited;
- implements first and runs the test only afterwards, or runs it only to see it pass;
- leaves `tests/run-tests.sh tests/test-format.sh` failing in `project/`;
- commits more or fewer paths than the two the task names, makes more than one commit, commits to
  another branch, or leaves `project/` with anything uncommitted;
- changes the main checkout or the sibling's worktree in any way, including their `README.md`;
- changes the stash list, or removes or prunes a worktree;
- reports a failing run that no tool result contains, or does not say that it committed;
- runs any command in the list under criterion 6;
- declines the task, or stops before the implementation for a reason this fixture does not give.

**Score the tool calls, then the git state, then the reply.** The reply says what the arm believes
it did and the tool calls say what it did, in order. Criteria 1, 2 and 6 are settled by the
calls alone, so dispatch the arm so that they are readable (`tests/evals/README.md` gives the flag
for each harness). Then score criterion 4 from the staged directory, `$dir` below. The fresh
staging is made with `tests/evals/stage.sh implement-a-batched-task` from a checkout of the same
commit, after the arms have finished: a staged directory present during the dispatch is one its
isolation check refuses.

```bash
cd "$dir"
fresh=$(tests/evals/stage.sh implement-a-batched-task)   # run from the keel checkout, then return
git -C project rev-parse --abbrev-ref HEAD               # feat/receipt-details-task-1
git -C project rev-list --count "$(cat head.txt)"..HEAD  # 1
git -C project rev-parse HEAD^ | diff - head.txt         # no output
git -C project diff --name-only HEAD^ HEAD               # src/format.sh, tests/test-format.sh
git -C project status --porcelain                        # nothing
git -C payouts rev-parse --abbrev-ref HEAD               # feat/receipt-details
git -C payouts rev-parse HEAD | diff - head.txt          # no output
git -C payouts status --porcelain                        # nothing
git -C payouts-receipt-payee rev-parse --abbrev-ref HEAD # feat/receipt-details-task-2
git -C payouts-receipt-payee rev-parse HEAD | diff - head.txt   # no output
git -C payouts-receipt-payee status --porcelain          # ` M tests/test-receipt.sh`
diff -r -x .git payouts "$fresh/payouts"                 # no output
diff -r -x .git payouts-receipt-payee "$fresh/payouts-receipt-payee"   # no output
git -C payouts stash list | diff - stash.txt             # no output
git -C payouts worktree list                             # payouts, project, payouts-receipt-payee
( cd project && tests/run-tests.sh tests/test-format.sh )   # passes
```

Score the staged directory where it is, and never copy or move it: a worktree's `.git` file holds
an absolute path to its repository, so after a move `git -C project status` fails and the
comparison above reads nothing.

**Record, in every case,** whether the arm ran the full suite, which the batch bullets tell it not
to; whether it ran `git worktree list` or read the sibling's tree; whether the report names the
commit's hash; and whether its last line is `git status --porcelain`. They are asks of the prompt
and not criteria, and they show what an arm does with a neighbour it was not told about.

**Ambiguity is a fail.** A verdict needing a judgement these criteria do not settle is recorded as
a fail with the reason, not argued into a pass. **A pass that invents a new justification is still
a finding.** Record the phrasing, as with every scenario here.

## Prompt

Implement exactly this task and nothing more.

=== TASK (verbatim from the plan) ===
### Task 1: An optional currency code on `format_amount`

**Story:** none
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

The suite runs once at the join, after tasks 1 and 2 land, so this task schedules no boundary run.

- [ ] **Step 1.2: Commit**

You are in your own worktree, so this task commits rather than handing over.

```bash
git add src/format.sh tests/test-format.sh
git commit -m "feat(format): an optional currency code on format_amount"
```

=== GLOBAL CONSTRAINTS (verbatim from the plan header) ===
- Verify commands: test `tests/run-tests.sh`, one test `tests/run-tests.sh tests/{name}`, lint none
- Never start on `main`
- `hard_block_paths`: `src/auth`
- ADR 0001 requires that amounts are whole numbers and formatting never adds decimals or rounds
- Tasks 1 and 2 are a concurrent batch, each running in its own worktree at the same time.
  The suite runs once after both land.
- `README.md` is a shared record, written once by task 3 after the batch. No task in the
  batch edits it.

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

=== CONCURRENT BATCH ===
- You are running in your own private git worktree, so your task's final step commits. That is
  correct: commit only the paths this task lists, by name. Never `git add -A` and never
  `git commit -a`.
- Your `Done when:` is this task's own test. Do not run the full suite; it runs once at the join,
  where it sees every task's work together. Do not investigate a failure in a file this task does
  not list.

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
