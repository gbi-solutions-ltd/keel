# Idea: the generated CI pipeline enforces almost none of what `ship` asks for

| | |
|---|---|
| Raised by | Bernard, 2026-09-19, "plan the work that makes keel enforceable outside the agent" |
| Status | shaped |
| Recommendation | Extend `write_ci` to run every non-null `verify.*` command as its own CI step. Do not attempt to make CI enforce review, docs, plan-checkboxes, or mutation testing |
| Next | `write-plan`, as one increment of the outside-the-agent plan |

## The problem

`skills/ship/SKILL.md` states eight gate items a change must clear before it ships. All eight are
agent-run, prose-enforced checks inside the ship skill's own turn. `write_ci` (`bin/keel:1144-1162`)
generates the only CI pipeline keel produces for a new project, and it reads exactly one profile
key: `verify.test`. A human pushing directly, a session that compacted before running `ship`, or a
tool other than the one that wrote the skill bypasses all eight items silently, and the generated
pipeline notices none of it.

**Evidence.** `write_ci()` at `bin/keel:1144-1162` (called once, from `cmd_new`, when `keel new`
scaffolds a project) writes `.github/workflows/ci.yml` with one job, `verify`: checkout, a
stack-conditional language setup, one `Test` step running the literal value of `verify.test`
(falling back to an `echo` if null), and one hardcoded "refuse committed key material" grep, not
driven by any profile key. It never reads `verify.lint`, `verify.format`, `verify.typecheck`,
`verify.build`, `verify.e2e`, `verify.security`, `verify.test_integration`, or any `gates.*` key.

Notably, keel's own repository does not run this generated file. Its real
`.github/workflows/ci.yml` is hand-authored, with a `validate` job that also runs `verify.lint` via
`jq`, plus a separate `supply-chain` job. `.keel/profile.json`'s own `_note` confirms: "keel
dogfoods itself. Maintained by hand rather than by `keel init`." The generator's own output is
thinner than even the pipeline the project that ships it actually relies on.

## The delta

| Ship requirement (`skills/ship/SKILL.md:20-32`) | CI (`write_ci`) enforces? | Evidence |
|---|---|---|
| 1. Tests pass | Partial. Generated CI runs `verify.test`, but only protects a merge if branch protection requires the check | `bin/keel:1146,1156` |
| 2. New code has new tests | No | No such step exists |
| 3. Lint/format/typecheck pass | No. Never read | `docs/profile-keys.md` cites only `doctor`/commit-guard as readers, never CI |
| 4. `security-audit --diff` clean, `hard_block_paths` not overridable | No. `gates.security_audit` is advisory skill prose; `hard_block_paths` is enforced only by `hooks/sensitive-guard`, a Claude Code hook, not CI | `docs/profile-keys.md` |
| 5. `review-code` has run | No | No CI step invokes review |
| 6. Docs updated | No | No doc-staleness check anywhere |
| 7. Plan checkboxes ticked | No | No such check exists |
| 8. Not on default branch | No, adjacent. `conventions.protect_default_branch` gates a pre-push hook, not CI | `docs/profile-keys.md` |

## Two things this is not

**Not a call to CI-enforce review, docs, or plan state.** Decision 3
(`docs/07-open-decisions.md:163-236`) already establishes the house posture: a skill's compliance
is unwitnessable from outside the model's own turn unless the check is external and mechanical. A
review having happened, docs being current, and plan checkboxes being ticked are judgment calls,
not commands with exit codes. Proposing to CI-enforce them contradicts that reasoning rather than
extending it.

**Not a call to add mutation testing to CI.** ADR-0006 introduces mutation as a technique inside
`tdd` and a review pass inside `review-code`, deliberately naming no tool: "every mutation harness
is a new install in every stack." There is no `gates.mutation` key and `write_ci` has no mutation
step. Adding one would contradict an explicit, dated design decision, not close an unintentional
gap. Separately, ADR-0007 already rejected tiering and retired `gates.tdd` outright; reviving
CI-level enforcement of it repeats a rejected proposal, not a new one.

## What is actually cheap and mechanical

`verify.lint`, `verify.format`, `verify.typecheck`, `verify.build`, `verify.e2e`, `verify.security`
are already, by schema, either a shell command or null. `write_ci` ignoring seven of ten `verify.*`
keys is the same "claim with no reader" defect this repository already removed from the profile
schema once. Closing it is one loop over the non-null keys, one CI step per key, in the shape
`write_ci` already uses for `verify.test`. It touches only `bin/keel`, needs no skill edit, and
costs no body-word budget.

## Recommendation

Extend `write_ci` to emit one step per non-null `verify.*` command, and make keel's own
`.github/workflows/ci.yml` a byproduct of `write_ci` (or bring it into parity by hand) so the
project that ships the generator dogfoods it. Leave items 2, 5, 6, 7, and mutation testing alone;
they are not CI-shaped by this repository's own settled reasoning, and treating them as an oversight
would be wrong, not merely expensive.

## Open questions

1. Should `security-audit --diff` gain a scriptable, non-interactive mode that a CI step could
   invoke, separate from its skill-prose form? Out of scope here; flagged for its own idea if wanted.
2. Should `write_ci` also emit the "refuse committed key material" step conditionally, or keep it
   unconditional as today? Not touched by this idea.
