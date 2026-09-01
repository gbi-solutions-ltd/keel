# Stories: detect Dart and Flutter projects

| | |
|---|---|
| Derived from | `docs/prd/dart-flutter-stack-detection.md`, PRD status `approved` |
| Date | 2026-08-29 |
| Stories | 11 (build: 7, verify: 2, fix: 1, decide: 1) |
| Coverage | 23 of 23 requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> The PRD is approved, so these are not provisional as a set. **Twenty-one of its twenty-three
> requirements are `inferred`**, so each story below names its requirement's status rather than
> letting the approval imply more agreement than there is.

**The build gate that sets the order.** `tests/validate-skills.sh:414-429` extracts the language list
out of `detect_languages` and fails when a language has no row in
`skills/keel/references/tool-choices.md`. So the moment `out="$out dart"` lands, the suite goes red
unless the rows are already there. `S-02` therefore depends on `S-01`, and that is a hard ordering
rather than a preference.

---

## Epic E-01: A Dart project is recognised, and nothing else changes

**Goal:** `keel init` on a Flutter repository names the language, framework and package manager, and
`keel init` on every other repository produces exactly what it produces today.
**Requirements:** FR-01, FR-02, FR-03, FR-04, FR-05, FR-17, FR-18, FR-19, NFR-01, NFR-02, NFR-03
**Stories:** S-11, S-01, S-02, S-03, S-09, S-10
**Ships when:** a Flutter fixture detects as `dart` with framework `flutter`, the orphan-tree fixture
detects as nothing, and every existing fixture's profile is byte-identical to today's.

### S-11 Decide where `dart` sits in the `detect_languages` chain

| | |
|---|---|
| Kind | decide |
| Satisfies | FR-19 |
| Size | S |
| Depends on | none |
| Status of requirement | FR-19 inferred |

**As a** developer implementing the detector
**I want** the position of the `pubspec.yaml` check in the marker chain settled before I write it
**So that** the polyglot behaviour is a decision on the record rather than wherever the diff landed

**Acceptance criteria**

```gherkin
Scenario: the position is recorded where an implementer will look
  Given no repository in current work declares two ecosystems
  When the position is chosen
  Then the reason is written into FR-19's Evidence column in the PRD
  And no ADR is written, because the choice does not shape the system

Scenario: the decision bounds the polyglot case
  Given a repository with both a pubspec.yaml and a package.json
  When the chosen position is applied
  Then the document states which language is primary and which appears in stack.also
```

**Notes:** first in the backlog because `S-02` implements it. The answer is a requirement value, not
an architecture decision, so it belongs in `FR-19` rather than in `docs/decisions/`, per the story
template's rule on where a `decide` story's answer goes. `Q2` of the PRD.

### S-01 Add the `dart` rows to the tool table

| | |
|---|---|
| Kind | build |
| Satisfies | FR-17 |
| Size | S |
| Depends on | none |
| Status of requirement | FR-17 inferred |

**As a** developer whose snapshot names a Dart gap
**I want** the tool table to already say what to reach for
**So that** the recommendation is a written-down choice rather than improvised differently each time

**Acceptance criteria**

```gherkin
Scenario: the test runner table names Dart's runner
  Given skills/keel/references/tool-choices.md
  When the Test table is read
  Then it has a row whose first cell is dart
  And the row gives a reason rather than only a verdict

Scenario: the lint table names the analyzer and the formatter
  Given the Lint and format table
  When it is read
  Then the dart row names the SDK analyzer and dart format

Scenario: the typecheck table says why there is no separate typecheck
  Given the Typecheck table
  When it is read
  Then the dart row says the analyzer is already the lint command and verify.typecheck stays null

Scenario: the build gate is satisfied before dart is detected
  Given tests/validate-skills.sh
  When it runs against a tree where detect_languages emits dart
  Then it reports no missing tool row
```

**Notes:** three rows rather than the one `CON-01` requires, matching what `plsql` already does at
`tool-choices.md` lines 45, 70 and 83. **This must land before or with `S-02`**, because the
validator fails the moment `dart` is detectable without it.

### S-02 Detect `dart` from a declared `pubspec.yaml`, and never from `.dart` files

