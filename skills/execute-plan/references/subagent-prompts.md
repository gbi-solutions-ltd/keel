# Subagent prompts for delegated mode

One prompt implements a task, two review it (one in the light loop). Read before the first dispatch.

## Why two review passes and not one

A single reviewer asked "is this good?" answers about code style, because that is the easier
question, and skips the one that matters: did it build what the task asked for. Splitting them
forces both to be answered.

Pass one compares the work to the task and nothing else. Pass two judges the code on its merits.
Run them in that order: a beautifully written implementation of the wrong task is still the wrong
task, and finding that out after a style review wastes the style review.

## 1. The implementer prompt

The subagent sees only what you send. It has no conversation, no plan file loaded, and no memory of
the previous task, so anything omitted is unavailable rather than merely unmentioned.

```
Implement exactly this task and nothing more.

=== TASK (verbatim from the plan) ===
<paste the task, including its Files, Interfaces, Behaviours, Done when, and every numbered step>

=== GLOBAL CONSTRAINTS (verbatim from the plan header) ===
<paste the whole Global constraints block, including the verify commands>

=== PROJECT STANDARDS ===
<paste the rules from <docs_root>/standards.md this task could breach>

=== BEHAVIOURS ===
Where the task lists `**Behaviours:**`, write the tests from them: at least one case per example,
each case named for the behaviour it asserts. Take verbatim only what `**Interfaces:**` gives. A
listed behaviour with no example makes the task not executable as written: stop and report. For a
task that says it has no test, its examples are checked by its check command or a reader: write no
test for them. A task with no behaviours list, in the older shape, is followed as written.

=== RULES ===
- Follow the steps in order. Do not skip the step that runs the test and watches it fail.
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
noticed and deliberately left alone, and anything that blocked you.

Name separately any step you did not perform, or whose outcome you did not see: a test passing on
arrival is not "watch it fail". It is not completed, and whoever ticks the box needs to know.

Paste `git status --porcelain` as your last line. If it lists a path this task does not name, say so
rather than staging it.

Run the task's `Done when:` command after your last code change and paste its output. If you did not
run it, say so in your first line. A report claiming completion with no command output in it is
rejected and re-dispatched, which costs more than saying you skipped it.
```

Paste the standards too, and not a path to them. The review prompt below offers the path as an
option because a reviewer goes looking for what to judge against; an implementer writes to what is
in front of it, and as the section opening says, this brief is all of that there is. Send the rules
the task can actually breach, not the whole document: a paste nobody can finish reading is the same
omission with more tokens.

## 2. Spec compliance review

```
Review this work against the task it claims to implement. Judge only whether it did what was
asked. Ignore style, naming, and elegance entirely; a separate pass covers those.

=== TASK ===
<paste the same task verbatim>

=== DIFF ===
<paste the diff, or name the changed files>

=== IMPLEMENTER REPORT ===
<paste the implementer's report verbatim>

Do not change the tree you are judging. Run no git command that changes its index, working tree or
stash: no `stash`, `checkout`, `restore`, `reset`, `commit`, or `git add` of a file. Read it with
`diff`, `log`, `show` and `status`. If you create a worktree, make it with
`git worktree add --detach` in a new directory under the system temp directory, so no branch or
stray directory lands in the author's repo, and remove it with `git worktree remove --force`
before you report, whatever the outcome; a plain remove refuses a modified worktree.
On 2026-10-12 a spec reviewer ran `git stash` on the tree under review to measure a baseline, and a
quality reviewer left a worktree behind.

Answer five questions:
1. Is every step's stated outcome actually present?
2. Is anything here that no step asked for? Name it.
3. Does each listed behaviour have a test asserting its example, and does no test assert something
   adjacent instead? For a task with no test, quote the line of the diff, or the check output, that
   produces each behaviour's example. For a task with no behaviours list, in the older shape, does
   the test assert the behaviour the task describes?
4. Did the verify commands run, and did they pass? Quote the output rather than the claim.
5. Is the output of the task's `Done when:` command in the report? Absence is DEVIATES on its own,
   however good the code looks: an unrun done condition means nothing here has been checked.

Verdict: COMPLIES or DEVIATES, then the reasons. Deviating is not a failure to be softened; it is
the finding.
```

