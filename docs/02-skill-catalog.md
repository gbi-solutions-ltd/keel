# Skill Catalog

24 skills. Each row below is a build specification: the name, the trigger conditions that
go in the `description` frontmatter, what it reads, what it writes, and which of your 14
requirements it satisfies.

The count comes from `skills/`, which is the authority, and every skill in it has a section below.
That was not true until 0.5.0: `incident-response` shipped at 0.3.0 with no entry here, and the gap
survived two releases because nothing checked. The router, the shipped cheatsheet and the
SessionStart injection are now checked against `skills/` mechanically. **This file is not**, so it
stays a discipline: a skill added without a section here is a skill nobody can look up.

## A convention every skill obeys: checks must not be stricter than correct output

Five times during development a mechanical check flagged output that was correct:

| Check | What it wrongly rejected |
|---|---|
| "every requirement contains `must`" | `No token may be logged`, a correctly phrased prohibition |
| "no story title contains `and`" | `upload and download`, one story because shipping half delivers nothing |
| "every `Run:` command is in `profile.verify`" | A `grep` used to enumerate config defaults |
| "no file contains `docs/keel`" | Prose naming the default, and template header comments |
| The same `Run:` rule again, reintroduced in `execute-plan` | The same `grep` |

The pattern is always the same: a proxy for the real rule is easier to check than the rule, so
the proxy gets written down and then rejects valid work. The costs are asymmetric. A check that
is too loose misses a defect; a check that is too strict teaches people to ignore checks, and
that is unrecoverable.

**So: when a check disagrees with output you believe is correct, the check is wrong until proven
otherwise.** Fix the check, and add the case to `tests/validate-skills.sh` as a must-not-reject
test so it cannot regress. The validator already carries two such cases.

## Standards that cut across several skills

Four cross-cutting concerns live in `coding-standards`' references because more than one skill needs
them, and duplicating them would guarantee drift:

| Concern | Reference | Also read by |
|---|---|---|
| Logging, telemetry, traces | `references/observability.md` | `setup-deployment` when wiring the exporter, `debug` when reading an error log |
| Frontend components, theming, browser security | `references/frontend.md` | `review-code`, `security-audit`, `design-architecture` |
| GBi defaults: writing, secrets, errors, money, data, tests | `references/house-defaults.md` | every skill that writes code |
| Database-backed testing | `tdd/references/writing-good-tests.md` | `write-plan` when planning a `verify` story |

Two of these carry GBi-specific requirements worth naming here, because they are easy to miss:

**Error logs are written to be pasted into an agent CLI.** An `error` line names the failing
operation in domain terms, carries the identifiers needed to reproduce as fields, and includes a
`remediation` field naming the skill to use. Whoever is on call pastes the line and the right work
starts. A stable short string, not generated prose, so it stays greppable.

**Observability backend is configurable, defaulting to SigNoz.** `profile.observability.backend`
accepts `signoz`, `grafana`, `datadog`, or `none`. Instrumentation is OpenTelemetry regardless, so
the vendor sits behind the exporter and a switch is configuration rather than a rewrite.

## Coverage against your 14 requirements

| # | Requirement | Skills |
|---|-------------|--------|
| 1 | TDD | `tdd`, enforced by `execute-plan` |
| 2 | PRD generation, new and existing | `write-prd`, fed by `repo-snapshot` |
| 3 | Skill generation from good workflows | `create-skill` |
| 4 | Project documentation | `write-docs`, `write-plan`, `design-architecture` |
| 5 | Security aware development, audit before ship | `security-audit` + `security-guidance` plugin hooks + `ship` gate |
| 6 | Deployment setup | `setup-deployment` |
| 7 | Implementation plan execution | `execute-plan` |
| 8 | Debugging and root cause analysis | `debug` |
| 9 | Coding standards enforcement | `coding-standards` |
| 10 | Architecture and stack choices | `design-architecture` |
| 11 | Repository snapshots | `repo-snapshot` |
| 12 | Review, refactor, performance | `review-code`, `refactor`, `optimize-performance` |
| 13 | User stories from PRDs | `write-user-stories` |
| 14 | Memory optimization and prompt caching | `context-budget`, plus the design in doc 05 |

---

## 0. Router

### `keel`
**Trigger:** the user types `/keel`, says "keel", asks which skill fits, or starts substantive
work where no skill has been picked yet.
**Reads:** `.keel/profile.json`.
**Writes:** nothing.
**Does:** routes to one skill and stops. This is the only skill whose body is a table of
"if the request looks like X, invoke Y". Kept under 200 words because the `SessionStart`
hook injects a compressed version of it into every session.

