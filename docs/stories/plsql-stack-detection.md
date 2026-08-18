# Stories: detect PL/SQL projects

| | |
|---|---|
| Derived from | `docs/prd/plsql-stack-detection.md`, PRD status `approved` |
| Date | 2026-08-18 |
| Stories | 8 (build: 6, verify: 1, fix: 0, decide: 1) |
| Coverage | 17 of 17 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> The PRD is approved and every requirement in it is `confirmed`, so no story here is provisional.

**The one `decide` story does not block anything, which is unusual and deliberate.** `S-08` carries
the risk `A7` records: an Oracle codebase of pure table DDL, using none of the three tokens, is now
missed. Answering it needs a real Oracle repository, which is not reachable from here, so it is
filed rather than treated as a blocker. Every other story can start today.

---

## Epic E-01: The marker

**Goal:** `detect_languages` reports `plsql` on an Oracle repository and stays silent on everything
else, including the manifest-less SQL repositories that are the hard case.
**Requirements:** FR-01, FR-02, FR-03, FR-04, FR-10, FR-11, FR-12, FR-13, NFR-01, NFR-02, NFR-03, NFR-04
**Stories:** S-01, S-02, S-03
**Ships when:** all three pass together.

**`S-01` must not ship without `S-02`.** On its own the marker is the filename rule, which labels a
manifest-less PostgreSQL migrations repository as Oracle. That is the false positive `FR-12` exists
to remove, and shipping the halves separately would put a known mislabel in a release.

### S-01 Report `plsql` on a manifest-less, SQL-dominant tree

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01, FR-02, FR-03, FR-10, FR-11, NFR-03 |
| Size | L |
| Depends on | nothing |
| Status of requirement | all confirmed |

**As an** engineer running `keel init` on an Oracle codebase
**I want** the profile to name the language instead of leaving it `unknown`
**So that** the skills that read `stack.language` have something to work from

**Acceptance criteria**

```gherkin
Scenario: an Oracle-shaped tree is detected
  Given a repository with no manifest for any of the thirteen languages
  And 191 .sql files, more than any other extension
  And at least one containing an Oracle-exclusive token
  When detect_languages runs
  Then it reports plsql

Scenario: a declared language always wins
  Given a repository with package.json and tsconfig.json
  And 20 .sql files against 379 .ts files
  When detect_languages runs
  Then it reports typescript
  And it does not report plsql

Scenario: a manifest suppresses the marker whatever the SQL count
  Given a repository with a go.mod
  And 500 .sql files and 3 .go files
  When detect_languages runs
  Then it does not report plsql

Scenario: below the floor, nothing is claimed
  Given a repository with no manifest and 9 .sql files
  When detect_languages runs
  Then it reports no language at all

Scenario: SQL present but not dominant
  Given a repository with no manifest, 12 .sql files and 40 .md files
  When detect_languages runs
  Then it does not report plsql

Scenario: plsql is the only language reported
  Given a repository detected as plsql
  When detect_also runs
  Then it outputs nothing
```

**Notes:** the accumulator assignment must be spelled `out="$out plsql"`. `FR-10` exists because
`tests/validate-skills.sh:367-368` extracts the language list by matching that exact spelling, and
`:369-375` records that a different spelling disables the tool-table rule silently rather than
breaking it.

### S-02 Require an Oracle-exclusive token in the tree

| | |
|---|---|
| Kind | build |
| Satisfies | FR-12, FR-13, NFR-03 |
| Size | M |
| Depends on | S-01 |
| Status of requirement | all confirmed |

**As an** engineer on a PostgreSQL migrations repository with no manifest
**I want** keel to leave my project alone
**So that** it is not labelled Oracle on the strength of a file extension

**Acceptance criteria**

