---
name: review-code
description: Use when asked to review changes, look at a diff or a pull request, check work before it ships, or give a second opinion on code someone has written.
allowed-tools: [Read, Bash, Grep, Glob, Agent]
---

# Review Code

## Overview

Find what will break, then what will be expensive to live with. In that order.

**Core principle:** rank ruthlessly and say which findings block. Why each step is as it is:
[references/rationale.md](references/rationale.md). Read it before changing a step.

## Step 1: Establish what the change was meant to do

Read the diff, and read the plan or story it claims to implement.

No plan or story? Ask the author what the change is for, or state the intent you inferred and review
against that.

`git diff <base>...HEAD`, plus `<docs_root>/standards.md` for the conventions and the plan for the
contract.

## Step 2: Delegate to the plugin if it is there

If the `code-review` plugin is installed, invoke `/code-review` and use its findings as the
correctness pass.

Not installed? Say so once, then go straight to step 3, which is then the whole review:

> The `code-review` plugin runs several reviewers with confidence scoring, which catches more than
> a single pass. Install with `/plugin install code-review@claude-plugins-official`. Continuing
> without it.

Either way, run step 3.

## Step 3: The pass that only we can do

Run `profile.verify.test` yourself first.

**Find the sensitive files before dispatching.** Run the command in
[../security-audit/references/sensitive-match.md](../security-audit/references/sensitive-match.md)
with the review's base and read the result by its rules. Where they make every changed file
sensitive, or read the result as touching without naming paths, count every changed production
file and say so in the report.

**Dispatch this pass; do not run it inline.**
Read [references/rubric-pass.md](references/rubric-pass.md) now, and brief a
subagent as it says, with model `inherit` and a description starting `inherit: `. The brief carries
the rubric, the sensitive files and six checks a generic reviewer lacks: the diff matches the plan,
every changed line traces to the request, the tests came first, no accepted decision is
contradicted, a test was proved able to fail, and every changed decision line on a sensitive path
was mutated. A dispatch without them reviews none of these. Where step 2's plugin ran, both stand:
it is the correctness pass, and this one settles a conflict.

## Step 4: Rank, and say what blocks

| Severity | Means | Action |
|---|---|---|
| **Blocking** | Wrong behaviour, a security defect, data loss, or an unmet requirement | Must fix before merge |
| **Should fix** | Will cost real time later, or violates a standard | Fix now or file it with an owner |
| **Consider** | A genuine preference | Say it once, do not insist |

Blocking first. If nothing blocks, say so in the first line and name what you checked. Cap at
around ten.

## Step 5: Report

Per finding: `file:line`, what is wrong, why it matters, and what to do. Do not rewrite it yourself;
the author fixes it.

When the author's fix for a blocking finding comes back, re-review once: dispatch step 3's pass
again with the last round's item 6 survivors. If the re-review still finds anything blocking, take
both reports to the person rather than start another round.

Read [../keel/references/reporting-findings.md](../keel/references/reporting-findings.md) once: it
carries the reason behind each rule.

Then name `security-audit` and `ship` as next. Do not start them, unless `execute-plan` started
this review in a delivery run, in which case `ship` follows as `execute-plan`'s delivery reference
says.

## Common mistakes

| Mistake | Instead |
|---|---|
| Style comments a formatter should make | Fix the tooling instead, once |
| Passing a behaviour change with stale docs | Documentation is part of the gate, not a follow-up |