| | |
|---|---|
| Kind | build |
| Satisfies | FR-01, FR-02, FR-03, FR-19 |
| Size | M |
| Depends on | S-01, S-11 |
| Status of requirement | FR-01, FR-02, FR-03, FR-19 all inferred |

**As a** developer running `keel init` on a Flutter repository
**I want** the detector to recognise the project from the manifest it already declares
**So that** the profile stops coming out empty, without keel guessing at anything

**Acceptance criteria**

```gherkin
Scenario: a repository with a pubspec is Dart
  Given a repository with a pubspec.yaml at its root
  When detect_languages runs
  Then its output contains dart

Scenario: Dart source without a manifest is not a Dart project
  Given a directory of .dart files with no pubspec.yaml at any level
  When detect_languages runs
  Then its output does not contain dart
  And detect_stack reports unknown

Scenario: a repository declaring two ecosystems reports both
  Given a repository with both a pubspec.yaml and a package.json
  When detect_languages runs
  Then dart appears in the output
  And the other language appears in the output
  And the primary is whichever S-11 decided

Scenario: the accumulator spelling keeps the build rule alive
  Given lib/detect-stack.sh
  When tests/validate-skills.sh extracts the language list
  Then dart is among the languages it extracts
```

**Notes:** the last scenario is not ceremony. `tests/validate-skills.sh:414-429` records that a
renamed accumulator disables the rule silently rather than breaking it, which is why `FR-03` pins the
spelling `out="$out dart"`.

### S-03 Emit the stack tuple, splitting Flutter from pure Dart

| | |
|---|---|
| Kind | build |
| Satisfies | FR-04, FR-05 |
| Size | M |
| Depends on | S-02 |
| Status of requirement | FR-04, FR-05 both inferred |

**As a** skill reading `stack` out of the profile
**I want** to know whether this is a Flutter application or a plain Dart package
**So that** I reach for the right command and the right conventions

**Acceptance criteria**

```gherkin
Scenario: a Flutter application
  Given a pubspec.yaml declaring flutter with sdk: flutter
  When lang_profile dart runs
  Then it emits language dart, runtime dart, framework flutter, package manager pub

Scenario: a pure Dart package
  Given a pubspec.yaml with no Flutter SDK dependency
  When lang_profile dart runs
  Then it emits language dart, runtime dart, framework none, package manager pub

Scenario: the profile carries the tuple
  Given a Flutter fixture
  When keel init runs
  Then .keel/profile.json has stack.language dart and stack.framework flutter
```

**Notes:** `runtime` is `dart` and not `flutter`, mirroring `php php`, `python python`, `ruby ruby`
and `rust rust`. `CON-05` bounds how the split is detected: `grep` on the manifest, because there is
no YAML parser available to this file, so a `flutter` mentioned in a comment would match. That is the
known exposure, recorded as `A2`.

### S-09 A Dart project is recommended no language server

| | |
|---|---|
| Kind | verify |
| Satisfies | FR-18 |
| Size | S |
| Depends on | S-02 |
| Status of requirement | FR-18 inferred |

**As a** developer running `keel init` on a Flutter repository
**I want** no plugin suggested for a language server that does not exist
**So that** `.claude/settings.json` never names a plugin that fails to resolve

**Acceptance criteria**

```gherkin
Scenario: no plugin is emitted for Dart
  Given a Flutter fixture
  When detect_plugins runs
  Then its output contains no dart entry

Scenario: the settings file gains no unresolvable id
  Given a Flutter fixture
  When keel init runs
  Then .claude/settings.json enabledPlugins contains no dart language server
```

**Notes:** `verify` and not `build`, because `lang_lsp` already returns empty for an unmapped language
and `detect_plugins` already drops it (`lib/detect-stack.sh:758-785`). The work is the test proving
Dart takes that path, not a new branch. If the test fails, this becomes a `fix`. `CON-03` is why
there is nothing to add.

### S-10 No existing stack's profile changes

| | |
|---|---|
| Kind | verify |
| Satisfies | NFR-01, NFR-02, NFR-03 |
| Size | S |
| Depends on | S-08 |
| Status of requirement | NFR-01, NFR-02, NFR-03 all inferred |

