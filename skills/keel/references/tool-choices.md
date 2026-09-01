# Tool choices

Read this when a document is about to say "there are no tests here" or "nothing formats this code",
and the reader will then have to choose a tool. Cited by `repo-snapshot` section 10; usable by any
skill recommending tooling.

**Each row carries its reason, not its verdict.** A pick without a reason is an opinion that cannot
be corrected and cannot be seen going stale. If a reason has stopped being true, the row is wrong
whatever the tool's current popularity, and changing it is a normal edit.

## The rules that matter more than the tables

1. **A working tool is not a gap.** A repository with 2,000 passing Jest tests has a test runner.
   Recommending Vitest there is a migration proposal, which is a different document and usually a
   bad idea. Read what is installed before reading these tables.
2. **One pick, one reason, one runner-up.** The runner-up says when the pick is wrong. A list of
   five is the decision fatigue this file exists to remove.
3. **At most three new tools per document.** Section 10 caps recommendations at seven items and asks
   for two or three in the handoff, for the same reason: a reader adopts none of a list of seven.
4. **Key on `profile.stack.language`**, which every keel project already has, rather than
   re-detecting. Where a repository is multi-stack, `stack.also` holds the rest and the primary
   language wins.
5. **Never recommend a second CI system, a second package manager, or a second test runner.** Those
   are the three where two of a thing is worse than one of either.
6. **Prefer what is already in the toolchain.** `go test`, `cargo test` and `dotnet format` add
   nothing to install, nothing to configure, and nothing to keep current.

## Test runner

| Language | Pick | Runner-up | Why the pick |
|---|---|---|---|
| `typescript` | Vitest | Jest | Reads the project's existing bundler config, runs TS and ESM with no transform layer to maintain, and its API is close enough to Jest's that knowledge transfers |
| `javascript` | Vitest | `node:test` | Same reason. `node:test` is the right answer when the project refuses every dependency, and it is now capable enough to mean it |
| `python` | pytest | `unittest` | Plain functions and fixtures, so a test costs less to write than a class; `unittest` where a dependency is genuinely refused, since it is stdlib |
| `go` | `go test` | none | In the toolchain. Adding a framework to Go tests is a step backwards, and table-driven tests are the idiom |
| `java` | JUnit 5 | TestNG | Both Maven and Gradle wire it up with no plugin, and it is what every current guide assumes |
| `kotlin` | JUnit 5 with kotlin-test | Kotest | Keeps one runner across a mixed JVM repository. Kotest earns itself on property-based testing, not on ordinary unit tests |
| `csharp` | xUnit | NUnit | The .NET template default, so `dotnet new` and every tutorial agree with the repository |
| `php` | PHPUnit | Pest | What Laravel and Symfony both ship against, so the framework's own test helpers work unmodified. Pest is a nicer syntax over the same engine, worth it on a new codebase |
| `ruby` | RSpec | Minitest | Where Rails generated Minitest, keep Minitest: it is installed, it is fast, and switching costs a rewrite for no behaviour change |
| `rust` | `cargo test` | none | In the toolchain, and doc tests come free |
| `swift` | swift-testing | XCTest | The current direction and much less ceremony per test. XCTest where the project still supports an older toolchain |
| `cpp` | Catch2 | GoogleTest | Header-only, so it adds a dependency and not a build system. GoogleTest where mocking is central |
| `lua` | busted | none | The only option with real adoption |
| `plsql` | utPLSQL | none | The only real option, and the ecosystem agrees on it. It runs inside the database, so `verify.test` stays `null` until somebody supplies a connection string, a schema and credentials, none of which belong in the repository |
| `dart` | `flutter test` for a Flutter project, `dart test` for a plain package | none | Both are SDK commands, but only Flutter bundles its runner. `flutter test` needs no dev dependency; `dart test` fails with "Could not find package `test`" unless the pubspec declares `package:test`. The lock is one-directional, measured 2026-08-29: `dart test` cannot drive a Flutter project, because the plain VM has no `dart:ui`, while `flutter test` does run in a plain package. `dart test` is still the right answer there, so that testing a plain package does not drag in the Flutter SDK. Both need a test to run before they are worth writing down: measured 2026-08-30, each exits non-zero when `test/` is absent or holds no `*_test.dart`, so `verify.test` stays `null` until there is one |

**Coverage:** use the runner's own first (`vitest --coverage`, `pytest --cov`, `go test -cover`,
JaCoCo on Gradle). A separate coverage tool is a second thing to configure for a number that is
already available.

## Lint and format

The profile splits these on purpose: `verify.lint` and `verify.format` must be **check-only**,
because the commit guard runs them and a hook that rewrites files puts content into a commit its
author never read. `verify.format_fix` is the writing one.

