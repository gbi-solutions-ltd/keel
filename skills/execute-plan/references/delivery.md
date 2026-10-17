# Delivering a plan to a pull request

Read at `execute-plan` step 6, after the report, when the plan's header carries
`**Delivery:** pull-request`. The coordinator reads that line from the plan, never from the
request: the person chose delivery when they approved the plan, and the line is what lets
`review-code` and `ship` start without a further word from them. Asking to "deliver" a plan whose
line says `hand-off` changes nothing until the line is changed, so a later session reads the same
answer the first one did. A plan with `**Delivery:** hand-off`, or with no such line, stops at
step 6 as it always has, and nothing below applies. Any other value is read as `hand-off`, and the
report says it was not recognised.

## The rule, and why it is general

Under `**Delivery:** pull-request`, any point in the chain where a skill or one of its references
says stop, ask, or "the user decides" ends the run with a report of where it stopped, what it
needs, and what was left as it was. For example: "Stopped at `ship` check 4: `security-audit`
found 1 finding under `warn`, which the user decides. Nothing was pushed."

**Why:** delivery removes the waits between skills, not the decisions inside them. The person
agreed to a pull request being opened. They did not agree to a deviation, an override or an
accepted finding, and a run that made one for them would hand back a pull request that looks
finished and hides it.

The cases below name instances of the rule, not all of it. A stop in a skill or reference this
list forgot still stops the run, because a list read as complete turns every case it missed into a
decision the run makes alone.

## The cases named

- An `execute-plan` step 5 stop: a verification that fails in a way nobody can explain, an
  ambiguous step, a missing dependency, a `verify` command that does not run, or the same failure
  twice.
- A deviation from the plan, a skipped task, or a step deferred or marked not applicable. Each
  needs the user's agreement before the plan is changed, and `ship` check 7 reads the result.
- The loop sending a task to the person: a second light-loop DEVIATES, or a full-loop DEVIATES or
  blocking finding with no fix allowed, where the only way past is the user accepting the finding
  by name.
- `keel plan risk` exit 4: nothing staged, or an empty range, which means the implementer staged
  nothing or committed against its rules.
- A dirty tree before a dispatch. Committing, stashing and discarding are the user's call.
- A rejected attempt already committed. Undoing a commit is the user's call.
- An unknown routing value. The routing is not guessed at.
- A plan repair that changes what was planned, such as making a blocked task passable or a batch
  eligible. It is proposed for the user to rule on. A tightening edit, such as withdrawing a wrong
  batch declaration or recording a verdict, stays the coordinator's.
- An empty join diff, which is reviewed as nothing and passes as everything.
- `review-code`'s second blocking round, whose two reports go to the person.
- Any red `ship` check, apart from the `profile.verify.format_fix` exception that `ship` itself
  allows. A gate that repairs its own failures is not a gate.
- Any `security-audit` finding, under `required` or `warn`. Under `required` only a finding the
  person names passes, under `warn` the person decides, and a delivery run holds neither.
- A `hooks/sensitive-guard` ask the person declines or does not answer. An ask that gets no answer
  is not a yes.
- A context-watch block. The session writes down where it is and stops; the record below is what
  the next one resumes from.

## The run

Once every task is ticked and committed, the coordinator runs `review-code` over the whole change,
then `ship`. The review's base is `git merge-base <default_branch> HEAD`, which is what `ship`
opens the pull request against, so the review sees the diff the pull request will show and not
only the last task's. Step 6's report is still written first, and the follow-up list below draws
on it.

A blocking finding, or a standards violation `ship` check 5 would refuse under
`gates.coding_standards: required`, gets one fix pass:

1. A fresh implementer on the plan's `**Implementer routing:**`, given the findings and told to
   change only what they name. The coordinator writes no code (ADR-0002), review fixes included.
2. `keel plan risk --staged` on the result, as for any task's staged change.
3. The coordinator commits it as `fix: <what> (review-code)`, naming the paths.
4. Exactly one re-review.

If `keel plan risk` answers `loop: full` for the fix, the fix gets the full loop's two passes
before the re-review, as any task would; exit 4 stops the run, as the case above says.

A second blocking round stops the run, because `review-code` step 5 takes two blocking reports to
the person rather than start a third round. Should fix and consider findings do not stop it; they
go into the pull request body as the follow-up list that `ship` writes.

