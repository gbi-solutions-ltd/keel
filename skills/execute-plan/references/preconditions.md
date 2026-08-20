# Preconditions, and the two that have exceptions

The table in step 1 lists what stops execution. This file says why each one blocks, and covers the
two that are refused wrongly more often than they are refused rightly.

Both exceptions were found the same way: by running the whole artifact chain on a real greenfield
project on 2026-08-15 and hitting a gate that could not be cleared by doing anything correctly.

## Why each blocks

| Condition | Why |
|---|---|
| An ADR the plan cites is `proposed` | Building on it means building on something nobody agreed. See the exception below |
| The plan has open questions blocking its own tasks | The plan is telling you it is not finished. Ask them as choices rather than reporting them |
| The PRD is a draft, or the stories are provisional | The requirement may change or vanish, and the work with it |
| You are on the default branch | Never implement on `main` without explicit consent. Branch first, which most plans say in their own constraints |
| A verify command cannot produce a verdict | Steps 2 and 4 of every task then prove nothing. Absent from the profile is one way; present and unable to run is the other, and both are below. **Investigative commands need no profile entry**: `grep`, `git log` and `ls` are not verification |

## What "cannot produce a verdict" means, and how to establish it

Presence in `.keel/profile.json` is not the check. A command can be present and prove nothing: a
linter with no config, a runner whose dependencies were never installed, a script at a path that no
longer exists. It passes a JSON read and fails on first contact, mid-run, after a dispatch has been
spent on it. The waste is the smaller half. Every task's step 2 then watches a red that means
nothing and the box gets ticked on it, which is the false witness
[parallel-batches.md](parallel-batches.md) already names for a different cause.

**The exit code is not the question.** A suite reporting two failures has verified something and
exits non-zero. Requiring exit 0 would refuse every plan whose purpose is to turn a suite green.

**What the output describes is the question.** `2 passed, 1 failed` is a report on the code.
`Cannot find module 'eslint'` is a report on the tool. Run it and read which one you got: no exit
code separates those across stacks, and you are an agent reading output rather than a script
matching a number.

**What to run, and when.** At step 1, before the first dispatch: the plan's `lint`, `typecheck` and
`build`, which are cheap and are where this breaks, plus `test_one` against **a test that already
exists**. Not the full suite, which task 1's own step 2 runs minutes later anyway. Not the test file
the plan's first task creates either: it does not exist yet, and a runner told to run a missing file
complains about itself, which is the signature this check reads as broken.

**Do not delegate this to `keel doctor`.** It runs the commands rather than reading the profile,
which is why it looks like the right instrument, and it discards their output
(`bin/keel:1346-1348`), so the exit code is the only thing it keeps. An exit code cannot separate a
verdict about the code from a complaint about the tool, which is the whole of the question here.
Doctor answers "is this project healthy". It cannot answer this one, and rewording it would not
change that.

## The condition that is not in the table: a dirty working tree

`git status --porcelain` is not empty when the run starts.

**This does not refuse the plan**, which is why it is not a row in step 1's table. It is checked at
the start of the loop and again before each dispatch, in
[subagent-prompts.md](subagent-prompts.md), because it is a property of the moment rather than of
the plan, and it can become true again halfway through a run that started clean.

It matters because of what sits downstream of it. A task's hand-over step stages named paths, so a
pre-existing uncommitted change is not swept up by a correct implementer. But the rule against
`git add -A` is what makes that true, and a subagent that reaches for it, or a plan written before
that rule existed, turns whatever was already in the tree into part of the first task's commit,
attributed to work that never touched it. Then the reviewer is shown a diff containing changes no
task asked for and returns a DEVIATES that is about the tree rather than about the work.

Stop and ask. Committing it, stashing it, or discarding it are all reasonable and all the user's
call, and none of them is yours to pick: an uncommitted change is by definition work somebody has not
finished deciding about.

## Exception 1: a plan whose first task creates or repairs the verify commands

A greenfield project has `verify.test`, `test_one`, `lint`, `typecheck` and `build` all `null`,
because there is no project yet. That is not a broken profile, it is the starting state, and
`write-plan` is instructed to handle it by making **task 1 create the toolchain and write the
commands into the profile**.

Refusing such a plan makes it unexecutable by construction: the commands cannot exist before the
task that creates them runs, and that task cannot run while they are missing.

**So:** where the plan's global constraints name the commands task 1 will create or repair, and
task 1 does it, start. Task 1's own step 2 legitimately watches its test command fail because the
toolchain is absent. Every task after it must use the real commands, and if task 1 finishes without
`keel doctor` passing, stop there. Doctor is right for that one: after task 1 the bar really is
exit 0, which is all it keeps.

**The exception is about the plan, not about greenfield.** What clears the gate is that a task in
this plan makes the command produce a verdict. A new project whose task 1 writes the toolchain and
an established one whose task 1 fixes a linter config that has never run are the same case: the
command proves nothing today, the plan owns it, and every task after it uses the real command. The
2026-08-19 baselines found the second half of that by accident, on a profile naming
`npx eslint src test` with no config and no `node_modules`, and three runs reached the gate before
anything in this file did.

Still refuse when nothing in the plan makes the command work. That is a plan that cannot be
verified, which is the case the rule is for.

**Say what would clear it, because there are exactly two things and neither is yours to do
silently.** A task in this plan that repairs the command, which is a change to the plan and the
user's to approve; or the user deciding this repository gets the tooling, which is a standing
decision about the repo rather than a step in a task.
[../../tdd/references/no-test-tooling.md](../../tdd/references/no-test-tooling.md) makes the same
argument for the case where there is no runner at all, and its reasoning carries: introducing
tooling is *"a standing decision about the repo, not a cheap reversible one"*. Writing the config
yourself is not a third option. It is the first one, taken without the approval and without a
review.

**What is still not covered: no plan, and no task.** An established codebase that has never had a
test runner, with no plan and no task creating one, is not a precondition failure to route around:
it is a decision for the user about whether this repository gets test tooling. `keel:tdd` carries
it, under "the project has no test tooling at all". Refusing outright and installing a framework
unasked are both wrong, and nothing above supports either.

## Exception 2: `proposed` is about agreement, not proof

The blocker exists because building on a decision nobody made wastes the build. It does not exist
to demand certainty, and the two get confused constantly.

- **Nobody has agreed it.** A genuine blocker. The decision has no owner and no one has ruled.
  Do not refuse and stop: **ask the decider to accept it**, which is usually one exchange, and
  remember that only a person moves an ADR to `accepted`.
- **Agreed but unproven.** Not a blocker. Every ADR carries a `Verification` section precisely
  because acceptance is not proof, and an accepted ADR with an open verification is the normal
  state of a decision that has just been made.

The case that exposed this: a plan whose whole purpose was a walking skeleton to prove that a
vendor's offline cache survived a week on a cheap device. Its ADRs were `proposed` because the
evidence did not exist yet, and the evidence could not exist until the plan ran. Refusing it meant
the decision could never be earned. What actually unblocked it was asking the person who had
already made the choice to accept the ADRs, leaving their `Verification` sections open for the plan
to close.

**So:** on a `proposed` ADR, establish which of the two it is before refusing. If the decision has
been taken and only the evidence is missing, ask for acceptance and note that the plan is what
produces the evidence. If nobody has decided, that is the refusal the rule is for.
