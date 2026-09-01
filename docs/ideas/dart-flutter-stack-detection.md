# Idea: detect Dart and Flutter projects

| | |
|---|---|
| Raised by | Bernard, 2026-08-29, from a `keel init` run against a Flutter project |
| Status | agreed, built 2026-08-30 |
| Recommendation | Build it. Detect Flutter from `pubspec.yaml`, fill six of the ten verify keys from the SDK toolchain, and add no language server |
| Next | Built to `docs/plans/2026-08-29-dart-flutter-stack-detection.md`, from `docs/prd/dart-flutter-stack-detection.md`, 2026-08-29. Three of the four open questions were answered in the PRD and `Q2` was answered by the plan |

## A note on naming

The repositories behind the evidence below are client and internal work and are not named, for the
reason `docs/ideas/plsql-stack-detection.md` gives: `tests/no-internal-leaks.sh` refuses
project-specific identifiers, a name in here reads as though it means something to keel, and it
discloses who we work with. They are referred to by count and by what makes them evidence. **The
mobile fleet** is fifteen Flutter applications on one developer machine. **The orphan tree** is the
directory holding ten `.dart` files and no `pubspec.yaml`, which is the false positive any detector
has to survive.

## The problem

Anyone running `keel init` on a Flutter repository gets a profile with no language, no framework, no
package manager, no datastore, no verify command and `has_ui: false`, so every skill that reads the
profile has nothing and asks the user instead. There are fifteen such repositories on one machine.

**Evidence.** Run on 2026-08-29 against a Flutter application with `pubspec.yaml`, `pubspec.lock`,
`lib/`, `test/`, `android/` and `ios/`. Sourcing `lib/detect-stack.sh` read-only in that directory
produced:

```
detect_languages: []
detect_stack:     unknown unknown none none
detect_also:      []
detect_has_ui:    false
detect_datastores:[]
verify:           []
```

Every field empty, and `has_ui: false` on a mobile application, which is the one field that is not
merely absent but wrong. The same shape reproduces across the fleet: all fifteen declare
`flutter: sdk: flutter` in `pubspec.yaml` and all fifteen detect as nothing.

## What was asked for

> Keel should detect dart/flutter. keel init mentioned this in a sample flutter project; `keel's
> detector has no Dart/Flutter support, so the profile came out empty. Gathering the facts to fill
> it.`

## The case against

**Strongest argument for not building this at all: Dart was considered for exactly this and
deliberately deferred fifteen days ago, and the reason given still holds.**
`docs/plans/2026-08-14-multi-stack-detection.md:67-70` says the six languages added were "exactly the
six that have a language server in `claude-plugins-official`", and names Dart among those "considered
and deferred: they have real toolchains but no LSP plugin, so they would get a test command and
nothing else". The LSP half of that was re-checked on 2026-08-29 against the marketplace on this
machine: it carries twelve language server ids, they are the same twelve `lang_lsp`
(`lib/detect-stack.sh:758-773`) already maps, and **none of them is for Dart.** Nothing has changed.
Reopening a decision that was taken on the record, with its reason intact, needs a better argument
than a fresh instance of the same request.

That argument is answerable, and the answer is in the second half of the deferral's own sentence
rather than in the first. **"A test command and nothing else" is measurably false for Dart.** The
Flutter SDK ships the test runner, the analyzer, the formatter and the build system in one binary
that is already on `PATH` when the project can be worked on at all, so `test`, `test_one`, `lint`,
`format`, `format_fix` and `build` are all knowable with no config file and no dependency sniffing.
That is six of the ten verify keys, unconditional, against PL/SQL's nought, and PL/SQL was built. The
LSP finding is not a reason to decline; it is a reason for the `lang_lsp` arm not to exist, which is
already how that function handles an unmapped language (`lib/detect-stack.sh:758-773` returns empty
and `detect_plugins` at `:778-785` drops it) and exactly what `plsql` does today.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The empty profile is reproducible on fifteen repositories, and one of its fields, `has_ui`, is wrong rather than absent. A wrong field makes a skill proceed where an empty one makes it ask |
| Do it manually | One edit to `.keel/profile.json` after `init`, per repository | Viable, and it is what happens today. Fifteen repositories means fifteen edits, and the fleet has no shared tooling to copy one to the next: no Makefile, no justfile, no `scripts/` directory in any of the fifteen |
| Buy it | Nothing available | No tool classifies a repository and emits keel's profile shape |
| Build something smaller | The marker and the six verify commands, no LSP, no `analysis_options` parsing | Recommended. See the variants table |

**Variants of building it**

