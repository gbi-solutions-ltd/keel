# Sources and attribution

keel is assembled from four open source projects, all MIT licensed. Some of our skills are
close adaptations of theirs; others take only a structural idea. This file records which is
which, per source and per file, so the obligation is discharged precisely rather than by a
blanket credit.

Attribution lives here and in `THIRD-PARTY-LICENSES.md`, which is what discharges the MIT notice
requirement. It is **not** repeated in each `SKILL.md`: this file claimed a source trailer in every
close adaptation until 2026-08-17, and there has never been one in any of the five. The reference
files adapted directly from an upstream document do name it in their first line, which is where the
borrowing is most concrete.

---

## superpowers

- Repository: https://github.com/obra/superpowers
- Author: Jesse Vincent and Prime Radiant
- Licence: MIT, Copyright (c) 2025 Jesse Vincent
- Version referenced: 6.2.0

The largest single influence. What we take:

| Ours | Theirs | Relationship |
|---|---|---|
| `skills/tdd` | `test-driven-development` | Close adaptation. Iron law, RED-GREEN-REFACTOR, rationalisation table, red flags. Changed to read `verify.test` from `.keel/profile.json`, and to add an explicit stated-exception path for spikes |
| `skills/debug` | `systematic-debugging` | Close adaptation. Four phases, three-fix circuit breaker, boundary instrumentation, root cause tracing |
| `skills/write-plan` | `writing-plans` | Close adaptation. Bite-sized steps, interface blocks, no-placeholders rule, self-review |
| `skills/execute-plan` | `executing-plans`, `subagent-driven-development` | Adaptation of both, merged into inline and delegated modes |
| `skills/create-skill` | `writing-skills` | Close adaptation. TDD-for-skills, match-the-form-to-the-failure, bulletproofing |
| Every `SKILL.md` in this repo | `writing-skills` | Structural. The frontmatter discipline (description states when to use and never summarises the workflow), the word budget, the prohibition on `@` links, and progressive disclosure into `references/` |
| `hooks/session-start` | their `hooks/session-start` | Structural only. We inject a much smaller static payload and deliberately avoid their dynamic content, for prompt-cache reasons documented in `docs/05-token-and-memory-design.md` |

## andrej-karpathy-skills

- Repository: https://github.com/forrestchang/andrej-karpathy-skills
- Author: forrestchang, deriving the principles from Andrej Karpathy's observations
- Licence: MIT

| Ours | Theirs | Relationship |
|---|---|---|
| `templates/project-claude-md-block.md` | `CLAUDE.md`, `skills/karpathy-guidelines` | Close adaptation of the four principles: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution. Reworded and compressed to fit a 450 token budget, and merged with our verify-command and artifact-location sections |

The surgical-changes test ("every changed line should trace directly to the request") is also
carried into `skills/review-code` and `skills/refactor` as an explicit check.

## cursor-starter

- Repository: cursor-starter, a collection of Cursor AI prompts
- Licence: MIT, stated in the project README. Note there is no `LICENSE` file in the
  distribution we worked from, only the README statement
- Provides prompt content rather than skill mechanics

| Ours | Theirs | Relationship |
|---|---|---|
| `skills/repo-snapshot` | `documentation/repository-snapshot.md` | Section structure adapted. We added the evidence rules, the health rubric with `measured`/`estimated`/`unmeasured` tags, subagent delegation, the verification step, and dropped their overall score out of 10 |
| `skills/write-prd` | `planning/prd-from-idea.md`, `prd-questionnaire.md`, `prd-refactor-existing.md` | Three modes adapted from their three prompts |
| `skills/write-user-stories` | `planning/user-stories.md` | Adapted, plus PRD requirement traceability |
| `skills/design-architecture` | `planning/architecture-design.md`, `tech-stack-selection.md` | Merged into one skill, plus mermaid C4 diagrams and ADRs |
| `skills/review-code` | `development/code-review.md` | Rubric adapted |
| `skills/refactor` | `development/refactoring-assistant.md` | Adapted, plus the tests-must-pass-first precondition |
| `skills/optimize-performance` | `development/performance-optimization.md` | Adapted, plus the measure-before-changing precondition |
| `skills/debug` | `development/debugging-assistant.md` | Secondary influence; the primary is superpowers |
| `skills/security-audit` | `maintenance/security-audit.md` | Adapted, plus STRIDE, a confidence gate, and a payments checklist |
| `skills/setup-deployment` | `deployment/cicd-setup.md`, `environment-configuration.md` | Adapted |
| `skills/write-docs` | `documentation/readme-generator.md` | README mode adapted |
| `skills/tdd` | `testing/test-generation.md`, `integration-testing.md`, `e2e-testing.md` | Secondary influence on test-design guidance |