**As a** developer with an existing keel project
**I want** the Dart work to be invisible to my repository
**So that** a language I do not use cannot change what my profile says

**Acceptance criteria**

```gherkin
Scenario: every existing fixture is unchanged
  Given each stack fixture that exists today
  When keel init runs after the Dart change
  Then the generated .keel/profile.json is byte-identical to the one generated before it

Scenario: no new external command is introduced
  Given lib/detect-stack.sh
  When it is searched for sed, sort, uniq and tr
  Then none of the four appears
  And no YAML parser is invoked

Scenario: a non-Dart repository pays one file check
  Given a repository with no pubspec.yaml
  When detect_languages runs
  Then no directory is walked on Dart's account
```

**Notes:** depends on `S-08` because `S-08` is the only story that edits a function shared by every
language. This is the guard on that edit. The second scenario is the same property assertion
`tests/test-apex-export.sh` already makes about `lib/apex_render.py`, and `lib/detect-stack.sh:102-104`
records that it uses none of those four commands and that a change must not be the one that
introduces them.

---

## Epic E-02: A Dart project gets the verify commands the SDK can answer for

**Goal:** `tdd`, `ship` and `review-code` can run this project's tests, analyzer and formatter without
asking, and are told plainly that there is no build.
**Requirements:** FR-07, FR-08, FR-09, FR-10, FR-11, FR-12, FR-13, FR-14, NFR-04
**Stories:** S-04, S-05, S-06
**Ships when:** a Flutter fixture's profile carries five verify commands that run, and five nulls.

### S-04 Fill the test and single-test commands

| | |
|---|---|
| Kind | build |
| Satisfies | FR-07, FR-08, FR-09 |
| Size | M |
| Depends on | S-03 |
| Status of requirement | FR-07 confirmed; FR-08, FR-09 inferred |

**As a** developer running `tdd` on a Flutter project
**I want** the profile to name the test command and how to run one test
**So that** the skill runs the suite instead of asking me what the command is

**Acceptance criteria**

```gherkin
Scenario: a Flutter project's test command
  Given a Flutter fixture
  When keel init runs
  Then verify.test is flutter test

Scenario: a pure Dart package's test command
  Given a pure Dart fixture with no Flutter SDK dependency
  When keel init runs
  Then verify.test is dart test

Scenario: a single test is addressable
  Given a Flutter fixture
  When keel init runs
  Then verify.test_one is flutter test {path}

Scenario: the command runs against a real project
  Given a Flutter repository with one widget_test.dart
  When verify.test is executed
  Then it exits zero
```

**Notes:** the fourth scenario is the one that catches a plausible but wrong command string.
`verify.test` is set even where the only test file is the generated `widget_test.dart`, which is
**13 of the 15** repositories in the fleet. That is assumption `A3`, kept as `Q4` in the PRD because
it is the one most likely to be disagreed with: `verify.test` states how to run the tests, not that
they are worth running.

### S-05 Fill the lint, format and format-fix commands

| | |
|---|---|
| Kind | build |
| Satisfies | FR-07, FR-10, FR-11, FR-12, NFR-04 |
| Size | M |
| Depends on | S-03 |
| Status of requirement | FR-07 confirmed; FR-10, FR-11, FR-12, NFR-04 inferred |

**As a** developer running `coding-standards` or `ship` on a Dart project
**I want** a lint and a format command that check without rewriting
**So that** a gate can use them, and the fix command is what a refusal names as the remedy

**Acceptance criteria**

```gherkin
Scenario: the analyzer is the lint command
  Given a Flutter fixture with no analysis_options.yaml
  When keel init runs
  Then verify.lint is flutter analyze

Scenario: a pure Dart package uses the dart spelling
  Given a pure Dart fixture
  When keel init runs
  Then verify.lint is dart analyze

Scenario: format is check-only
  Given a Flutter fixture with a badly formatted .dart file
  When verify.format is executed
  Then it exits non-zero
  And the file on disk is unchanged

Scenario: format_fix writes
  Given the same badly formatted file
  When verify.format_fix is executed
  Then the file on disk is reformatted
```

