# Stories: audit and seed modes for `coding-standards`

| | |
|---|---|
| Derived from | `docs/prd/coding-standards-audit-and-seed.md`, PRD status `approved, 2026-09-02` |
| Date | 2026-09-02 |
| Stories | 13 (build: 9, verify: 4, fix: 0, decide: 0) |
| Coverage | 29 of 29 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> **The PRD was approved on 2026-09-02 in `b2ae8cc`, so these stories are no longer provisional.**
> S-01 and S-02 are delivered. S-07 to S-09 and S-13 remain cancellable as a group, not because
> the PRD is unsettled but because section 5.4's fallback turns on audit's eval arm, which has
> not run.

**There are no `decide` stories.** The PRD's Q1 and Q2 were settled on 2026-09-02 before these were
written: audit takes `-standards-audit.md`, and audit and seed are two modes rather than one. Q3,
what audit does when the tree contradicts itself, blocks nothing: it inherits Step 1's counting rule
and becomes an acceptance scenario on S-05 rather than a decision.

**Seven requirements are `author-added` and two are `inferred`.** Each story names the status of
what it satisfies, because a story built on an invented requirement is the cheapest one to cancel.

## The ordering, and why it is not by value

The critical path is **S-01, then S-02, then everything else**, and both of those exist to answer a
question rather than to deliver a mode. They are first because if either comes back wrong, the shape
in the PRD changes and most of the stories below it are rewritten or dropped.

**S-01 is first because author mode has never been exercised.** Both new modes make it load bearing:
audit ends by offering it, seed is its Step 4 with a different source. A weak author mode is
inherited by both, and finding that out after audit ships means audit's terminal branch and seed's
whole output are built on something nobody measured. It is the highest-risk item in the change and
it is not last.

**S-02 is second because it tests the structural claim on the mode that already ships.** The PRD's
section 5.3 accepts moving mode detail into `references/` on an argument it calls plausible and
unproven. S-02 makes that move for assess alone, which is the only mode with an existing scenario
(`assess-a-stale-standard`) and therefore the only one whose before-and-after can be compared
against a recorded run. Testing the risky move on shipped behaviour before writing two new modes on
top of it is what keeps the fallback cheap.

## Epic A: de-risk the shape

### S-01 Author mode gets a recorded eval arm, or a written acceptance that it has none

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-06 |
| Size | M |
| Depends on | nothing |
| Status of requirement | confirmed |

**As a** keel maintainer
**I want** to know whether author mode is actually followed before two modes depend on it
**So that** a weakness in it is found now rather than after audit and seed inherit it

**Acceptance criteria**

```gherkin
Scenario: an arm exercises author mode end to end
  Given a repository with code and no standards.md
  And coding-standards injected as the only skill
  When the arm is run with the flags tests/evals/README.md fixes
  Then it derives conventions from the code rather than importing a style guide
  And it writes docs/standards.md
  And the run is recorded in tests/evals/results.md with its model, turns, duration and cost

Scenario: the arm cannot be made to pass
  Given the arm has been run and author mode was not followed
  Then the finding is recorded in tests/evals/results.md
  And the PRD's section 5 is revisited before S-03 starts
  And no audit or seed story begins

Scenario: an arm is not run at all
  Given a decision is taken not to run it
  Then docs/standards.md records author mode as shipping unexercised, by name
  And the record says which two modes depend on it
```

### S-02 Assess's four checks move to a reference, and assess is still followed

| | |
|---|---|
| Kind | build |
| Satisfies | FR-19, NFR-02, NFR-05 (assess) |
| Size | M |
| Depends on | nothing |
| Status of requirement | FR-19 author-added, forced by the PRD's 900 measurement, which leaves zero headroom |

**As a** keel maintainer
**I want** the reference-behind-a-link move proved on a mode that already ships
**So that** the cheapest test of the PRD's central unproven claim happens before two new modes rest
on it

**Acceptance criteria**

```gherkin
Scenario: Step 0a moves and the body shrinks
  Given skills/coding-standards/SKILL.md is 876 words
  When Step 0a's four checks move to references/assess.md
  Then the body is about 757 words
  And Step 0 still names the mode and points at the reference

Scenario: assess is still followed with its steps behind a link
  Given the assess-a-stale-standard scenario
  When the arm is run against the moved shape
  Then all four checks run in the order references/assessment-report.md fixes
  And the report carries the same fixed section order as docs/audits/2026-09-02-standards.md
  And the run is recorded in tests/evals/results.md

Scenario: the arm shows a check was skipped
  Given the arm ran and one of the four checks did not fire
  Then FR-19 is falsified
  And the PRD's section 5.4 fallback is taken rather than the shape being adjusted
```

