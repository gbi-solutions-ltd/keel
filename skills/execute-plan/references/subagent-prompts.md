# Subagent prompts for delegated mode

Three prompts: one to implement a task, two to review it. Read this before the first dispatch.

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
<paste the task, including its Files, Interfaces, and every numbered step>

=== GLOBAL CONSTRAINTS (verbatim from the plan header) ===
<paste the whole Global constraints block, including the verify commands>

=== RULES ===
- Follow the steps in order. Do not skip the step that runs the test and watches it fail.
- Use only the verify commands above. Do not substitute the command you would expect this stack to
  use; this project's real one is frequently not the obvious one.
- Implement only this task. If you notice something else worth doing, name it in your report and
  leave it alone.
- If a step cannot be executed as written, stop and report why. Do not improvise a way past it.
- Do not edit the plan file.

=== REPORT ===
Finish with: which steps you completed, the exact output of each verify command, anything you
noticed and deliberately left alone, and anything that blocked you.

Name separately any step that was already satisfied when you arrived. Do not count it as completed:
you did not perform it, and whoever ticks the box needs to know that.

Run the task's `Done when:` command last and paste its output. If you did not run it, say so in
your first line. A report claiming completion with no command output in it is rejected and
re-dispatched, which costs more than saying you skipped it.
```

Paste the constraints in full rather than summarising them. A summary is where "never start on the
default branch" quietly disappears.

## 2. Spec compliance review

```
Review this work against the task it claims to implement. Judge only whether it did what was
asked. Ignore style, naming, and elegance entirely; a separate pass covers those.

=== TASK ===
<paste the same task verbatim>

=== DIFF ===
<paste the diff, or name the changed files>

Answer five questions:
1. Is every step's stated outcome actually present?
2. Is anything here that no step asked for? Name it.
3. Does the test assert the behaviour the task described, or something adjacent?
4. Did the verify commands run, and did they pass? Quote the output rather than the claim.
5. Is the output of the task's `Done when:` command in the report? Absence is DEVIATES on its own,
   however good the code looks: an unrun done condition means nothing here has been checked.

Verdict: COMPLIES or DEVIATES, then the reasons. Deviating is not a failure to be softened; it is
the finding.
```

Question five is the cheapest of the five and the only one that cannot be answered by reading the
diff, which is exactly why a reviewer under time pressure skips it. Question three is the one that
catches most real problems. A test that passes while asserting
something adjacent to the requirement is the most common way a task looks done and is not.

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

Rank findings: blocking, should fix, consider. Cap at ten. If nothing blocks, say so in the first
line.
```

## Running the loop

One task at a time, unless the plan declares a concurrent batch and every condition in
[parallel-batches.md](parallel-batches.md) holds. Outside a declared batch, do not dispatch task N+1
while task N is unreviewed: if task N deviated, task N+1 may have built on it, and you now have two
problems entangled.

After both passes: tick the checkboxes in the plan file, commit as the task specifies, then dispatch
the next.

You are ticking boxes for work you did not do, so tick on the subagent's reported output and add a
note for every step it named as already satisfied. Nobody witnessed those, and the plan is the only
place that can say so.

**On a DEVIATES verdict**, re-dispatch the same task to a fresh subagent with the review attached,
rather than asking the original to fix it. A subagent that has already justified its approach will
defend it, and you get a negotiation instead of a correction.

## Which model each prompt goes to

**Dispatch implementation and both reviews with model `inherit`.** These write code under the TDD
gate and judge whether another agent's verdict is right, which is the work least worth making
cheaper. The wide reading briefs in `repo-snapshot`, `port-assess`, `apex-port-plan` and
`shape-idea` go to `sonnet`; these do not.

Say which model you dispatched, in one line, whichever it is. A cheaper model that silently handled
something that mattered is the failure this rule exists to make visible, and it is invisible by
construction: the output looks like output.

## What you keep, and what you do not touch

Delegate mechanical execution. Keep for yourself: any task whose step says to stop and ask, any
decision the plan left open, and the judgement of whether a verdict is right. A subagent cannot ask
you a question mid-task, so a task that needs one will guess.

**And write no production code while you are coordinating.** Not a rename, not a template string,
not the one-character fix that is plainly correct. Every correction goes back through a fresh
dispatch, at any size.

The reason is not tidiness. Both review passes are fed the subagent's diff, so **an edit you make
is the only change in the whole run that neither pass sees.** It is not a small unreviewed change,
it is the only unreviewed change.

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