| Variant | Note |
|---|---|
| Detect on `pubspec.yaml`, and split Flutter from pure Dart on whether it declares `flutter: sdk: flutter` | Recommended. `pubspec.yaml` is a declared manifest, so this is the fourteenth language read rather than the second inferred, and the doctrine at `lib/detect-stack.sh:345-350` is untouched. The split matters because the commands differ: a Flutter project must use `flutter test`, a pure Dart package uses `dart test` |
| Detect Flutter only, and treat a pure Dart package as unknown | Cheaper, and defensible on the evidence: **all 22 `pubspec.yaml` files on the machine are Flutter and none is pure Dart.** It also means the first server-side Dart repository silently gets nothing, and the split costs one `grep` |
| Set `language: flutter` rather than `language: dart` | Rejected. Flutter is the framework and Dart is the language, which is the shape every other row uses: `stack.framework` already holds `laravel`, `spring`, `next`, `apex`. It would also break the `tool-choices.md` row rule, which keys on the language |
| Add a `dart` arm to `lang_lsp` | Rejected, and it needs no code. There is no Dart language server in the marketplace, checked 2026-08-29. An id that does not resolve is worse than none, which `lang_lsp`'s own comment says |
| Read `analysis_options.yaml` to decide `verify.lint` | Rejected. `flutter analyze` runs against the SDK's default lint set whether or not that file exists, and **8 of the 15 do not have it.** Gating on it would leave the majority of the fleet with a null lint command that in fact runs |
| Add `sqflite` and `shared_preferences` to `detect_datastores` | Recommended as part of it. `sqflite` is SQLite and appears in 13 of 15. `detect_datastores` already has a `sqlite` pair; the change is adding `pubspec.yaml` to its manifest file list and the token to that pair |
| Detect Flutter version or channel from the project | Rejected. Nothing in the fleet declares one: no `.fvmrc`, no `fvm_config.json`, no `.fvm/`, and `fvm` is not installed. The only source would be the ambient `flutter --version`, which is a property of the machine and not of the repository |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A Dart project declares itself with `pubspec.yaml` | The marker is a manifest, like the other thirteen | 15 of 15 in the fleet have one, and all 22 found on the machine do | **Yes** |
| `.dart` files alone are not a safe marker | A tree of Dart source without a manifest exists | The orphan tree: ten `.dart` files under `lib/`, no `pubspec.yaml` at any level, not a git repository. Keying on the manifest excludes it correctly | **Yes, and it rules out the obvious shortcut** |
| `pubspec.yaml` does not collide with another manifest | No project declares two ecosystems | Checked across all 22: none sits beside a `package.json`, `go.mod`, `Cargo.toml` or `pom.xml`. So the precedence question is untested rather than settled | Partly. No instance exists to test the ordering against |
| `verify.test` is worth setting | A test command that runs is better than null | All 15 have a `test/` directory and at least one `*_test.dart`, so `flutter test` always runs. **But 13 of the 15 have exactly one, the generated `widget_test.dart`.** The command is real; what it exercises mostly is not | **Yes, and the caveat is real.** Open question 3 |
| Six verify keys are fillable from the toolchain | The SDK ships runner, analyzer, formatter and builder | `dart --version` 3.12.2 and `flutter --version` 3.44.4 on this machine, one binary each, no per-project config needed | **Yes** |
| Flutter implies a user interface | `has_ui` should be true | Follows from what Flutter is. `detect_has_ui` (`lib/detect-stack.sh:700-706`) keys on a framework list that would gain `flutter`, exactly as it already carries `apex` | **Yes** |
| One `build` command is knowable | Flutter builds without a target | It does not: `flutter build` requires `apk`, `ipa`, `web` and so on. The platform directories are discoverable (`android/` and `ios/` in all 15) but choosing among them is a guess | **No, and it is the one key that should stay null.** Open question 4 |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| Dart was excluded by name, with a reason | `docs/plans/2026-08-14-multi-stack-detection.md:67-70` | This is a reversal and must argue against that sentence, not around it. The reversal is that Dart yields six verify keys, not one |
| There is still no Dart language server | The marketplace on this machine lists twelve LSP ids, the same twelve at `lib/detect-stack.sh:758-773`. Checked 2026-08-29 | The LSP half needs no code. `lang_lsp` returns empty for an unmapped language and `detect_plugins` skips it, which is what `plsql` already relies on |
| Every detected language is read from a declared manifest | `lib/detect-stack.sh:306-364` | `pubspec.yaml` fits the doctrine exactly. Unlike PL/SQL, this needs no inference and no ratio test |
| A detected language with no `tool-choices.md` row fails the build | `tests/validate-skills.sh:414-429`, which extracts the languages from `detect_languages` itself and demands a row per language | Adding `dart` requires at least one row in `skills/keel/references/tool-choices.md`. Its Test, Lint and Typecheck tables all carry a `plsql` row, so three is the shape to match |
| `has_ui` is currently wrong, not merely empty | `detect_has_ui` (`lib/detect-stack.sh:700-706`) keys on `next react vue svelte angular apex`, then falls back to `public/` or `index.html`. A Flutter app has neither, so it returns `false` | The only field where the current behaviour actively misinforms a skill. One word in one `case` fixes it |
| `detect_datastores` cannot see a Dart dependency | `lib/detect-stack.sh:721-753` greps a fixed list of manifest files that does not include `pubspec.yaml` | `sqflite` in 13 of 15 is invisible. Adding one filename and one token to the existing `sqlite` pair covers the fleet |
| The verify arms are per-language `case` blocks | `detect_verify` (`lib/detect-stack.sh:456-693`), one arm per language, each gating a command on a marker before emitting it | A `dart` arm is additive and touches nothing else. The Rust and C# arms are the closest models: toolchain commands, emitted unconditionally |
| There is no Dart fixture anywhere in the tests | `tests/test-keel.sh:44-140` builds one fixture per ecosystem; none is Dart | The test shape is established and the work is a new `fixture_build` arm plus rows in the existing detection loop at `:174-191` |
| PL/SQL is the precedent for the whole shape of this change | `docs/ideas/plsql-stack-detection.md`, `docs/prd/plsql-stack-detection.md`, `docs/plans/2026-08-18-plsql-stack-detection.md` | A fourteenth language has been added once, recently, through the full chain. This one is strictly easier: a declared manifest, real commands, and no language server to argue about |
| The fleet has no wrapper scripts to read | No `Makefile`, no `justfile`, no `scripts/` directory in any of the 15 | Nothing to detect beyond the SDK commands, and nothing to prefer over them |
| The language list is enumerated in only one place that must be kept in step | `skills/keel/references/tool-choices.md`, and it is enforced. `templates/profile.schema.json:58` describes the detection doctrine rather than listing languages, and its sentence stays true for Dart because `pubspec.yaml` is a declared manifest. No count in `README.md` or `docs/` needs changing | The documentation cost is one to three table rows, not a sweep. Checked 2026-08-29 rather than assumed, because the PL/SQL change had to correct that sentence |

