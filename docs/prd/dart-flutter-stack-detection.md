# PRD: detect Dart and Flutter projects

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Bernard, with Claude |
| Date | 2026-08-29 |
| Derived from | `docs/ideas/dart-flutter-stack-detection.md`, untracked at the time of writing, and this conversation |
| Approved by | Bernard, 2026-08-29 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

**Of the 23 requirements below, 19 functional and 4 non-functional, 2 were stated by Bernard and 21
are derived from the idea record, the code, or command output taken on 2026-08-29.** The two are
`FR-13` and `FR-07`, each asked as a choice on 2026-08-29. `FR-07` was `author-added` when this
document was approved and was confirmed the same day while writing the stories, which is why it now
reads `confirmed`; the trace is in `Q1`.

**Twenty-one of twenty-three are `inferred`, and that is what approval turned on.** The feature was
asked for; almost none of its specifics were.

## 1. Executive summary

`keel init` on a Flutter repository produces a profile with no language, no framework, no package
manager, no datastore and no verify command, and with `has_ui` set to `false` on a mobile
application. This PRD covers detecting Dart as the fourteenth language read from a declared
manifest, distinguishing Flutter from pure Dart, and filling five verify commands from the SDK
toolchain.

It is for anyone running keel on a Dart codebase, and it matters now because fifteen Flutter
repositories exist on one developer machine in current work. Unlike PL/SQL, this needs no inference:
`pubspec.yaml` is a declared manifest, so the doctrine that makes detection trustworthy is untouched.

**It reverses a decision.** `docs/plans/2026-08-14-multi-stack-detection.md:67-70` considered Dart and
deferred it, on the grounds that a language with no plugin language server "would get a test command
and nothing else". The language server half of that is still true and this PRD does not dispute it:
`CON-03`. The other half is false, and `FR-08` to `FR-12` are the five verify commands that make it
so.

## 2. Problem statement

Every skill that reads `.keel/profile.json` on a Flutter repository has nothing to work from, so it
asks the user instead, on every session, in fifteen repositories.

**Evidence.** Sourced `lib/detect-stack.sh` read-only in a Flutter application on 2026-08-29, a
repository with `pubspec.yaml`, `pubspec.lock`, `lib/`, `test/`, `android/` and `ios/`:

```
detect_languages: []
detect_stack:     unknown unknown none none
detect_also:      []
detect_has_ui:    false
detect_datastores:[]
verify:           []
```

Fourteen of the fifteen fields a profile carries about a stack are empty. **One is wrong rather than
empty:** `has_ui: false` on a mobile application. An empty field makes a skill ask; a wrong field
makes it proceed.

The scale is the difference from PL/SQL. All 22 `pubspec.yaml` files found on the machine belong to
Flutter applications, and fifteen of them are live project work.

## 3. Goals and non-goals

**Goals**

- A Flutter repository gets a profile that names its language, framework, package manager and
  datastore without a human editing the file.
- The verify commands that the SDK can answer for are filled, and the ones it cannot are `null`.
- No repository that is not a Dart project is ever labelled one.

**Non-goals**

- Recommending a language server. There is none, `CON-03`.
- Producing a build command. Decided against by Bernard on 2026-08-29, `FR-13`.
- Reading `analysis_options.yaml`, choosing a lint rule set, or having any opinion on lint
  configuration.
- Detecting the Flutter SDK version, channel, or an `fvm` pin.
- A `coding-standards` section for Dart. Out of scope, as it was for PL/SQL.

## 4. Users and personas

Anyone running `keel init` or `keel doctor` on a Dart repository, and every skill that reads the
resulting profile. The immediate population is one developer with fifteen Flutter applications; the
mechanical consumers are `tdd`, `coding-standards`, `ship` and `review-code`, which each read
`verify` and `stack.language` before they do anything.

