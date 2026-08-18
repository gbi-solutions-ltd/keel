# Stories: the profile a user can actually use

| | |
|---|---|
| Derived from | `docs/prd/usable-profile.md`, PRD status `approved` |
| Date | 2026-08-18 |
| Stories | 13 (build: 7, verify: 5, fix: 1) |
| Coverage | 16 of 16 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> The PRD is approved, so these stories are not provisional. Five of the sixteen requirements they
> satisfy are `inferred`, and each story names which.

**There are no `decide` stories.** The PRD's Q1 and Q2 were answered before approval and became
`FR-02`, `FR-06` and `FR-12`. Q4 was answered while writing these stories: the hardcoded fallback
stays, so a profile written before this change keeps being checked against the three official
plugins. Q3 and Q5 block nothing and are recorded in the PRD.

**Where each check lives, and why it is not a free choice.** `tests/validate-skills.sh` is the fast
check that runs on every commit and must not grow a `keel init` run. `tests/test-keel.sh` already
runs `init` 117 times and takes about 210 seconds. So the schema and description half is checked in
the fast validator, and anything needing a real profile is checked in the slow suite. S-05 and S-04
are split along that line rather than by subject.

---

## Epic E-01: The schema describes itself

**Goal:** every key a user can set says what it does, in the file that defines it.
**Requirements:** FR-01
**Stories:** S-01
**Ships when:** no declared leaf key has an empty `description`.

### S-01 Every declared key carries a description

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01 |
| Size | L |
| Depends on | none |
| Status of requirement | FR-01 confirmed |

**As a** developer adjusting a profile
**I want** every key to say what it does and what happens if I change it
**So that** I can decide whether it applies to my project without reading keel's source

**Acceptance criteria**

```gherkin
Scenario: no key is left bare
  Given templates/profile.schema.json
  When every leaf key under properties is read
  Then each one has a description of at least one sentence

Scenario: a description says what changing it does
  Given the description of gates.context_watch
  When it is read
  Then it states what the key controls and what happens when it is false

Scenario: the existing descriptions are not disturbed
  Given the 24 keys that already had a description
  When the change is diffed
  Then their text is unchanged unless it was wrong
```

**Notes:** 35 of 59 are empty, counted 2026-08-18. This is the bulk of the work in the whole PRD and
it is writing rather than code. It stays one story because the zero-empty-descriptions assertion in
S-05 only passes when all 35 are done, so a half-finished split delivers nothing. If a reviewer
wants smaller units, split by schema section (`stack`, `verify`, `gates`, `deploy`, `conventions`,
`artifacts`) and expect the gate to stay red until the last one lands. `CON-01`: this needs no
`SCHEMA_VERSION` bump, because the validator fingerprints key paths and not descriptions.

---

## Epic E-02: A reference a user can read

**Goal:** the profile's keys are discoverable without opening a JSON Schema.
**Requirements:** FR-02, FR-03, FR-04, FR-05, FR-06, FR-12, NFR-01, NFR-04
**Stories:** S-02, S-03, S-04, S-05, S-06, S-07
**Ships when:** `docs/profile-keys.md` is committed, linked from the README, and a schema edit that
is not reflected in it fails the build.

### S-02 A script generates the reference from the schema

| | |
|---|---|
| Kind | build |
| Satisfies | FR-03, FR-12, NFR-04 |
| Size | M |
| Depends on | none |
| Status of requirement | FR-03 confirmed, FR-12 confirmed, NFR-04 inferred |

**As a** maintainer editing the schema
**I want** the reference produced from it rather than written alongside it
**So that** the two cannot say different things

**Acceptance criteria**

```gherkin
Scenario: every declared key reaches the page
  Given templates/profile.schema.json
  When the generator runs
  Then its output contains a row for each declared leaf key, with the key's type and description

Scenario: a key the schema does not declare is omitted
  Given that keel init writes artifacts._note and the schema does not declare it
  When the generator runs
  Then artifacts._note does not appear in the output

Scenario: generation is deterministic
  Given an unchanged schema
  When the generator runs twice
  Then both runs produce identical bytes

Scenario: no network and no key
  Given no network access and no ANTHROPIC_API_KEY
  When the generator runs
  Then it succeeds
```

**Notes:** the last scenario is `NFR-01`, asserted here because it is a property of the generator
rather than of the page. `tests/validate-skills.sh:279-280` records why: a check that only runs
where an API key happens to exist is absent exactly where nobody is watching.

### S-03 The reference is committed and readable

| | |
|---|---|
| Kind | build |
| Satisfies | FR-02 |
| Size | S |
| Depends on | S-01, S-02 |
| Status of requirement | FR-02 confirmed |

**As a** developer who has just run `keel init`
**I want** one page listing every key with its description
**So that** I can adjust the profile without reading the schema or the source

