# Stories: addressable plan steps

| | |
|---|---|
| Derived from | `docs/prd/addressable-plan-steps.md`, PRD status `approved` |
| Date | 2026-09-28 |
| Stories | 9 (build: 9, verify: 0, fix: 0, decide: 0) |
| Coverage | 20 of 20 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.

Five stories satisfy at least one `inferred` requirement (S-03, S-05, S-06, S-07, S-08), so each
names its statuses per requirement. None is disputed.

**Critical path:** S-01, S-05, S-06, S-08. S-02 to S-04 and S-09 run beside it once S-01 lands.

## Epic E-01: Plans carry step ids

**Goal:** a new plan names every step by an id, and a step can be left open on purpose, visibly.
**Requirements:** FR-01, FR-02, FR-03, FR-04, FR-12, FR-13
**Stories:** S-01
**Ships when:** a plan written from the template carries an id on every step and the validator
fails a template without them.

### S-01 The plan template gives every step an id, and the validator keeps it there

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01, FR-02, FR-03, FR-04, FR-12, FR-13 |
| Size | S |
| Depends on | none |
| Status of requirement | all confirmed |

**As a** coordinating model
**I want** every step in a new plan to carry an id naming its task and step, and a way to mark a
step deferred or not applicable with a reason
**So that** I can name one step without quoting the text around it, and a box left open on purpose
reads differently from one forgotten

**Acceptance criteria**

```gherkin
Scenario: the template's steps carry ids
  Given skills/write-plan/references/plan-template.md
  When its step checkboxes are listed
  Then each carries an id naming its task and its step
  And no two ids in the template are the same

Scenario: the template states the four states and their marks
  Given the plan template
  Then it states how a step is shown open, done, deferred and not applicable
  And it states that a deferred or not-applicable step carries its reason beside it

Scenario: the plan stays markdown
  Given a plan written from the new template
  Then it is a .md file whose steps are markdown checkboxes

Scenario: the validator fails a template whose steps lost their ids
  Given a copy of the repository whose plan template has its step ids removed
  When tests/validate-skills.sh runs
  Then it exits non-zero and names the plan template

Scenario: existing plans are not migrated
  Given the 31 plans under docs/plans before this change
  When this story lands
  Then none of them has gained step ids
  And any edit to one of them only repairs a citation this change moved
```

## Epic E-02: `keel plan status`

**Goal:** a plan's progress is readable without reading the plan.
**Requirements:** FR-05, FR-06, FR-11, NFR-01
**Stories:** S-02, S-03, S-04
**Ships when:** `keel plan status` on a plan with ids reports its progress in under a second, flags
reasonless deferrals, and reports a plan without ids as unaddressable.

### S-02 `keel plan status` reports a plan's progress

| | |
|---|---|
| Kind | build |
| Satisfies | FR-05, NFR-01 |
| Size | M |
| Depends on | S-01 |
| Status of requirement | FR-05 confirmed, NFR-01 confirmed |

**As a** coordinating model resuming after a compaction
**I want** one command that says how far each task has got and which step is next
**So that** I find my place without reading 35,000 words

**Acceptance criteria**

```gherkin
Scenario: counts per task and the next step
  Given a plan with task 1 at steps 1.1 and 1.2 done, and task 2 with all steps open
  When keel plan status runs on it
  Then it prints, for task 1, 2 done and the rest open
  And for task 2, every step open
  And it names 1.3 as the first open step
  And it exits 0

Scenario: every step done
  Given a plan whose steps are all done
  When keel plan status runs on it
  Then it says no step is open
  And it exits 0

Scenario: deferred and not-applicable steps are counted apart
  Given a plan with one deferred step and one not-applicable step, both with reasons
  When keel plan status runs on it
  Then each task's counts show the deferred and not-applicable steps separately from open and done

Scenario: under a second on the largest plan shape
  Given a plan of about 35,000 words and 2,000 lines with ids on every step
  When keel plan status runs on it under macOS's /bin/bash 3.2
  Then it completes in under a second
```

### S-03 `keel plan status` flags a deferral with no reason

| | |
|---|---|
| Kind | build |
| Satisfies | FR-06 |
| Size | S |
| Depends on | S-02 |
| Status of requirement | FR-06 inferred |

**As a** model running `ship`
**I want** status to fail when a step is deferred or not applicable without saying why
**So that** a box parked without a reason cannot pass as a decision

**Acceptance criteria**

```gherkin
Scenario: a deferral with no reason
  Given a plan in which step 2.3 is deferred with no reason
  When keel plan status runs on it
  Then it names 2.3 as lacking a reason
  And it exits non-zero

Scenario: a not-applicable step with no reason
  Given a plan in which step 1.4 is marked not applicable with no reason
  When keel plan status runs on it
  Then it names 1.4 as lacking a reason
  And it exits non-zero

Scenario: every deferral has a reason
  Given a plan whose deferred and not-applicable steps all carry reasons
  When keel plan status runs on it
  Then it names none as lacking a reason
```