### S-03 Step 0 routes four modes on two facts

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01, FR-02, FR-19, FR-20, NFR-01 |
| Size | M |
| Depends on | S-02 |
| Status of requirement | FR-20 inferred, FR-19 author-added |

**As a** developer or agent running `coding-standards`
**I want** the right mode chosen from whether a standards document exists and whether there is code
**So that** a brownfield repository stops being handed a standard it never agreed to

**Acceptance criteria**

```gherkin
Scenario: the four cells route
  Given no standards.md and code to read
  Then audit runs
  Given no standards.md and no code
  Then seed runs
  Given standards.md exists and code to read
  Then assess runs
  Given standards.md exists and no code
  Then assess runs, per FR-14

Scenario: the mode is chosen before anything is read
  When the skill starts
  Then the mode is decided from the request's words and the two facts
  And no source file has been read

Scenario: a precondition is wrong
  Given the request asks to assess and no standards.md exists
  Then the skill says so and offers seed or audit by which precondition holds
  Given the request asks to seed and standards.md exists
  Then the skill names the existing document and asks before writing

Scenario: the body stays inside the ceiling
  When tests/validate-skills.sh runs
  Then the body is at or under 900 words
  And no gate has been changed to make it pass
```

## Epic B: audit

### S-04 Audit derives a brownfield tree and writes a dated report

| | |
|---|---|
| Kind | build |
| Satisfies | FR-03, FR-04, FR-05, FR-07, NFR-08 |
| Size | L |
| Depends on | S-03 |
| Status of requirement | FR-07 author-added, settled by the requester 2026-09-02 |

**As a** developer inheriting a repository with conventions and no document
**I want** a derivation I can read and ratify
**So that** what the code happens to do is not silently promoted into a standard

**Acceptance criteria**

```gherkin
Scenario: audit derives and reports
  Given a repository with code and no standards.md
  When audit runs
  Then it samples at least ten files across different areas, per Step 1
  And it writes docs/audits/YYYY-MM-DD-standards-audit.md

Scenario: audit writes nothing else
  When audit completes
  Then docs/standards.md does not exist
  And no file it read has been modified
  And git status shows exactly one new file

Scenario: the report says what it is
  Then its header states it is a derivation and not an agreed standard

Scenario: the filename does not collide with assess
  Given docs/audits/2026-09-02-standards.md already exists from an assess run
  When audit runs on the same day
  Then it writes DATE-standards-audit.md and does not overwrite the assess report

Scenario: the tree contradicts itself
  Given seven call sites concatenate SQL and three parameterise it
  Then the report records the minority as the rule and says why, per Step 1's counting rule
  And it does not record the majority as the convention
```

### S-05 Audit offers to author at its end

| | |
|---|---|
| Kind | build |
| Satisfies | FR-06 |
| Size | S |
| Depends on | S-04 |
| Status of requirement | author-added |

**As a** developer who has just read an audit report
**I want** the next step offered rather than left to me
**So that** a derivation that is deliberately not a standard does not become a dead end

**Acceptance criteria**

```gherkin
Scenario: the offer is made
  When audit finishes writing its report
  Then it offers to author standards.md from the same derivation
  And it does not author without being asked

Scenario: the offer is declined
  When the offer is declined
  Then the report remains and nothing else is written
```

### S-06 Audit has a passing eval arm

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-05 (audit) |
| Size | M |
| Depends on | S-04, S-05 |
| Status of requirement | author-added |

**As a** keel maintainer
**I want** proof that audit is followed with its steps behind a link
**So that** FR-19 is measured for this mode rather than assumed from assess

**Acceptance criteria**

```gherkin
Scenario: the arm runs and is recorded
  Given a brownfield fixture with code and no standards.md
  When the arm is run with the flags tests/evals/README.md fixes
  Then the report is written and standards.md is not
  And the run is recorded in tests/evals/results.md

Scenario: the arm fails
  Then section 5.4's fallback is taken, and S-07 to S-09 are cancelled
```

## Epic C: seed

### S-07 Seed writes a starting document from the house defaults, and says so

| | |
|---|---|
| Kind | build |
| Satisfies | FR-08, FR-10, FR-11 |
| Size | L |
| Depends on | S-03 |
| Status of requirement | confirmed |

**As a** developer starting a project with no code yet
**I want** a standards document that states where it came from
**So that** nobody mistakes an inherited default for a derived convention

**Acceptance criteria**