## 5. Functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | `detect_languages` must report `dart` when a `pubspec.yaml` exists at the root of the tree. | inferred | The declared-manifest doctrine at `lib/detect-stack.sh:345-350`. 15 of 15 in the fleet have one, and so do all 22 found on the machine |
| FR-02 | `dart` must not be reported when no `pubspec.yaml` exists, whatever `.dart` files are present. | inferred | The orphan tree: ten `.dart` files under `lib/`, no `pubspec.yaml` at any level. Keying on the manifest is what excludes it |
| FR-03 | The accumulator assignment must be spelled `out="$out dart"`, matching the fourteen existing branches. | inferred | `CON-01`. `tests/validate-skills.sh:414-429` extracts languages by matching that exact spelling, and a different spelling disables the rule silently rather than breaking it |
| FR-04 | `lang_profile dart` must emit language `dart`, runtime `dart`, and package manager `pub`. | inferred | The tuple shape every language uses, `lib/detect-stack.sh:368-434`. `runtime` mirrors `php php`, `python python`, `ruby ruby` and `rust rust`: the language's own VM |
| FR-05 | `lang_profile dart` must emit framework `flutter` when `pubspec.yaml` declares the Flutter SDK dependency, and `none` otherwise. | inferred | The framework is what varies within the language, as `laravel`, `spring` and `apex` already do. 15 of 15 declare `flutter:` with `sdk: flutter` |
| FR-06 | `detect_has_ui` must return `true` when the framework is `flutter`. | inferred | `lib/detect-stack.sh:700-706` keys on a framework list that already carries `apex`, then falls back to `public/` or `index.html`, neither of which a Flutter app has. This is the field that is currently wrong rather than empty |
| FR-07 | Where the framework is `none`, the verify commands must use the `dart` spelling rather than the `flutter` one. | **confirmed** | **Bernard, 2026-08-29, asked as a choice: keep it.** No pure Dart project exists in current work, so it rests on the tooling contract rather than on an instance, and it was kept on the argument that the first server-side Dart or CLI package otherwise gets a profile whose commands do not run, which is worse than the empty one this PRD fixes. `Q1`, now closed |
| FR-08 | `verify.test` must be `flutter test` for a Flutter project and `dart test` for a pure Dart one, and `null` for a plain package that does not declare `package:test`. | inferred | `flutter test --help` and `dart test --help`, run 2026-08-29. All 15 have a `test/` directory and at least one `*_test.dart`, so the command always runs. **Amended 2026-08-29 by Bernard, asked as a choice, after task 2's review measured the precondition. Flutter bundles `flutter_test` and needs no gate; the Dart SDK ships the `dart test` command but not the package. An ungated `dart test` would be the guessed command `CON-02` forbids.** |
| FR-09 | `verify.test_one` must be `flutter test {path}` for a Flutter project and `dart test {path}` for a pure Dart one, and `null` for a plain package that does not declare `package:test`. | inferred | The schema requires `{path}` or `{name}` substitution and `tdd` depends on it. **Amended 2026-08-29 by Bernard, asked as a choice, after task 2's review measured the precondition. Flutter bundles `flutter_test` and needs no gate; the Dart SDK ships the `dart test` command but not the package. An ungated `dart test` would be the guessed command `CON-02` forbids.** |
| FR-10 | `verify.lint` must be `flutter analyze` for a Flutter project and `dart analyze` for a pure Dart one, ungated by the presence of `analysis_options.yaml`. | inferred | `flutter analyze --help` and `dart analyze --help`, run 2026-08-29. The analyzer runs against the SDK's default lint set whether or not that file exists, and **8 of the 15 do not have it**, so gating would null out the majority |
| FR-11 | `verify.format` must be `dart format --output=none --set-exit-if-changed .` for both. | inferred | `dart format --help`, run 2026-08-29, which lists `-o, --output [none] Discard output` and `--set-exit-if-changed`. `NFR-04` requires check-only. `flutter format` was removed from the SDK and now errors with "Could not find a command named format", verified the same day |
| FR-12 | `verify.format_fix` must be `dart format .` for both. | inferred | The writing counterpart the schema requires, same command without the two flags |
| FR-13 | `verify.build` must be `null`. | **confirmed** | **Bernard, 2026-08-29, asked as a choice.** `flutter build` is not a command on its own: `flutter build --help` lists eight targets including `apk`, `ipa`, `appbundle`, `web` and `bundle`. Choosing among them is a guess, and `CON-02` forbids it |
| FR-14 | `verify.typecheck`, `verify.e2e`, `verify.security` and `verify.test_integration` must be `null`. | inferred | The analyzer is the type checker and it is already `FR-10`, so repeating it as a typecheck would double-count one command. `integration_test/` is absent in all 15 |
| FR-15 | `detect_datastores` must report the backend a declared Dart store package actually talks to: `sqlite` for `sqflite`, `drift` and `sembast`, `postgres` for `supabase_flutter`, and `firestore` for `cloud_firestore`. | inferred, amended | `sqflite` is SQLite on the device and appears in **13 of 15**. `lib/detect-stack.sh:721-753` already carried a `sqlite` pair; what it lacked was `pubspec.yaml` in its manifest file list. **Amended 2026-08-30 by Bernard, asked as a choice.** `sqflite` alone under-reported: a realistic 30-package pubspec named seven stores and keel reported one. Widened to the packages that map onto a backend keel already names, plus `firestore`, which is the one new name and the one product among them with a server behind it. `hive`, `isar` and `objectbox` stay unreported **by decision, not by oversight**: they are embedded libraries, so there is nothing to map them onto, and a test now fails if they start being reported without that decision being revisited |
| FR-16 | `detect_datastores` must add `pubspec.yaml` to the manifest files it greps, and must not change what it reports for any other language. | inferred | The function is shared by every language, so this is the one requirement here that can regress an existing stack. `NFR-02` |
| FR-17 | `skills/keel/references/tool-choices.md` must carry a `dart` row in each of its test runner, lint and typecheck tables. | inferred | `CON-01` requires only one row anywhere, so three is a choice, matching what `plsql` already does at lines 45, 70 and 83. The typecheck row's honest verdict is that the analyzer is the lint command and `verify.typecheck` stays `null` |
| FR-18 | `lang_lsp` must have no `dart` arm. | inferred | `CON-03`. The function returns empty for an unmapped language and `detect_plugins` drops it, `lib/detect-stack.sh:758-785`. An id that does not resolve fails in `settings.json`, which the function's own comment says is worse than suggesting nothing |
| FR-19 | A repository detected as `dart` must report `dart` as its primary language, and must not suppress any other language whose manifest is also present. | inferred | `detect_languages` is a chain whose first line is the primary, `lib/detect-stack.sh:303-305`, and `detect_also` is everything after it, `:442-445`. **Position decided 2026-08-29, S-11: first, before the `package.json` block.** Later positions were rejected because they hand a Dart project another language's verify commands. It is safe at the front because the check reads the root only, so a `pubspec.yaml` there means the root is a Dart package; a Flutter app in a subdirectory is invisible to it either way. Where both manifests are present, `dart` is `stack.language` and the other is in `stack.also`, which is the shape the polyglot row of the detection matrix in `docs/03-install-and-distribution.md` already describes. No collision exists in current work to test against, which is why this is a decision and not an observation |

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | Detection must add no new interpreter dependency and no external command beyond what `lib/detect-stack.sh` already uses. In particular it must not add a YAML parser, nor `sed`, `sort`, `uniq` or `tr`. | inferred | The file is sourced by `bin/keel` on every `init` and `doctor`. Its own comment at `lib/detect-stack.sh:102-104` records that it uses none of those four and that a change must not be the one that introduces them |
| NFR-02 | `stack.language`, `stack.has_ui` and `stack.datastores` must be unchanged for a repository that is not a Dart project. | inferred | `FR-16` edits a function shared by every language. This is the property that makes that edit safe, and every existing fixture asserts it. **Narrowed twice, 2026-08-29 and 2026-08-30, both times because the wording claimed more than was asserted. 'Byte-identical' was untestable, since `keel_version` and a `mktemp`-derived `project.name` vary per run. 'The stack and verify blocks' was still wider than the guard, which reads three of `stack`'s seven keys and none of `verify`'s ten. The three named are exactly the fields the shared, non-arm edits can reach: `detect_languages`, `detect_datastores`, `detect_has_ui` and `detect_plugins`. `detect_plugins` is the exception and is named for completeness: its edited branch is gated on `fw` being `flutter`, which only `lang_profile`'s `dart)` arm sets, so no other language reaches it, and the regression block says so itself. The rest are protected by construction, because `lang_profile` and `detect_verify` gained new `case` arms that no other language can enter, and the existing `---- detection ----` cases pin the primary language for all ten stacks, `---- framework detection ----` pins the tuples, and `---- verify commands ----` pins the commands.** |
| NFR-03 | Detecting Dart must add at most one filesystem check for a repository that is not a Dart project. | inferred | `[ -f pubspec.yaml ]`, the same cost as the twelve marker checks around it. No tree walk, unlike the PL/SQL census |
| NFR-04 | `verify.lint` and `verify.format` must be check-only and must not rewrite a file. | inferred | The schema requires it of both keys: "Must be check-only. A command that rewrites files cannot gate." It is why `FR-11` carries `--output=none --set-exit-if-changed` and `FR-12` is a separate key |

