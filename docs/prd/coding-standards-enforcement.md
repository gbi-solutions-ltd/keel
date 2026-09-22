# PRD: Coding standards enforcement

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Claude (session with Bernard) |
| Date | 2026-09-21 |
| Derived from | `docs/ideas/standards-that-bind.md` (2026-09-01, most recent finding 2026-09-19), this conversation, and direct reading of `bin/keel`, `lib/harness/claude.sh`, `lib/detect-stack.sh`, `skills/ship/SKILL.md`, `skills/review-code/SKILL.md`, `skills/coding-standards/SKILL.md`, `skills/repo-snapshot/SKILL.md`, `skills/execute-plan/references/subagent-prompts.md`, `templates/profile.schema.json` |
| Approved by | Bernard, 2026-09-21 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

Of 12 requirements below (FR-01 through FR-11, NFR-01), 4 are confirmed from the user's own words
or decisions this session (FR-04, FR-05, FR-06, FR-11), 4 are inferred from established keel
conventions (FR-02, FR-03, FR-07, NFR-01), and 4 are author-added (FR-01, FR-08, FR-09, FR-10).

## 1. Executive summary

`gates.coding_standards` is declared in every project's profile and enforces nothing:
`templates/profile.schema.json:283` says so of itself. Of the 81 individual rules in
`skills/coding-standards/references/`, 33 are checked by `review-code`'s rubric, and again per-task
by `execute-plan`'s own quality review, but classified `Should fix`, not `Blocking`, so they never
stop a ship or a tick; the other 48 have no check at all. This PRD wires `gates.coding_standards`
to something real, at three points: it makes a `required` project's ship gate actually refuse on
an unaddressed standards violation, it makes `execute-plan` refuse to tick a task over an
unaddressed `Blocking` quality finding the same way it already refuses over a failed spec-compliance
review, it ships lint- and CI-level config for the handful of rules that are genuinely mechanical,
and it makes `repo-snapshot` surface a standards gap during onboarding instead of staying silent
about one the way it does today.

## 2. Problem statement

The user asked for confirmation that coding standards can be enforced and, where possible, that
they are difficult to violate. Investigated directly this session: they cannot be, and are not.

`docs/profile-keys.md:54`, verbatim, about `gates.coding_standards`: "No skill, hook or CLI path
is written to read it, so nothing in keel enforces it." Grepped to confirm this is still true: the
key's only appearance in `bin/keel` is inside the pre-push hook's loosening-check, which protects
the *value* from being silently weakened on a push, and it never gates the code's content.