**Acceptance criteria**

```gherkin
Scenario: the page exists and is complete
  Given docs/profile-keys.md
  When it is read
  Then it lists every leaf key the schema declares, each with its type and description

Scenario: the page says it is generated
  Given docs/profile-keys.md
  When its header is read
  Then it names the script that produces it and says not to edit it by hand
```

**Notes:** depends on S-01 because a page generated before the descriptions exist is 59 percent
blank, which is worse than no page.

### S-04 The page says which keys keel writes and which are yours

| | |
|---|---|
| Kind | build |
| Satisfies | FR-05 |
| Size | M |
| Depends on | S-02, S-03 |
| Status of requirement | FR-05 inferred |

**As a** developer reading the reference
**I want** to see at a glance which keys `keel init` fills in
**So that** I know which ones are mine to add and which will be regenerated

**Acceptance criteria**

```gherkin
Scenario: the split is shown
  Given docs/profile-keys.md
  When a key that keel init writes is read
  Then its row is marked as written by init

Scenario: a key only a human sets is marked as such
  Given the row for plugins.recommended before this PRD's plugin work lands
  When it is read
  Then it is marked as one a human adds

Scenario: the column is derived, not maintained by hand
  Given a fixture repository
  When keel init runs in it and the resulting profile is compared with the page's column
  Then every key agrees
```

**Notes:** the third scenario is the point of the story and it needs a real `init` run, so it
belongs in `tests/test-keel.sh` rather than the fast validator. There were eleven human-only keys on
2026-08-18, down from twelve when the idea was written, because the context window work moved
`gates.context_window` into the written column. That is exactly the drift a hand-maintained list
would have carried.

### S-05 A schema edit that skips the page fails the build

| | |
|---|---|
| Kind | build |
| Satisfies | FR-04 |
| Size | S |
| Depends on | S-03 |
| Status of requirement | FR-04 confirmed |

**As a** maintainer adding a key
**I want** the build to stop when I forget to regenerate the page
**So that** the reference cannot quietly become wrong

**Acceptance criteria**

```gherkin
Scenario: the page and the schema agree
  Given a committed page generated from the current schema
  When tests/validate-skills.sh runs
  Then it passes

Scenario: a key added to the schema and not to the page
  Given a key added to templates/profile.schema.json
  And the page not regenerated
  When tests/validate-skills.sh runs
  Then it fails, naming the key and the command that regenerates the page

Scenario: a description edited in the schema and not in the page
  Given a changed description in templates/profile.schema.json
  And the page not regenerated
  When tests/validate-skills.sh runs
  Then it fails

Scenario: no key is left with an empty description
  Given templates/profile.schema.json
  When tests/validate-skills.sh runs
  Then it fails if any declared leaf key has no description
```

**Notes:** the last scenario is the gate for S-01 and is why S-01 cannot half-land. This rule goes in
the fast validator, which must not grow a `keel init` run; the written-by-init column is checked in
S-04 instead. Same shape as the existing tool-table rule at `tests/validate-skills.sh:341-345`.

### S-06 The reference is reachable from the README

| | |
|---|---|
| Kind | build |
| Satisfies | FR-06 |
| Size | S |
| Depends on | S-03 |
| Status of requirement | FR-06 inferred |

**As a** developer who does not know the reference exists
**I want** the README to point at it
**So that** the page solves the discovery problem rather than repeating it

**Acceptance criteria**

```gherkin
Scenario: the README links it
  Given README.md
  When it is read
  Then it links docs/profile-keys.md in the section describing the profile

Scenario: the link resolves
  Given the link in README.md
  When the target is checked
  Then docs/profile-keys.md exists
```

**Notes:** `A3` of the PRD, that a reader who cannot find a key will look at a linked reference, is
untested and this story is its only expression. If the assumption is wrong, this is the story that
was wasted.

### S-07 Generation needs nothing but the repository

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-01 |
| Size | S |
| Depends on | S-02 |
| Status of requirement | NFR-01 inferred |

**As a** contributor on a fresh clone
**I want** to regenerate the page without credentials or a network
**So that** the check is not absent exactly where nobody is watching

**Acceptance criteria**

```gherkin
Scenario: the generator makes no outbound request
  Given the generator's source
  When it is read
  Then it opens no socket and invokes no network client

Scenario: it runs with no API key set
  Given ANTHROPIC_API_KEY is unset
  When the generator runs
  Then it succeeds and produces the same bytes as with one set
```

---

## Epic E-03: Plugins are recommended, and the gap is reported