```gherkin
Scenario: VARCHAR2 satisfies the signal
  Given a manifest-less, SQL-dominant tree whose only Oracle token is VARCHAR2
  When detect_languages runs
  Then it reports plsql

Scenario: DBMS_ satisfies the signal
  Given a manifest-less, SQL-dominant tree whose only Oracle token is DBMS_OUTPUT
  When detect_languages runs
  Then it reports plsql

Scenario: PACKAGE BODY satisfies the signal
  Given a manifest-less, SQL-dominant tree whose only Oracle token is PACKAGE BODY
  When detect_languages runs
  Then it reports plsql

Scenario: the match ignores case
  Given a manifest-less, SQL-dominant tree containing only lowercase varchar2
  When detect_languages runs
  Then it reports plsql

Scenario: PL/pgSQL is not mistaken for Oracle
  Given a manifest-less, SQL-dominant tree using %TYPE and %ROWTYPE and no Oracle token
  When detect_languages runs
  Then it does not report plsql

Scenario: no Oracle token anywhere
  Given a manifest-less, SQL-dominant tree of plain CREATE TABLE statements
  When detect_languages runs
  Then it does not report plsql
```

**Notes:** the fifth scenario is the whole point of this story. `%TYPE` and `%ROWTYPE` were proposed
as Oracle signals and rejected, because PL/pgSQL supports both, so including them would readmit the
false positive. The scan stops at the first matching file (`FR-13`).

### S-03 Pay nothing for the census on a project that declares itself

| | |
|---|---|
| Kind | build |
| Satisfies | FR-04, NFR-01, NFR-02, NFR-04, NFR-03 |
| Size | M |
| Depends on | S-01 |
| Status of requirement | all confirmed |

**As an** engineer running `keel init` on a large TypeScript monorepo
**I want** PL/SQL detection to cost me nothing
**So that** a feature for a language I do not use does not slow down my setup

**Acceptance criteria**

```gherkin
Scenario: a declared project never reaches the census
  Given a repository with a package.json
  When detect_languages runs
  Then the extension census is not performed

Scenario: vendored directories are not counted
  Given a manifest-less repository with 12 .sql files
  And a node_modules directory containing 900 .js files
  When detect_languages runs
  Then it reports plsql

Scenario: the git directory is not counted
  Given a manifest-less repository with 12 .sql files and a populated .git directory
  When detect_languages runs
  Then it reports plsql

Scenario: the census is one pass
  Given a manifest-less repository
  When detect_languages runs
  Then the tree is walked once rather than once per extension
```

**Notes:** there is no timed assertion anywhere in this story, by decision. A wall-clock test fails
on a loaded CI runner for reasons unrelated to the code; these four properties bound the same cost
and a fixture can assert them.

---

## Epic E-02: The profile fields

**Goal:** a detected PL/SQL project gets a profile that describes it, and admits what it does not
know.
**Requirements:** FR-05, FR-06, FR-07, FR-08
**Stories:** S-04, S-05, S-06
**Ships when:** `keel init` on an Oracle-shaped fixture writes language `plsql`, runtime `oracle`,
datastore `oracle`, and leaves every verify command `null`.

### S-04 Fill in the stack row for PL/SQL

| | |
|---|---|
| Kind | build |
| Satisfies | FR-05, FR-06 |
| Size | M |
| Depends on | S-01 |
| Status of requirement | all confirmed |

**As a** skill reading `stack` from the profile
**I want** runtime and framework populated rather than `unknown`
**So that** I can act without asking the user what the project is

**Acceptance criteria**

```gherkin
Scenario: the ordinary PL/SQL project
  Given a repository detected as plsql with no apex-export manifest
  When lang_profile plsql runs
  Then it outputs language plsql, runtime oracle, framework none, package manager none

Scenario: an APEX export tree
  Given a repository detected as plsql
  And a manifest.json at the root containing "apex_version"
  When lang_profile plsql runs
  Then it outputs framework apex

Scenario: a manifest.json that is not an APEX export
  Given a repository detected as plsql
  And a manifest.json at the root with no apex_version key
  When lang_profile plsql runs
  Then it outputs framework none
```