## 7. Constraints

| ID | Constraint | Imposed by | Note |
|---|---|---|---|
| CON-01 | Every language in `detect_languages` must have a row in `skills/keel/references/tool-choices.md` or the build fails. One row anywhere in the file satisfies it. | `tests/validate-skills.sh:414-429` | Read 2026-08-29. The rule extracts the language list from `detect_languages` itself, which is why `FR-03` pins the accumulator spelling |
| CON-02 | Detection never guesses a verify command. An absent command becomes `null` so a skill knows to ask. | `lib/detect-stack.sh:454-455` | The doctrine that makes the profile trustworthy. It is what makes `FR-13` `null` rather than a guessed build target |
| CON-03 | No Dart language server exists in the `claude-plugins-official` catalogue. | The catalogue | Checked 2026-08-29: twelve language server ids, the same twelve `lang_lsp` maps at `lib/detect-stack.sh:758-773`, none for Dart. This needs no code, `FR-18` |
| CON-04 | Dart was considered and deferred on 2026-08-14. | `docs/plans/2026-08-14-multi-stack-detection.md:67-70` | This PRD reverses it. The deferral's reason divides in two: the language server half stands, `CON-03`, and the "a test command and nothing else" half is contradicted by `FR-08` to `FR-12` |
| CON-05 | Detection must read `pubspec.yaml` with `grep`, because there is no YAML parser available to it. | `NFR-01` | It bounds what `FR-05` and `FR-15` can ask: a declared dependency is a matched token, not a parsed key. A `sqflite` mentioned in a comment would match |