**Notes:** lint is ungated by `analysis_options.yaml` on purpose: the analyzer runs against the SDK
default set regardless, and **8 of the 15** repositories have no such file, so gating would null out
the majority. Format uses the `dart` spelling for both kinds of project because `flutter format` was
removed from the SDK; running it on 2026-08-29 gives "Could not find a command named format". The
third scenario is what `NFR-04` exists for: a command that rewrites files cannot gate.

**Why lint and format are one story and not two**, since a lint command is genuinely useful without a
formatter: both are the same `case` arm in the same function and the same fixture, so splitting them
produces two stories that edit the same lines and conflict, and `format` and `format_fix` cannot be
separated at all because `NFR-04` defines each in terms of the other. Four scenarios, under the six
the template sets as the ceiling.

### S-06 Leave null every key the toolchain cannot answer for

| | |
|---|---|
| Kind | build |
| Satisfies | FR-13, FR-14 |
| Size | S |
| Depends on | S-03 |
| Status of requirement | FR-13 confirmed; FR-14 inferred |

**As a** skill deciding whether this project has a build step
**I want** the profile to say `null` rather than a command that guesses
**So that** I ask the user instead of running the wrong thing

**Acceptance criteria**

```gherkin
Scenario: there is no build command
  Given a Flutter fixture
  When keel init runs
  Then verify.build is null

Scenario: the analyzer is not counted twice
  Given a Flutter fixture
  When keel init runs
  Then verify.typecheck is null

Scenario: the remaining keys are null
  Given a Flutter fixture
  When keel init runs
  Then verify.e2e, verify.security and verify.test_integration are all null
```

**Notes:** the work here is the assertion, not a branch: the arm emits nothing for these keys and
this story is what stops a later edit quietly filling one. `verify.build` is `null` by Bernard's
decision of 2026-08-29, `FR-13`, because `flutter build --help` lists eight targets and choosing one
is the guess `CON-02` forbids. `verify.typecheck` is `null` because the analyzer is already
`verify.lint` and repeating it would double-count one command.

---

## Epic E-03: The two profile fields outside the stack tuple

**Goal:** a Flutter application is not reported as having no user interface and no datastore.
**Requirements:** FR-06, FR-15, FR-16
**Stories:** S-07, S-08
**Ships when:** a Flutter fixture reports `has_ui: true` and `datastores: ["sqlite"]`, and no other
fixture's datastores change.

### S-07 Stop reporting a Flutter application as having no user interface

| | |
|---|---|
| Kind | fix |
| Satisfies | FR-06 |
| Size | S |
| Depends on | S-03 |
| Status of requirement | FR-06 inferred |

**As a** skill deciding whether this project has a user interface
**I want** `has_ui` to be true for a Flutter application
**So that** I do not skip the interface work on a mobile app because the profile said there is none

**Acceptance criteria**

```gherkin
Scenario: a Flutter application has a user interface
  Given a Flutter fixture with no public directory and no index.html
  When detect_has_ui runs
  Then it prints true

Scenario: a pure Dart package does not
  Given a pure Dart fixture with no public directory and no index.html
  When detect_has_ui runs
  Then it prints false

Scenario: no existing framework's answer changes
  Given each existing has_ui fixture
  When detect_has_ui runs
  Then each prints what it printed before
```

**Notes:** `fix` and not `build`, which is unusual in a `from-idea` PRD. The current code returns
`false` for a Flutter application because `lib/detect-stack.sh:700-706` keys on
`next react vue svelte angular apex` and then falls back to `public/` or `index.html`, and a Flutter
app has none of them. **This is the only field that is currently wrong rather than merely empty**, so
it is the only story here correcting a behaviour instead of adding one.

### S-08 Read `pubspec.yaml` for datastore dependencies

| | |
|---|---|
| Kind | build |
| Satisfies | FR-15, FR-16 |
| Size | M |
| Depends on | S-02 |
| Status of requirement | FR-15, FR-16 both inferred |

**As a** skill that needs to know what this application stores data in
**I want** a declared `sqflite` dependency to appear as a datastore
**So that** `design-architecture` and `security-audit` know there is a local database

**Acceptance criteria**