`skills/ship/SKILL.md:26` already says "`review-code` has run and nothing blocking remains," and
`review-code` already runs unconditionally inside `ship` (schema 4 retired the standalone
`gates.review` flag for exactly this reason). But `skills/review-code/SKILL.md:61-63` defines
`Should fix` to explicitly include "violates a standard," separately from `Blocking` ("wrong
behaviour, a security defect, data loss, or an unmet requirement"). So a pure standards violation
that `review-code`'s rubric catches is reported, never blocking, regardless of what
`gates.coding_standards` says. Confirmed this session by dispatching a real `review-code` run
against a manufactured diff in a real repository (`agroplex-express-api`): it correctly found and
reported a hand-rolled-rate-limiter-instead-of-reusing-the-existing-store finding, tagged
`Should-fix`, not `Blocking`.

The same shape recurs one level earlier, inside `execute-plan`'s own delegated loop.
`skills/execute-plan/references/subagent-prompts.md:108-125` already dispatches a per-task code
quality review carrying the same `PROJECT STANDARDS` block and the same
`Blocking`/`Should fix`/`Consider` vocabulary, on every task, not only at final ship. But
`:145-165` ("Running the loop") states in full what a `DEVIATES` verdict from the *other* review
pass requires (discard, re-dispatch, never tick) and says nothing about what a `Blocking` quality
finding requires before the coordinator ticks the box and commits.

Separately, `skills/coding-standards/SKILL.md:16-24` already has a working "assess" mode
(`references/assess.md`) for checking code against an existing `standards.md`, built and shipped
for a prior gap in this same idea record. `skills/repo-snapshot/SKILL.md` (grepped, zero
mentions of `coding-standards` or `assess` anywhere in the file) does not call it, despite both
skills' own descriptions naming "onboarding onto an unfamiliar codebase" as a trigger.

## 3. Goals and non-goals

**Goals**

- A project with `gates.coding_standards: required` cannot ship (via `keel:ship`) while an
  unaddressed standards-violation finding from `review-code` remains.
- `execute-plan` cannot tick a task, in delegated mode, while an unaddressed `Blocking` finding
  from that task's own code quality review remains.
- The handful of coding-standards rules that are genuinely mechanical (a lint flag, a type-checker
  flag, a CI step) are enforced pre-commit via config `keel init` merges into the project, not only
  caught at review time.
- `repo-snapshot` reports whether the project's code follows its own `standards.md`, using the
  assessment mode that already exists, instead of never mentioning it.

**Non-goals**

- Building typed/structural ("impossible to violate") enforcement. Zero of 81 rules are there
  today and this PRD does not change that; it is a separate, much larger effort the idea record
  already declined to size here.
- A new git-hook mechanism separate from `keel guard install`'s existing pre-commit/pre-push hooks.
- Changing `gates.commit_guard`'s default value (`off`, written by `keel init`). This PRD makes
  `required` mean something real when a project chooses it; it does not choose it for them.
- Covering all 8 of the mechanically-shaped rules the idea record's 2026-09-19 finding named, or
  every stack `keel` detects. See Out of scope.

## 4. Users and personas

Three, all people already using keel-managed projects:

- **The project owner who sets `gates.coding_standards: required`** and currently gets nothing for
  it. They want the setting to mean what its name says.
- **The coordinator running `execute-plan`**, who today can tick and commit a task over an
  unaddressed `Blocking` standards finding from that task's own quality review, because nothing
  says not to.
- **An engineer onboarding onto an existing project via `repo-snapshot`**, who today has no way to
  learn from the snapshot itself whether the code the project claims to follow a standard for
  actually does.

## 5. Functional requirements

### Gate enforcement in `ship`

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | When `gates.coding_standards` is `required`, `keel:ship`'s Step 5 must refuse to complete while `review-code` has reported an unaddressed finding tagged as a standards violation, in addition to its existing refusal on `Blocking` findings. | author-added | `skills/ship/SKILL.md:26`, `skills/review-code/SKILL.md:61-63`; confirmed by this session's dispatch that a standards-only finding is classified `Should-fix` today and does not block |
| FR-02 | When `gates.coding_standards` is `warn`, `ship` must report an unaddressed standards-violation finding without refusing. | inferred | Matches the `required`/`warn`/`off` vocabulary every other gate in `templates/profile.schema.json` already uses (e.g. `security_audit`, `commit_guard`) |
| FR-03 | When `gates.coding_standards` is `off`, `ship`'s gate behaves exactly as it does today: no additional check. | inferred | Same vocabulary; `off` already means "skip" for every existing gate |
| FR-04 | A `Should fix` finding from `review-code` counts as a standards violation for FR-01/FR-02 when its citation names a file under `skills/coding-standards/references/`. No new field on the finding; inferred from the citation at `ship` time. | confirmed | Bernard, 2026-09-21 (Q2). This session's own dispatched review already cited the specific reference file per rubric-sourced finding (e.g. "See `caching.md`"), so the information already exists in the finding's prose |

### Plan-time enforcement, in `execute-plan`

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-11 | `execute-plan`'s delegated loop must treat a `Blocking` finding from the per-task code-quality review the same way it already treats a `DEVIATES` verdict from the spec-compliance review: the task is not ticked or committed until the finding is resolved, or the user explicitly accepts it. | confirmed | Bernard, 2026-09-21, proposing plan-time enforcement directly, confirmed as in-scope for this PRD. `skills/execute-plan/references/subagent-prompts.md:108-125` (the quality review already receives the `PROJECT STANDARDS` block and produces `Blocking`/`Should fix`/`Consider` findings, on every task); `:145-165` ("Running the loop") states the `DEVIATES` handling in full and says nothing about what a `Blocking` quality finding requires before ticking |

This is the cheapest of the three enforcement points in this PRD: the review dispatch, the
standards block, and the severity vocabulary all already exist per-task; only the *handling* of a
`Blocking` verdict is missing. It complements FR-01 rather than replacing it: work that never goes
through a formal plan (a direct edit, a small fix) still only meets `gates.coding_standards` at
`ship`.

### Mechanical rules, shipped as config

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-05 | `keel init` must, for a TypeScript project, merge the strict-mode compiler flags named in `skills/coding-standards/references/*.md`'s "strict type-checking flags" rule into `tsconfig.json`, without removing or overriding a flag the project has already set differently. | confirmed | User, this session: "I would be agreeable to keel shipping lint config that's compatible with the repo... You can recommend as you see fit," and confirmed as the v1 pair, 2026-09-21 (Q1). `lib/detect-stack.sh` (grepped) only detects existing lint/type-check tooling today, never writes rule content |
| FR-06 | `keel init`'s generated CI workflow (`write_ci`, `bin/keel:1188`) must add a dependency audit-scan step ("lockfile/audit-scan CI checks") alongside the existing verify-command steps it already writes, keyed on `stack.package_manager`: `npm` runs `npm audit --audit-level=high`, `pnpm` runs `pnpm audit --audit-level high`, `yarn` runs `yarn npm audit --severity high`, `pip` runs `pip install pip-audit && pip-audit -r requirements.txt` when `requirements.txt` exists at init time and `pip install pip-audit && pip-audit` otherwise. A package manager with no mapping gets no step, and on a JavaScript, TypeScript or Python project init says so. | confirmed | Same user authorization and Q1 confirmation as FR-05; keying on the package manager and the `-r requirements.txt` form confirmed by Bernard at planning time, 2026-09-21 (Q5, Q6 below). `write_ci` already exists, already merges non-destructively (confirmed by this session's own testing of items 1-2 on this list: it leaves an already-declared `deploy.ci` alone and is silent on an ambiguous marker) |
| FR-07 | Both merges (FR-05, FR-06) must be idempotent: re-running `keel init` must not duplicate a rule or step already merged. | inferred | Matches the already-tested, already-passing behaviour for permission guardrails ("re-running init does not duplicate guardrails", `tests/test-keel.sh`) |