## 8. Observed but not required

Not applicable: this is `from-idea` mode, which has no existing behaviour to classify. The one
behaviour that exists today is the empty profile, and it is the problem rather than a requirement.

## 9. Success metrics

| Metric | Target | Source |
|---|---|---|
| Fleet repositories that detect as `dart` with framework `flutter` | 15 of 15 | Run the detector read-only in each, as done on 2026-08-29 for one of them |
| Repositories that wrongly detect as `dart` | 0, and the orphan tree specifically | The orphan tree of ten `.dart` files with no manifest is the named case |
| Existing fixtures whose detected profile changes | 0 | `NFR-02`, asserted by the existing suite rather than by a new measurement |
| Verify keys filled on a Flutter repository | 5 of 10: test, test_one, lint, format, format_fix | `FR-08` to `FR-12` |
| Adoption of the resulting profiles | `Unknown, needs a decision` | Nobody has committed to running `keel init` on the fleet. The work is justified on detector correctness, as PL/SQL's was |

## 10. Milestones

`Unknown, needs a decision`. None were given.

## 11. Out of scope

- **A language server recommendation.** None exists, `CON-03`.
- **A build command.** `FR-13`, decided by Bernard.
- **Lint configuration.** keel reports the command, never the rule set.
- **Flutter version or channel detection.** Nothing in the fleet declares one: no `.fvmrc`, no
  `fvm_config.json`, no `.fvm/`, and `fvm` is not installed. The only source would be the ambient
  `flutter --version`, which is a property of the machine and not of the repository.
