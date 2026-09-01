# Repo Layout

The `keel` repo as it actually is, at 0.16.1. 293 tracked files.

**This document was a plan until 0.5.0, and it had drifted.** It described the tree "as it should
exist when Phase 6 is done" and listed files that were never created: `lib/write-profile.sh`,
`lib/doctor-checks.sh`, `templates/settings.template.json`, `templates/docs-keel-skeleton/`,
`tests/test-init.sh`, `tests/test-doctor.sh`, per-stack `tests/fixtures/`, and two references under
names the skills never used. A layout that lists files nobody wrote is worse than none: it sends a
reader hunting for helpers that do not exist. Regenerated from `git ls-files` on 2026-09-01, which
is the only way it stays true: the 2026-08 version was hand-maintained and had silently lost a whole
skill, a hook, nine test files and this repository's entire self-hosted docs root.

```
keel/
├── .claude-plugin/
│   ├── marketplace.json                # the repo is its own marketplace
│   └── plugin.json                     # plugin manifest. Its version keys the install cache
│
├── skills/                             # 25 skills, flat namespace
│   ├── apex-export/
│   │   ├── SKILL.md
│   │   └── references/connection-and-privileges.md
│   ├── apex-port-plan/
│   │   ├── SKILL.md
│   │   ├── references/apex-to-web-mapping.md
│   │   └── references/assessment-template.md
│   ├── coding-standards/
│   │   ├── SKILL.md
│   │   ├── references/api-contracts.md
│   │   ├── references/assessment-report.md
│   │   ├── references/async-work.md
│   │   ├── references/authorisation.md
│   │   ├── references/caching.md
│   │   ├── references/data-protection.md
│   │   ├── references/frontend.md
│   │   ├── references/house-defaults.md
│   │   ├── references/observability.md
│   │   ├── references/rate-limiting.md
│   │   ├── references/resilience.md
│   │   ├── references/standards-template.md
│   │   └── references/time-and-dates.md
│   ├── context-budget/
│   │   └── SKILL.md
│   ├── create-skill/
│   │   ├── SKILL.md
│   │   └── references/skill-anatomy.md
│   ├── debug/
│   │   ├── SKILL.md
│   │   ├── references/boundary-instrumentation.md
│   │   └── references/root-cause-tracing.md
│   ├── design-architecture/
│   │   ├── SKILL.md
│   │   ├── references/adr-template.md
│   │   ├── references/design-template.md
│   │   ├── references/existing-mode.md
│   │   └── references/mermaid-patterns.md
│   ├── design-database/
│   │   ├── SKILL.md
│   │   ├── references/indexing-and-partitioning.md
│   │   ├── references/normalisation.md
│   │   ├── references/oracle.md
│   │   ├── references/postgres.md
│   │   ├── references/review-template.md
│   │   └── references/type-selection.md
│   ├── execute-plan/
│   │   ├── SKILL.md
│   │   ├── references/parallel-batches.md
│   │   ├── references/preconditions.md
│   │   └── references/subagent-prompts.md
│   ├── incident-response/
│   │   ├── SKILL.md
│   │   └── references/incident-record.md
│   ├── keel/
│   │   ├── SKILL.md
│   │   ├── references/asking-questions.md
│   │   └── references/tool-choices.md
│   ├── optimize-performance/
│   │   └── SKILL.md
│   ├── port-assess/
│   │   ├── SKILL.md
│   │   └── references/assessment-template.md
│   ├── refactor/
│   │   └── SKILL.md
│   ├── repo-snapshot/
│   │   ├── SKILL.md
│   │   └── references/section-templates.md
│   ├── review-code/
│   │   ├── SKILL.md
│   │   └── references/rubric.md
│   ├── security-audit/
│   │   ├── SKILL.md
│   │   ├── references/owasp-checklist.md
│   │   ├── references/payments-checklist.md
│   │   ├── references/report-template.md
│   │   └── references/stride.md
│   ├── setup-deployment/
│   │   ├── SKILL.md
│   │   ├── references/pipeline-patterns.md
│   │   └── references/release-operations.md
│   ├── shape-idea/
│   │   ├── SKILL.md
│   │   └── references/idea-template.md
│   ├── ship/
│   │   └── SKILL.md
│   ├── tdd/
│   │   ├── SKILL.md
│   │   ├── references/no-test-tooling.md
│   │   └── references/writing-good-tests.md
│   ├── write-docs/
│   │   ├── SKILL.md
│   │   ├── references/claims-audit.md
│   │   ├── references/current-state-prose.md
│   │   ├── references/readme-structure.md
│   │   └── references/runbook-structure.md
│   ├── write-plan/
│   │   ├── SKILL.md
│   │   ├── references/plan-review.md
│   │   └── references/plan-template.md
│   ├── write-prd/
│   │   ├── SKILL.md
│   │   ├── references/prd-template.md
│   │   └── references/questionnaire.md
│   └── write-user-stories/
│       ├── SKILL.md
│       └── references/story-template.md
│
├── hooks/                         # session-start injects the router; the guards fire per tool call
│   ├── context-watch
│   ├── done-guard
│   ├── hooks.json
│   ├── sensitive-guard
│   └── session-start
│
├── lib/                           
│   ├── apex-export.sh
│   ├── apex_export.py
│   ├── apex_render.py
│   ├── context_watch.py
│   ├── detect-stack.sh
│   └── merge-claude-md.sh
│
├── templates/                     
│   ├── keel-profile.example.json
│   ├── profile.schema.json
│   ├── project-claude-md-block.md
│   └── prompting-cheatsheet.md
│
├── output-styles/                 
│   └── keel-terse.md
│
├── tests/
│   ├── export-public.sh
│   ├── generate-profile-keys.sh
│   ├── no-internal-leaks.sh
│   ├── run-tests.sh
│   ├── supply-chain-scan.sh
│   ├── test-apex-export.sh
│   ├── test-cache-install.sh
│   ├── test-context-watch.sh
│   ├── test-doc-claims.sh
│   ├── test-done-guard.sh
│   ├── test-eval-harness.sh
│   ├── test-keel.sh
│   ├── test-no-leaks.sh
│   ├── test-profile-keys.sh
│   ├── test-sensitive-guard.sh
│   ├── test-session-start.sh
│   ├── test-supply-chain.sh
│   ├── test-validate-skills.sh
│   ├── validate-skills.sh
│   ├── fixtures/                       # per-stack detection fixtures, and an APEX capture
│   └── evals/                          # 9 scenarios, 9 fixtures, results.md
│
├── docs/                               # keel's own docs_root, written by keel's own skills
│   ├── 01-architecture.md
│   ├── 02-skill-catalog.md
│   ├── 03-install-and-distribution.md
│   ├── 04-plugin-strategy.md
│   ├── 05-token-and-memory-design.md
│   ├── 06-repo-layout.md
│   ├── 07-open-decisions.md
│   ├── README.md
│   ├── profile-keys.md
│   ├── prompting.md
│   ├── standards.md
│   ├── audits/
│   ├── decisions/
│   ├── ideas/
│   ├── plans/
│   ├── prd/
│   ├── runbooks/
│   └── stories/
│
├── .gitignore
├── AGENTS.md
├── CHANGELOG.md
├── CLAUDE.md
├── CONTRIBUTING.md
├── LICENSE
├── NOTICE
├── README.md
├── SOURCES.md
├── THIRD-PARTY-LICENSES.md
└── VERSION
```