### S-04 A plan without step ids is reported as unaddressable

| | |
|---|---|
| Kind | build |
| Satisfies | FR-11 |
| Size | S |
| Depends on | S-02, S-05 |
| Status of requirement | FR-11 confirmed |

**As a** coordinating model
**I want** the commands to say plainly when a plan has no step ids
**So that** I fall back to editing the file instead of trusting a count of nothing

**Acceptance criteria**

```gherkin
Scenario: status on a plan without ids
  Given docs/plans/2026-09-27-push-scan-reads-pushed-commits.md, which has no step ids
  When keel plan status runs on it
  Then it says the plan is unaddressable
  And it exits non-zero

Scenario: tick on a plan without ids
  Given a plan with no step ids
  When keel plan tick runs on it with any id
  Then it says the plan is unaddressable
  And the file is byte-for-byte unchanged
  And it exits non-zero
```

## Epic E-03: `keel plan tick`

**Goal:** a step's state changes by naming its id, and only that step changes.
**Requirements:** FR-07, FR-08, FR-09, FR-10, FR-16
**Stories:** S-05, S-06, S-07
**Ships when:** tick marks a step done, deferred or not applicable, writes its note or reason, and
two ticks at once both land.

### S-05 `keel plan tick` marks one step done, with an optional note

| | |
|---|---|
| Kind | build |
| Satisfies | FR-07, FR-08, FR-10 |
| Size | M |
| Depends on | S-01 |
| Status of requirement | FR-07 confirmed, FR-08 inferred, FR-10 inferred |

**As a** coordinating model whose reviews have passed
**I want** to mark a step done by its id, and record what I did not witness
**So that** the tick lands on the right line and the plan does not overstate what was seen

**Acceptance criteria**

```gherkin
Scenario: tick one step
  Given a plan in which step 1b.2 is open
  When keel plan tick runs on it with 1b.2
  Then step 1b.2 is done
  And every other line of the plan is unchanged
  And it exits 0

Scenario: tick with a note
  Given a plan in which step 3.1 is open
  When keel plan tick runs on it with 3.1 and a note "file already on disk on arrival"
  Then step 3.1 is done
  And the note is in the plan beside step 3.1

Scenario: an id the plan does not hold
  Given a plan with no step 9.9
  When keel plan tick runs on it with 9.9
  Then it names 9.9 as not found
  And the file is byte-for-byte unchanged
  And it exits non-zero

Scenario: a step already done
  Given a plan in which step 1.1 is done
  When keel plan tick runs on it with 1.1
  Then step 1.1 is still done, once
  And it exits 0
```

### S-06 `keel plan tick` defers a step or marks it not applicable, only with a reason

| | |
|---|---|
| Kind | build |
| Satisfies | FR-09 |
| Size | S |
| Depends on | S-05 |
| Status of requirement | FR-09 inferred |

**As a** coordinating model
**I want** to park a step as deferred or not applicable and say why
**So that** `ship` can tell a deliberate gap from a forgotten one

**Acceptance criteria**

```gherkin
Scenario: defer with a reason
  Given a plan in which step 6.2 is open
  When keel plan tick marks 6.2 deferred with the reason "moved to the follow-up plan"
  Then step 6.2 is deferred
  And the reason is in the plan beside step 6.2

Scenario: not applicable with a reason
  Given a plan in which step 4.2 is open
  When keel plan tick marks 4.2 not applicable with the reason "no behaviour to test"
  Then step 4.2 is not applicable
  And the reason is in the plan beside step 4.2

Scenario: no reason given
  Given a plan in which step 6.2 is open
  When keel plan tick marks 6.2 deferred with no reason
  Then it says a reason is required
  And the file is byte-for-byte unchanged
  And it exits non-zero
```

### S-07 Two ticks at once both land

| | |
|---|---|
| Kind | build |
| Satisfies | FR-16 |
| Size | M |
| Depends on | S-05 |
| Status of requirement | FR-16 inferred |

**As a** coordinating model ticking a concurrent batch
**I want** simultaneous ticks on one plan to both take effect
**So that** a batch's ticks cannot overwrite one another through a stale read

**Acceptance criteria**

```gherkin
Scenario: two ticks started together
  Given a plan in which steps 2.1 and 3.1 are open
  When keel plan tick for 2.1 and keel plan tick for 3.1 start at the same time
  Then both steps are done
  And no other line of the plan changed

Scenario: many ticks started together
  Given a plan with ten open steps
  When ten keel plan tick runs, one per step, start at the same time
  Then all ten steps are done
```

