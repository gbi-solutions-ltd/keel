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
| A verify command is absent from the profile | Steps 2 and 4 of every task cannot run, so nothing can be proved. See the exception below. **Investigative commands need no profile entry**: `grep`, `git log` and `ls` are not verification |

## Exception 1: a plan whose first task creates the verify commands

A greenfield project has `verify.test`, `test_one`, `lint`, `typecheck` and `build` all `null`,
because there is no project yet. That is not a broken profile, it is the starting state, and
`write-plan` is instructed to handle it by making **task 1 create the toolchain and write the
commands into the profile**.

Refusing such a plan makes it unexecutable by construction: the commands cannot exist before the
task that creates them runs, and that task cannot run while they are missing.

**So:** where the plan's global constraints name the commands task 1 will create, and task 1
creates them, start. Task 1's own step 2 legitimately watches its test command fail because the
toolchain is absent. Every task after it must use the real commands, and if task 1 finishes without
`keel doctor` passing, stop there.

Still refuse when the commands are absent and no task creates them. That is a plan that cannot be
verified, which is the case the rule is for.

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
