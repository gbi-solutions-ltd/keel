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

No plan or story? Ask the author what the change is for, or state the intent you inferred and review
against that.

`git diff <base>...HEAD`, plus `<docs_root>/standards.md` for the conventions and the plan for the
contract.

## Step 2: Delegate to the plugin if it is there

If the `code-review` plugin is installed, invoke `/code-review` and use its findings as the
correctness pass. Its multi-agent confidence scoring catches more than one inline read.

Not installed? Say so once, then go straight to step 3, which is then the whole review:

> The `code-review` plugin runs several reviewers with confidence scoring, which catches more than
> a single pass. Install with `/plugin install code-review@claude-plugins-official`. Continuing
> without it.

Either way, run step 3. A generic reviewer does not know this project's intent.

## Step 3: The pass that only we can do

Run `profile.verify.test` yourself first. `keel:tdd` runs it once at a unit boundary, so review
is where the suite result is established rather than inherited.

**Dispatch this pass; do not run it inline.** A reviewer that watched the code being written is
anchored on it. Read [references/rubric-pass.md](references/rubric-pass.md) now, and brief a
subagent as it says, with model `inherit` and a description starting `inherit: `. The brief carries
the rubric and five checks a generic reviewer lacks: the diff matches the plan, every changed line
traces to the request, the tests came first, no accepted decision is contradicted, and a test was
proved able to fail. A dispatch without them reviews none of these. Where step 2's plugin ran, both
stand: it is the correctness pass, and this one settles a conflict, having read the plan, the
decisions and the standards.

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

Read [../keel/references/reporting-findings.md](../keel/references/reporting-findings.md) once: it
carries the reason behind each rule.

Then name `security-audit` and `ship` as next. Do not start them.

## Common mistakes

| Mistake | Instead |
|---|---|
| Style comments a formatter should make | Fix the tooling instead, once |
| Passing a behaviour change with stale docs | Documentation is part of the gate, not a follow-up |
