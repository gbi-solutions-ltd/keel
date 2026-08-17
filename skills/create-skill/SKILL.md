---
name: create-skill
description: Use when a workflow just went well and should be repeatable, when the user says to make something a skill, or when the same correction keeps being needed.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, Agent]
---

# Create Skill

## Overview

Writing a skill is test-driven development applied to process documentation.

**Core principle:** if you did not watch an agent fail without the skill, you do not know the skill
teaches the right thing. You know only that it reads well.

## Step 0: Check an existing skill does not already cover it

Ask whether an existing skill already covers this. Overlapping skills are worse than a missing
one: the router picks arbitrarily and neither gets improved.

**"No new skill" is a correct outcome.** Observed: a repo-audit workflow run three times looked
like an obvious candidate, and the baseline showed a capable agent already doing it well. What it
lacked was already covered by `repo-snapshot` and `security-audit`. Strengthen those instead.

## Step 1: Baseline first, and write down the failure

Before writing any skill content, run the scenario against a subagent **without** the skill.

Record exactly how it fails, and quote the reasoning it used. Those quotes become the skill's
content: a rationalisation table built from real rationalisations closes real loopholes, and one
you imagined closes imaginary ones.

Skipping the baseline is the same mistake as writing a test after the code. You get something that
passes and proves nothing.

## Step 2: Match the form to the failure

This determines whether the skill works, and getting it wrong makes things worse rather than
neutral.

| The baseline failure | The form that fixes it | The form that backfires |
|---|---|---|
| Knows the rule, skips it under pressure | Prohibition, rationalisation table, red flags | Soft guidance ("prefer", "consider") |
| Complies, but the output has the wrong shape | A positive recipe: state what the output IS, in order | Prohibitions. Under a competing incentive the model negotiates with "do not X" |
| Omits a required element from something it already produces | Structural: a required field in the template it fills in | Prose reminders near the template |
| Behaviour should depend on a condition | A conditional on an observable predicate | An unconditional rule plus exemption clauses |

**No nuance clauses.** "Do not X unless it matters" reopens the negotiation. A real exception is its
own conditional on something observable.

## Step 3: Write the minimum

Address the failures you observed, nothing more. Follow the shape in
[references/skill-anatomy.md](references/skill-anatomy.md).

The description states **when to use**, never what the skill does. A description summarising the
workflow becomes a shortcut the model takes instead of reading the body.

## Step 4: Re-run, then close the new loopholes

Run the same scenario with the skill present. The agent should comply, while usually finding a new
way around the edge. Add that, re-run, repeat. Two or three passes is normal.

## Step 5: Validate mechanically

Run `profile.verify.test`. In keel that checks frontmatter shape, the word budget, `@` links,
the docs-root notation, and link resolution.

A check rejecting output you believe correct is probably wrong: fix the check and pin the case. See
`docs/02-skill-catalog.md`.

## Step 6: Delegate the measurement

If the `skill-creator` plugin is installed, use its eval harness and variance benchmarking. Our
skill owns capture and authoring discipline; theirs owns measurement. Recommend it if absent.

## Step 7: Ship it as a reviewed change

A skill affects every repository at once, so it goes through `review-code` and `ship` like any other
change. Update `README.md`, `CHANGELOG.md`, and the plan in the same commit.

## Common mistakes

| Mistake | Instead |
|---|---|
| Writing the skill first | Baseline first. Otherwise you are guessing at the failure |
| An invented rationalisation table | Quote what the agent actually said |
| Prohibitions for a wrong-shaped output | A positive recipe. Prohibitions backfire here |
| A description summarising the workflow | State when to use it only |
| One pass and done | Re-run. The second loophole is always there |
| Shipping without the docs | A skill nobody knows exists is not a skill |