Routing table lives in [`templates/prompting-cheatsheet.md`](../templates/prompting-cheatsheet.md),
which is the same content shipped to users so the routing rules and the user documentation
cannot drift apart.

---

## 1. Discover

### `repo-snapshot`
**Trigger:** "what is this repo", onboarding onto an unfamiliar codebase, before writing a
PRD for an existing system, or a periodic health check.
**Reads:** the codebase.
**Writes:** `<docs_root>/snapshot.md`.
**Does:** the ten-section analysis from `cursor-starter/documentation/repository-snapshot.md`:
overview, architecture, structure, features, dev setup, documentation assessment, missing
docs, technical debt, health metrics, prioritised recommendations.

**Two changes from the source prompt.** First, it dispatches parallel `Explore` subagents
per area (entry points, data layer, API surface, tests, CI, config) so the raw file reads
land in subagent context, not the main thread. On a large repo this is the difference
between a 200k-token session and a 30k-token one. Second, it ends by proposing
`.keel/profile.json` values it detected, so snapshot and init reinforce each other.

### `apex-export`
**Trigger:** an Oracle APEX application id arrives with a database connection, or someone asks to
read, export, or migrate an APEX application.
**Reads:** the APEX dictionary views, through `keel apex-export`.
**Writes:** `<docs_root>/apex/APP-<id>/`.
**Does:** probes the APEX version, asks the catalog which dictionary columns that version actually
has, selects the intersection, and writes one directory per page with the SQL and PL/SQL in their
own files beside a `page.md`. Plus `xref.tsv`, one line per database object use, which is the file
that makes the export worth producing: `grep TABLE_NAME xref.tsv` answers what a schema change
breaks.

**Why not the native export.** `f100.sql` is the obvious artifact and it is the wrong one. Every
reference in it is a 14 digit internal id, so grepping it for a table name finds nothing, and it
is routinely tens of megabytes. It is kept under `raw/` behind `--raw`, as something to diff
against when a rendered page and the truth disagree, and nothing reads it by default.

The dictionary views also need lower privileges than `APEX_EXPORT`: any schema associated with the
workspace can read them, where the export API wants `APEX_ADMINISTRATOR_ROLE`. Asking a client for
a read only user is a conversation that succeeds; asking for a DBA account is one that does not.

### `apex-port-plan`
**Trigger:** deciding whether or how to port an APEX application, or scoping the migration.
**Reads:** an export produced by `apex-export`.
**Writes:** `<docs_root>/apex/APP-<id>/PORT-ASSESSMENT.md`.
**Does:** dispatches six `Explore` agents over the export (data, logic, screens, auth,
integrations, gaps), challenges the difficulty bands the tool computed, and writes one assessment
that ends by routing to `write-prd`, `design-architecture`, or `write-plan`.

**The bands are deliberately arguable.** `apex-export` computes a per page score from component
counts and writes every contribution into `page.md` as a table. The skill's job is to revise them
against what the packages behind the page actually do, and to record each revision. A band that
nobody challenged is still a judgement, and the assessment says so rather than letting a computed
number pass as an assessed one.

### `write-prd`
**Trigger:** a product idea, a feature to specify, "write requirements", "we need a PRD",
or an existing PRD that needs improving.
**Reads:** `<docs_root>/snapshot.md` if present, existing PRD if refactoring.
**Writes:** `<docs_root>/prd/<slug>.md`.
**Does:** three modes, picked by what the user has.

| Mode | When | Source |
|------|------|--------|
| `from-idea` | rough idea, nothing written | `cursor-starter/planning/prd-from-idea.md` |
| `from-repo` | existing system, no PRD | snapshot plus code reading, reverse-engineers intent then confirms |
| `revise` | a PRD exists but is weak | `cursor-starter/planning/prd-refactor-existing.md` |

The third mode is `revise`, not `refactor`, so the mode name cannot be confused with the
`refactor` skill.

All three run the questionnaire first, one question per message, following the
`brainstorming` pattern from superpowers. The hard gate: no design or code until the user
has approved the PRD in writing.

Sections: executive summary, problem statement, vision and goals, users and personas,
functional requirements, non-functional requirements, technical constraints, UX
considerations, success metrics, milestones, assumptions, out of scope, open questions.