**Goal:** a project is told which plugins it is missing, including on a repository that already had
a settings file.
**Requirements:** FR-07, FR-08, FR-09, FR-10, FR-11, NFR-02
**Stories:** S-08, S-09, S-10, S-11, S-12
**Ships when:** `keel doctor` on a repository with a pre-existing `.claude/settings.json` names the
missing language server and the command that installs it.

### S-08 Init records the plugins this project expects

| | |
|---|---|
| Kind | build |
| Satisfies | FR-07 |
| Size | S |
| Depends on | none |
| Status of requirement | FR-07 confirmed |

**As a** developer initialising a project
**I want** the profile to record which plugins suit my stack
**So that** doctor has something to check against other than a generic list

**Acceptance criteria**

```gherkin
Scenario: a TypeScript project records its language server
  Given a repository with package.json declaring typescript
  When keel init -y runs
  Then the profile's plugins.recommended contains typescript-lsp@claude-plugins-official

Scenario: a polyglot project records one server per language
  Given a repository with both go.mod and package.json
  When keel init -y runs
  Then plugins.recommended contains both gopls-lsp and typescript-lsp

Scenario: the generated profile is still valid
  Given any fixture
  When keel init -y runs
  Then the profile parses as JSON and keel reports no invalid profile
```

**Notes:** `detect_plugins` (`lib/detect-stack.sh:601-608`) already computes this list and
`write_settings` already uses it. Only the profile writer is missing. `plugins` is already declared
in the schema, so no `SCHEMA_VERSION` bump.

### S-09 Doctor reports the gap on a repository that already had a settings file

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-08 |
| Size | M |
| Depends on | S-08 |
| Status of requirement | FR-08 confirmed |

**As a** developer on a mature repository
**I want** to be told which plugins are missing
**So that** the silence that currently looks like health stops looking like health

**Acceptance criteria**

```gherkin
Scenario: a mature repository is told what is missing
  Given a repository with an existing .claude/settings.json that enables nothing
  When keel init -y then keel doctor run
  Then doctor names typescript-lsp as a recommended plugin that is not enabled
  And names keel@gbi as not enabled

Scenario: a fresh repository is quiet
  Given a repository with no .claude/settings.json
  When keel init -y then keel doctor run
  Then doctor names no missing recommended plugin

Scenario: a profile written before this change still gets the generic list
  Given a profile with no plugins.recommended
  When keel doctor runs
  Then it checks the three official plugins as it did before
```

**Notes:** this is `verify` rather than `build` because `plugin_report` (`bin/keel:142-163`) already
does the comparison; S-08 supplies the input it was always meant to have. The third scenario is Q4,
answered 2026-08-18: the hardcoded fallback stays, so an old profile loses nothing and re-running
`keel init` upgrades it.

### S-10 Doctor names the command that fixes it

| | |
|---|---|
| Kind | fix |
| Satisfies | FR-09 |
| Size | S |
| Depends on | S-09 |
| Status of requirement | FR-09 confirmed |

**As a** developer told a plugin is missing
**I want** the command to install it
**So that** the warning is a next step rather than a research task

**Acceptance criteria**

```gherkin
Scenario: the install command is named
  Given a repository missing typescript-lsp
  When keel doctor runs
  Then its output contains the /plugin install command for typescript-lsp

Scenario: nothing missing, nothing said
  Given a repository with every recommended plugin enabled
  When keel doctor runs
  Then it prints no install command
```

**Notes:** `fix` rather than `build` because the message exists at `bin/keel:1242` and says only
"recommended plugin not enabled: X. The skill that uses it degrades to an inline fallback", which
tells the reader what is wrong and not what to do. The pattern to copy is the marketplace nudge at
`bin/keel:1407`, which already names its command.

### S-11 A hand-edited plugin list survives, and settings files are left alone

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-10, FR-11 |
| Size | S |
| Depends on | S-08 |
| Status of requirement | FR-10 inferred, FR-11 confirmed |

**As a** developer who curated the plugin list, or who owns a committed settings file
**I want** keel to leave both alone
**So that** re-running init does not undo my choices or change what loads for everyone who clones

**Acceptance criteria**

```gherkin
Scenario: a curated list survives re-initialisation
  Given a profile whose plugins.recommended was edited by hand
  When keel init -y runs again
  Then plugins.recommended is unchanged

Scenario: an existing settings file gains no plugin entries
  Given a repository with an existing .claude/settings.json
  When keel init -y runs
  Then the file's enabledPlugins is unchanged, and absent if it was absent

Scenario: permissions are still merged into that file
  Given the same repository
  When keel init -y runs
  Then the keel deny and ask rules are present in .claude/settings.json
```

**Notes:** the first scenario asserts existing behaviour (`merge_profile`, `bin/keel:290`). The
second is `FR-11`, the report-only decision: it pins a deliberate non-behaviour, which is the kind
most easily lost to a later "helpful" change. The third is there so a future fix to the second does
not quietly disable the permission merge, which is the one thing that path is for.

