# The plan reviewer brief

Dispatch this once, after step 5's four mechanical checks pass, before handing off. Model
`inherit`: this is judgement about whether a plan is buildable, which is the work least worth
making cheaper.

## Why a dispatch and not a fifth checklist item

The four checks in step 5 compare the plan to itself. Story coverage counts headings, the
placeholder scan greps for phrases, name consistency reads two tasks side by side, command
accuracy reads the profile. **None of them opens the code the plan will be built on.**

A run given exactly those four checks over a deliberately flawed plan passed all four and reported
the plan's central defect only because it opened a source file off its own initiative:

> "I found the S-05 / queue-drain gap only because I opened `src/queue.js`. Nothing in step 5 tells
> you to read the codebase. A reviewer executing the four items literally would have passed this
> plan on all four and never opened that file. That is the single most important finding in this
> review and the checklist does not reach it."

The same run named its own failure mode as anchoring: "Task granularity was never on the checklist,
and I only glanced at it... I noted it and moved on because no checklist item asked."

So the reviewer is briefed on dimensions, not on items, and it is told to read the repository.

## The prompt

```
Review this implementation plan for whether it can actually be built against this repository.
Someone has already checked it for placeholder phrases, name consistency between tasks, story
coverage, and that its commands come from the profile. All four passed. Do not repeat them.

=== PLAN ===
<paste the plan, or its path>

=== REPOSITORY ===
<the repo path, and the profile path>

Read the source files the plan names before answering. A finding without a `path:line` behind it
is a guess, and says so.

Answer six questions.

1. Every symbol a task consumes: does it exist in the code today, or does a named task in this
   plan create it? List each one and which. A consumed function that neither exists nor is created
   is the defect this question is for, and it is usually invisible from the plan alone.
2. Can each story actually be delivered by the tasks assigned to it? Not "is there a task", but
   "does the work in that task produce the outcome the story states". Read the story's "so that"
   clause against the code.
3. Are the steps executable as written? A step saying "write the failing test" with no test in it,
   or "run it and watch it fail" naming no command and no expected output, is not executable,
   however clean the plan looks. Count them.
4. Does the decomposition match this codebase's established patterns? Name any task that puts a
   file somewhere the repo does not otherwise put files, or splits work the repo keeps together.
   Also say whether the task count looks right, and why.
5. What in the existing test setup could make these tasks' verification unreliable? Module-level
   mutable state, order dependence between test files, a suite the tasks all gate on, a lint or
   build command that does not currently run cleanly. Say what would go wrong and when.
6. What would you not know how to build if you were handed one task and nothing else? Name the
   task and the missing decision.

Rank findings: blocking, should fix, consider. If nothing blocks, say so in the first line.
```

## Reading the result

A blocking finding goes back into the plan before hand-off. A finding you disagree with gets
recorded in the plan's open questions with your reason, not dropped: the reviewer read the code and
you may not have.

**Do not dispatch this to the same context that wrote the plan.** The point is a reader who has no
memory of deciding any of it, and who will therefore ask why rather than remembering why.