### `repo-snapshot` surfaces standards gaps

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-08 | `repo-snapshot` must run `coding-standards`' assess mode (`references/assess.md`) as part of producing a snapshot, when a standards document already exists at the project's standards document path (default `<docs_root>/standards.md`, or wherever `coding-standards` itself resolves it), regardless of whether `coding-standards` itself generated that document, and fold the assessment's findings into the snapshot's gap/debt reporting. | author-added; scope confirmed | User, this session: "even during snapshots, gaps could also be identified based on violated coding standards." `skills/coding-standards/SKILL.md:16-24` (assess mode already reads an arbitrary `standards.md`); `skills/repo-snapshot/SKILL.md` grepped, zero mentions of `coding-standards` or `assess`. Origin-agnostic scope confirmed by Bernard, 2026-09-21 (Q3) |
| FR-09 | When no standards document exists, `repo-snapshot` must say so explicitly as a gap in its own report, rather than omitting the dimension silently. | author-added | Closes the same edge FR-10 (doctor) raises, applied to the snapshot: a project that has opted into standards but has nothing to check is itself worth naming |

### `doctor`

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-10 | `keel doctor` must fail, not warn, when `gates.coding_standards` is `required` and no standards document exists at the resolved path. | inferred, direction; author-added, fail-vs-warn choice | `docs/ideas/standards-that-bind.md`, section 3, item 5: "the only hook-shaped check available is that `standards.md` exists when `gates.coding_standards` is `required`, and that belongs in `keel doctor`... Worth doing on its own merits; it is not enforcement." `fail` chosen over `warn` because `required` with nothing to check against is indistinguishable from `off`, and `doctor`'s existing idiom already fails on an unmet precondition for a `required` gate elsewhere (e.g. missing permission guardrails) |

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | The config merges in FR-05 and FR-06 must never remove or override a rule or step the project has already configured differently from keel's own default. | inferred | Matches the non-destructive merge posture already proven this session for `write_ci` and, in the existing suite, for permission guardrails |