The `security-audit` report file `ship` writes is committed on its own before the pull request, so
the audit the gate relied on travels with the branch and the tree is clean when the pull request
opens. The run ends at that pull request or, where `gh` is absent, at the pushed branch and the
compare URL, reported as such.

## The record

After each stage the coordinator adds to a `## Delivery` section of the plan, and commits it
with the stage. A stage with no commit of its own, such as a clean `review-code`, gets a commit of
the plan alone. The `- review-code:` line states the verdict and whether any standards violation
that `ship` check 5 acts on (under `gates.coding_standards: required`, per
`skills/ship/references/standards-gate.md`) remains. The `- follow-up:` list holds the should fix
and consider findings from the per-task reviews and from `review-code`, plus the remaining items
in step 6's report. Both review lines, the `- review-code round 1:` line below and the
`- review-code:` line, go above the follow-up list, so the section reads in order. Every rule
below keys on a line's prefix and not on where it sits, because different stages add the lines and
a rule that counted positions would break the first time one landed elsewhere. For example:

```
## Delivery

- review-code: nothing blocking, no standards violation open (2026-10-16, base 57c1bc4)
- follow-up:
  - should fix: <finding> (<path>)
  - consider: <finding> (<path>)
```

When each task is ticked, its should fix and consider findings are appended to the follow-up list
in this section, and committed with that task. A task with none appends nothing. An empty list is
written as `- follow-up: none` by the `review-code` stage, and only if the list is still empty
then, so that an empty list and an unwritten one differ.

When a `review-code` is blocking, or leaves a standards violation `ship` check 5 would refuse, and
its fix pass is committed, a `- review-code round 1:` line naming the first review's blocking
findings is committed with that fix commit:

```
- review-code round 1: 2 blocking (2026-10-16, base 57c1bc4)
  - <finding> (<path>)
```

A review that gets a fix pass writes no `- review-code:` line; the round 1 line is its record,
because a `- review-code:` line written before the fix would tell a resumed session the review is
done.

The first review's should fix and consider findings are appended to the follow-up list in that
same commit. The fix pass does not change them, and otherwise they reach the pull request body only
if the re-review happens to find them again. The list is then no longer empty, so the
`- follow-up: none` rule above is unchanged: it is written only when nothing was appended.

After a fix pass the final `- review-code:` line records the re-review's verdict, not the first
review's; the round 1 line stays. `ship` gets no record line of its own: the plan is committed
before the pull request opens, so a line added after would never be pushed, and the pull request
URL in the report is the record.

**Why:** a resumed session has lost what the first one saw. After a compaction or a context-watch
block it reads the plan's `**Delivery:**` line, `keel plan status` and this section. It re-runs
`review-code` unless the section holds both a `- review-code:` line with its standards state and
the `- follow-up:` list, because a review that ran and left only half its result is not evidence
that it did, and without the list the pull request body would be written from memory the session
no longer has. A `- review-code round 1:` line alone does not satisfy it: it records the first
review, which the fix pass answered, not the verdict on the change as it now stands. Per-task
entries in the list with no `- review-code:` line show only that tasks were ticked, not that the
review ran. `ship` check 5 reads the `- review-code:` line in a delivery run for the same reason:
a session that never saw the review has nothing else to check "has run" against.

A `- review-code round 1:` line and no `- review-code:` line means the fix is committed and the
re-review is not. The session runs the re-review as the last round, over the base on that line,
and a blocking result there stops the run and takes both reports to the person, the first from the
round 1 line. A fresh first review would instead find the fix's leftovers, spend a second fix pass
this file allows no one, and lose the first report.

A `- review-code:` line whose verdict is blocking, or that leaves a standards violation open, ends
the run before `ship`, with both reports to the person (the first from the round 1 line), because
`ship` would only refuse it at check 5 without them.

## What the run never does

- Merge, or push to the default branch. Merging stays a person's act.
- Override a gate on the person's behalf. An override is a failure the person names.
- Accept a finding the person has not named. Acceptance is how a blocking finding passes without a
  fix, and it is theirs.
- Start `ship` from a `review-code` that `execute-plan` did not start in a delivery run. Only that
  review has the recorded base and the line that check 5 reads; a review someone else began has
  neither, and `review-code` step 5 allows the continuation for no other.
