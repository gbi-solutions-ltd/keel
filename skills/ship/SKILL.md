---
name: ship
description: Use when work is believed complete and the user wants to ship it, open a pull request, or push it for review.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Ship

## Overview

A gate, not a convenience. Run the checks, and refuse while anything is red.

Why each step is as it is: [references/rationale.md](references/rationale.md). Read it before
changing a step.

## The gate

Work down. Report the first failure and stop; do not run the rest and bury it.

1. **Tests pass.** Run `profile.verify.test` yourself. Not "the last run was green".
2. **New code has new tests.** A diff adding behaviour with no test added is incomplete, not
   finished.
3. **Lint, format, and typecheck pass**, for each that is not `null` in the profile.
4. **`security-audit --diff` per `gates.security_audit`**: `required`, findings block and only a
   named override per finding passes; `warn`, findings are reported and the user decides; `off`, the
   report says `skipped (gate off)`. A diff touching a `hard_block_paths` path, as `security-audit`
   decides it by
   [the match reference](../security-audit/references/sensitive-match.md), is audited under any
   value; a finding on such a path blocks and conversation cannot override it.
5. **`review-code` has run**, nothing blocking remains, and, under `gates.coding_standards`, no
   standards violation remains unaddressed:
   [references/standards-gate.md](references/standards-gate.md).
6. **Docs updated** where behaviour changed, and written as current state rather than as a record
   of the review.
7. **`keel plan status <plan>` prints `next: none` and exits 0**, and the report names each
   deferred or not-applicable step with its reason. Exit 1 fails the gate.
   Where `keel` is not installed or not on PATH, or reports the plan unaddressable, read the
   plan by hand instead: every checkbox is ticked, or the remainder is explicitly deferred and
   said out loud.
8. **Not on the default branch**, and the branch name follows the project convention.

## When something is red

Say which check failed, show the output, and stop. Do not fix it as part of shipping: the fix
belongs in its own reviewed change.

The exception is a mechanical formatting fix from `profile.verify.format_fix`, run only on files the
diff already touches (passed as paths; if the command cannot take them, do not run it) and committed
on its own. Say that you ran it.

## "They are flaky"

Not an override on its own.

Ask for either evidence or a named override: run the test ten times on a clean checkout, or accept
"two failing tests, believed flaky, unverified" in writing. "Everyone ignores them" is not evidence.

## Overrides

The user can accept a specific failure, and that is normal. Two rules: they name what they are
accepting, and it is recorded in the PR body. "Ship it anyway" without a named exception is not an
override; ask which check.

`hard_block_paths` cannot be overridden this way. Those need the underlying finding fixed.

## Committing and the PR

Commit style comes from `profile.conventions.commit_style`. A fix commit also follows
`../debug/references/rework-link.md`.

**No attribution footers.** No `Co-Authored-By`, no robot emoji, no generated-with line. Title and
body only. Same for the PR body: it ends with its content.

The PR body states: what changed and why, which stories or requirements it satisfies, how it was
tested with the actual commands and results, the risk, and how to roll back. Write it from the plan
and the diff, not from the commit subjects. When the change is behind a flag, it names the flag, its
default in each environment, and who turns it on.

Any accepted override goes in the body, named.

When the branch changed a plan, add `keel plan report <plan>`'s output, reporting a non-zero exit
as such; in a delivery run, the follow-up list. Placement and contents:
[references/step-detail.md](references/step-detail.md#committing-and-the-pr); read it before you do
this step.

**Opening it.** `command -v gh` decides: with it, `gh pr create --base <default_branch>
--body-file <path>`. Without it, push and hand over the compare URL git prints. Either way the PR
URL is the last thing you report, and a pushed branch with no PR is not shipped.

## After

Report the PR URL, what the gate checked, and anything accepted rather than fixed. Name
`setup-deployment` if there is no pipeline to run this, or `write-docs` if docs were deferred.

## Common mistakes

| Mistake | Instead |
|---|---|
| Shipping with unticked plan boxes | Stop. Finish the step in its own change, or defer it with its reason |
