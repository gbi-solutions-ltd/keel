# Stories: Coding standards enforcement

| | |
|---|---|
| Derived from | `docs/prd/coding-standards-enforcement.md`, PRD status `approved` |
| Date | 2026-09-21 |
| Stories | 7 (build: 7, verify: 0, fix: 0, decide: 0) |
| Coverage | 11 of 11 requirements covered (FR-01 through FR-11, NFR-01). See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.

All 7 stories are `build`: every FR describes behaviour that does not exist yet, wired into a
mechanism that does. Checked against the current code before classifying, not assumed:
`skills/ship/SKILL.md:26` has no `gates.coding_standards` awareness at all;
`skills/execute-plan/references/subagent-prompts.md:146-166` states `DEVIATES` handling in full
and nothing about a `Blocking` quality finding; `lib/detect-stack.sh` only detects existing
lint/type-check tooling, never writes it; `skills/repo-snapshot/SKILL.md` has zero mentions of
`coding-standards` or `assess`; `keel doctor`'s `gates.coding_standards` check does not exist
(the key's only appearance in `bin/keel` is the pre-push loosening-check). No `verify`, `fix` or
`decide` stories: nothing here contradicts a requirement, and no open question survived the PRD.

## Epic E-01: Ship refuses on an unaddressed standards violation

**Goal:** a project with `gates.coding_standards: required` cannot ship while `review-code` has
found a standards violation nobody addressed.
**Requirements:** FR-01, FR-02, FR-03, FR-04
**Stories:** S-01, S-02
**Ships when:** `keel:ship` refuses on a `required` project with an unaddressed standards-citing
finding, reports without refusing on `warn`, and is unchanged on `off`.

### S-01 A `review-code` finding is recognised as a standards violation

| | |
|---|---|
| Kind | build |
| Satisfies | FR-04 |
| Size | S |
| Depends on | none |
| Status of requirement | confirmed |

**As a** `keel:ship` gate
**I want** to tell a standards violation apart from any other `Should fix` finding
**So that** FR-01/FR-02 can act on it mechanically instead of re-reading the finding's prose

**Acceptance criteria**

```gherkin
Scenario: a Should-fix finding citing a coding-standards reference file
  Given a review-code finding tagged "Should fix"
  And its text cites a path under skills/coding-standards/references/
  When ship classifies the finding
  Then it is recognised as a standards violation

Scenario: a Should-fix finding citing nothing under coding-standards
  Given a review-code finding tagged "Should fix"
  And its text names no path under skills/coding-standards/references/
  When ship classifies the finding
  Then it is not recognised as a standards violation

Scenario: a Blocking finding is never reclassified
  Given a review-code finding tagged "Blocking"
  And its text cites a path under skills/coding-standards/references/
  When ship classifies the finding
  Then it stays Blocking, not a standards violation with a different label

Scenario: a finding that restates a rubric bullet but drops its file
  Given a review-code finding tagged "Should fix"
  And its text restates a bullet from skills/review-code/references/rubric.md without naming
    the reference file that bullet cites
  When ship classifies the finding
  Then it is recognised as a standards violation, read as citing that bullet's file

Scenario: a finding with no citation and no rubric bullet behind it
  Given a review-code finding tagged "Should fix"
  And it cites no file and matches no rubric bullet
  When ship classifies the finding
  Then it is not recognised as a standards violation
```

**Notes:** no new field on the finding. Confirmed by Bernard, 2026-09-21 (PRD Q2): inferred from
the citation at `ship` time. This session's own dispatched `review-code` run already produced this
exact shape unprompted (a finding citing "See `caching.md`"), so the classification rule has real
prose to match against, not a hypothetical format.

---

### S-02 Ship's gate reads `gates.coding_standards`

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01, FR-02, FR-03 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | FR-01 author-added, FR-02 inferred, FR-03 inferred |

**As a** project owner who set `gates.coding_standards: required`
**I want** `keel:ship` to refuse while an unaddressed standards violation remains
**So that** the setting means what its name says, the way every other gate already does

**Acceptance criteria**

```gherkin
Scenario: required, with an unaddressed standards violation
  Given .keel/profile.json sets gates.coding_standards to "required"
  And review-code reported a standards violation (per S-01) that was not fixed or accepted
  When keel:ship's Step 5 runs
  Then ship refuses to complete
  And the refusal names the violation and its citation

Scenario: required, with the violation fixed before shipping
  Given .keel/profile.json sets gates.coding_standards to "required"
  And the diff no longer contains the violation review-code found
  When keel:ship's Step 5 runs
  Then this check does not block

Scenario: required, with the user explicitly accepting the finding
  Given .keel/profile.json sets gates.coding_standards to "required"
  And the user has explicitly accepted the standards-violation finding
  When keel:ship's Step 5 runs
  Then this check does not block, the same escape hatch item 4 (security-audit) already offers

Scenario: warn, with an unaddressed standards violation
  Given .keel/profile.json sets gates.coding_standards to "warn"
  And review-code reported an unaddressed standards violation
  When keel:ship's Step 5 runs
  Then ship reports the violation
  And ship does not refuse because of it

Scenario: off
  Given .keel/profile.json sets gates.coding_standards to "off"
  And review-code reported a standards violation
  When keel:ship's Step 5 runs
  Then ship's behaviour is exactly what it is today: no additional check
```

**Notes:** mirrors the `required`/`warn`/`off` vocabulary `templates/profile.schema.json` already
uses for `security_audit` and `commit_guard`, and item 4 of `skills/ship/SKILL.md`'s own checklist
("`security-audit --diff` is clean, or its findings are explicitly accepted by the user") is the
precedent for the accept escape hatch in scenario 3.

## Epic E-02: `execute-plan` refuses to tick over a blocking quality finding

**Goal:** a task cannot be ticked and committed while its own per-task quality review found
something blocking, the same way a `DEVIATES` spec-compliance verdict already stops it.
**Requirements:** FR-11
**Stories:** S-03
**Ships when:** a delegated `execute-plan` run with a `Blocking` quality-review finding is not
ticked or committed until the finding is resolved or accepted.

### S-03 A `Blocking` quality finding gates the tick, the same as `DEVIATES`

| | |
|---|---|
| Kind | build |
| Satisfies | FR-11 |
| Size | S |
| Depends on | none |
| Status of requirement | confirmed |

**As a** coordinator running `execute-plan` in delegated mode
**I want** a `Blocking` finding from a task's code-quality review to stop the tick
**So that** I cannot commit a standards violation just because the spec-compliance pass alone
happened to pass

**Acceptance criteria**

```gherkin
Scenario: quality review returns a Blocking finding
  Given a task's spec-compliance review returned COMPLIES
  And its code-quality review returned a Blocking finding
  When the coordinator reaches the tick-and-commit step
  Then the task is not ticked
  And the task is not committed
  And the coordinator's next action is the same as a DEVIATES verdict: resolve, then re-verify

Scenario: quality review returns only Should-fix or Consider findings
  Given a task's spec-compliance review returned COMPLIES
  And its code-quality review returned only Should-fix or Consider findings
  When the coordinator reaches the tick-and-commit step
  Then the task is ticked and committed
  And the Should-fix and Consider findings are recorded in the report per Step 6

Scenario: the user explicitly accepts a Blocking quality finding
  Given a task's code-quality review returned a Blocking finding
  And the user has explicitly accepted it
  When the coordinator reaches the tick-and-commit step
  Then the task is ticked and committed
  And the acceptance is noted in the plan file
```

**Notes:** `skills/execute-plan/references/subagent-prompts.md:108-125` already dispatches this
review with the `PROJECT STANDARDS` block and the `Blocking`/`Should fix`/`Consider` vocabulary on
every task; `:145-165` only ever discusses `DEVIATES` handling. This story adds the missing branch
to "Running the loop," not a new review pass. Confirmed by Bernard, 2026-09-21, proposed directly
and confirmed in-scope for this PRD.

## Epic E-03: Mechanical rules shipped as config by `keel init`

**Goal:** the two v1 mechanical rules are enforced pre-commit via config `keel init` merges,
non-destructively and idempotently, not only caught at review time.
**Requirements:** FR-05, FR-06, FR-07, NFR-01
**Stories:** S-04, S-05
**Ships when:** a fresh `keel init` on a TypeScript project sets the strict-mode flags, a fresh
`keel init` on a Node or Python project's CI workflow includes an audit-scan step, neither
overwrites an existing, different setting, and re-running `keel init` does not duplicate either.

### S-04 `keel init` merges TypeScript strict-mode flags

| | |
|---|---|
| Kind | build |
| Satisfies | FR-05, FR-07 (for this merge), NFR-01 (for this merge) |
| Size | M |
| Depends on | none |
| Status of requirement | FR-05 confirmed, FR-07 inferred, NFR-01 inferred |

**As a** project owner running `keel init` on a TypeScript project
**I want** the strict-mode compiler flags coding-standards names merged into `tsconfig.json`
**So that** the rule is enforced by the compiler on every build, not only found by a reviewer

**Acceptance criteria**

```gherkin
Scenario: a TypeScript project with a tsconfig.json missing the strict flags
  Given a project detected as TypeScript, with a tsconfig.json that does not set strict mode
  When keel init runs
  Then tsconfig.json's compilerOptions include the strict-mode flags named in
    skills/coding-standards/references/*.md's "strict type-checking flags" rule

Scenario: a tsconfig.json that already sets one of the flags differently
  Given a tsconfig.json that explicitly sets one of those flags to a different value
  When keel init runs
  Then that flag is left exactly as the project set it
  And the other flags this rule names are still merged in

Scenario: re-running init after the flags are already merged
  Given a tsconfig.json that already has all of this rule's flags set
  When keel init runs again
  Then tsconfig.json is unchanged: no duplicate keys, no reordering, no value changes

Scenario: a non-TypeScript project
  Given a project not detected as TypeScript
  When keel init runs
  Then no tsconfig.json is created or modified by this rule
```

**Notes:** `lib/detect-stack.sh` (grepped) only detects existing lint/type-check tooling today,
never writes rule content; this is new behaviour. Non-destructive merge posture matches what
`tests/test-keel.sh` already proves for permission guardrails ("re-running init does not duplicate
guardrails") and what this session directly tested for `write_ci` (leaves an already-declared
`deploy.ci` alone).

---

### S-05 `keel init`'s generated CI adds an audit-scan step

| | |
|---|---|
| Kind | build |
| Satisfies | FR-06, FR-07 (for this merge), NFR-01 (for this merge) |
| Size | M |
| Depends on | none |
| Status of requirement | FR-06 confirmed, FR-07 inferred, NFR-01 inferred |

**As a** project owner running `keel init` on a Node or Python project
**I want** the generated CI workflow to include a package-manager audit-scan step
**So that** a known-vulnerable dependency fails CI instead of being found later, if at all

**Acceptance criteria**

```gherkin
Scenario: an npm project's CI workflow is generated fresh
  Given a project whose profile says stack.package_manager is "npm"
  And no existing CI workflow keel recognises
  When keel init calls write_ci
  Then the generated workflow includes a step running "npm audit --audit-level=high"
    alongside the existing verify-command steps

Scenario: a pnpm or yarn project gets its own package manager's audit command
  Given a project whose profile says stack.package_manager is "pnpm" (or "yarn")
  When keel init calls write_ci
  Then the audit step runs "pnpm audit --audit-level high" (or "yarn npm audit --severity high")
  And never "npm audit"

Scenario: a pip project with a requirements.txt
  Given a project whose profile says stack.package_manager is "pip"
  And requirements.txt exists
  When keel init calls write_ci
  Then the generated workflow includes a step running
    "pip install pip-audit && pip-audit -r requirements.txt"

Scenario: a pip project with no requirements.txt
  Given a project whose profile says stack.package_manager is "pip"
  And no requirements.txt exists
  When keel init calls write_ci
  Then the audit step runs "pip install pip-audit && pip-audit"

Scenario: a package manager with no audit mapping
  Given a JavaScript, TypeScript or Python project whose profile says stack.package_manager is
    null or an unmapped value
  When keel init calls write_ci
  Then no audit step is written
  And init's output says no audit step was written and why

Scenario: a project outside those ecosystems
  Given a Go project, whose package manager the mapping was never going to cover
  When keel init calls write_ci
  Then no audit step is written
  And init says nothing about it

Scenario: a project that already declares its own CI
  Given deploy.ci is already set, or a CI marker file already exists
  When keel init runs
  Then write_ci does not touch the existing workflow, matching its current behaviour for every
    other step it writes

Scenario: re-running init after the audit step is already present
  Given a generated CI workflow that already has the audit-scan step
  When keel init runs again
  Then the workflow is unchanged: no duplicate step
```

**Notes:** `write_ci` (`bin/keel:1188`) already exists and already merges non-destructively;
this session directly tested that it leaves an already-declared `deploy.ci` alone and stays silent
on an ambiguous CI-marker case. This story extends its step list, not its merge logic.

## Epic E-04: Standards visibility, in `repo-snapshot` and `doctor`

**Goal:** a snapshot or a doctor run tells the truth about whether a project's code follows its
own standards, instead of staying silent about it.
**Requirements:** FR-08, FR-09, FR-10
**Stories:** S-06, S-07
**Ships when:** `repo-snapshot` reports a standards gap either way (assessed, or none to assess
against), and `doctor` fails a `required` project with no standards document.

### S-06 `repo-snapshot` runs the standards assessment, or names its absence

| | |
|---|---|
| Kind | build |
| Satisfies | FR-08, FR-09 |
| Size | M |
| Depends on | none |
| Status of requirement | FR-08 author-added, scope confirmed; FR-09 author-added |

**As an** engineer onboarding onto an existing project via `repo-snapshot`
**I want** the snapshot to say whether the code follows its own `standards.md`
**So that** I learn this from the snapshot instead of discovering it the hard way later

**Acceptance criteria**

```gherkin
Scenario: a standards document exists
  Given a project with a document at its resolved standards-document path
  When repo-snapshot runs
  Then it runs coding-standards' assess mode against that document
  And the assessment's findings appear in the snapshot's gap/debt reporting

Scenario: the standards document was hand-written, not generated by coding-standards
  Given a standards document at the resolved path with no coding-standards provenance marker
  When repo-snapshot runs
  Then it is assessed exactly as in the scenario above, regardless of origin

Scenario: no standards document exists
  Given no document exists at the resolved standards-document path
  When repo-snapshot runs
  Then the snapshot states explicitly that no standards document exists
  And this is reported as a gap, not omitted
```

**Notes:** `skills/coding-standards/SKILL.md:16-24` already has a working assess mode
(`references/assess.md`); `skills/repo-snapshot/SKILL.md` currently has zero mentions of
`coding-standards` or `assess`. Origin-agnostic scope confirmed by Bernard, 2026-09-21 (PRD Q3).

---

### S-07 `keel doctor` fails a `required` project with no standards document

| | |
|---|---|
| Kind | build |
| Satisfies | FR-10 |
| Size | S |
| Depends on | none |
| Status of requirement | inferred, direction; author-added, fail-vs-warn choice |

**As a** project owner who set `gates.coding_standards: required`
**I want** `keel doctor` to fail if there is no standards document to check code against
**So that** a `required` gate with nothing to enforce does not silently read as configured

**Acceptance criteria**

```gherkin
Scenario: required, with no standards document
  Given .keel/profile.json sets gates.coding_standards to "required"
  And no document exists at the resolved standards-document path
  When keel doctor runs
  Then it reports a fail-level finding naming the missing document
  And doctor's overall exit code is non-zero

Scenario: required, with a standards document present
  Given .keel/profile.json sets gates.coding_standards to "required"
  And a document exists at the resolved standards-document path
  When keel doctor runs
  Then this check reports ok

Scenario: warn or off
  Given .keel/profile.json sets gates.coding_standards to "warn" or "off"
  And no standards document exists
  When keel doctor runs
  Then this check does not fail, matching every other gate's off/warn posture
```

**Notes:** `docs/ideas/standards-that-bind.md`, section 3, item 5: "the only hook-shaped check
available is that `standards.md` exists when `gates.coding_standards` is `required`, and that
belongs in `keel doctor`... about four lines of bash and zero skill words." `fail`, not `warn`,
because `required` with nothing to check against reads the same as `off`.

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | author-added | S-02 | |
| FR-02 | inferred | S-02 | |
| FR-03 | inferred | S-02 | |
| FR-04 | confirmed | S-01 | |
| FR-05 | confirmed | S-04 | |
| FR-06 | confirmed | S-05 | |
| FR-07 | inferred | S-04, S-05 | One requirement, satisfied once per merge it covers |
| FR-08 | author-added | S-06 | |
| FR-09 | author-added | S-06 | |
| FR-10 | inferred/author-added | S-07 | |
| FR-11 | confirmed | S-03 | |
| NFR-01 | inferred | S-04, S-05 | Same split as FR-07, for the same reason |
| CON-01 | n/a | none | Constraint, not work. Correctly uncovered: every story ships declarative config, never runtime code, by construction |
| CON-02 | n/a | none | Constraint, not work. Correctly uncovered: no story adds a git hook; S-02 and S-03 act through existing skills, S-04/S-05 through existing merge machinery |

**Forward:** 11 of 11 FRs/NFRs have at least one story. `CON-01` and `CON-02` are constraints, not
work, and are correctly uncovered.
**Backward:** every story's `Satisfies` names a requirement that exists in the PRD.

## Self-review

1. Every story has a non-empty `Satisfies`, and each ID exists in the PRD. Confirmed.
2. Every `FR` and `NFR` appears in the coverage table with stories or a stated reason. Confirmed.
3. No story bundles two things that could ship separately. S-02 bundles FR-01/02/03 (one
   conditional's three branches, not separably useful) and S-06 bundles FR-08/09 (the same
   conditional's two branches in `repo-snapshot`); both are one behaviour, not two.
4. No acceptance criterion asserts on an internal call; each asserts on a refusal, a report line,
   a file's content, or an exit code.
5. No `decide` story exists; none was needed, since the PRD's four open questions were all
   answered before this document was written.
6. Sizes are `S`, `M`, or `L` only. Confirmed: five `S`, two `M`, no `L`.