**Every requirement carries a stable ID and a status.** IDs (`FR-01`, `NFR-01`, `CON-01`) are
what `write-user-stories` traces to and what `write-plan` proves coverage against, so they are
not decoration. Status is `confirmed`, `inferred`, or `disputed`.

**In `from-repo` mode every requirement starts as `inferred`** and must be confirmed by the
user or left visibly inferred. This is the mode's whole value: what the code does and what the
product requires are different things, and a PRD that promotes an accident to a requirement is
worse than no PRD. The gap between the two is the deliverable.

---

## 2. Define

### `write-user-stories`
**Trigger:** a PRD exists and needs breaking down, "write user stories", "create tickets",
"break this into epics".
**Reads:** `<docs_root>/prd/<slug>.md`.
**Writes:** `<docs_root>/stories/<slug>.md`.
**Does:** epics, then features, then tasks. Every story carries: the `As a / I want / So that`
statement, Gherkin acceptance criteria, a size estimate, dependencies, and the PRD
requirement ID it traces to. That traceability field is what lets `write-plan` prove
coverage later.

### `design-architecture`
**Trigger:** "how should we build this", stack choice, system design, "what database",
service boundaries, or a significant structural change to an existing system.
**Reads:** PRD, stories, snapshot, `.keel/profile.json`.
**Writes:** `<docs_root>/architecture/<slug>.md` and one `<docs_root>/decisions/ADR-NNNN-<slug>.md`
per material choice.
**Does:** merges `architecture-design.md` and `tech-stack-selection.md` from cursor-starter,
because in practice they are one conversation. Produces:

- Context and container diagrams in mermaid (C4 levels 1 and 2)
- A sequence diagram per critical path
- Component responsibilities and interfaces
- Data model and storage choice with reasoning
- 2 to 3 candidate stacks with trade-offs, then a recommendation, never a silent pick
- Scalability, failure modes, and security architecture
- ADRs in the standard format: context, decision, status, consequences, alternatives rejected

**Plugin call:** consults `context7` for current library facts before recommending anything
with a fast-moving API surface. Recommending a version that no longer exists is the most
common failure mode here.

For an existing repo it must follow established patterns rather than propose a rewrite,
and any deviation gets its own ADR.

---

## 3. Plan

### `write-plan`
**Trigger:** an approved design or spec exists and work is about to start.
**Reads:** architecture doc, stories.
**Writes:** `<docs_root>/plans/YYYY-MM-DD-<slug>.md`.
**Does:** superpowers' `writing-plans`, near-verbatim, because it is the best version of
this that exists. Bite-sized steps of 2 to 5 minutes. Exact file paths. Real code in the
plan, never "add error handling here". Each task carries a `Consumes` and `Produces`
interface block so a task executed in isolation knows the signatures its neighbours use.

Every task follows the TDD five-step shape: write the failing test, run it and watch it
fail, write minimal code, run it and watch it pass, commit.

Each task also carries a `Depends on:` line, which is what lets `execute-plan` overlap work;
a plan may declare a batch of tasks as concurrent when the template's five conditions hold.

Ends with a self-review pass: does every story map to a task, are there placeholders left,
do the type names used in task 7 match what task 3 defined. Those four are mechanical and run
inline. A dispatched reviewer then covers what they cannot reach, because all four compare the
plan to itself and none of them opens the codebase the plan will be built on.

### `execute-plan`
**Trigger:** a plan file exists and the user says go.
**Reads:** the plan, `.keel/profile.json`.
**Writes:** code, commits, and checked boxes back into the plan file.
**Does:** two modes, one of them the default.

- **Delegated, the default:** a fresh subagent per task with two-stage review, spec compliance
  first, then code quality, from superpowers' `subagent-driven-development`. Implementation noise
  stays in subagents. Where the plan declares a concurrent batch, its tasks are dispatched
  together, each in its own worktree. The coordinator dispatches, reviews, ticks, commits and
  reports, and writes no production code at any size: both reviewers are fed the subagent's diff,
  so a coordinator's own edit is the only change in the run nobody reviews.
- **Inline:** executes tasks in the current session with a checkpoint after each. Right for
  small plans and when the user wants to watch, and taken by naming it and why, not by drifting.

Stops and asks rather than guessing when it hits a blocker, a failing verification it
cannot explain, or an instruction it does not understand. Never starts on `main`.

**REQUIRED SUB-SKILL:** `tdd` for every task, `debug` on any failure.

---

## 4. Build