- **Melos and workspace layouts.** No `melos.yaml` exists in the fleet. One repository has two nested
  `pubspec.yaml` files under `plugins/`, a local path dependency rather than a monorepo, `Q3`.
- **A `coding-standards` Dart section.**

## 12. Assumptions

| # | Assumption | Falsified if |
|---|---|---|
| A1 | A Dart project always declares `pubspec.yaml`, so the marker never needs to infer. | A Dart repository exists with source and no manifest. The orphan tree is that shape, and the position taken here is that it is not a project |
| A2 | `grep` on `pubspec.yaml` is enough to tell Flutter from pure Dart. | A pubspec mentions `flutter` in a comment, a description, or a dev-only dependency while not being a Flutter app. `CON-05` is the exposure |
| A3 | `flutter test` is worth setting even where the only test is the generated `widget_test.dart`. | A skill reports a green suite as evidence of coverage. **13 of the 15 have exactly that one file.** The position taken is that `verify.test` states how to run the tests, not that they are worth running, and no other language's arm makes that judgement. `Q4` |
| A4 | Adding `pubspec.yaml` to `detect_datastores` cannot change any other language's result. | A non-Dart repository contains a `pubspec.yaml`. None of the 22 sits beside a `package.json`, `go.mod`, `Cargo.toml` or `pom.xml`, so this is untested rather than proven |
| A5 | The Dart and Flutter CLIs keep these command spellings. | They change. `flutter format` was removed once already, which is why `FR-11` uses the `dart` spelling for both |

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| ~~Q1~~ | ~~Is the pure Dart arm wanted at all, given that no pure Dart project exists in current work?~~ **Answered 2026-08-29 by Bernard, asked as a choice: keep it.** `FR-07` moves from `author-added` to `confirmed` and both spellings stay in `FR-08` to `FR-10`. The reason recorded with the answer: a pure Dart package detected with `flutter` commands gets a profile whose commands do not run, which is worse than the empty profile this PRD exists to fix. | Closed | FR-07 |
| ~~Q2~~ | ~~Where does `dart` sit in the `detect_languages` chain? No repository declares two ecosystems, so nothing forces the answer.~~ **Answered 2026-08-29 by the plan's first task: first, before the `package.json` block, and recorded in `FR-19`.** A later position hands a Dart project another language's verify commands; the front is safe because the check reads the root only, so a root `pubspec.yaml` means the root is a Dart package. | Closed | FR-19 |
| Q3 | Does a local path-dependency plugin with its own `pubspec.yaml` need any rule? One repository has two. **Still open 2026-08-30: no instance forces it, because the marker check reads the root only and a nested `pubspec.yaml` is invisible to it either way.** **Still open after the follow-up plan of 2026-08-30: no task there changed `detect_languages`, which still reads the root only.** | Plan | Nothing yet |
| Q4 | Should `verify.test` be `null` where the only test file is the generated `widget_test.dart`? Answered here as no, `A3`, on consistency with every other language. Recorded because it is the assumption most likely to be disagreed with. **Still open 2026-08-30: the position is `A3` and the question is kept for anyone who disagrees with it.** **Reaffirmed after the follow-up plan of 2026-08-30. `dart_has_test_files` makes the position sharper rather than softer: a generated `widget_test.dart` ends in `_test.dart`, so it satisfies the gate and `verify.test` is filled because of it.** | Bernard | FR-08 |

**Settled while writing this PRD**, and struck through in `docs/ideas/dart-flutter-stack-detection.md`
so the trace survives:

- ~~What is `verify.build`?~~ `null`, `FR-13`, chosen by Bernard 2026-08-29.
- ~~Flutter only, or Dart generally?~~ Both, `FR-07`. It was marked `author-added` rather than
  justified when this PRD was approved, and confirmed by Bernard the same day, `Q1`.
- ~~Should `verify.test` be set when the only test is boilerplate?~~ Yes, `A3`, now `Q4` for anyone who
  disagrees.
