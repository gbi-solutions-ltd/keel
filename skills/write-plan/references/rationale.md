# Why the steps are as they are

The reasons behind `write-plan`'s steps, kept here so the body stays instruction; the steps
themselves are in [SKILL.md](../SKILL.md).

## Step 1: Read the inputs

Read the ADRs the stories point at because a plan that contradicts an accepted decision is worse
than no plan.

With no stories, stop and name `write-user-stories` because a plan cannot be written in the same
pass as the requirements it rests on.

## Step 2: Map the files before writing tasks

Map the files first because decomposition decisions get locked in there, and they are much cheaper
to change then than inside task 7.

Whether to hand the reading out is decided by the tree, not the mood.

The findings that come back are leads and the decomposition stays yours because Step 4 forbids
naming a function no task defines, and second-hand knowledge is how that creeps in.

## Step 3: Write the tasks

Write `Depends on:` as `none` rather than leaving it out because an absent line is read as unknown,
and that task runs alone.

Declare every batch `keel plan batches` prints in the header because the approver can only approve
overlap they can see.

## Step 4: No placeholders

These are plan failures, not shortcuts. Each one moves a decision from you to someone with less
context. That is the opposite of planning.

## Step 5: Self-review, then have it reviewed

Run the self-review yourself because it is mechanical, and a dispatch is slower and no more
reliable.

Have the plan reviewed as well because the self-review's checks compare the plan to itself; none
opens the codebase, so a plan can pass every one and still be unbuildable.

## Step 6: Hand off

Write the answer into `**Implementer routing:**` and `**Delivery:**` because `execute-plan` reads
those lines, not this conversation.

On the default branch, leave the plan uncommitted and start nothing because a delivery run records
its progress in a committed plan.

On `pull-request`, start `execute-plan` because approval chose the pull request as the next gate.