```gherkin
Scenario: seed writes the document
  Given no standards.md and no code
  When seed runs
  Then docs/standards.md is written from references/house-defaults.md and the applicable topic references
  And only the topic references whose index predicate holds are folded in

Scenario: the document states its provenance
  Then it says it was seeded from the house defaults and not derived from code

Scenario: the skill says out loud that seed inverts Step 1
  When the mode's own text is read
  Then it states that Step 1's rule assumes a codebase that exists
  And that where there is none the choice is between the house defaults and nothing

Scenario: code turns up after all
  Given seed was asked for and the repository has source files
  Then the skill names them and offers audit instead
```

### S-08 Seed reports which house references were missing for the stack

| | |
|---|---|
| Kind | build |
| Satisfies | FR-09, NFR-07, NFR-08 |
| Size | M |
| Depends on | S-07 |
| Status of requirement | confirmed |

**As a** keel maintainer
**I want** to be told when keel's own library has no reference for a stack it supports
**So that** a gap like Flutter's stops being invisible

**Acceptance criteria**

```gherkin
Scenario: the known true positive
  Given a project whose profile.stack.framework is flutter and has_ui is true
  When seed runs
  Then it reports that no house reference covers this stack's UI layer
  And the finding is addressed to keel's maintainers, not to the project

Scenario: no gap
  Given a Node service with no UI
  Then the gap report is present and empty, rather than absent

Scenario: the report is comparable between runs
  Then it carries a fixed section order and states its counting unit before any number
```

### S-09 Seed has a passing eval arm

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-05 (seed) |
| Size | M |
| Depends on | S-07, S-08 |
| Status of requirement | author-added |

**As a** keel maintainer
**I want** proof that seed is followed with its steps behind a link
**So that** FR-19 is measured for the mode furthest from the one it was proved on

**Acceptance criteria**

```gherkin
Scenario: the arm runs and is recorded
  Given an empty repository with a profile and no source
  When the arm is run
  Then standards.md is written, its provenance is stated, and the gap report is produced
  And the run is recorded in tests/evals/results.md

Scenario: the arm fails
  Then seed is dropped per section 5.4, and audit is unaffected
```

## Epic D: assess gains its second coverage number

### S-10 Check 1b counts the house defaults as its own number

| | |
|---|---|
| Kind | build |
| Satisfies | FR-15, FR-16, FR-17, FR-18 |
| Size | M |
| Depends on | S-02 |
| Status of requirement | FR-18 author-added, FR-15 to FR-17 confirmed |

**As a** reader of an assessment
**I want** house-defaults coverage reported separately from topic-reference coverage
**So that** I can see which of the two failed rather than a combined number that hides it

**Acceptance criteria**

```gherkin
Scenario: the unit is stated and reproducible
  Then check 1b counts every ## section of references/house-defaults.md
  And it excludes exactly two by name, "The other references, and when each applies" and "What is deliberately not here"
  And it subtracts no fixed number and makes no judgement about whether a heading reads like a rule
  And the denominator today is 12

Scenario: the two numbers are never summed
  Then the header carries check 1's coverage figure and check 1b's as separate named numbers
  And no figure in the report is the sum of them

Scenario: the section order stays comparable
  Then check 1b is reported immediately after check 1
  And checks 2, 3 and 4 keep their numbers and meanings
  And docs/audits/2026-09-02-standards.md remains comparable against a new report
```

### S-11 Assess runs where a document exists and there is no code

| | |
|---|---|
| Kind | build |
| Satisfies | FR-14 |
| Size | S |
| Depends on | S-03, S-10 |
| Status of requirement | confirmed by the requester, answer author-added |

**As a** developer with a standards document and no code yet
**I want** the checks that can run to run, and the rest to say why they cannot
**So that** the fourth cell of the mode table is a real answer rather than an empty corpus reported
as a failure

**Acceptance criteria**

```gherkin
Scenario: the checks that read no code still run
  Given standards.md exists and there is no source
  Then check 1 runs in full, because it reads no code
  And check 1b runs in full
  And check 4's ledger structure is assessed

Scenario: the checks that need a corpus say so
  Then check 2 reports no corpus and the reason, in the section it already has
  And check 3 reports no corpus and the reason
  And neither is reported as a coverage failure

Scenario: the header does not imply completeness
  Then the Not covered section names the two checks that could not run
```

## Epic E: the inheritance rule, stated

### S-12 `house-defaults.md` states that adopters inherit it unchanged

| | |
|---|---|
| Kind | build |
| Satisfies | FR-12, FR-13 |
| Size | S |
| Depends on | nothing |
| Status of requirement | FR-12 confirmed, FR-13 author-added |

**As an** external adopter of keel
**I want** to know how I am expected to disagree with a house default
**So that** I do not look for an overlay mechanism that does not exist

**Acceptance criteria**

