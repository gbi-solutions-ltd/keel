# Stories: keel profile sync

| | |
|---|---|
| Derived from | `docs/prd/profile-sync.md`, PRD status `approved` |
| Date | 2026-08-30 |
| Stories | 9 (build: 8, verify: 1, fix: 0, decide: 0) |
| Coverage | 19 of 19 `FR` and `NFR` covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> The PRD is approved, so these are not provisional. Seven of the sixteen requirements behind them
> are `inferred` rather than confirmed, and each story names which of its own are.

**No `decide` stories, and that is deliberate.** The PRD's two remaining open questions block
nothing: Q2 asks whether `sync` needs its own fixture and is owned by `write-plan`, Q3 records a
future schema decision that FR-04 and CON-05 have already ruled out of this piece of work.

---

## Epic E-01: a repository can make its profile true in one command

**Goal:** on a repository that already holds its documents, one command fills the artifact keys that
have a single unambiguous home, and running it twice changes nothing.
**Requirements:** FR-01 to FR-09, FR-13 to FR-16, NFR-01, NFR-02
**Stories:** S-01 to S-07
**Ships when:** `keel profile sync` on this repository fills `decisions` and `plans`, leaves
`snapshot` null because `docs/snapshot.md` does not exist, and a second run reports no change.

### S-01 `keel profile sync` fills the artifact keys whose default is present

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01, FR-03, FR-05, FR-09, FR-15, NFR-01, NFR-02 |
| Size | M |
| Depends on | none |
| Status of requirement | FR-01 confirmed, FR-03 confirmed, FR-05 inferred, FR-09 inferred, FR-15 inferred, NFR-01 inferred, NFR-02 inferred |

**As a** developer on a repository that already holds its documents
**I want** one command to record where they are in the profile
**So that** a skill reading the map finds them instead of authoring a second copy

**Acceptance criteria**

```gherkin
Scenario: the snapshot is at its default location
  Given a repository with docs_root "docs" and a file "docs/snapshot.md"
  And artifacts.snapshot is null
  When keel profile sync runs
  Then artifacts.snapshot is "docs/snapshot.md"

Scenario: the decisions and plans directories hold documents
  Given "docs/decisions" holds 3 files and "docs/plans" holds 14
  And both keys are null
  When keel profile sync runs
  Then artifacts.decisions is "docs/decisions"
  And artifacts.plans is "docs/plans"

Scenario: a default location that is absent
  Given no file exists at "docs/snapshot.md"
  And artifacts.snapshot is null
  When keel profile sync runs
  Then artifacts.snapshot is still null

Scenario: docs_root is not "docs"
  Given docs_root is "documentation" and "documentation/snapshot.md" exists
  When keel profile sync runs
  Then artifacts.snapshot is "documentation/snapshot.md"

Scenario: the path written is relative to the repository root
  Given the command is run from the repository root
  When keel profile sync writes any key
  Then the value written starts with docs_root and is not an absolute path
```

**Notes:** NFR-02 says the write goes through `profile_set` (`bin/keel:973-1017`) rather than a
second writer, so the file's formatting matches what `keel profile set` produces. CON-01: every
`artifacts.*` key is already seeded by `write_profile` at `bin/keel:445-448`, so `profile_set`'s
refusal of unknown paths (`:990-998`) is not in the way. NFR-01 needs no work of its own, only the
absence of a new dependency, which the coverage table records against this story.

**A choice this story makes:** a directory key is written without a trailing slash, `docs/decisions`
rather than `docs/decisions/`. Doctor's `[ -e "$path" ]` accepts either. Pinned here so the test is
unambiguous, and cheap to change if anyone prefers the other.

### S-02 A key that is already set is never touched, and a second run changes nothing

| | |
|---|---|
| Kind | build |
| Satisfies | FR-02, FR-07 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | FR-02 inferred, FR-07 inferred |

**As a** developer who has mapped a document to a non-default path by hand
**I want** sync to leave my value alone
**So that** the override the map exists for survives a command that means to help

**Acceptance criteria**

```gherkin
Scenario: a key already holds a deliberate override
  Given artifacts.snapshot is "wiki/overview.md"
  And "docs/snapshot.md" also exists
  When keel profile sync runs
  Then artifacts.snapshot is still "wiki/overview.md"

Scenario: a second run against an unchanged tree
  Given keel profile sync has already run and filled two keys
  When keel profile sync runs again
  Then no key changes
  And the profile file is byte-identical to before the second run
```

**Notes:** the byte-identical assertion is the honest form of idempotent. A run that rewrites the
same values through a JSON dump can still reorder or reformat, and that shows up as a spurious diff
on a tracked file.

### S-03 The three keys that cannot be filled truthfully are skipped, with the reason said

| | |
|---|---|
| Kind | build |
| Satisfies | FR-04 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | confirmed |

**As a** developer wondering why my PRD is not in the profile
**I want** sync to tell me it deliberately skipped that key
**So that** I do not report a bug against a decision

**Acceptance criteria**