| Language | Pick | Runner-up | Why the pick |
|---|---|---|---|
| `typescript`, `javascript` | Biome | ESLint with Prettier | One tool, one config, lint and format together, and fast enough that nobody disables it. ESLint stays right where the project already depends on plugins Biome has no equivalent for |
| `python` | Ruff | flake8 with Black | Replaces both linter and formatter with one binary and one config section, and it is a drop-in for the rules teams actually had enabled |
| `go` | `gofmt` with `go vet` | golangci-lint | Both in the toolchain and both non-negotiable in the ecosystem. golangci-lint when the team wants more than correctness |
| `java`, `kotlin` | Spotless | Checkstyle, or ktlint for Kotlin | Runs in the existing Gradle or Maven build, and has both a check and an apply goal, which is exactly the split the profile needs |
| `csharp` | `dotnet format` with analyzers | StyleCop | In the SDK. Analyzer rules ship with the compiler and fail the build, which is stronger than a separate pass |
| `php` | PHP-CS-Fixer | PHP_CodeSniffer | Fixes as well as reports, and its rule sets track the PSR standards the frameworks assume |
| `ruby` | RuboCop | standard | The ecosystem default, and its `--only` mode makes adoption on a legacy codebase possible rather than theoretical |
| `rust` | `cargo fmt` with `cargo clippy` | none | In the toolchain, and clippy catches real bugs rather than only style |
| `swift` | swift-format | SwiftLint | Ships with the toolchain now. SwiftLint adds opinions beyond formatting |
| `cpp` | clang-format with clang-tidy | cpplint | The compiler vendor's own, so it understands the language rather than pattern-matching it |
| `lua` | Stylua with luacheck | none | Formatting and static analysis are separate here, and both are small |
| `plsql` | none | none | No linter ships outside vendor IDE tooling, and a rule set nobody can run in CI is not a lint step. Say `null` in the profile |
| `dart` | `dart analyze` with `dart format` | none | Both ship with the SDK and both run with no configuration, which is why `verify.lint` is not gated on `analysis_options.yaml`: measured 2026-08-29, `dart analyze` reports real type errors in a package that has no such file. `flutter analyze` is the same analyzer invoked through the Flutter SDK. `flutter format` was removed; `dart format` is the only spelling left |
| shell | shellcheck | none | Nothing else finds shell bugs. It is what this repository uses on itself |

## Typecheck

| Language | Pick | Why |
|---|---|---|
| `typescript` | `tsc --noEmit` | The compiler already in the project. A bundler that strips types is not a typecheck |
| `python` | mypy | The reference implementation and the one library stubs target. Pyright is faster and stricter by default, which is better on a new codebase and painful to adopt on an old one |
| `php` | PHPStan | Levels 0 to 9 make adoption incremental, which is the only way it happens on an existing codebase |
| `ruby` | none | Sorbet only where it is already in use. Adding gradual typing to an untyped Ruby codebase is a project, not a gap |
| `java`, `kotlin`, `csharp`, `go`, `rust`, `swift`, `cpp` | the build | Compiled. `verify.build` is the typecheck and `verify.typecheck` stays `null` rather than repeating it |
| `javascript`, `lua` | none | Say `null` in the profile. A typecheck a language cannot do is not a gap |
| `plsql` | none | The database is the compiler. A package body that does not compile fails at install time, so `verify.typecheck` stays `null` rather than repeating it |
| `dart` | none | The analyzer is the type checker and it is already the lint command, so `verify.typecheck` stays `null` rather than running the same analysis twice under a second name |

## Everything else

Mostly language-independent, and the first rule is the same in every row: use what the repository
and its host already have.

| Gap | Pick | Runner-up | Why the pick |
|---|---|---|---|
| CI | Whatever the host is: GitHub Actions on GitHub, GitLab CI on GitLab | none | A second CI system is the worst outcome available. Where the repository is already on a host, the choice is made |
| Container | Multi-stage Dockerfile, non-root user, a `HEALTHCHECK`, pinned base by digest | none | The three things whose absence is always a finding. A `HEALTHCHECK` is what lets a deploy fail loudly rather than serving a broken image |
| Dependency updates | The host's own: Dependabot on GitHub, Renovate anywhere | Renovate | Zero infrastructure and it already has repository access. Renovate when grouping and scheduling matter more than setup cost |
| Vulnerable dependencies | The ecosystem's own in CI: `npm audit`, `pip-audit`, `govulncheck`, `cargo audit`, `bundler-audit`, `dotnet list package --vulnerable` | Trivy or Grype | Each knows its own lockfile format exactly. One scanner across a polyglot repository when there are three or more languages |
| Secret scanning | gitleaks | trufflehog | One config drives both the CI job and a pre-commit hook, so it catches the secret before the commit that has to be rewritten. trufflehog verifies findings against live services, which is better triage and needs more trust |
| Container and IaC scanning | Trivy | Grype with Checkov | One tool over images, filesystems and IaC, so it is one job rather than three |
| Observability | The OpenTelemetry SDK for the language, exporting OTLP to whatever `profile.observability.backend` names | none | The instrumentation outlives the backend choice, which is the whole point of picking OTLP over a vendor SDK |
| Structured logging | The ecosystem's own: pino, structlog, slog, Logback with a JSON encoder, Serilog, Monolog | none | Never a bespoke wrapper. `../../coding-standards/references/observability.md` sets what a log line must carry; these are what carry it |
| Migrations | The framework's own, and never hand-rolled SQL in a deploy script | none | Every framework has one, it is already wired to the connection config, and its state table is the thing a hand-rolled script lacks |
| Pre-commit orchestration | The `pre-commit` framework, or `keel guard install` in a keel project | Husky with lint-staged on JS | Language-independent and it pins each hook's version. `lint-staged` is right where the only hooks are JS formatters |

**If a stack is not in these tables**, say so in the document and name what you would look for
instead: whether the ecosystem has one obvious default, whether it is in the toolchain already, and
whether the repository's neighbours in the same organisation have made a choice worth matching. Do
not guess a package name.