Questions four and five cannot be answered by reading the diff, and five is the cheapest of all,
which is exactly why a reviewer under time pressure skips it. Question three is the one that catches
most real problems. A test that passes while asserting something adjacent to the requirement is the
most common way a task looks done and is not.

## 3. Code quality review

Only once pass one returns COMPLIES.

```
Review the quality of this work. It already matches its task; that is settled.

=== DIFF ===
<paste the diff>

=== PROJECT STANDARDS ===
<paste the relevant parts of the project's standards, or the path to them>

Look for: correctness bugs the tests would not catch, error and edge cases missed, duplication of
something that already exists in this codebase, a guard added at a leaf where the boundary was the
right place, and anything contradicting the standards above.

Do not change the tree you are judging. Run no git command that changes its index, working tree or
stash: no `stash`, `checkout`, `restore`, `reset`, `commit`, or `git add` of a file. Read it with
`diff`, `log`, `show` and `status`. If you create a worktree, make it with
`git worktree add --detach` in a new directory under the system temp directory, so no branch or
stray directory lands in the author's repo, and remove it with `git worktree remove --force`
before you report, whatever the outcome; a plain remove refuses a modified worktree.
On 2026-10-12 a spec reviewer ran `git stash` on the tree under review to measure a baseline, and a
quality reviewer left a worktree behind.

Rank findings: blocking, should fix, consider. Cap at ten. If nothing blocks, say so in the first
line.
```

[../../keel/references/reporting-findings.md](../../keel/references/reporting-findings.md) carries
the reason behind the ranking, cap and first-line rules the prompt above states.

## Which loop a task gets

How many review passes a task gets depends on what it touches, and a command decides it, not your
reading of the diff. "Running the loop" below is the full loop; this section says where the light
loop differs.

Once the implementer has staged, run `keel plan risk --staged`. For a batched task, run
`keel plan risk --range <base>..<task-head>` over that task's commits. It compares the changed paths
with the `hard_block_paths` of every profile the hook could read: the root's as `HEAD` has it (as
`<base>` has it, for a range) and as the working tree has it, every nested one, and the nearest
profile above the repository. So a change cannot lower its own review, and a change that includes
any `.keel/profile.json` is `loop: full` whatever the profiles then say. If you stage anything the
implementer did not, run `keel plan risk --staged` again on the index as it will be committed,
just before committing, and take that verdict.

- **Light loop** only when the command exits 0 and its last line is `loop: light`: a declared list
  that the change touches nowhere, or no list declared at all.
- **Full loop** otherwise: `loop: full` (a path matched), exit 1 (a usage error), 3 (a profile that
  cannot be read, or no `python3`) or 6 (git that cannot run), a `keel` too old to have the command,
  or no `keel`. Failing to decide is never a reason to review less.
- **Neither, on exit 4** (nothing staged, or an empty range). In the shared tree it means the
  implementer staged nothing: it committed against its rules, or produced nothing. Stop, check
  `git status` and `git log`, then ask.

In the light loop the task gets one spec pass. COMPLIES: tick and commit, the tick note carrying
`loop: light`. DEVIATES: **why the fix pass may build on the rejected attempt here**, where the full
loop's rule below forbids it: the fix is scoped to what the verdict names, it is capped at one
round, and a second rejection goes to a person rather than to another agent. In order:

1. One fix pass: a fresh implementer dispatch on the plan's routing, with the implementer's label,
   handed the staged attempt and the verdict and told to change only what the verdict names. It
   counts toward `rounds`. In a worktree it amends the task's commit with `git commit --amend`
   rather than adding one, and you re-resolve `<task-head>`.
2. Re-run the same `keel plan risk` command.
3. If it exits 0 with `loop: light`, one spec pass again. A second DEVIATES stops and asks the
   person, with both verdicts.