**Notes:** the APEX marker is keel's own output, written by `lib/apex_render.py:646` and pinned by
`tests/test-apex-export.sh:56`, so it is self-declaring and cannot false-positive. The third
scenario is what stops any other `manifest.json` claiming to be APEX.

### S-05 Record Oracle as the datastore

| | |
|---|---|
| Kind | build |
| Satisfies | FR-07 |
| Size | M |
| Depends on | S-01 |
| Status of requirement | confirmed |

**As a** skill that needs to know where the data lives
**I want** `stack.datastores` to say `oracle` on an Oracle project
**So that** I do not have to infer it from the language

**Acceptance criteria**

```gherkin
Scenario: a detected PL/SQL project names its datastore
  Given a repository detected as plsql
  When detect_datastores runs
  Then its output includes oracle

Scenario: a project that is not PL/SQL gains nothing
  Given a TypeScript repository with a package.json and 20 .sql files
  When detect_datastores runs
  Then its output does not include oracle

Scenario: the existing datastore detection is unchanged
  Given a Python repository declaring psycopg
  When detect_datastores runs
  Then its output includes postgres
  And it does not include oracle
```

**Notes:** this cannot reuse the existing mechanism. `detect_datastores` greps dependency manifests
and returns early when none exist (`CON-04`), so it can never reach a PL/SQL repository. The source
idea asserted an `oracle` pair already existed there; it does not, and this is new work keyed on the
marker from `S-01`.

### S-06 Leave every verify command null

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-08 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | confirmed |

**As an** engineer on an Oracle project
**I want** keel to admit it cannot run my tests
**So that** a skill asks me for the connection details instead of running something that fails

**Acceptance criteria**

```gherkin
Scenario: no test command is invented
  Given a repository detected as plsql with a tests/run_all_tests.sql
  When keel init runs
  Then verify.test is null
  And verify.test_one is null
  And verify.lint is null
  And verify.typecheck is null
  And verify.build is null
```

**Notes:** this is a `verify` story because the behaviour is already correct by construction:
`detect_verify` is keyed on manifests, so an unknown or manifest-less language yields nothing. What
is missing is a test saying so. If it fails, it becomes a `fix` and the notes say so rather than the
`verify` quietly growing. The presence of a real utPLSQL suite in the fixture is deliberate: it is
the case most likely to tempt a future change into guessing a command.

---

## Epic E-03: The reference tables

**Goal:** a reader looking up PL/SQL tooling finds an answer rather than a gap.
**Requirements:** FR-09
**Stories:** S-07
**Ships when:** `tests/validate-skills.sh` passes with `plsql` in `detect_languages`.

### S-07 Answer PL/SQL in all three tool tables

| | |
|---|---|
| Kind | build |
| Satisfies | FR-09 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | confirmed |

**As an** engineer or a skill choosing tooling for a PL/SQL project
**I want** the tool tables to say what to use, including where the answer is nothing
**So that** an absent row is not mistaken for an oversight

**Acceptance criteria**

```gherkin
Scenario: the build gate is satisfied
  Given plsql is reported by detect_languages
  When tests/validate-skills.sh runs
  Then it reports no missing tool-choices row

Scenario: all three tables answer
  Given skills/keel/references/tool-choices.md
  Then the test runner table has a plsql row naming utPLSQL
  And the lint table has a plsql row whose pick is none
  And the typecheck table has a plsql row whose pick is none

Scenario: each none carries a reason
  Given the plsql rows in the lint and typecheck tables
  Then each states why no tool is picked rather than leaving the cell empty
```

**Notes:** `CON-01` requires only one row anywhere in the file, so two of these three are a
deliberate choice rather than a build requirement. The typecheck table already carries `none` rows
with reasons for `ruby` and `lua`, so this follows established practice.

---

## Epic E-04: The risk that outlives the change