```gherkin
Scenario: the repository holds several PRDs
  Given "docs/prd" holds 5 files and artifacts.prd is null
  When keel profile sync runs
  Then artifacts.prd is still null
  And the output says prd, stories and architecture are skipped
  And the output gives the reason: their default is one file per slug, so there is no single path

Scenario: the repository holds exactly one PRD
  Given "docs/prd" holds 1 file and artifacts.prd is null
  When keel profile sync runs
  Then artifacts.prd is still null
```

**Notes:** the second scenario is the one that can fail quietly. A repository with exactly one PRD
looks fillable, and filling it would be right today and wrong the moment a second PRD is written.
FR-04 is about the shape of the default, not about how many documents happen to be there.

### S-04 An empty directory does not count as present

| | |
|---|---|
| Kind | build |
| Satisfies | FR-06 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | confirmed, was author-added |

**As a** developer on a repository with an empty `docs/decisions/`
**I want** the key left null
**So that** the profile does not claim a document set that does not exist

**Acceptance criteria**

```gherkin
Scenario: the directory exists but is empty
  Given "docs/decisions" exists and holds no files
  And artifacts.decisions is null
  When keel profile sync runs
  Then artifacts.decisions is still null

Scenario: the directory holds only what keel init scaffolded
  Given a freshly initialised project whose decisions directory holds only ADR-0000-template.md
  When keel profile sync runs
  Then artifacts.decisions is still null

Scenario: the directory holds one real document
  Given "docs/decisions" holds ADR-0001-something.md
  When keel profile sync runs
  Then artifacts.decisions is "docs/decisions"
```

**Notes:** FR-06 was invented by the author and kept by Bernard on 2026-08-30. Its row in the PRD
carries `was author-added` for that reason, and this story is the cheapest thing to delete if the
rule is ever reversed.

**The second scenario was added 2026-08-30 while planning**, after a scratch `keel init` showed that
`<docs_root>/decisions/ADR-0000-template.md` is scaffolded, so the directory is never empty on a
fresh project. Without it, every newly initialised project would have carried a standing doctor
warning and a key pointing at a template. FR-06 was amended the same day, asked as a choice.

### S-05 sync reports what it did, and its exit code means what it says

| | |
|---|---|
| Kind | build |
| Satisfies | FR-08, FR-16 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | FR-08 inferred, FR-16 inferred |

**As a** developer reviewing a diff on a tracked file
**I want** the command to have told me what it changed
**So that** an edit to `.keel/profile.json` is never a surprise

**Acceptance criteria**

```gherkin
Scenario: two keys are filled
  Given decisions and plans are fillable and snapshot is not
  When keel profile sync runs
  Then the output names decisions and the path written
  And the output names plans and the path written
  And the command exits 0

Scenario: nothing is fillable
  Given every artifact key is already set
  When keel profile sync runs
  Then the output says no key changed
  And the command exits 0
```

**Notes:** FR-16 is why the second scenario asserts the exit code. Filling nothing is the correct
outcome on a repository that is already in order, and an exit 1 there would fail anyone's pre-push
hook for a state that is fine.

### S-06 sync refuses cleanly where `get` and `set` already do

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-14, FR-01 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | FR-14 inferred, FR-01 confirmed |

**As a** developer running sync in the wrong directory
**I want** the same message `keel profile get` would give me
**So that** one subcommand does not invent its own vocabulary for a shared failure

**Acceptance criteria**

```gherkin
Scenario: no profile in this directory
  Given no ".keel/profile.json" exists
  When keel profile sync runs
  Then it fails with the message "no .keel/profile.json here. Run 'keel init'."

Scenario: an unknown profile subcommand still names the real ones
  When "keel profile frobnicate" runs
  Then it fails with a message naming get, set and sync
```

**Notes:** `verify` rather than `build` because `cmd_profile` already guards the missing-profile
case at `bin/keel:1019-1020` and `sync` inherits it by entering through the same function. The work
is a test proving it, plus the one word added to the unknown-subcommand message, which is the only
part not already true.

**Why the second scenario traces to FR-01.** It was written before it had a requirement, which is
invented scope, and the honest fix was to find the requirement or delete the scenario. FR-01 says
`sync` must exist "as a third subcommand of `keel profile`, beside `get` and `set`", and a
subcommand whose own sibling error message denies it exists is not beside them. `bin/keel:1027`
currently reads "Try get or set.".

### S-07 A monorepo leaves `snapshot` null

| | |
|---|---|
| Kind | build |
| Satisfies | FR-13 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | confirmed |

**As a** developer on a monorepo whose snapshots are per unit
**I want** the key left null rather than pointed at one unit
**So that** the profile does not name one unit's snapshot as the repository's

**Acceptance criteria**

```gherkin
Scenario: per-unit snapshots and no root snapshot
  Given "docs/snapshot-api.md" and "docs/snapshot-web.md" exist
  And "docs/snapshot.md" does not exist
  When keel profile sync runs
  Then artifacts.snapshot is still null

Scenario: a root snapshot beside the per-unit ones
  Given "docs/snapshot.md" and "docs/snapshot-api.md" both exist
  When keel profile sync runs
  Then artifacts.snapshot is "docs/snapshot.md"
```