## 7. Constraints

| ID | Requirement | Imposed by |
|---|---|---|
| CON-01 | Keel ships declarative configuration only (compiler flags, CI steps) into a target project, never executable application code. | Narrows, rather than reverses, the boundary `docs/ideas/standards-that-bind.md`'s Recommendation section already drew ("keel does not ship code into the projects it configures"): config is not application code, and the user's authorization this session was specifically for "lint config... compatible with the repo," not for keel-authored runtime helpers |
| CON-02 | No new git-hook mechanism. FR-01 through FR-03 act through `keel:ship`, an existing skill; FR-11 acts through `execute-plan`'s existing review loop; FR-05 through FR-07 act through `keel init`'s existing merge machinery and the existing `write_ci`/pre-commit hook path (`gates.commit_guard`), which already runs `verify.lint`/`format`/`typecheck` when the project turns it on. | `docs/ideas/standards-that-bind.md`, section 3, item 5: "A hook. Not available... 'Did this edit follow the conventions' has no equivalent observable," for anything past what a linter or type-checker itself already expresses |

## 8. Observed but not required

| Behaviour | Kind | Evidence | What to do |
|---|---|---|---|
| `gates.coding_standards` accepted and stored by `keel init`/`keel profile set` with no effect elsewhere | deliberate deferral | `templates/profile.schema.json:283`, `docs/profile-keys.md:54` | Addressed by FR-01 through FR-03; not a bug, a known and named gap |
| `review-code` classifies every standards violation as `Should fix`, never `Blocking` | deliberate consequence of `review-code`'s own general-purpose design | `skills/review-code/SKILL.md:61-63` | Not to be changed generally. FR-01 adds a second, `gates.coding_standards`-specific check in `ship`, rather than reclassifying `review-code`'s severity table, which serves every review, not only standards |
| `execute-plan`'s per-task quality review already produces `Blocking` findings against the standards block, and nothing requires acting on one before the coordinator ticks and commits | accident | `skills/execute-plan/references/subagent-prompts.md:108-165` | Addressed by FR-11 |
| `repo-snapshot`'s six fan-out agents (Boot/Data/Surface/Quality/Delivery/Docs) never read the project's `standards.md` | accident | `skills/repo-snapshot/SKILL.md`, grepped for any mention | Addressed by FR-08 |

## 9. Success metrics

No tracked metric. Bernard, 2026-09-21 (Q4): success is `ship` and `execute-plan` refusing
correctly when a standards violation is present and not otherwise, which FR-01 through FR-04 and
FR-11 already state as testable behaviour. No trend measurement is built for this PRD.

## 10. Milestones

`Unknown, needs a decision`. None given.

## 11. Out of scope

- **Typed/structural enforcement** (level 1, "impossible to violate") for any rule. Zero of 81
  rules are there today; sizing that work is a separate PRD.
- **The other 6 of the 8 mechanically-shaped rules** the 2026-09-19 finding named (money as a
  float, `sql.raw` string concatenation, the `remediation` field on error logs, deny-by-default
  route middleware, doc-comment coverage, a cache TTL wrapper). None maps cleanly onto an
  off-the-shelf compiler flag or CI step the way FR-05 and FR-06's pair do; each is its own
  follow-on once this mechanism is proven.
- **Stacks other than Node/TypeScript (FR-05) and Node/Python (FR-06).** `keel` detects go, php,
  ruby, csharp, kotlin, dart/flutter and PL/SQL too; each needs its own rule mapping, later.
- **Changing `gates.commit_guard`'s default.** FR-05/FR-06's config only becomes a hard pre-commit
  block for a project that has already turned `commit_guard` on; this PRD does not turn it on for
  anyone.