## gstack

- Repository: https://github.com/garrytan/gstack
- Author: Garry Tan
- Licence: MIT, Copyright (c) 2026 Garry Tan

We take no content from gstack, only structural decisions. Recorded because the decisions are
load-bearing and the influence should be visible:

| Ours | Theirs | Relationship |
|---|---|---|
| Distribution model | their install and team mode | Structural. Skills live once in the plugin, never vendored into a project, so upgrading upgrades every repo. This is the single most important structural choice in keel and it is theirs |
| `skills/keel` router | their `SKILL.md` router | Structural. A thin skill whose only job is to route to the right skill |
| Token tiering in `docs/05` | their `preamble-tier` system | Structural, and partly a reaction against it. We adopted the idea of tiering what loads; we rejected their dynamic session-start injection because it invalidates the prompt cache every session |

We deliberately did not adopt their browser daemon, telemetry, or template-to-SKILL.md build
step. Reasoning is in `docs/01-architecture.md` under "What we deliberately leave out".

---

## Our own work

**Skills with no upstream at all.** Listed by name rather than left to "everything not above", so a
reader can tell an original skill from an adaptation nobody credited. Each of these was written here,
against a real repository:

| Ours | Why there is no source to credit |
|---|---|
| `skills/coding-standards` | Prompt content from `cursor-starter` is credited above; the ten topic references, the derive-then-split mechanic, and the counting rule are ours |
| `skills/context-budget` | Follows from the prompt-cache analysis in `docs/05`, which is ours |
| `skills/ship` | The gate list, the PR body assembled from the plan and the diff, and the override-recording rule are ours. `superpowers` has no equivalent skill and `cursor-starter` no equivalent prompt |
| `skills/incident-response` | Produced by `create-skill`, baseline first. Written around what its baseline lacked, which was anything durable and any handoff to a root cause |
| `skills/apex-export` | No upstream exists. Reads the APEX dictionary views rather than the native export |
| `skills/apex-port-plan` | Same engagement, same absence of any upstream |
| `skills/shape-idea` | Produced by `create-skill`. Its baseline pushed back well without any skill, so the content is the four things that baseline did badly, not the pushback |
| `skills/port-assess` | Produced by `create-skill`. Every step came from an observed failure in a baseline run against a real service |

**Everything else that is ours:** the `.keel/profile.json` contract and the practice of skills
reading verify commands from it rather than guessing; the artifact chain and its `<docs_root>`
layout; the hooks-over-instructions split; the prompt-cache constraints and token budgets in
`docs/05`; the verification step and evidence rules in `repo-snapshot`; the gitignored-docs guard;
the supply chain scan and the push guard; the context watchdog; and the plugin assessment in
`docs/04`.

## Licence of this work

Chosen 2026-08-17: MIT, replacing the proprietary all-rights-reserved notice this file used to
record. The reasoning is that roughly a third of the skill set is adapted from four MIT projects, so a
permissive licence is the honest match, and a public repository under an all-rights-reserved notice is
source nobody may legally use. Relicensing keel relicenses only keel: the adapted portions keep their
own notices. See `LICENSE`, and `THIRD-PARTY-LICENSES.md`, which reproduces the MIT notices verbatim,
since crediting a source in this file does not on its own discharge the MIT obligation.