4. If it is anything else, because the fix touched a declared path or the command could not decide,
   discard the attempt and dispatch fresh in the full loop, `rounds` continuing.

A light-loop task has had no quality review. Its Step 6 report names `review-code` as that review,
which the feature gets once at the end. `ship` step 5 enforces the project's standards through it
only under `gates.coding_standards: required`; `warn` reports a violation and ships, and `off`, or
no key, does not look. It is the light loop's quality review, not an optional next step.

## Running the loop

One task at a time, unless the plan declares a concurrent batch and every condition in
[parallel-batches.md](parallel-batches.md) holds. Outside a declared batch, do not dispatch task N+1
while task N is unreviewed: if task N deviated, task N+1 may have built on it, and you now have two
problems entangled.

**Find where the run stands with `keel plan status <plan>`**: its `next:` line names the first
open step, and so the next task to dispatch; after a compaction it replaces rereading the plan.
Where `keel` is not installed or not on PATH, or it reports the plan unaddressable, read the
checkboxes instead.

**Before the first dispatch, and again before each one, check `git status --porcelain` is empty.**
A dirty tree is not a refusal, so it is not in step 1's table; it is handled here, because it can
become true again halfway through a run that started clean. Stop and ask what to do with what is
there: committing, stashing and discarding are all reasonable and all the user's call. See
[preconditions.md](preconditions.md).

After both passes, with pass one at COMPLIES and pass two carrying nothing `blocking`: tick the
task's steps with `keel plan tick <plan> <id>`, **then commit**, with the paths and the message the
task's hand-over step names, then dispatch the next. Where `keel` cannot run, or reports the plan
unaddressable because it has no step ids, tick the checkboxes by editing the plan file.

`<id>` is a step id such as `3.2`, one call per step, never a task number. The command is used
rather than an edit because it rewrites only that step's line, in the form `keel plan status` and
`ship`'s gate read back, and holds a lock so a batch's ticks cannot overwrite each other. In the
fallback, "cannot run" means `keel` is not installed or not on PATH. Any other failure (exit 1)
names what is wrong with the id or the plan, such as an id the plan does not hold, a fence that
never closes, or a lock still held, and is fixed rather than bypassed by editing the plan by hand,
which would reopen the race the lock closes.

**You commit, not the implementer.** The implementer stages and stops, unless its task's final step
says otherwise, which only a batched task's does. This is the order the skill body already states,
and it is what keeps the review a gate rather than a comment on history that has already landed: a
verdict you can only act on by rewriting a commit is not a verdict you can act on.
[plan-template.md](../../write-plan/references/plan-template.md) carries the reasoning and the one
exception, a declared concurrent batch, where each task commits inside its own private worktree and
nothing reaches the shared tree until you merge it back after review.

You are ticking boxes for work you did not do, so tick on the subagent's reported output and add a
note, `keel plan tick <plan> <id> --note <text>`, for every step it named as already satisfied.
Nobody witnessed those, and the plan is the only place that can say so.

**The last step you tick done in a task carries
`--note 'rounds: <n>; routing: <profile>; loop: <light|full>'`**, `n` being the number of
implementer dispatches the task took and `loop` the word the section above decided. Any other text
follows after a further `; `, because `keel plan report` reads a field only at the start of the
note or after `; `. The note applies in inline mode too, where you implement and `n` is 1 unless the
task was redone. Nothing decides a loop in inline mode: write the loop `keel plan risk`
printed if you ran it, and otherwise leave the field out.

**On a DEVIATES verdict in the full loop**, re-dispatch the same task to a fresh subagent with the
review attached, rather than asking the original to fix it. A subagent that has already justified
its approach will defend it, and you get a negotiation instead of a correction.

**In the full loop, discard the first attempt before re-dispatching, and be explicit about what that
means**, because "fresh subagent" is a claim about the tree as much as about the agent. Nothing was
committed, so there is no history to rewrite: unstage and discard the working tree, and the second
subagent starts from exactly the state the first one did. In a declared batch, reset or delete that
task's worktree and do not merge it.