```gherkin
Scenario: sqflite is SQLite
  Given a pubspec.yaml declaring sqflite
  When detect_datastores runs
  Then its output contains sqlite

Scenario: a Flutter project with no datastore dependency
  Given a pubspec.yaml declaring neither sqflite nor any other known store
  When detect_datastores runs
  Then its output is empty

Scenario: no other language's datastores change
  Given each existing datastore fixture
  When detect_datastores runs
  Then each reports exactly what it reported before
```

**Notes:** `detect_datastores` (`lib/detect-stack.sh:721-753`) already carries a `sqlite` pair; what
it lacks is `pubspec.yaml` in the list of manifest files it greps. This is **the only story that
edits a function shared by every language**, which is why the third scenario exists and why `S-10`
depends on it. `sqflite` appears in 13 of the 15 repositories in the fleet.

---

## Order and critical path

| # | Story | Kind | Why here |
|---|---|---|---|
| 1 | S-11 | decide | `S-02` implements its answer. `decide` stories come first |
| 2 | S-01 | build | **Hard gate.** The suite fails the moment `dart` is detectable without the tool rows |
| 3 | S-02 | build | The marker. Everything below reads the language it sets |
| 4 | S-03 | build | The tuple. `S-04` to `S-07` all branch on the framework it emits |
| 5 | S-04 | build | Verify commands, independent of `S-05` and `S-06` from here |
| 6 | S-05 | build | |
| 7 | S-06 | build | |
| 8 | S-07 | fix | The wrong field |
| 9 | S-08 | build | The shared function, deliberately late so it lands alone |
| 10 | S-09 | verify | Nothing to build; proves the absence |
| 11 | S-10 | verify | Last, because it guards everything above it |

**Critical path:** S-11 → S-01 → S-02 → S-03 → S-08 → S-10. The rest hang off `S-03` and can be done
in any order once it lands.

## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | inferred | S-02 | |
| FR-02 | inferred | S-02 | |
| FR-03 | inferred | S-02 | |
| FR-04 | inferred | S-03 | |
| FR-05 | inferred | S-03 | |
| FR-06 | inferred | S-07 | The only `fix` |
| FR-07 | confirmed | S-04, S-05 | Spans both verify stories |
| FR-08 | inferred | S-04 | |
| FR-09 | inferred | S-04 | |
| FR-10 | inferred | S-05 | |
| FR-11 | inferred | S-05 | |
| FR-12 | inferred | S-05 | |
| FR-13 | confirmed | S-06 | |
| FR-14 | inferred | S-06 | |
| FR-15 | inferred | S-08 | |
| FR-16 | inferred | S-08 | |
| FR-17 | inferred | S-01 | |
| FR-18 | inferred | S-09 | |
| FR-19 | inferred | S-11, S-02 | Decided in `S-11`, implemented in `S-02` |
| NFR-01 | inferred | S-10 | |
| NFR-02 | inferred | S-10 | |
| NFR-03 | inferred | S-10 | |
| NFR-04 | inferred | S-05 | |
| CON-01 | n/a | none | Constraint. It drives `S-01`'s fourth scenario. Correctly uncovered |
| CON-02 | n/a | none | Constraint. It is why `FR-13` and `FR-14` are null. Correctly uncovered |
| CON-03 | n/a | none | Constraint. It is why `S-09` is `verify` and not `build`. Correctly uncovered |
| CON-04 | n/a | none | Constraint. It records the reversal. Not work |
| CON-05 | n/a | none | Constraint. It bounds `S-03`'s method. Correctly uncovered |

**Forward:** 23 of 23 requirements have at least one story: 19 `FR` and 4 `NFR`. No gaps. The five
`CON` entries have no stories, which is correct: a constraint is a bound on the work, not work.

**Backward:** every story's `Satisfies` names a requirement that exists in the PRD. Checked by
tabulating the two columns above, not asserted.

## Open questions still standing

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q2 | Where does `dart` sit in the `detect_languages` chain? | Plan | S-11 owns it |
| Q3 | Does a local path-dependency plugin with its own `pubspec.yaml` need a rule? One repository has two. | Plan | Nothing. Out of scope until an instance forces it |
| Q4 | Should `verify.test` be null where the only test is the generated `widget_test.dart`? Answered no, `A3`. | Bernard, if he disagrees | S-04 |

`Q1` closed on 2026-08-29: the pure Dart arm is kept, and `FR-07` is now `confirmed`.