```gherkin
Scenario: the rule is explicit
  Then references/house-defaults.md states in its opening that adopters inherit it unchanged
  And that disagreement is expressed only through the project's own departures ledger

Scenario: no mechanism is added
  Then no overlay file exists
  And templates/profile.schema.json gains no key for house defaults
  And SCHEMA_VERSION does not move
```

## Cross-cutting

### S-13 The new modes change nothing at the point of work, and the shipped checks still pass

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-21, NFR-03, NFR-04 |
| Size | S |
| Depends on | S-04, S-07 |
| Status of requirement | FR-21 inferred |

**As a** keel maintainer
**I want** the assumption in the PRD's section 12 held as a check rather than a hope
**So that** the modes stay outside the open question at `standards-that-bind.md:624`

**Acceptance criteria**

```gherkin
Scenario: no enforcement is added
  Then neither mode adds a hook, a gate, or a read enforced elsewhere
  And .keel/profile.json gains no gate key

Scenario: the checks that shipped on 2026-09-02 still pass
  When tests/run-tests.sh runs
  Then the delegation check passes
  And tests/test-doc-claims.sh passes
  And shellcheck is clean

Scenario: both modes run offline
  Then neither makes a network request
```

## If the arms fail: what survives and what drops

Section 5.4 of the PRD names the fallback. This is that fallback mapped onto these stories, so it is
reachable from the backlog rather than re-derived under pressure.

| Trigger | Drops | Survives, possibly rewritten |
|---|---|---|
| **S-01's arm shows author mode is weak** | nothing yet, but S-03 does not start | Everything is paused. The PRD's section 5 is revisited first, because audit's terminal branch and seed's Step 4 both rest on author |
| **S-02's arm shows assess is not followed from a reference** | S-03, S-07, S-08, S-09, and Epic C entirely | S-04 and S-05 are rewritten as a terminal branch of author costing about 15 body words, which needs 9 words to come from somewhere. S-10, S-11 and S-12 are unaffected, because none of them depends on the reference move |
| **S-06's arm fails** | S-07, S-08, S-09 | Audit is reworked before seed is attempted |
| **S-09's arm fails** | S-09 and seed | Audit is unaffected and ships alone, which is section 5.4's named fallback |

**S-10, S-11 and S-12 are independent of the reference-move question** and can proceed whatever the
arms say. S-10 and S-11 change assess's checks rather than where its steps live; S-12 is a
sentence in a reference file. If the shape collapses entirely, those three are still worth shipping.

## Coverage

**Forward: every requirement appears in at least one story.**

| Requirement | Status | Stories |
|---|---|---|
| FR-01 | confirmed | S-03 |
| FR-02 | confirmed | S-03 |
| FR-03 | confirmed | S-04 |
| FR-04 | confirmed | S-04 |
| FR-05 | confirmed | S-04 |
| FR-06 | author-added | S-05 |
| FR-07 | author-added | S-04 |
| FR-08 | confirmed | S-07 |
| FR-09 | confirmed | S-08 |
| FR-10 | confirmed | S-07 |
| FR-11 | confirmed | S-07 |
| FR-12 | confirmed | S-12 |
| FR-13 | author-added | S-12 |
| FR-14 | confirmed | S-11 |
| FR-15 | confirmed | S-10 |
| FR-16 | confirmed | S-10 |
| FR-17 | confirmed | S-10 |
| FR-18 | author-added | S-10 |
| FR-19 | author-added | S-02, S-03 |
| FR-20 | inferred | S-03 |
| FR-21 | inferred | S-13 |
| NFR-01 | confirmed | S-03 |
| NFR-02 | confirmed | S-02 |
| NFR-03 | inferred | S-13 |
| NFR-04 | inferred | S-13 |
| NFR-05 | author-added | S-02, S-06, S-09 |
| NFR-06 | confirmed | S-01 |
| NFR-07 | author-added | S-08 |
| NFR-08 | author-added | S-04, S-08 |

**29 of 29 covered.** No requirement is uncovered.

**Backward: every story satisfies a requirement that exists in the PRD.** All thirteen do, and the
`Satisfies` fields are the proof. No story invents scope.

**The five constraints carry no stories, deliberately.** CON-01 to CON-05 are inherited limits
rather than work: they are asserted by the acceptance criteria of S-03 (CON-01), S-02 and S-03
(CON-04), S-12 (CON-03) and S-04 (CON-05). CON-02 is not exercised, because no story adds a skill.

## Critical path

**S-01, S-02, S-03**, in that order, then the epics fan out. S-01 and S-02 have no dependencies and
could run concurrently, but neither should start after S-03, because both exist to decide whether
S-03 is the right shape at all.
