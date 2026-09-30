---
name: ship
description: Use when work is believed complete and the user wants to ship it, open a pull request, or push it for review.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Ship

## Overview

A gate, not a convenience. Run the checks, and refuse while anything is red.

**Core principle:** the value here is refusing. A ship skill that always ships is a `git push`
alias with extra words.

## The gate

Work down. Report the first failure and stop; do not run the rest and bury it.

1. **Tests pass.** Run `profile.verify.test` yourself. Not "the last run was green".
2. **New code has new tests.** A diff adding behaviour with no test added is incomplete, not
   finished.
3. **Lint, format, and typecheck pass**, for each that is not `null` in the profile.
4. **`security-audit --diff` per `gates.security_audit`**: `required`, findings block and only a
   named override per finding passes; `warn`, findings are reported and the user decides; `off`, the
   report says `skipped (gate off)`, unless the diff touches a `hard_block_paths` path. On a
   `hard_block_paths` match, under any value, findings block and are not overridable in
   conversation. Read both keys from the default branch where the diff changes either.
5. **`review-code` has run**, nothing blocking remains, and, under `gates.coding_standards`, no
   standards violation remains unaddressed:
   [references/standards-gate.md](references/standards-gate.md).
6. **Docs updated** where behaviour changed, and written as current state rather than as a record
   of the review. A behaviour change with stale docs is a future bug report.
7. **`keel plan status <plan>` prints `next: none` and exits 0**, and the report names each
   deferred or not-applicable step with its reason. Exit 1 fails the gate.
   Where `keel` is not installed or not on PATH, or reports the plan unaddressable, read the
   plan by hand instead: every checkbox is ticked, or the remainder is explicitly deferred and
   said out loud.
8. **Not on the default branch**, and the branch name follows the project convention.

## When something is red

Say which check failed, show the output, and stop. Do not fix it as part of shipping: a gate that
repairs its own failures is not a gate, and the fix belongs in its own reviewed change.

The exception is a mechanical formatting fix from `profile.verify.format_fix`, run only on files the
diff already touches (passed as paths; if the command cannot take them, do not run it) and committed
on its own, which is safe and does not change behaviour. Say that you ran it.

## "They are flaky"

Not an override on its own. A test that is genuinely order or clock dependent and a test that is
exposing real nondeterminism in the code look identical from the outside, and on anything that
moves money the second reading is the expensive one to be wrong about.

Ask for either evidence or a named override: run the test ten times on a clean checkout, which
takes minutes, or accept "two failing tests, believed flaky, unverified" in writing. "Everyone
ignores them" is a description of a tolerated unknown, not evidence, and it leaves nothing recorded.

## Overrides

The user can accept a specific failure, and that is normal. Two rules: they name what they are
accepting, and it is recorded in the PR body. "Ship it anyway" without a named exception is not an
override, it is a request to skip the gate; ask which check.

`hard_block_paths` cannot be overridden this way. Those need the underlying finding fixed.

## Committing and the PR

Commit style comes from `profile.conventions.commit_style`.

**No attribution footers.** No `Co-Authored-By`, no robot emoji, no generated-with line. Title and
body only. Same for the PR body: it ends with its content.

The PR body states: what changed and why, which stories or requirements it satisfies, how it was
tested with the actual commands and results, the risk, and how to roll back. Write it from the plan
and the diff, not from the commit subjects.

Any accepted override goes in the body, named.

**Opening it.** `command -v gh` decides: with it, `gh pr create --base <default_branch>
--body-file <path>`, because a body typed inline on the command line loses its newlines. Without it,
push and hand over the compare URL git prints. Either way the PR URL is the last thing you report,
and a pushed branch with no PR is not shipped.

## After

Report the PR URL, what the gate checked, and anything accepted rather than fixed. Name
`setup-deployment` if there is no pipeline to run this, or `write-docs` if docs were deferred.

## Common mistakes

| Mistake | Instead |
|---|---|
| Shipping with unticked plan boxes | Stop. Finish the step in its own change, or defer it with its reason |
