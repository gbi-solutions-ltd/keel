# No test tooling, and the project is not greenfield

The case: `verify.test` and `verify.test_one` are `null`, the codebase is established, no plan is
running, and no task anywhere creates a toolchain. The request in front of you is small.

This is the gap between the two situations the skills already cover. Greenfield-with-no-tooling is
handled by `write-plan` (task 1 builds the toolchain) and by `execute-plan`'s preconditions.
Brownfield-with-poor-coverage is handled by the rationalisation "This code has no tests" -> "add one
for what you touch". **Neither fits here**, and read literally the second one pushes toward
installing a framework the team never asked for.

A run that hit this said so plainly: *"The `tdd` exceptions list is closed and none of its three
members covers 'the project has no runner'."* It stopped and asked, which was right, and it reported
that nothing in the skills told it to.

## The asymmetry that named the gap

The managed engineering standard says: *"Lint after each file edit, not at the end; with no lint
command, say so and run the nearest check."* There is a stated fallback for a missing **lint**
command and none for a missing **test** command. That is the hole this page fills.

## The question to ask

Per [../../keel/references/asking-questions.md](../../keel/references/asking-questions.md), with
your reading offered first. Options in this order:

| Option | What it costs |
|---|---|
| **Take the exception: write it untested, on the record** | This change ships unproven. The codebase is unchanged, no dependency is added, and the exception is written down instead of taken silently |
| **Add a runner and write the commands into the profile** | The service gains test tooling and a profile change nobody asked for, off the back of one request. Right when the team wants it, or when the change is large enough to deserve it |
| **Write the test now, leave it unrunnable** | Nothing executes it. You would be claiming RED having never seen red, which this skill's own red flags call out |

**Recommend the first** where the request is small and nobody has asked for tooling. The reasoning
a run gave for it holds generally: *"introducing one is a bigger change than the feature"*, and it
declined to decide alone because *"that is a standing decision about the repo, not a cheap
reversible one"*.

## The third option is the one to watch for in yourself

It is the only one that looks like compliance. It produces a file named `*.test.js`, it satisfies
the letter of "write the test first", and it proves nothing, ever, because no command will run it.
A reviewer skimming the diff sees a test and moves on. That is worse than the honest gap, in the
same way the plan template says a fabricated test is worse than a task that says it has none.

If you find yourself reaching for it, the real reason is that asking felt like an interruption.

## Recording the answer

Whichever is chosen, write it where the project reads:

- Runner added: `keel profile set verify.test ...` and `verify.test_one`, then `keel doctor`.
- Exception taken: say so in the commit message, naming what is untested and why. A repeat of this
  question next week means the first answer was not recorded.

If the user is unavailable and the work cannot wait, take the first option, never the third, and say
in your report that you took it without an answer.