**Notes:** `skills/execute-plan/references/parallel-batches.md:101` ticks serially today because of
this race; once this lands, that rule can say why it is no longer needed, or keep it as the
fallback for FR-17.

## Epic E-04: The skills use the commands

**Goal:** `execute-plan` and `ship` read and tick plans through the commands, and still work without
them and on plans without ids.
**Requirements:** FR-14, FR-15, FR-17, FR-18, FR-19
**Stories:** S-08, S-09
**Ships when:** both skills name the commands, their fallbacks, and the old-plan path, and their
eval arms pass.

### S-08 `execute-plan` ticks and finds its place with the commands

| | |
|---|---|
| Kind | build |
| Satisfies | FR-14, FR-17, FR-19 |
| Size | M |
| Depends on | S-02, S-04, S-06 |
| Status of requirement | FR-14 confirmed, FR-17 confirmed, FR-19 inferred |

**As a** coordinating model
**I want** `execute-plan` to tell me to tick with `keel plan tick` and find my place with
`keel plan status`, and what to do when either cannot run
**So that** every tick lands the same way wherever I run

**Acceptance criteria**

```gherkin
Scenario: the skill names both commands
  Given skills/execute-plan/SKILL.md after this story
  Then Step 4 tells the coordinator to tick with keel plan tick and to resume with keel plan status

Scenario: the fallback where keel is not on the PATH
  Given the same skill
  Then it says that where keel is not on the PATH, the coordinator edits the step by its id

Scenario: a plan without ids
  Given the same skill
  Then it says that on a plan keel plan status reports as unaddressable, the coordinator ticks by editing the file as before

Scenario: the pinned sentence moves with the text
  When tests/run-tests.sh runs
  Then tests/test-eval-harness.sh passes, its pin updated to the new Step 4 sentence

Scenario: the eval arms that inject execute-plan still pass
  When each scenario whose Inject line names execute-plan is re-run against the new body
  Then each passes
```

**Notes:** `tests/test-eval-harness.sh:480` pins Step 4's tick sentence (CON-04). A body over 700
words owes a passing arm at its new length (CON-03).

### S-09 `ship` reads plan readiness from `keel plan status`

| | |
|---|---|
| Kind | build |
| Satisfies | FR-15, FR-17, FR-18 |
| Size | M |
| Depends on | S-03, S-04 |
| Status of requirement | FR-15 confirmed, FR-17 confirmed, FR-18 confirmed |

**As a** model running `ship`
**I want** the checkbox gate to come from `keel plan status`, with a stated fallback
**So that** a plan ships only with no open step and every parked step explained

**Acceptance criteria**

```gherkin
Scenario: the skill uses status for the gate
  Given skills/ship/SKILL.md after this story
  Then its plan gate passes a plan only where keel plan status reports no open step and exits 0

Scenario: the fallback where keel is not on the PATH
  Given the same skill
  Then it says that where keel is not on the PATH, the plan is read by step id for open steps and reasonless deferrals

Scenario: a plan without ids still ships
  Given the same skill
  Then it says that on a plan keel plan status reports as unaddressable, the checkboxes are read from the file as before

Scenario: the eval arms that inject ship still pass
  When each scenario whose Inject line names ship is re-run against the new body
  Then each passes
```

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | confirmed | S-01 | |
| FR-02 | confirmed | S-01 | |
| FR-03 | confirmed | S-01, S-02 | |
| FR-04 | confirmed | S-01, S-06 | |
| FR-05 | confirmed | S-02 | |
| FR-06 | inferred | S-03 | |
| FR-07 | confirmed | S-05 | |
| FR-08 | inferred | S-05 | |
| FR-09 | inferred | S-06 | |
| FR-10 | inferred | S-05 | |
| FR-11 | confirmed | S-04 | |
| FR-12 | confirmed | S-01 | |
| FR-13 | confirmed | S-01 | |
| FR-14 | confirmed | S-08 | |
| FR-15 | confirmed | S-09 | |
| FR-16 | inferred | S-07 | |
| FR-17 | confirmed | S-08, S-09 | |
| FR-18 | confirmed | S-09 | |
| FR-19 | inferred | S-08 | |
| NFR-01 | confirmed | S-02 | |
| CON-01 | constraint | none | Constraint, not work: holds for S-02 to S-07 |
| CON-02 | constraint | none | Constraint, not work |
| CON-03 | constraint | none | Constraint, not work: S-08 and S-09 carry it in their notes and arms |
| CON-04 | constraint | none | Constraint, not work: S-08 moves the pin |

**Forward:** 20 of 20 functional and non-functional requirements have at least one story. The four
constraints have none, correctly.
**Backward:** every story's `Satisfies` names a requirement that exists in the PRD.
