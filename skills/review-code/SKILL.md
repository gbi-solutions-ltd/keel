---
name: review-code
description: Use when asked to review changes, look at a diff or a pull request, check work before it ships, or give a second opinion on code someone has written.
allowed-tools: [Read, Bash, Grep, Glob, Agent]
---

# Review Code

## Overview

Find what will break, then what will be expensive to live with. In that order.

**Core principle:** a review that lists thirty things gets ignored. Rank ruthlessly and say which
findings block.

## Step 1: Establish what the change was meant to do

Read the diff, and read the plan or story it claims to implement. A review without the intent is
proofreading.

`git diff <base>...HEAD`, plus `<docs_root>/standards.md` for the conventions and the plan for the
contract.

## Step 2: Delegate to the plugin if it is there

If the `code-review` plugin is installed, invoke `/code-review` and use its findings as the
correctness pass. Its multi-agent confidence scoring catches more than one inline read.

Not installed? Say so once, then do the inline pass:

> The `code-review` plugin runs several reviewers with confidence scoring, which catches more than
> a single pass. Install with `/plugin install code-review@claude-plugins-official`. Continuing
> inline.

Either way, add the checks in step 3. A generic reviewer does not know this project's intent.

## Step 3: The passes that only we can do

Read [references/rubric.md](references/rubric.md) for the full checklist. The four that a generic
reviewer cannot run:

1. **Does the diff match the plan?** Anything implemented that no task asked for is unplanned
   scope. Anything a task asked for and is absent is an incomplete claim.
2. **Does every changed line trace to the request?** Adjacent improvements, reformatting, and
   drive-by refactoring belong in their own change. This is the surgical-changes test.
3. **Were the tests written first?** A test committed after its implementation, in the same
   commit or a later one, passed on its first run and proves nothing. Check the commit order.
4. **Does it contradict an accepted decision?** Check wherever this project records them: an ADR
   directory, or a decision log. Not every project uses ADRs, and an empty `decisions/` means
   look elsewhere before concluding there are none.

## Step 4: Rank, and say what blocks

| Severity | Means | Action |
|---|---|---|
| **Blocking** | Wrong behaviour, a security defect, data loss, or an unmet requirement | Must fix before merge |
| **Should fix** | Will cost real time later, or violates a standard | Fix now or file it with an owner |
| **Consider** | A genuine preference | Say it once, do not insist |

Put blocking findings first. If nothing blocks, say so in the first line: a reviewer who buries
approval under nine nitpicks trains people to skim reviews.

Cap it at around ten findings. More than that means the change is too large to review, and that
is itself the finding.

## Step 5: Report

Per finding: `file:line`, what is wrong, why it matters, and what to do. Never a finding without a
location, and never a location without a reason.

Then name `security-audit` and `ship` as next. Do not start them.

## Common mistakes

| Mistake | Instead |
|---|---|
| Reviewing without reading the plan | Intent is what makes a review more than proofreading |
| Thirty equally weighted findings | Rank. Blocking first, cap around ten |
| Style comments a formatter should make | Fix the tooling instead, once |
| "Looks good" with no evidence of reading | Name what you checked, including what was fine |
| Approving a diff you did not run the tests on | Run `verify.test`. A green claim needs a green run |
| Rewriting it yourself in the review | Say what is wrong. The author fixes it |
| Passing a behaviour change with stale docs | Documentation is part of the gate, not a follow-up |