**Goal:** the one unchecked assumption is owned rather than forgotten.
**Requirements:** none. This epic carries `A7` and `Q7`, which are an assumption and a question
rather than requirements.
**Stories:** S-08
**Ships when:** a written answer exists, whether or not it changes the code.

### S-08 Decide whether the token set is wide enough

| | |
|---|---|
| Kind | decide |
| Satisfies | none. It settles `A7` and `Q7` |
| Size | S |
| Depends on | nothing, and it blocks nothing |
| Status of requirement | not a requirement |

**As** whoever owns keel's detection accuracy
**I want** the three-token set checked against a real Oracle codebase
**So that** we know whether `FR-12` trades a false positive for a false negative

**Acceptance criteria**

```gherkin
Scenario: the token set is checked against a real repository
  Given access to an Oracle repository not written by keel
  When its .sql files are searched for VARCHAR2, DBMS_ and PACKAGE BODY
  Then the result is recorded as a written decision
  And the decision either widens the token set in FR-12 or accepts it as it stands
```

**Notes:** this produces a decision, not code. It is a **requirement value** rather than an
architectural choice, so the answer belongs in `FR-12` and its `Evidence` column, not in an ADR.
Neither known Oracle repository was reachable while the PRD was written, which is why the assumption
is unchecked rather than confirmed.

Ordering note: `decide` stories normally come first, because building on an undecided requirement is
rework. This one is last on purpose. `FR-12` is decided and testable as written; `Q7` asks whether
it should later be widened, which is a question about a future revision rather than a blocker on
this one.

---

## Order and critical path

| # | Story | Why here |
|---|---|---|
| 1 | S-01 | Everything else keys off the marker |
| 2 | S-02 | Completes the marker. E-01 does not ship without it |
| 3 | S-03 | The cost properties of the same walk |
| - | S-04, S-05, S-06, S-07 | Parallel, after S-01 |
| - | S-08 | Any time. Blocks nothing, and needs access nobody has yet |

**Critical path:** S-01, S-02, S-03.

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | confirmed | S-01, S-02 | Clauses one to three in S-01, clause four in S-02 |
| FR-02 | confirmed | S-01 | |
| FR-03 | confirmed | S-01 | |
| FR-04 | confirmed | S-03 | |
| FR-05 | confirmed | S-04 | |
| FR-06 | confirmed | S-04 | |
| FR-07 | confirmed | S-05 | |
| FR-08 | confirmed | S-06 | `verify` kind: the behaviour is believed correct and untested |
| FR-09 | confirmed | S-07 | |
| FR-10 | confirmed | S-01 | |
| FR-11 | confirmed | S-01 | |
| FR-12 | confirmed | S-02 | |
| FR-13 | confirmed | S-02 | |
| NFR-01 | confirmed | S-03 | |
| NFR-02 | confirmed | S-03 | |
| NFR-03 | confirmed | S-01, S-02, S-03 | Asserted wherever a new command could creep in |
| NFR-04 | confirmed | S-03 | |
| CON-01 | confirmed | none | Constraint. S-07 is what keeps it satisfied |
| CON-02 | confirmed | none | Constraint. S-06 asserts it holds for PL/SQL |
| CON-03 | confirmed | none | Constraint imposed by the catalogue. No story, and no code |
| CON-04 | confirmed | none | Constraint. It is why S-05 is new work rather than a pair in a list |
| CON-05 | confirmed | none | Constraint. It is the reason S-02 exists at all |

**Forward:** 17 of 17 requirements have at least one story. All 13 `FR` and all 4 `NFR` entries are
covered. The 5 `CON` entries have no stories, which is correct: a constraint is something the work
must not violate. Each names where it is honoured rather than being left blank.

**Backward:** every story's `Satisfies` names a requirement that exists in
`docs/prd/plsql-stack-detection.md`, except `S-08`, which is a `decide` story that settles an
assumption and a question and says so in place of an ID.
