# Stories: skill and reference review

| | |
|---|---|
| Derived from | `docs/prd/skill-and-reference-review.md`, PRD status `approved` |
| Date | 2026-09-28 |
| Stories | 7 (build: 5, verify: 1, fix: 0, decide: 1) |
| Coverage | 12 of 12 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.

Five stories satisfy at least one `inferred` requirement (S-01 by FR-02 and FR-03; S-03, S-04, S-05
and S-06 by FR-09), so each names its statuses per requirement. None is disputed.

**Critical path:** S-01, S-02, S-04, S-07. S-03 runs as soon as S-01 lands; S-05 and S-06 run beside
S-04 once S-02 has ruled.

## Epic E-01: The findings

**Goal:** every problem in the skills is written down, classified and ruled on before any skill
changes.
**Requirements:** FR-01, FR-02, FR-03, FR-07, FR-11, FR-12
**Stories:** S-01, S-02
**Ships when:** the findings file exists under `docs/audits/`, covers every skill file, and every
finding that would remove a rule or a trigger carries Bernard's ruling.

### S-01 A findings pass over every body, description and reference

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01, FR-02, FR-03, FR-11 |
| Size | L |
| Depends on | none |
| Status of requirement | FR-01 confirmed, FR-02 inferred, FR-03 inferred, FR-11 confirmed |

**As a** maintainer
**I want** one record of what is wrong or unclear in every skill, before anything is changed
**So that** the changes are chosen from the whole picture and each one traces to a finding

**Acceptance criteria**

```gherkin
Scenario: every skill file is covered
  Given the 25 SKILL.md files and the 62 reference files under skills/
  When the findings file under docs/audits/ is complete
  Then it names every one of those files, with its findings or with "no findings"
  And it names every skill's description, with its findings or with "no findings"

Scenario: each finding is located and classified
  Given any finding in the file
  Then it gives a path:line
  And its kind is exactly one of: repository fact, contradiction, stale or broken reference, clarity change

Scenario: the known defect is recorded
  Given the findings file
  Then it records skills/tdd/SKILL.md's "The suite is 313 seconds and one test is 2." as a repository fact

Scenario: a finding that would remove a rule or trigger says so
  Given a finding whose change would drop a rule from a skill or a trigger from a description
  Then the finding names the rule or trigger it would remove

Scenario: no skill file changed during the pass
  Given the commit that adds the findings file
  Then it changes no file under skills/
```

### S-02 Bernard rules on every finding that removes a rule or a trigger

| | |
|---|---|
| Kind | decide |
| Satisfies | FR-07, FR-12 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | FR-07 confirmed, FR-12 confirmed |

**As a** maintainer
**I want** to approve or refuse each removal of a rule or trigger before it is made
**So that** a rule that holds because it is repeated, or a trigger a user relies on, is not lost
to tidying

**Acceptance criteria**

```gherkin
Scenario: every removal carries a ruling
  Given the findings file after this story
  Then every finding that names a rule or trigger to remove carries "approved" or "refused", with the date

Scenario: a refused removal
  Given a finding whose removal was refused
  Then no later story removes that rule or trigger
```

**Notes:** the answer lands in the findings file, beside each finding. No ADR: these are rulings on
text, not decisions that shape the system.

## Epic E-02: The changes

**Goal:** every defect fixed and every skill clearer, with no rule, reason or trigger lost
unapproved.
**Requirements:** FR-04, FR-05, FR-06, FR-07, FR-08, FR-09, FR-10, FR-11, FR-12
**Stories:** S-03, S-04, S-05, S-06, S-07
**Ships when:** every finding is resolved, `tests/run-tests.sh` and shellcheck pass, and every
scenario injecting a changed skill passes.

### S-03 Every defect the findings record is fixed

| | |
|---|---|
| Kind | build |
| Satisfies | FR-04, FR-09 |
| Size | M |
| Depends on | S-01 |
| Status of requirement | FR-04 confirmed, FR-09 inferred |

**As a** model following a keel skill in any project
**I want** no skill to state keel's own facts as mine, contradict itself, or point at nothing
**So that** I never act on a rule that was never about my project

**Acceptance criteria**

```gherkin
Scenario: every defect is resolved
  Given the findings file
  Then every repository-fact, contradiction and stale-or-broken-reference finding is marked fixed, with its commit

Scenario: the tdd timing no longer ships
  Given skills/tdd/SKILL.md after this story
  Then it states no suite or test duration measured on keel's own repository

Scenario: citations and pins still hold
  When tests/validate-citations.sh and tests/run-tests.sh run
  Then both pass
```

### S-04 Clarity changes in every skill body

| | |
|---|---|
| Kind | build |
| Satisfies | FR-05, FR-07, FR-08, FR-09 |
| Size | L |
| Depends on | S-02, S-03 |
| Status of requirement | FR-05 confirmed, FR-07 confirmed, FR-08 confirmed, FR-09 inferred |

**As a** model following a keel skill
**I want** each rule stated once, plainly, where I need it, with its reason kept
**So that** I do not have to reconcile two phrasings of one rule