## Open questions

1. ~~**Flutter only, or Dart generally?**~~ **Answered 2026-08-29 while writing the PRD: both, and
   the pure Dart half is labelled rather than justified.** It is `FR-07`, and it is the one
   requirement in that document marked `author-added`, because no pure Dart project exists anywhere
   in current work. It survives on the tooling contract alone. Whether it is wanted at all is now
   `Q1` of the PRD.
2. ~~**Where does `dart` sit in the precedence chain in `detect_languages`?**~~ **Answered
   2026-08-29 by the plan's first task, S-11: first, before the `package.json` block.** `FR-19`
   requires only that `dart` be primary and that no other language's manifest be suppressed, and no
   repository on the machine declares two ecosystems, so nothing forced the position. A later
   position hands a Dart project another language's verify commands; the front is safe because the
   check reads the root only. Now `Q2` of the PRD, closed there.
3. ~~**Should `verify.test` be set when the only test is the generated `widget_test.dart`?**~~
   **Answered 2026-08-29: yes.** Now assumption `A3` of the PRD, on the argument recommended here,
   and kept as `Q4` because it is the assumption most likely to be disagreed with. 13 of 15.
4. ~~**What is `verify.build` for a Flutter project?**~~ **Answered 2026-08-29 by Bernard, asked as a
   choice: `null`.** Now `FR-13`, the only `confirmed` requirement in the PRD besides the feature
   itself. `flutter build --help` was run the same day and lists eight targets, which is why there is
   no default to pick.

## Recommendation

**Build it.** Detect `dart` from `pubspec.yaml`, set `framework` to `flutter` where the manifest
declares the SDK dependency, fill `test`, `test_one`, `lint`, `format` and `format_fix` from the
toolchain, leave `build`, `typecheck`, `e2e`, `security` and `test_integration` null, set `has_ui`
true for Flutter, and teach `detect_datastores` to read `pubspec.yaml`.

Why: the marker is a declared manifest, so this respects the doctrine that PL/SQL had to bend; the
evidence is fifteen live repositories against PL/SQL's two; and the 2026-08-14 deferral rests on a
claim about Dart's toolchain that does not survive being checked. The one field that is currently
wrong rather than empty, `has_ui`, is fixed by a word.

Next: `write-prd`. It should settle the four open questions above, and the `tool-choices.md` rows,
before any code is written.

## Not decided here

- The exact `detect_verify` command strings, including whether format is
  `dart format --output=none --set-exit-if-changed .` or the `flutter` spelling of it. Left to
  `write-prd`.
- ~~Whether `stack.runtime` reads `dart`, `flutter` or `vm`.~~ Settled in the PRD as `dart`, `FR-04`,
  mirroring `php php`, `python python`, `ruby ruby` and `rust rust`: the runtime is the language's own
  VM and `flutter` is the framework.
- How a local path-dependency plugin is treated. One repository in the fleet has two nested
  `pubspec.yaml` files under a `plugins/` directory; none has a `melos.yaml`. It is not a monorepo
  and probably needs no rule, but nobody has decided that.
- Whether `coding-standards` grows a Dart section. Out of scope, as it was for PL/SQL.