### S-12 Doctor stays within its interpreter budget

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-02 |
| Size | S |
| Depends on | S-08, S-10 |
| Status of requirement | NFR-02 confirmed |

**As a** developer running doctor
**I want** it to stay fast
**So that** the command that reports problems does not become one

**Acceptance criteria**

```gherkin
Scenario: the budget holds after the plugin work
  Given the changes from S-08 through S-11
  When keel doctor runs on a fixture
  Then it starts python3 at most ten times
```

**Notes:** the assertion already exists at `tests/test-keel.sh:405` and measured 8 on 2026-08-18.
This story is a guard, not new work: `FR-07` adds a profile read and `FR-09` adds output, both on
doctor's hot path. The context window work hit this same budget and solved it by reading a constant
with `sed` rather than an interpreter, which is the precedent if this goes over.

---

## Epic E-04: Nothing else moved

**Goal:** the always-loaded prefix is untouched.
**Requirements:** NFR-03
**Stories:** S-13
**Ships when:** the session-start hook injects the same bytes it did before.

### S-13 The session prefix is unchanged

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-03 |
| Size | S |
| Depends on | none |
| Status of requirement | NFR-03 confirmed |

**As a** developer paying for every token in every request
**I want** this work to add nothing to the always-loaded prefix
**So that** the headroom stays available for the ideas that need it

**Acceptance criteria**

```gherkin
Scenario: the prefix has not grown
  Given hooks/session-start
  When its output is measured
  Then it is between 300 and 356 estimated tokens
```

**Notes:** the guard added by the context window work already asserts this in
`tests/test-session-start.sh`, with both an upper and a lower bound after the first version was
found to pass vacuously. This story is a claim that no task in this PRD touches that file, and it
needs no new assertion; if the existing one still passes, `NFR-03` holds.

---

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | confirmed | S-01 | Gated by S-05's fourth scenario |
| FR-02 | confirmed | S-03 | |
| FR-03 | confirmed | S-02 | |
| FR-04 | confirmed | S-05 | |
| FR-05 | inferred | S-04 | Checked in the slow suite, not the fast validator |
| FR-06 | inferred | S-06 | |
| FR-07 | confirmed | S-08 | |
| FR-08 | confirmed | S-09 | |
| FR-09 | confirmed | S-10 | |
| FR-10 | inferred | S-11 | |
| FR-11 | confirmed | S-11 | |
| FR-12 | confirmed | S-02 | |
| NFR-01 | inferred | S-02, S-07 | |
| NFR-02 | confirmed | S-12 | |
| NFR-03 | confirmed | S-13 | Satisfied by an existing assertion |
| NFR-04 | inferred | S-02 | |
| CON-01 | confirmed | none | Constraint. Correctly uncovered: it records that no version bump is needed |
| CON-02 | confirmed | S-02 | Encoded by S-02's second scenario |
| CON-03 | confirmed | none | Constraint. Correctly uncovered: keel cannot install a plugin |
| CON-04 | confirmed | S-11 | Encoded by S-11's second scenario |
| CON-05 | confirmed | none | Constraint. Correctly uncovered: no skill is touched |

**Forward:** 16 of 16 `FR` and `NFR` requirements have at least one story. No gaps. Three of the
five constraints are correctly uncovered, being statements rather than work; the other two are
asserted inside a story and named above.

**Backward:** every story's `Satisfies` names a requirement that exists in the PRD. No story
satisfies nothing.

## Order

Dependency order, critical path marked.

| # | Story | Kind | Critical path |
|---|---|---|---|
| 1 | S-01 Every declared key carries a description | build | **yes** |
| 2 | S-02 A script generates the reference | build | **yes** |
| 3 | S-07 Generation needs nothing but the repository | verify | |
| 4 | S-03 The reference is committed and readable | build | **yes** |
| 5 | S-04 The page says which keys keel writes | build | |
| 6 | S-05 A schema edit that skips the page fails the build | build | **yes** |
| 7 | S-06 The reference is reachable from the README | build | |
| 8 | S-08 Init records the plugins this project expects | build | **yes** |
| 9 | S-09 Doctor reports the gap on a mature repository | verify | **yes** |
| 10 | S-10 Doctor names the command that fixes it | fix | |
| 11 | S-11 A hand-edited list survives, settings left alone | verify | |
| 12 | S-12 Doctor stays within its interpreter budget | verify | |
| 13 | S-13 The session prefix is unchanged | verify | |

S-13 has no dependencies and asserts an existing guard, so it can be done at any point or folded
into the final verification. The two epics are independent: E-02 and E-03 could be built by
different people in either order, and the only reason to start with E-01 is that S-03 is worthless
before it.