**In the full loop, never re-dispatch on top of the rejected attempt.** A fresh agent handed a tree
containing work a reviewer just rejected reads it as the starting point and builds on it, which is
how a DEVIATES verdict turns into two entangled problems instead of one corrected task. If the work
was committed anyway, by an implementer that ignored its rules or a plan written before them, say so
and stop: undoing a commit is the user's call, and it is the one repair this loop must not make
silently.

**A `blocking` finding from the quality review is handled exactly as a DEVIATES verdict is**, and
for the same reason: the tick is the gate, and a finding acted on only after the commit is a
comment on history. Do not tick, do not commit. Discard the attempt and re-dispatch the task to a
fresh subagent with the finding attached, as above. `should fix` and `consider` findings do not
stop the tick; they go in the Step 6 report beside the task they came from. The one way past a
`blocking` finding without a fix is the user accepting it by name, and that acceptance is written
into the plan file beside the task before its box is ticked.

## Which model each prompt goes to

**Dispatch implementation and both reviews with the routing named here, each description starting
with it.** Both reviews go to model `inherit`, with the description starting `inherit: `. They judge
whether another agent's verdict is right, which is the work least worth making cheaper, and no plan
routes them. The wide reading briefs in other skills go to delegation profile `keel-fanout`; these
do not.

**The implementer goes to the routing the plan's header names, and to `inherit` when it names
none.** The line is `**Implementer routing:**`. On `inherit` the implementer is model `inherit`, its
description starting `inherit: `. On `keel-implementer` it is delegation profile `keel-implementer`,
its description starting `keel-implementer: `. Any other routing value is not guessed at: stop and
ask. Announce the routing in one line before the first dispatch.

A cheaper model that silently handled something that mattered is the failure this rule exists to
make visible, and it is invisible by construction: the output looks like output. The label and the
tick note's routing field are how a routed implementer is seen.

## What you keep, and what you do not touch

Delegate mechanical execution. Keep for yourself: any task whose step says to stop and ask, any
decision the plan left open, and the judgement of whether a verdict is right. A subagent cannot ask
you a question mid-task, so a task that needs one will guess.

**And write no production code while you are coordinating.** Not a rename, not a template string,
not the one-character fix that is plainly correct. Every correction goes back through a fresh
dispatch, at any size.

The reason is not tidiness. Every review pass, two in the full loop and one in the light, is fed the
subagent's diff, so **an edit you make is the only change in the whole run that no pass sees.** It
is not a small unreviewed change, it is the only unreviewed change.

**The plan file is the exception, and it is yours.** The implementer prompt forbids the subagent
from touching it and step 6 requires you to keep it true, so nobody else can. The test for an
honest plan edit is direction: recording a verdict, tightening a step whose assertions a review
found too weak, or withdrawing a claim the plan cannot support all make the task **harder** to pass,
and those are yours to make. Loosening a gate so a failing step passes makes it easier, and that is
the mistake the skill names. Where the repair would make a blocked task passable by changing what
was planned, propose it and let the user rule.

It is also usually bigger than it looks. A subagent that wrote its test first and watched it fail
has a test asserting whatever it built, so a report saying "returns `a - b` rather than the
specified `a: b`" describes two wrong files, not one wrong character. Fix the source and you turn
a green test red, and the next temptation is to edit the test.

This is the rule most easily rationalised away, because the enumeration above says what to keep and
a reader under time pressure hears it as the whole of the boundary. It is not: a correction is
neither "mechanical execution of a task" nor a judgement call, which is exactly the gap the
temptation lives in.

| The thought | What it costs |
|---|---|
| "Re-dispatching a one-character fix is absurd overhead" | The one change nobody reviewed, on top of a test asserting the wrong thing |
| "It moves the code toward the plan, so it is not a deviation" | True, and irrelevant. The rule is about who reviewed it, not which direction it went |
| "I am reviewing anyway, so I have effectively reviewed it" | You wrote it. That is the reviewer you do not have |