**Acceptance criteria**

```gherkin
Scenario: every clarity finding on a body is resolved
  Given the findings file
  Then every clarity finding on a SKILL.md body is marked made or declined, with a reason for each declined one

Scenario: all 25 skills are in scope
  Given a skill with no eval scenario
  Then its clarity findings are resolved like any other skill's

Scenario: no rule is lost unapproved
  Given each changed body
  Then every rule it stated before the change is still stated, or its removal was approved under S-02

Scenario: no reason is cut for clarity
  Given each changed body
  Then no sentence stating the reason for a rule was removed as a clarity change

Scenario: bodies stay within their budget
  When tests/validate-skills.sh runs
  Then no body is over 900 words
  And every body over 700 words has a passing arm at its new length recorded in tests/evals/results.md
```

### S-05 Clarity changes in every reference file

| | |
|---|---|
| Kind | build |
| Satisfies | FR-05, FR-07, FR-08, FR-09 |
| Size | L |
| Depends on | S-02, S-03 |
| Status of requirement | FR-05 confirmed, FR-07 confirmed, FR-08 confirmed, FR-09 inferred |

**As a** model that opened a skill's reference
**I want** it to agree with its body and state each rule once
**So that** following the reference never means contradicting the skill

**Acceptance criteria**

```gherkin
Scenario: every clarity finding on a reference is resolved
  Given the findings file
  Then every clarity finding on a reference file is marked made or declined, with a reason for each declined one

Scenario: no rule is lost unapproved
  Given each changed reference
  Then every rule it stated before the change is still stated, or its removal was approved under S-02

Scenario: no reason is cut for clarity
  Given each changed reference
  Then no sentence stating the reason for a rule was removed as a clarity change

Scenario: citations and pins still hold
  When tests/validate-citations.sh and tests/run-tests.sh run
  Then both pass
```

### S-06 Clarity changes in every skill description

| | |
|---|---|
| Kind | build |
| Satisfies | FR-11, FR-12, FR-09 |
| Size | M |
| Depends on | S-02 |
| Status of requirement | FR-11 confirmed, FR-12 confirmed, FR-09 inferred |

**As a** model choosing which skill to invoke
**I want** each description to name plainly when its skill applies
**So that** the right skill fires, and no request that used to route to it stops doing so

**Acceptance criteria**

```gherkin
Scenario: every description finding is resolved
  Given the findings file
  Then every finding on a description is marked made or declined, with a reason for each declined one

Scenario: no trigger is lost unapproved
  Given each changed description
  Then every trigger it named before the change is still named, or its removal was approved under S-02

Scenario: descriptions stay within budget
  When tests/validate-skills.sh runs
  Then no description is over 216 characters
  And the stated total of all descriptions is within 1,320 tokens
```

**Notes:** the eval arms inject a skill directly, so they do not exercise routing. FR-12 is what
guards routing here.

### S-07 The scenarios for every changed skill pass

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-06, FR-10 |
| Size | M |
| Depends on | S-03, S-04, S-05, S-06 |
| Status of requirement | FR-06 confirmed, FR-10 confirmed |

**As a** maintainer
**I want** every scenario that injects a changed skill re-run against the changed text
**So that** a clarity change that broke behaviour does not land

**Acceptance criteria**

```gherkin
Scenario: every covered skill that changed is re-run
  Given the skills changed by S-03 to S-06 that a scenario's Inject line names
  When each of those scenarios is re-run
  Then each result is recorded in tests/evals/results.md

Scenario: a failing arm stops its change
  Given a re-run arm that fails
  Then the change to its skill is reverted or reworked until the arm passes, and results.md says which

Scenario: no new scenario
  Given tests/evals/scenarios after this story
  Then it holds the same scenario files as before the review
```

**Notes:** a failure here becomes a `fix` story against the change that caused it, rather than
widening this one.

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | confirmed | S-01 | |
| FR-02 | inferred | S-01 | |
| FR-03 | inferred | S-01 | |
| FR-04 | confirmed | S-03 | |
| FR-05 | confirmed | S-04, S-05 | |
| FR-06 | confirmed | S-07 | |
| FR-07 | confirmed | S-02, S-04, S-05 | |
| FR-08 | confirmed | S-04, S-05 | |
| FR-09 | inferred | S-03, S-04, S-05, S-06 | |
| FR-10 | confirmed | S-07 | |
| FR-11 | confirmed | S-01, S-06 | |
| FR-12 | confirmed | S-02, S-06 | |
| CON-01 | constraint | none | Constraint, not work: S-04 checks it |
| CON-02 | constraint | none | Constraint, not work |
| CON-03 | constraint | none | Constraint, not work: every story's checks run it |
| CON-04 | constraint | none | Constraint, not work: S-06 checks it |

**Forward:** 12 of 12 functional requirements have at least one story. The PRD has no
non-functional requirements. The four constraints have none, correctly.
**Backward:** every story's `Satisfies` names a requirement that exists in the PRD.