- **Re-opening `docs/ideas/standards-that-bind.md`'s open question 3** ("why does a loaded rule not
  bind"). FR-01's and FR-11's mechanisms are structural (a gate check in `ship`, a tick-blocking
  rule in `execute-plan`, not a stronger sentence in a skill), so neither depends on that question
  being answered.
- **`execute-plan` run solo, without delegation.** FR-11 acts on the delegated loop's own review
  dispatch (`subagent-prompts.md`); a solo run has no separate quality-review pass to gate on.

## 12. Assumptions

- `gates.coding_standards` keeps its existing three values (`required`/`warn`/`off`); this PRD adds
  no new value. Falsifiable: if a fourth value is wanted, FR-01 through FR-03 need rewriting.
- `review-code` keeps running unconditionally inside `ship`. Falsifiable: if that changes, FR-01's
  precondition ("review-code has run") may no longer hold on every ship attempt.
- `execute-plan`'s delegated loop keeps dispatching a code quality review carrying the
  `PROJECT STANDARDS` block, on every task. Falsifiable: if that dispatch is removed or stops
  receiving the block, FR-11 has nothing to gate on.
- A project adopting FR-05/FR-06 already has a working `tsconfig.json` or CI workflow for the merge
  to target; a project with neither gets whichever of `keel init`'s existing scaffolding paths
  already write one, unchanged by this PRD.

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | ~~Is the FR-05/FR-06 v1 pair (TS strict flags, npm/pip audit-scan CI step) the right two to start with?~~ **Answered by Bernard, 2026-09-21: yes, that pair.** |  |  |
| Q2 | ~~Should FR-01's "standards violation" tag (FR-04) be a new field on every `review-code` finding, or inferred at `ship` time?~~ **Answered by Bernard, 2026-09-21: infer it from citation.** FR-04 below states this directly. |  |  |
| Q3 | ~~What should FR-08 do with a hand-written standards.md that coding-standards itself never generated?~~ **Answered by Bernard, 2026-09-21: assess it regardless of origin.** FR-08 above states this directly. |  |  |
| Q4 | ~~Track a standards-violation metric over time, or is "ship refuses correctly" enough?~~ **Answered by Bernard, 2026-09-21: no metric, correctness is enough.** Section 9 above states this directly. |  |  |
| Q5 | ~~FR-06's Python step: bare `pip-audit` audits an empty runner environment, since the generated workflow has no install step. Which invocation?~~ **Answered by Bernard at planning time, 2026-09-21: `pip install pip-audit && pip-audit -r requirements.txt` when that file exists at init, else the plain form.** FR-06 states this directly. Adding an install step to `write_ci` was declined as outside this PRD. |  |  |
| Q6 | ~~FR-06 named `npm audit` for every Node project; a pnpm or yarn project would fail that step.~~ **Answered by Bernard at planning time, 2026-09-21: key the command on `stack.package_manager`.** FR-06 states the mapping directly. |  |  |

## Self-review

1. **Testability:** every FR states an observable pass/fail (a refusal, a file's content after
   `keel init`, a report's presence). None are wishes.
2. **Banned words:** searched for "should", "fast", "secure", "user-friendly", "robust",
   "scalable": none present outside quoted evidence.
3. **Invented specifics:** no number or deadline invented; section 9 states no metric by the
   user's own answer (Q4), section 10 says `Unknown`.
4. **Conflicts:** none found between FRs.
5. **Status honesty:** nothing marked `confirmed` that the user did not say; every `confirmed` FR
   traces to a direct quote or an answered question, named in its own Evidence column.
6. **Empty sections:** none; all filled or explicitly `Unknown, needs a decision`.
7. **Did anyone ask for this?** FR-08, FR-11, and the enforcement half of FR-01 trace directly to
   the user's requests this session ("upheld and difficult to violate"; "gaps could also be
   identified based on violated coding standards"; plan-time enforcement of logging and other
   standards). FR-04, FR-05 and FR-06 are confirmed by the user's own words and this session's
   answered questions. FR-02, FR-03, FR-07 and NFR-01 are inferred from already-established keel
   conventions. FR-01's blocking mechanism, FR-09 and FR-10's fail-versus-warn choice are
   author-added.