### `tdd`
**Trigger:** implementing any feature or bugfix, before writing implementation code.
**Reads:** `.keel/profile.json` for `verify.test` and `verify.test_one`.
**Writes:** tests, then code.
**Does:** superpowers' `test-driven-development`, adapted to read the test command from the
profile instead of guessing. Keeps the iron law, the rationalisation table, and the red
flags list, all of which are load-bearing under pressure.

Adds one thing superpowers lacks: an explicit exception path. Throwaway spikes, generated
code, and pure config are exempt, but the exemption must be stated out loud and the spike
deleted before the real implementation starts.

### `coding-standards`
**Trigger:** "what are our conventions", a new contributor or a new service, review
feedback about style, or before the first commit in an unfamiliar repo.
**Reads:** the codebase, `.keel/profile.json`, existing lint and format configs.
**Writes:** `<docs_root>/standards.md`, and lint/format/hook config when missing.
**Does:** two distinct jobs.

1. **Derive.** Infer the repo's actual conventions from the code rather than imposing a
   generic style guide, then write them down. Naming, file layout, error handling, logging,
   test structure, commit format, dependency policy.
2. **Enforce.** Wire the mechanical parts into linters, formatters, and CI so they stop
   being a prompting problem. Anything a regex can check should never be a skill
   instruction. What remains in `standards.md` is only the judgement calls.

Also emits the GBi-wide defaults: conventional commits, no secrets in code, structured
logging, no `any` escape hatches without a comment explaining why.

### `debug`
**Trigger:** any bug, test failure, unexpected behaviour, performance anomaly, build
failure, or integration problem, before proposing any fix.
**Reads:** logs, stack traces, git history.
**Writes:** a failing test that reproduces the bug, then the fix.
**Does:** superpowers' four-phase `systematic-debugging`. Root cause investigation, pattern
analysis, single hypothesis and minimal test, then implementation. Iron law: no fixes
before investigation. Circuit breaker: after three failed fixes, stop and question the
architecture rather than attempting a fourth.

Includes the multi-component evidence-gathering technique, which is the highest-value part
for our services: instrument every boundary, run once, and let the evidence say which layer
broke instead of guessing.

**Plugin call:** when a language server plugin is installed, use its diagnostics and
find-references rather than grep. It is both faster and correct.

---

## 5. Verify

### `review-code`
**Trigger:** "review this", before opening a PR, after finishing a task, or on request for
a second opinion on a diff.
**Reads:** the diff, `<docs_root>/standards.md`, the plan if one exists.
**Writes:** findings, ranked by severity, and optionally applies fixes.
**Does:** delegates to the `code-review` plugin when installed, because its multi-agent
confidence-scored review beats a single inline pass. Falls back to an inline rubric
otherwise: correctness, standards conformance, test coverage and honesty, error handling,
performance, security, simplicity.