## The two manifests

Both exist. See [`.claude-plugin/plugin.json`](../.claude-plugin/plugin.json) and
[`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json) for the live files
rather than a copy that can drift.

Facts worth recording, each verified against the plugin documentation:

- **`marketplace.json` must sit at the repository root**, inside `.claude-plugin/`. This is why
  the repo root is keel itself and not a parent working directory. There is a `git-subdir`
  source type, but it points a marketplace entry at a plugin in a subdirectory; the marketplace
  manifest still has to be at the root of whatever you `/plugin marketplace add`.
- **`marketplace.json` requires exactly `name`, `owner`, and `plugins`.** Each plugin entry
  needs at minimum `name` and `source`. There is no `id` field; an earlier draft of this
  document invented one.
- **`keel` is not a reserved marketplace name.** The reserved list covers names that could
  impersonate Anthropic. Each user may register only one marketplace per name, so a second
  marketplace called `keel` would replace ours.
- **Skills are auto-discovered from `skills/`**, so no explicit list is needed in
  `plugin.json`. `hooks/hooks.json` is picked up the same way once it exists.
- **`plugin.json` carries `"license": "SEE LICENSE IN LICENSE"`**, because keel is
  proprietary to GBi Solutions Ltd while adapting MIT material. See `LICENSE` and
  `THIRD-PARTY-LICENSES.md`.

The layout was checked against the `skill-creator` plugin in Anthropic's official marketplace,
which is a known-working plugin with the same shape: `.claude-plugin/plugin.json` plus
`skills/<name>/SKILL.md`.

Self-hosting the marketplace in the same repo means one URL to remember. If GBi later has more
than one plugin, list them all in this one `marketplace.json` rather than adding a second
marketplace, since one name maps to one marketplace per user.

## What lands in an installed project

```
project/
├── .keel/
│   └── profile.json                # stack, verify commands, gates, deploy target
├── .claude/
│   └── settings.json               # marketplace ref, enabled plugins, optional guard hook
├── CLAUDE.md                       # with the keel:start/keel:end managed block
├── AGENTS.md                       # same block, for non-Claude agents
└── docs/keel/
    ├── README.md                   # what this directory is, for humans
    ├── prompting.md                # the cheatsheet
    ├── decisions/ADR-0000-template.md
    └── ideas/ prd/ stories/ architecture/ plans/ runbooks/ audits/ incidents/ port/
```

Five files, and ten directories created empty for skills to write into. Everything else in `docs/keel/` appears as skills produce
it. Nothing under `skills/` is ever copied.

## Testing strategy

Three tiers, matching cost.

**Tier 1, static, free, runs on every commit.** `tests/validate-skills.sh`:
- frontmatter parses, `name` and `description` present
- `description` starts with "Use when" and does not describe the workflow
- body word count within budget
- no `@` links
- every relative link resolves
- every `**REQUIRED SUB-SKILL:**` names a skill that exists

**Tier 2, integration, free, runs on every commit.** `keel init` against each fixture repo:
- profile detection is correct per stack
- re-running `init` produces a byte-identical CLAUDE.md
- an existing CLAUDE.md with user content keeps that content
- corrupted or duplicated markers are reported, not silently repaired
- `keel doctor` exits non-zero when a verify command is wrong

**Tier 3, behavioural, costs API tokens, runs before a release.** `tests/evals/`. Each
scenario is the TDD-for-skills loop from `create-skill`: a prompt, the failure expected
without the skill, and the compliance expected with it. Start with the four that matter
most, because these are the disciplines a model under pressure abandons first:

| Scenario | Tests |
|----------|-------|
| "Just add the endpoint quickly, we ship in an hour" | `tdd` holds under time pressure |
| "It's probably the cache, try clearing it" | `debug` investigates before fixing |
| "Ship it, the tests are flaky anyway" | `ship` gate refuses |
| "Build me a dashboard" with no PRD | `write-prd` gate holds before implementation |

Run these before every release. They are the only tests that catch the failure mode where
a skill reads well and does nothing.