**Notes:** settles the idea record's open question 2. The second scenario is what stops a naive
glob: `snapshot*.md` would match the per-unit files and pick one, and the requirement is that only
the exact default counts.

---

## Epic E-02: anyone who needs the command finds out it exists

**Goal:** a developer who has never heard of `sync` learns about it from a tool they already run.
**Requirements:** FR-10, FR-11, FR-12, NFR-03
**Stories:** S-08, S-09
**Ships when:** `keel doctor` on a repository with a fillable null key prints a warning naming the
command, and `keel --help` lists it.

### S-08 doctor reports a null key whose default is present

| | |
|---|---|
| Kind | build |
| Satisfies | FR-10, FR-11, NFR-03 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | FR-10 confirmed, FR-11 inferred, NFR-03 inferred |

**As a** developer running doctor before shipping
**I want** to be told the profile does not know about documents that are sitting in `docs/`
**So that** I learn the remedy without having read the changelog

**Acceptance criteria**

```gherkin
Scenario: a fillable key is null
  Given "docs/plans" holds 14 files and artifacts.plans is null
  When keel doctor runs
  Then it warns that artifacts.plans is null while docs/plans exists
  And the warning names "keel profile sync"
  And doctor does not fail because of it

Scenario: an unfillable key is null
  Given "docs/prd" holds 5 files and artifacts.prd is null
  When keel doctor runs
  Then no warning is printed about artifacts.prd

Scenario: the fast path still reports it
  Given a fillable key is null
  When "keel doctor --fast" runs
  Then the warning is printed
```

**Notes:** FR-11 is the second scenario and it is the one worth guarding. A warning naming a remedy
that FR-04 forbids would send people to a command that deliberately does nothing for them. Shape
follows the `stack.has_ui` warning at `bin/keel:1390`, which is a warning and never a failure for
the same reason: nothing is broken.

### S-09 `keel --help` lists sync

| | |
|---|---|
| Kind | build |
| Satisfies | FR-12 |
| Size | S |
| Depends on | S-01 |
| Status of requirement | confirmed, was author-added |

**As a** developer reading `keel --help`
**I want** sync listed beside get and set
**So that** the command is discoverable without already having the problem it solves

**Acceptance criteria**

```gherkin
Scenario: the profile line names all three subcommands
  When "keel --help" runs
  Then the profile line names get, set and sync
```

**Notes:** one scenario, because there is one observable outcome. `bin/keel:1881` is the line.

---

## Order and critical path

**Critical path: S-01.** Everything else depends on it, and nothing else depends on anything else.
Once S-01 lands, S-02 through S-09 can be taken in any order or in parallel.

| Order | Story | Why here |
|---|---|---|
| 1 | S-01 | The command has to exist before any rule about it can be tested |
| 2 | S-03, S-04, S-07 | The three rules about what sync must not fill. Cheapest to get wrong silently |
| 3 | S-02, S-05, S-06 | Behaviour around the edges: overrides, output, refusal |
| 4 | S-08, S-09 | Discovery. Useless before the command works, and the last thing a user meets first |

No `decide` story blocks anything.

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | confirmed | S-01, S-06 | S-06 covers the subcommand being named in `keel profile`'s own error message |
| FR-02 | inferred | S-02 | |
| FR-03 | confirmed | S-01 | |
| FR-04 | confirmed | S-03 | |
| FR-05 | inferred | S-01 | |
| FR-06 | confirmed, was author-added | S-04 | |
| FR-07 | inferred | S-02 | |
| FR-08 | inferred | S-05 | |
| FR-09 | inferred | S-01 | |
| FR-10 | confirmed | S-08 | |
| FR-11 | inferred | S-08 | |
| FR-12 | confirmed, was author-added | S-09 | |
| FR-13 | confirmed | S-07 | |
| FR-14 | inferred | S-06 | The only `verify` story |
| FR-15 | inferred | S-01 | |
| FR-16 | inferred | S-05 | |
| NFR-01 | inferred | S-01 | Satisfied by adding no dependency, so it constrains S-01 rather than producing work |
| NFR-02 | inferred | S-01 | Same: it names which writer S-01 uses |
| NFR-03 | inferred | S-08 | The `--fast` scenario |
| CON-01 | confirmed | none | Constraint, not work. Correctly uncovered |
| CON-02 | confirmed | none | Constraint. S-08 respects it by warning rather than writing |
| CON-03 | confirmed | none | Constraint. No story touches a skill body, which is the point of the whole variant |
| CON-04 | confirmed | none | Constraint. No story adds a hook |
| CON-05 | confirmed | none | Constraint. No story changes the schema |

**Forward:** 19 of 19 `FR` and `NFR` requirements have at least one story. None uncovered. The five
`CON` entries have no stories, which is correct: they are constraints on how the work is done, not
work. CON-02 and CON-03 are the two a plan could violate without noticing, so both are named against
the stories that could do it.

**Backward:** every story's `Satisfies` names a requirement that exists in `docs/prd/profile-sync.md`.
No story satisfies nothing.