The GBi-specific additions the generic plugin will not know about: does the diff match the
plan, does every changed line trace to the request (Karpathy's surgical-changes test), and
were any tests written after the code.

### `security-audit`
**Trigger:** before shipping, "is this secure", any auth, payments, PII, secrets, or
external input work, on a schedule, or on request.
**Reads:** the diff or the whole repo, `.keel/profile.json`.
**Writes:** `<docs_root>/audits/YYYY-MM-DD-security.md`.
**Does:** two scopes.

- `--diff` (the default, and what the `ship` gate calls): only changed code. Fast enough to
  run on every PR.
- `--full`: the whole repo. Monthly, or on a new engagement.

Phases, ordered by where breaches actually come from: secrets in git history, dependency
and supply chain, CI/CD pipeline and env var exposure, then OWASP Top 10 against the code,
then a STRIDE threat model of the architecture, then auth and authorisation specifically.

Two rules that keep it useful rather than noisy: every finding needs a concrete exploit
scenario and a file:line, and findings below a confidence threshold are dropped rather than
listed as "consider reviewing". A report of forty maybes gets ignored; a report of three
real ones gets fixed.

**Plugin calls:** `security-guidance` for its hook-level coverage on every edit, and the
built-in `/security-review` command as a cross-check on the diff.

Given GBi is in payments, this skill also carries a payments-specific checklist: idempotency
on money-moving endpoints, webhook signature verification, amount and currency handling,
PII at rest and in logs, and audit trail completeness.

### `refactor`
**Trigger:** "clean this up", code that is hard to change, duplication, a file that has
grown too large, or preparation before adding a feature to messy code.
**Reads:** the target code, tests, `<docs_root>/standards.md`.
**Writes:** refactored code, same behaviour.
**Does:** the non-negotiable precondition first: tests must exist and pass before touching
anything. If they do not, write them first via `tdd`, and that is the whole task for now.
Then assess, propose a staged sequence with a commit per stage, and verify green after each.

Explicitly bounded by Karpathy's surgical-changes rule. Refactoring the file you were asked
about is the job; refactoring its neighbours is not.

### `optimize-performance`
**Trigger:** "this is slow", latency or throughput targets missed, high resource use, or a
performance regression.
**Reads:** the code, any profiling data, `.keel/profile.json`.
**Writes:** a benchmark, then the optimisation.
**Does:** measure first, always. The skill refuses to change code before a baseline exists,
because an unmeasured optimisation is a guess with extra steps. Sequence: reproduce, measure,
profile, find the actual bottleneck, form one hypothesis, change one thing, re-measure,
keep or revert.

Covers the layers from cursor-starter's performance prompt: query and index, N+1, caching
strategy and invalidation, payload size, concurrency, memory, and frontend bundle and render
cost where applicable.

---

## 6. Ship

### `setup-deployment`
**Trigger:** a new service with no pipeline, "add CI", "dockerise this", "how do we deploy",
or a deployment that needs fixing.
**Reads:** `.keel/profile.json`, architecture doc.
**Writes:** `.github/workflows/*.yml`, `Dockerfile`, `.dockerignore`, `compose.yaml`,
`.env.example`, `<docs_root>/runbooks/deploy.md`.
**Does:** a complete pipeline rather than a starting point. Build, test, lint, typecheck,
security scan, image build, push, deploy per environment, smoke test, rollback procedure.

Environment and secrets handling is the part most teams get wrong, so it is explicit:
what lives in env vars, what lives in the secret manager, what is safe to log, and how a
new environment gets provisioned.

The runbook is a deliverable, not an afterthought. It covers deploying, rolling back,
reading logs, common failures, and who to call.

### `ship`
**Trigger:** "ship it", "open a PR", "let's land this", work believed complete.
**Reads:** everything.
**Writes:** a commit, a branch, a PR.
**Does:** a gate, not a convenience. It runs the checklist and refuses to open a PR while
anything is red.

1. All tests pass, and new code has new tests
2. Lint, format, and typecheck clean
3. `security-audit --diff` clean, or findings explicitly accepted by the user
4. `review-code` run and blocking findings resolved
5. Docs updated when behaviour changed
6. Plan checkboxes all ticked, or the remainder explicitly deferred
7. Commit message follows the convention, with no attribution footers

Then it writes a PR body from the plan and the diff: what changed, why, how it was tested,
risk, and rollback.

---

## 7. Document

### `write-docs`
**Trigger:** "write the README", "document this", onboarding material, a runbook, an API
reference, or a process flow diagram.
**Reads:** the codebase and every artifact in `<docs_root>/`.
**Writes:** depends on the document type.
**Does:** one skill covering six document types, because they share the same research step
and differ only in output shape.

| Type | Output | Notes |
|------|--------|-------|
| README | `README.md` | From `cursor-starter/documentation/readme-generator.md`. Quickstart must be verified by actually running it |
| Runbook | `<docs_root>/runbooks/<topic>.md` | Operational, written for 3am. Symptoms, diagnosis, actions, escalation |
| Process flow | mermaid in the relevant doc | Sequence, flowchart, state, and ER diagrams. Every non-trivial flow gets one |
| API reference | `<docs_root>/api/` | Generated from code and OpenAPI where possible, hand-written only where not |
| ADR | `<docs_root>/decisions/ADR-NNNN-*.md` | Also written by `design-architecture` |
| Onboarding | `<docs_root>/onboarding.md` | Built on top of `repo-snapshot` output |

Diagrams are mermaid, always, because they render in GitHub and GitLab, they diff as text,
and the model writes them reliably. No image files.

A generator is preferred wherever one exists: OpenAPI from the framework's decorators, code docs
from JSDoc or docstrings, release notes from Conventional Commits. Hand-written prose covers only
what no generator can produce.

Every document states the current state rather than the review history that produced it.
`references/current-state-prose.md` carries the tells and the rewrites, and section 8 of
`review-code`'s rubric checks a diff for them.

---

## 8. Meta

### `create-skill`
**Trigger:** a workflow just went well and should be repeatable, "make this a skill",
"we do this every time", or a recurring correction the user is tired of making.
**Reads:** the session transcript.
**Writes:** a new skill directory in the keel repo, as a branch and a PR.
**Does:** superpowers' `writing-skills` discipline, which is TDD applied to process docs.

1. Establish the baseline. Run the scenario against a subagent **without** the skill and
   record exactly how it fails, and what it says while rationalising.
2. Write the minimum skill that addresses those specific failures.
3. Re-run. The subagent should now comply.
4. Close the loopholes the re-run exposes, and repeat.

The rule that saves the most pain: match the form to the failure. A discipline failure,
where the model knows the rule and skips it under pressure, needs prohibitions plus a
rationalisation table. A shaping failure, where the output has the wrong structure, needs a
positive recipe instead, and prohibitions actively make it worse.

**Plugin call:** hands off to `skill-creator` for its eval harness, variance benchmarking,
and packaging scripts. Our skill owns the capture and the authoring discipline; theirs owns
the measurement.

### `context-budget`
**Trigger:** long sessions, repeated compaction, "this is using too many tokens", a slow or
forgetful session, or a periodic audit.
**Reads:** `CLAUDE.md`, `.claude/settings.json`, `.keel/`, skill sizes.
**Writes:** `<docs_root>/context-audit.md`, and fixes.
**Does:** the practices in [doc 05](05-token-and-memory-design.md). Measures what is in the
always-loaded prefix, flags anything volatile that breaks the prompt cache, checks skill
bodies against the word budget, finds `@` links that force-load, and proposes moving
detail from `CLAUDE.md` into on-demand skills or `<docs_root>/`. Also empties `.keel/handoff.md`
before it is discarded, since that file is git-ignored and anything durable left in it is lost.

**Plugin call:** `claude-md-management` for its CLAUDE.md quality rubric.

### `incident-response`
**Trigger:** production is broken now, an outage is in progress, customers are affected, or the
user is on call and does not know where to start. Fires before `debug`.
**Reads:** `<docs_root>/runbooks/`, logs, dashboards, the recent deploy history.
**Writes:** `<docs_root>/audits/` incident record, opened during the incident rather than after.
**Does:** inverts `debug` deliberately. Restoring outranks explaining, so it acts on the most
reversible route available before the cause is known, opens the record in the first two minutes,
reconciles before any bulk retry, and hands off to `debug` for the root cause once service is back.

**Why it exists.** Produced by `create-skill`, and its baseline **did not fail** at the thing it was
going to teach: a capable agent already rolled back competently. What the baseline lacked was
anything durable written down, any use of the runbook that existed, and any handoff to a root cause
analysis. The skill is written around those three, which is why it is mostly about the record and the
handoff rather than about restoring.

### `shape-idea`
**Trigger:** a rough idea, "help me think this through", "is this worth building", or a
solution described with no problem stated.
**Reads:** the code and docs that bear on the idea. Delegates wide reading.
**Writes:** `<docs_root>/ideas/<slug>.md`.
**Does:** finds the problem under the proposed solution, checks the idea against the system
with citations, then writes the case against it before any recommendation: the strongest
argument for not building it, alternatives including doing nothing, and the assumptions it
rests on. Ends on one recommendation and stops. `write-prd --from-idea` reads the record and
asks nothing it settles.

**Why it exists.** A baseline pushed back well without any skill, so the skill is not about
teaching pushback. It is about the four things the baseline did badly: it wrote nothing
durable, it produced a sprint plan for an idea with no requirements, it asked five questions
in one closing wall, and it deliberately buried its own strongest objection inside the plan.
Its own words: "opening by dismissing the premise tends to end the conversation instead of
improving the idea."

### `port-assess`
**Trigger:** "should we port this service", scoping a rewrite, moving off a stack, or wanting
the risks of a migration before committing. For Oracle APEX, `apex-port-plan` instead.
**Reads:** `<docs_root>/snapshot.md` and the codebase. One `Explore` agent per concern.
**Writes:** `<docs_root>/port/<service>-assessment.md`.
**Does:** proves the snapshot describes the checked-out tree before anything else, names every
part of the target stack with no source to port from, verifies wire-format claims by running
both sides and diffing, then sweeps a second time for inputs nothing opened and records that
ledger in the document. Every claim marked verified, inferred or estimated.

**Why each step exists.** All four came from runs, not from design. A baseline read a snapshot
describing a different branch. "Port to NestJS and React" was put to a service with no UI at
all. The obvious Node replacement for a Java serialiser dropped null fields, producing
identical meaning, different bytes, and a rejected signature on every request with an absent
optional field. And two separate runs judged a document from a grep count or its filename, then
said so afterwards, unprompted.
