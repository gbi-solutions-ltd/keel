# Multi-Stack Detection Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** make `keel init` produce a usable profile on twelve languages rather than six, with a
verified language server suggested for each and verify commands read from what the project declares.

**Stories:** none written. This plan was requested directly and the scope was settled with two
choices, recorded under Decisions taken below.
**ADRs:** none. No accepted decision touches stack detection.
**Architecture:** `lib/detect-stack.sh` keeps its existing contract, that a command is emitted only
when the project declares the tool, and gains a single marker table (`detect_languages`) that both
the primary stack and the new secondary list read from. `bin/keel` writes the new `stack.also` field
and enables a language server per detected language. No new file is created.

## Global constraints

Copied from `.keel/profile.json` and the repository conventions. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch`
- There is no format, typecheck or build command in this project. Where a step would need one, it
  says so rather than substituting a guess.
- Never start on `main`. Branch first.
- Conventional commits, title and body only. No attribution footers, no robot emoji.
- No em dashes or en dashes anywhere. `tests/validate-skills.sh` enforces this for `skills/` and
  `templates/`.
- **A command is emitted only when the project declares the tool.** This is the existing contract at
  the top of `lib/detect-stack.sh` and the reason a wrong profile is worse than an empty one. A
  declaration is a file in the repository: a lockfile, a config file, a manifest entry. It is never
  the presence of a binary on the machine running `keel init`, because that freezes one laptop's
  answer into a file every teammate reads.
- The full suite takes a few minutes. Run it in the background rather than at a 120s timeout.

## Execution order, and the one adjustment it needs

**Tasks 5, 6 and 7 run first, then 1, 2, 3 and 4.** Decided after the plan was written: those three
are bug fixes to languages keel already claims to support, so they help repositories that are using
it today, while the new languages help repositories that are not using it yet. Task numbers are left
alone so the references between tasks still resolve.

Two PRs, at the seam between the two groups:

| PR | Tasks | What it is |
|---|---|---|
| 1 | 5, 6, 7 | Bug fixes. Changes what an existing project gets when `init` is re-run, so it is the one to read carefully |
| 2 | 1, 2, 3, 4 | Six new languages, a server each, and `stack.also` |

**The seam was not used.** Asked at the point tasks 5, 6 and 7 were committed, the decision was to
keep going on `fix/stack-tooling-detection` and land all seven as one PR. The two groups are still
separate commits in that order, so the bug fixes can be read on their own in review.

Running 5 and 6 before 1 needs one adjustment, because they were written to replace stubs that task 1
introduces. Instead of replacing a stub, each **adds** its function and wires it into the existing
`detect_stack`, which today hardcodes `npm` and `pip`:

- Task 5 changes `printf '%s %s %s %s\n' "$lang" "$rt" "$fw" "npm"` to use `$(detect_js_pm)`.
- Task 6 changes `printf 'python python none pip\n'` to `printf 'python python none %s\n' "$(detect_py_pm)"`.
- Task 1 then drops its stubs section: `lang_profile` already calls both functions, and they exist.
- The `verify_of` test helper is written in task 2. Task 5 defines it instead, as the first task to
  run, and task 2 drops its copy.

## Decisions taken

1. **Twelve languages, not seventeen.** The six added are exactly the six that have a language
   server in `claude-plugins-official`: C#, Ruby, Kotlin, Swift, C/C++ and Lua. Elixir, Dart, Scala,
   Terraform and shell were considered and deferred: they have real toolchains but no LSP plugin, so
   they would get a test command and nothing else.
2. **Polyglot repos get a primary plus a secondary list.** `stack.language` stays single and drives
   the verify commands. A new `stack.also` array names every other language detected, and each one
   gets its language server enabled.

Verified against the marketplace manifest at
`~/.claude-profiles/gbi/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json`,
287 plugins. The six ids used below are `csharp-lsp`, `ruby-lsp`, `kotlin-lsp`, `swift-lsp`,
`clangd-lsp` and `lua-lsp`. Do not add a plugin id that is not in that file.

## Bugs this plan fixes, found while reading

These are not new features. Each is current behaviour that is wrong, and each has a task.

| Bug | Where | Task |
|---|---|---|
| A Kotlin Gradle project is reported as `java`, framework `spring` | `detect_stack` | 1 |
| Every Maven or Gradle project is reported as framework `spring`, Quarkus and Micronaut included | `detect_stack` | 1 |
| `verify.test` is set to `pytest` on every Python project, declared or not, so `keel doctor` fails on a project that uses unittest | `detect_verify` | 6 |
| PHP gets no test command at all unless `vendor/` happens to be installed, which it is not on a fresh clone | `detect_verify` | 7 |
| Go's lint command depends on `golangci-lint` being on the detecting machine's PATH, which is exactly what the `gofmt` comment three lines below says not to do | `detect_verify` | 7 |
| A declared `typecheck` script is detected and then discarded in favour of `npx tsc --noEmit` | `detect_verify` | 5 |
| `pnpm`, `yarn` and `bun` projects are all told to run `npm` | `detect_stack`, `detect_verify` | 5 |

---

### Task 1: One marker table, and six more languages in it

**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `bin/keel` (`write_profile`, one line)
- Modify: `docs/03-install-and-distribution.md` (detection matrix)
- Test: `tests/test-keel.sh`

**Interfaces:**
- Produces: `detect_languages()`, prints every detected language one per line in priority order,
  nothing when none match. `lang_profile(<lang>)`, prints `language runtime framework package_manager`
  for one language. `find_marker(<maxdepth> <pattern>...)`, returns 0 when a matching path exists.
  `detect_also()`, prints every language after the first.
- Consumes: nothing new.
- `detect_stack()` keeps its existing output contract exactly: one line,
  `language runtime framework package_manager`.
- `detect_verify()` gains an optional second argument, the language, defaulting to the detected one.
  `write_profile` already knows the language and calls `detect_verify` ten times in a loop; without
  this each of those ten calls re-runs detection, and detection now touches the filesystem.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, extend the `fixture()` helper with the six new stacks. Add these cases to
its `case "$stack" in` block, before `bare)`:

```bash
        csharp)
          mkdir -p src/Api
          printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>\n' \
            > src/Api/Api.csproj ;;
        ruby)
          printf "source 'https://rubygems.org'\ngem 'rails'\ngem 'rspec'\n" > Gemfile
          mkdir -p spec ;;
        kotlin)
          printf 'plugins { kotlin("jvm") version "2.0.0" }\n' > build.gradle.kts
          mkdir -p src/main/kotlin && printf 'fun main() {}\n' > src/main/kotlin/App.kt ;;
        swift)
          printf '// swift-tools-version:5.9\nimport PackageDescription\n' > Package.swift ;;
        cpp)
          printf 'cmake_minimum_required(VERSION 3.20)\nproject(f)\nenable_testing()\n' > CMakeLists.txt ;;
        lua)
          printf '{"runtime":{"version":"LuaJIT"}}\n' > .luarc.json
          printf 'return {}\n' > init.lua ;;
        polyglot)
          cat > package.json <<'P'
{"name":"f","scripts":{"test":"vitest run"},"devDependencies":{"typescript":"^5"}}
P
          echo '{}' > tsconfig.json
          printf '[project]\nname = "f"\n' > pyproject.toml ;;
```

Then extend the existing detection loop. Replace the `for stack in node-ts go php python; do` line
and its `case` with:

```bash
for stack in node-ts go php python csharp ruby kotlin swift cpp lua; do
    d="$(fixture "$stack")"
    ( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
    got="$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json'))['stack']['language'])" 2>/dev/null)"
    case "$stack" in
      node-ts) want=typescript ;;
      go)      want=go ;;
      php)     want=php ;;
      python)  want=python ;;
      csharp)  want=csharp ;;
      ruby)    want=ruby ;;
      kotlin)  want=kotlin ;;
      swift)   want=swift ;;
      cpp)     want=cpp ;;
      lua)     want=lua ;;
    esac
    [ "$got" = "$want" ] && ok "detects $stack as $want" || bad "detects $stack" "got '$got', want '$want'"
    rm -rf "$d"
done

# A Kotlin Gradle build was reported as java/spring: the build.gradle.kts branch was reached before
# anything looked for Kotlin, and the java branch hardcoded spring. Both halves are asserted here
# because fixing one without the other still writes a wrong profile.
d="$(fixture kotlin)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(python3 -c "import json;s=json.load(open('$d/.keel/profile.json'))['stack'];print(s['framework'],s['package_manager'])" 2>/dev/null)"
[ "$got" = "none gradle" ] && ok "a Kotlin build is not labelled spring" \
  || bad "detects kotlin" "framework and package manager were '$got', want 'none gradle'"
rm -rf "$d"

# A Maven project with no Spring dependency must not be called spring either.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '<project><groupId>f</groupId><artifactId>f</artifactId></project>\n' > pom.xml )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json'))['stack']['framework'])" 2>/dev/null)"
[ "$got" = "none" ] && ok "a Maven project with no Spring dependency is framework none" \
  || bad "detects java" "framework '$got', want 'none'"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `detects csharp`, `detects ruby`, `detects kotlin`, `detects swift`, `detects cpp`,
`detects lua` (each reporting `got 'unknown'`, except kotlin which reports `got 'java'`), on
`a Kotlin build is not labelled spring`, and on
`a Maven project with no Spring dependency is framework none`.

- [x] **Step 3: Write the minimal implementation**

In `lib/detect-stack.sh`, add the marker helper above `detect_stack`:

```bash
# Whether any path matching one of the given patterns exists within $1 levels. Depth-bounded and
# stopped at the first hit, because a detector that walks a monorepo costs seconds on every init.
# Only the languages whose manifest is routinely in a subdirectory need this; a top-level `[ -f ]`
# is checked first everywhere it can be, so most repositories never reach a find at all.
find_marker() {   # find_marker <maxdepth> <pattern>...
    local depth="$1" p; shift
    for p in "$@"; do
        [ -n "$(find . -maxdepth "$depth" -name "$p" \
                  -not -path './node_modules/*' -not -path './.git/*' \
                  -print -quit 2>/dev/null)" ] && return 0
    done
    return 1
}
```

Replace the whole of `detect_stack` with the table and its two readers:

```bash
# Every language with a marker in this tree, one per line, most specific first. The order is the
# priority order: the first line is the primary stack and drives the verify commands, and the rest
# become stack.also. A language appears at most once.
detect_languages() {
    local out=""
    if [ -f package.json ]; then
        if [ -f tsconfig.json ] || grep -q '"typescript"' package.json 2>/dev/null
        then out="$out typescript"; else out="$out javascript"; fi
    fi
    [ -f go.mod ] && out="$out go"
    [ -f composer.json ] && out="$out php"
    { [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; } && out="$out python"
    [ -f Cargo.toml ] && out="$out rust"
    [ -f Gemfile ] && out="$out ruby"
    [ -f Package.swift ] && out="$out swift"
    { [ -f .luarc.json ] || [ -f init.lua ] || find_marker 2 '*.rockspec'; } && out="$out lua"
    { [ -f CMakeLists.txt ] || [ -f meson.build ] || [ -f Makefile.am ]; } && out="$out cpp"
    { [ -f global.json ] || find_marker 3 '*.csproj' '*.sln' '*.fsproj'; } && out="$out csharp"

    # Kotlin before java, because a Gradle build is the marker for both and Kotlin is the specific
    # case. Read from the build files rather than the source tree: a Java project with one Kotlin
    # test is still a Java project, and a Gradle build that applies the Kotlin plugin is not.
    { [ -f build.gradle.kts ] || grep -qs kotlin build.gradle build.gradle.kts; } && out="$out kotlin"
    if [ -f pom.xml ] || [ -f build.gradle ]; then
        # Where Kotlin already matched, Java is added only if the tree really has Java sources.
        # Otherwise every Kotlin project built with a Groovy build file is reported as Java as well.
        case " $out " in
          *" kotlin "*) find_marker 4 '*.java' && out="$out java" ;;
          *)            out="$out java" ;;
        esac
    fi

    # Word splitting is the point here, and the first occurrence wins so the primary is stable
    # whatever a repository adds later.
    # shellcheck disable=SC2086
    [ -n "$out" ] && printf '%s\n' $out | awk '!seen[$0]++'
    return 0
}

# Echo: language runtime framework pkgmgr, for one language. Split out of detect_stack so the
# primary stack and every secondary language read the same table.
lang_profile() {
    local l="$1"
    case "$l" in
      typescript|javascript)
        local fw=none marker
        # Each framework has its own marker. An earlier version OR'd the nestjs marker into
        # every iteration, so the first name in the list always won and every NestJS service was
        # reported as Next.js.
        for f in nest next nuxt express fastify react vue svelte angular; do
            case "$f" in
              nest) marker='"@nestjs/core"' ;;
              *)    marker="\"$f\"" ;;
            esac
            grep -q "$marker" package.json 2>/dev/null && { fw=$f; break; }
        done
        printf '%s node %s %s\n' "$l" "$fw" "$(detect_js_pm)" ;;
      go)     printf 'go go none go\n' ;;
      php)
        local fw=none
        grep -q 'laravel/framework' composer.json 2>/dev/null && fw=laravel
        grep -q 'symfony/' composer.json 2>/dev/null && fw=symfony
        printf 'php php %s composer\n' "$fw" ;;
      python) printf 'python python none %s\n' "$(detect_py_pm)" ;;
      rust)   printf 'rust rust none cargo\n' ;;
      java|kotlin)
        local g=gradle fw=none
        [ -f pom.xml ] && g=maven
        # Framework, not assumed. Every JVM project was reported as spring, which put a wrong
        # framework in front of every skill that reads the profile.
        grep -qs 'springframework\|spring-boot' pom.xml build.gradle build.gradle.kts && fw=spring
        grep -qs 'io.quarkus' pom.xml build.gradle build.gradle.kts && fw=quarkus
        grep -qs 'io.micronaut' pom.xml build.gradle build.gradle.kts && fw=micronaut
        printf '%s jvm %s %s\n' "$l" "$fw" "$g" ;;
      csharp)
        local fw=none
        grep -rqs 'Microsoft.AspNetCore' --include='*.csproj' . && fw=aspnetcore
        printf 'csharp dotnet %s nuget\n' "$fw" ;;
      ruby)
        local fw=none
        grep -qs "rails" Gemfile && fw=rails
        grep -qs "sinatra" Gemfile && fw=sinatra
        printf 'ruby ruby %s bundler\n' "$fw" ;;
      swift)
        local pm=swiftpm
        find_marker 2 '*.xcodeproj' && pm=xcode
        printf 'swift swift none %s\n' "$pm" ;;
      cpp)
        local pm=make
        [ -f CMakeLists.txt ] && pm=cmake
        [ -f meson.build ] && pm=meson
        printf 'cpp native none %s\n' "$pm" ;;
      lua)    printf 'lua lua none luarocks\n' ;;
      *)      printf 'unknown unknown none none\n' ;;
    esac
}

# Echo: language runtime framework pkgmgr, for the primary stack.
detect_stack() {
    local l; l="$(detect_languages | head -n 1)"
    lang_profile "${l:-unknown}"
}

# Every language other than the primary. Empty when the repository is single-stack.
detect_also() {
    detect_languages | tail -n +2
}
```

Then let `detect_verify` take the language it should answer for, so the caller that already knows it
does not pay for detection ten times. Change its first line from

```bash
    local what="$1" lang; lang="$(detect_stack | cut -d' ' -f1)"
```

to

```bash
    # The language is passed in by write_profile, which already knows it. Detection now touches the
    # filesystem, and this function is called once per verify key.
    local what="$1" lang="${2:-}"
    [ -n "$lang" ] || lang="$(detect_stack | cut -d' ' -f1)"
```

and in `bin/keel`, in `write_profile`, change

```bash
          v="$(detect_verify "$k")"
```

to

```bash
          v="$(detect_verify "$k" "$lang")"
```

**Dropped while executing**, per the execution-order note above: tasks 5 and 6 ran first, so
`detect_js_pm` and `detect_py_pm` already exist and `lang_profile` calls the real ones. The stubs
below were not written.

```bash
# Replaced in task 5 with real lockfile detection.
detect_js_pm() { printf 'npm'; }
# Replaced in task 6 with real lockfile detection.
detect_py_pm() { printf 'pip'; }
```

Then update the detection matrix in `docs/03-install-and-distribution.md`, replacing the existing
six signal rows with:

```markdown
| `package.json` with `typescript` dep | TypeScript, plus `typescript-lsp` |
| `package.json` scripts | `verify.test`, `verify.lint`, `verify.build` read directly from `scripts` |
| `go.mod` | Go, `go test ./...`, plus `gopls-lsp` |
| `composer.json` | PHP, plus `php-lsp` |
| `pyproject.toml`, `requirements.txt` or `setup.py` | Python, plus `pyright-lsp` |
| `pom.xml` or `build.gradle` | Java, plus `jdtls-lsp` |
| `build.gradle.kts`, or `kotlin` in a Gradle build | Kotlin, plus `kotlin-lsp` |
| `Cargo.toml` | Rust, plus `rust-analyzer-lsp` |
| `*.csproj`, `*.sln` or `global.json` | C#, `dotnet test`, plus `csharp-lsp` |
| `Gemfile` | Ruby, plus `ruby-lsp` |
| `Package.swift` | Swift, `swift test`, plus `swift-lsp` |
| `CMakeLists.txt` or `meson.build` | C or C++, plus `clangd-lsp` |
| `.luarc.json`, `init.lua` or a `*.rockspec` | Lua, plus `lua-lsp` |
```

The polyglot row is added to this table in task 4, when `stack.also` exists.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all ten detection assertions, on the Kotlin framework assertion and on the Maven
one. Then `tests/run-tests.sh` in the background; nothing else may break. Then the lint command from
Global constraints; `find_marker` and the nested `add()` are the two places shellcheck is most
likely to complain.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh bin/keel tests/test-keel.sh docs/03-install-and-distribution.md
git commit -m "feat(detect): one marker table, and six more languages in it"
```

---

### Task 2: Verify commands for the six new languages

**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `detect_stack` from task 1, and the six language names it now emits.
- Produces: nothing new. `detect_verify <what>` keeps its signature and its contract, that an
  undeclared tool produces the empty string and therefore `null` in the profile.

- [x] **Step 1: Write the failing test**

Append to the detection section of `tests/test-keel.sh`:

```bash
# ---- verify commands for the languages added in this plan -------------------
# One assertion per language on the command that is not a guess, and one on a command that must
# stay null because the project declares no such tool. The null half is the half that matters:
# a profile with a wrong command fails at first use and teaches people to distrust the file.
# The `verify_of` helper this block used was dropped: task 5 ran first and already defines it.
d="$(fixture csharp)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "dotnet test" ] && ok "C# gets dotnet test" \
  || bad "verify csharp" "test was '$(verify_of "$d" test)'"
[ "$(verify_of "$d" format)" = "dotnet format --verify-no-changes" ] && ok "C# formats with the SDK formatter" \
  || bad "verify csharp" "format was '$(verify_of "$d" format)'"
rm -rf "$d"

d="$(fixture ruby)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "bundle exec rspec" ] && ok "Ruby with a spec dir gets rspec" \
  || bad "verify ruby" "test was '$(verify_of "$d" test)'"
[ -z "$(verify_of "$d" lint)" ] && ok "Ruby without rubocop declared gets no lint command" \
  || bad "verify ruby" "lint was guessed as '$(verify_of "$d" lint)'"
rm -rf "$d"

d="$(fixture kotlin)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "./gradlew test" ] && ok "Kotlin gets the Gradle test task" \
  || bad "verify kotlin" "test was '$(verify_of "$d" test)'"
[ "$(verify_of "$d" typecheck)" = "./gradlew compileKotlin" ] && ok "Kotlin typechecks with compileKotlin, not compileJava" \
  || bad "verify kotlin" "typecheck was '$(verify_of "$d" typecheck)'"
rm -rf "$d"

d="$(fixture swift)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "swift test" ] && ok "Swift gets swift test" \
  || bad "verify swift" "test was '$(verify_of "$d" test)'"
rm -rf "$d"

d="$(fixture cpp)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" build)" = "cmake --build build" ] && ok "CMake gets a build command" \
  || bad "verify cpp" "build was '$(verify_of "$d" build)'"
[ "$(verify_of "$d" test)" = "ctest --test-dir build" ] && ok "a CMake project that enables testing gets ctest" \
  || bad "verify cpp" "test was '$(verify_of "$d" test)'"
[ -z "$(verify_of "$d" format)" ] && ok "C++ without a .clang-format gets no format command" \
  || bad "verify cpp" "format was guessed as '$(verify_of "$d" format)'"
rm -rf "$d"

d="$(fixture lua)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" typecheck)" = "lua-language-server --check ." ] && ok "Lua with a .luarc.json gets a check command" \
  || bad "verify lua" "typecheck was '$(verify_of "$d" typecheck)'"
[ -z "$(verify_of "$d" test)" ] && ok "Lua without busted declared gets no test command" \
  || bad "verify lua" "test was guessed as '$(verify_of "$d" test)'"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on every assertion that wants a command (each returns the empty string, because
`detect_verify` has no branch for these languages) and PASS on the three that want an empty string,
which are passing for the wrong reason until step 3 gives them a branch that could have answered.

- [x] **Step 3: Write the minimal implementation**

Add these branches to the `case "$lang" in` in `detect_verify`, after the existing `rust` branch:

```bash
      csharp)
        case "$what" in
          test)     printf 'dotnet test' ;;
          test_one) printf 'dotnet test --filter FullyQualifiedName~{name}' ;;
          build)    printf 'dotnet build' ;;
          # `dotnet format` ships with the SDK, so naming it is not a guess. There is no separate
          # typecheck: the compiler runs as part of build, and a second command that compiles again
          # is a slower way to learn the same thing.
          format)     printf 'dotnet format --verify-no-changes' ;;
          format_fix) printf 'dotnet format' ;;
        esac ;;
      ruby)
        local bx='bundle exec '
        [ -f Gemfile ] || bx=
        case "$what" in
          test)
            if [ -d spec ]; then printf '%srspec' "$bx"
            elif [ -d test ]; then printf '%srake test' "$bx"; fi ;;
          test_one)
            if [ -d spec ]; then printf '%srspec {path}' "$bx"
            elif [ -d test ]; then printf '%sruby -Itest {path}' "$bx"; fi ;;
          # Rubocop reports offences and exits non-zero, so it is the lint gate. Its autocorrect is
          # the fix command. There is no separate check-only formatter to put in `format`, and
          # inventing one would mean running rubocop twice for one answer.
          lint)       { [ -f .rubocop.yml ] || grep -qs rubocop Gemfile; } && printf '%srubocop' "$bx" ;;
          format_fix) { [ -f .rubocop.yml ] || grep -qs rubocop Gemfile; } && printf '%srubocop -A' "$bx" ;;
          typecheck)
            if grep -qs sorbet Gemfile; then printf '%ssrb tc' "$bx"
            elif grep -qs steep Gemfile; then printf '%ssteep check' "$bx"; fi ;;
        esac ;;
      kotlin)
        case "$what" in
          test)      printf './gradlew test' ;;
          test_one)  printf "./gradlew test --tests '*{name}'" ;;
          build)     printf './gradlew build' ;;
          typecheck) printf './gradlew compileKotlin' ;;
          lint)      grep -qs detekt build.gradle build.gradle.kts && printf './gradlew detekt' ;;
          format)
            if grep -qs ktlint build.gradle build.gradle.kts; then printf './gradlew ktlintCheck'
            elif grep -qs spotless build.gradle build.gradle.kts; then printf './gradlew spotlessCheck'; fi ;;
          format_fix)
            if grep -qs ktlint build.gradle build.gradle.kts; then printf './gradlew ktlintFormat'
            elif grep -qs spotless build.gradle build.gradle.kts; then printf './gradlew spotlessApply'; fi ;;
        esac ;;
      swift)
        # An .xcodeproj build needs a scheme name that is not in the repository in any readable
        # form, so nothing is emitted for it. A wrong `xcodebuild -scheme` line is worse than null.
        [ -f Package.swift ] || return 0
        case "$what" in
          test)      printf 'swift test' ;;
          test_one)  printf 'swift test --filter {name}' ;;
          build)     printf 'swift build' ;;
          lint)      [ -f .swiftlint.yml ] && printf 'swiftlint' ;;
          format)     [ -f .swift-format ] && printf 'swift-format lint -r -s .' ;;
          format_fix) [ -f .swift-format ] && printf 'swift-format format -i -r .' ;;
        esac ;;
      cpp)
        case "$what" in
          build) [ -f CMakeLists.txt ] && printf 'cmake --build build' ;;
          test)
            # ctest only has tests to run if the build declares them.
            grep -qs 'enable_testing\|add_test' CMakeLists.txt && printf 'ctest --test-dir build' ;;
          test_one)
            grep -qs 'enable_testing\|add_test' CMakeLists.txt && printf 'ctest --test-dir build -R {name}' ;;
          format)
            # shellcheck disable=SC2016
            [ -f .clang-format ] && printf 'git ls-files "*.c" "*.h" "*.cc" "*.cpp" "*.hpp" | xargs clang-format --dry-run --Werror' ;;
          format_fix)
            # shellcheck disable=SC2016
            [ -f .clang-format ] && printf 'git ls-files "*.c" "*.h" "*.cc" "*.cpp" "*.hpp" | xargs clang-format -i' ;;
          lint)
            # shellcheck disable=SC2016
            [ -f .clang-tidy ] && printf 'git ls-files "*.c" "*.cc" "*.cpp" | xargs clang-tidy -p build' ;;
        esac ;;
      lua)
        case "$what" in
          test)     { [ -f .busted ] || grep -qrs busted --include='*.rockspec' .; } && printf 'busted' ;;
          test_one) { [ -f .busted ] || grep -qrs busted --include='*.rockspec' .; } && printf 'busted {path}' ;;
          lint)     [ -f .luacheckrc ] && printf 'luacheck .' ;;
          # lua-language-server is the same tool the lua-lsp plugin drives, so a project that has
          # configured it has already declared this command.
          typecheck)  [ -f .luarc.json ] && printf 'lua-language-server --check .' ;;
          format)     { [ -f stylua.toml ] || [ -f .stylua.toml ]; } && printf 'stylua --check .' ;;
          format_fix) { [ -f stylua.toml ] || [ -f .stylua.toml ]; } && printf 'stylua .' ;;
        esac ;;
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all fourteen assertions. Then `tests/run-tests.sh` in the background and the lint
command from Global constraints.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git commit -m "feat(detect): verify commands for csharp, ruby, kotlin, swift, cpp and lua"
```

---

### Task 3: A language server for every detected language

**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `docs/04-plugin-strategy.md`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `detect_languages` from task 1.
- Produces: `lang_lsp(<lang>)`, prints the marketplace id of that language's server or nothing.
  `detect_plugins` keeps its contract: plugin ids, one per line, consumed by `write_settings` in
  `bin/keel:437`, which is unchanged.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`:

```bash
# ---- language servers ------------------------------------------------------
# Every id asserted here is in claude-plugins-official. An id that is not real is worse than no
# suggestion: it lands in settings.json, fails to resolve, and the user distrusts the whole file.
plugins_of() {   # plugins_of <dir>
    python3 -c "import json;print(' '.join(json.load(open('$1/.claude/settings.json'))['enabledPlugins']))" 2>/dev/null
}
for pair in "csharp:csharp-lsp" "ruby:ruby-lsp" "kotlin:kotlin-lsp" "swift:swift-lsp" "cpp:clangd-lsp" "lua:lua-lsp"; do
    stack="${pair%%:*}"; want="${pair##*:}"
    d="$(fixture "$stack")"
    ( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
    case "$(plugins_of "$d")" in *"$want@claude-plugins-official"*) ok "$stack gets $want" ;;
      *) bad "lsp" "$stack got no $want: $(plugins_of "$d")" ;; esac
    rm -rf "$d"
done
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on all six, each printing the settings.json plugin list with the keel plugin and the
five unconditional ones and no language server.

- [x] **Step 3: Write the minimal implementation**

Replace `detect_plugins` in `lib/detect-stack.sh` with:

```bash
# The language server for one language, or nothing. Every id here is in claude-plugins-official.
# Checked against its marketplace.json rather than assumed: a suggested plugin that does not exist
# fails to resolve in settings.json, which is worse than suggesting nothing.
lang_lsp() {
    case "$1" in
      typescript|javascript) printf 'typescript-lsp' ;;
      python) printf 'pyright-lsp' ;;
      go)     printf 'gopls-lsp' ;;
      php)    printf 'php-lsp' ;;
      java)   printf 'jdtls-lsp' ;;
      kotlin) printf 'kotlin-lsp' ;;
      rust)   printf 'rust-analyzer-lsp' ;;
      csharp) printf 'csharp-lsp' ;;
      ruby)   printf 'ruby-lsp' ;;
      swift)  printf 'swift-lsp' ;;
      cpp)    printf 'clangd-lsp' ;;
      lua)    printf 'lua-lsp' ;;
    esac
}

# Plugins worth recommending for this repository. A polyglot repository gets a server per language,
# because the reason to have one at all is diagnostics in the file being edited, and that file is
# as likely to be in the second language as the first.
detect_plugins() {
    local l s
    for l in $(detect_languages); do
        s="$(lang_lsp "$l")"
        [ -n "$s" ] && printf '%s\n' "$s"
    done
    if [ "$(detect_has_ui)" = true ]; then printf 'frontend-design\nplaywright\n'; fi
}
```

Then in `docs/04-plugin-strategy.md`, replace the Language server row of the verdicts table with:

```markdown
| Language server | one per language, see below | **Install per stack** | Real diagnostics beat grep. Largest accuracy gain on refactors |
```

and add immediately after that table:

```markdown
### Language servers, per detected language

`keel init` enables one per language it detects, and a polyglot repository gets several. Every id is
checked against `claude-plugins-official`; a language absent from this table gets no server, which
is the honest answer rather than a plausible id that fails to resolve.

| Language | Plugin |
|---|---|
| TypeScript, JavaScript | `typescript-lsp` |
| Python | `pyright-lsp` |
| Go | `gopls-lsp` |
| PHP | `php-lsp` |
| Java | `jdtls-lsp` |
| Kotlin | `kotlin-lsp` |
| Rust | `rust-analyzer-lsp` |
| C# | `csharp-lsp` |
| Ruby | `ruby-lsp` |
| Swift | `swift-lsp` |
| C, C++ | `clangd-lsp` |
| Lua | `lua-lsp` |
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all six. Then `tests/run-tests.sh` in the background, which also runs
`tests/no-internal-leaks.sh` over the changed doc, and the lint command from Global constraints.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh docs/04-plugin-strategy.md
git commit -m "feat(plugins): a language server per detected language"
```

---

### Task 4: stack.also, so a polyglot repo is not half described

**Files:**
- Modify: `bin/keel` (`write_profile`, `project_kind`)
- Modify: `templates/profile.schema.json`
- Modify: `templates/keel-profile.example.json`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `detect_also()` from task 1.
- Produces: `stack.also`, an array of language names, in `.keel/profile.json`. Empty array when the
  repository is single-stack, never absent, so a reader never has to distinguish the two.
- The second language already gets its language server: `detect_plugins` in task 3 loops over
  `detect_languages`. The assertion for that lives in this task because this is where a polyglot
  fixture exists, and it should pass as soon as the profile field does.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`:

```bash
# ---- polyglot repositories -------------------------------------------------
# A Python service behind a TypeScript app was described as TypeScript and nothing else, so the
# Python half got no language server and every skill reading the profile believed the repo was
# single-stack.
d="$(fixture polyglot)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(python3 -c "import json;s=json.load(open('$d/.keel/profile.json'))['stack'];print(s['language'],','.join(s['also']))" 2>/dev/null)"
[ "$got" = "typescript python" ] && ok "a polyglot repo records the second language in stack.also" \
  || bad "polyglot" "got '$got', want 'typescript python'"
case "$(plugins_of "$d")" in *pyright-lsp*) ok "the second language gets its language server too" ;;
  *) bad "polyglot" "no pyright-lsp: $(plugins_of "$d")" ;; esac
# The primary still drives the verify commands. A repo is not tested twice because it has two
# languages, and choosing which one runs is the user's call, not a detector's.
[ "$(verify_of "$d" test)" = "npm test" ] && ok "the primary language still drives verify" \
  || bad "polyglot" "test was '$(verify_of "$d" test)'"
rm -rf "$d"

# Single-stack repositories get an empty array rather than a missing key, so nothing downstream has
# to tell absent from empty.
d="$(fixture go)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json'))['stack']['also'])" 2>/dev/null)" = "[]" ] \
  && ok "a single-stack repo gets an empty stack.also" || bad "polyglot" "stack.also is missing or not empty"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `a polyglot repo records the second language`, on `a single-stack repo gets an
empty stack.also` (both with a `KeyError: 'also'` swallowed into an empty string), and on `the
second language gets its language server too`.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, in `write_profile`, add the `also` array. Replace the `stack` line:

```bash
      printf '  "stack": { "language": "%s", "runtime": "%s", "framework": "%s", "package_manager": "%s", "also": [%s], "datastores": [], "has_ui": %s },\n' \
        "$lang" "$rt" "$fw" "$pm" "$(json_str_array "$(detect_also)")" "$ui"
```

and add this helper above `write_profile`:

```bash
# One JSON array from newline-separated input. Empty input gives an empty array rather than a
# missing key, so a reader never has to tell absent from none.
json_str_array() {
    printf '%s\n' "$1" | awk 'NF { if (n++) printf ", "; printf "\"%s\"", $0 }'
}
```

Also widen the source-file scan in `project_kind`, which lists extensions and has not been touched
since the six-language era:

```bash
    src=$(git ls-files 2>/dev/null | grep -cE '\.(ts|js|py|go|java|kt|php|rs|rb|cs|swift|lua|c|cc|cpp|h|hpp)$' || true)
```

In `templates/profile.schema.json`, add to `properties.stack.properties`, after `package_manager`:

```json
      "also": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Every other language detected in this repository. The primary in `language` drives the verify commands; these get a language server each."
      },
```

In `templates/keel-profile.example.json`, add `"also": [],` to the `stack` object so the example
matches what init writes.

Add the polyglot row to the detection matrix in `docs/03-install-and-distribution.md`, at the end of
the table task 1 edited:

```markdown
| More than one of the above | The first is `stack.language` and drives the verify commands; the rest are `stack.also`, and each gets its language server |
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four assertions. Then `tests/run-tests.sh` in the background: it validates the
example profile against the schema, so a mismatch between the two shows up here. Then the lint
command from Global constraints.

- [x] **Step 5: Commit**

```bash
git add bin/keel templates/profile.schema.json templates/keel-profile.example.json \
        docs/03-install-and-distribution.md tests/test-keel.sh
git commit -m "feat(profile): record every language a polyglot repo contains"
```

---

### Task 5: JavaScript and TypeScript, beyond npm

**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: the `detect_js_pm` stub from task 1, which this task replaces.
- Produces: `detect_js_pm()`, prints `npm`, `pnpm`, `yarn` or `bun`. `pkg_run(<script>)`, prints the
  command that runs a declared package script under the detected manager.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`:

```bash
# ---- javascript package managers and tooling -------------------------------
# Every pnpm, yarn and bun project was told to run npm. The lockfile is the declaration.
for pair in "pnpm-lock.yaml:pnpm" "yarn.lock:yarn" "bun.lockb:bun"; do
    lock="${pair%%:*}"; want="${pair##*:}"
    d="$(fixture node-ts)"
    : > "$d/$lock"
    ( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
    got="$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json'))['stack']['package_manager'])" 2>/dev/null)"
    [ "$got" = "$want" ] && ok "$lock means $want" || bad "js pm" "got '$got', want '$want'"
    case "$(verify_of "$d" lint)" in "$want"*) ok "$want runs the lint script with $want" ;;
      *) bad "js pm" "lint was '$(verify_of "$d" lint)'" ;; esac
    rm -rf "$d"
done

# `bun test` runs bun's own runner and ignores the package script, so bun is the one manager that
# must use `run` even for test. Getting this wrong runs a different test suite than the project's.
d="$(fixture node-ts)"
: > "$d/bun.lockb"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "bun run test" ] && ok "bun runs the declared test script, not its own runner" \
  || bad "js pm" "test was '$(verify_of "$d" test)'"
rm -rf "$d"

# A declared typecheck script was detected and then thrown away for `npx tsc --noEmit`, which is a
# different command on any project whose script passes flags or points at a second tsconfig.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" typecheck)" = "npm run typecheck" ] && ok "a declared typecheck script is the typecheck command" \
  || bad "js tooling" "typecheck was '$(verify_of "$d" typecheck)'"
rm -rf "$d"

# No script, but a tsconfig: tsc --noEmit is the fallback rather than nothing.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","devDependencies":{"typescript":"^5"}}\n' > package.json
  echo '{}' > tsconfig.json )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" typecheck)" = "npx tsc --noEmit" ] && ok "a tsconfig with no script still typechecks" \
  || bad "js tooling" "typecheck was '$(verify_of "$d" typecheck)'"
[ -z "$(verify_of "$d" test)" ] && ok "no test script and no runner declared means no test command" \
  || bad "js tooling" "test was guessed as '$(verify_of "$d" test)'"
rm -rf "$d"

# Biome and Prettier are declared by their config file, which is how the project says which it uses.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f"}\n' > package.json
  printf '{"linter":{"enabled":true}}\n' > biome.json )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" lint)" = "npx biome check ." ] && ok "a biome.json is the lint command" \
  || bad "js tooling" "lint was '$(verify_of "$d" lint)'"
[ "$(verify_of "$d" format)" = "npx biome format ." ] && ok "biome is also the format check" \
  || bad "js tooling" "format was '$(verify_of "$d" format)'"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on all three package managers (`got 'npm'` each time), on the bun test command, on
the declared typecheck script (`got 'npx tsc --noEmit'`), on the tsconfig fallback (empty), and on
both biome assertions (empty).

- [x] **Step 3: Write the minimal implementation**

Replace the `detect_js_pm` stub from task 1 with the real one, and add `pkg_run` beside it:

```bash
# The manager this project actually uses. The lockfile is the declaration; the binaries on the
# machine running init are not, because a teammate's machine has a different set.
detect_js_pm() {
    if [ -f bun.lockb ] || [ -f bun.lock ]; then printf 'bun'
    elif [ -f pnpm-lock.yaml ]; then printf 'pnpm'
    elif [ -f yarn.lock ]; then printf 'yarn'
    else printf 'npm'; fi
}

# How this project runs a declared package script.
#
# `bun test` is the trap: it runs bun's own test runner and ignores the package script entirely, so
# bun has to use `run` even where the other three do not. Getting this wrong runs a different suite
# than the one the project declared.
pkg_run() {   # pkg_run <script>
    local pm; pm="$(detect_js_pm)"
    case "$pm" in
      bun)  printf 'bun run %s' "$1" ;;
      yarn) printf 'yarn %s' "$1" ;;
      *)
        if [ "$1" = test ]; then printf '%s test' "$pm"
        else printf '%s run %s' "$pm" "$1"; fi ;;
    esac
}
```

Then replace the `typescript|javascript` branch of `detect_verify` with:

```bash
      typescript|javascript)
        local s; s="$(pkg_script "$what")"
        case "$what" in
          test)
            if [ -n "$s" ]; then pkg_run test
            # No script, but a runner in devDependencies is still the project declaring one. `vitest`
            # alone watches forever, so the non-interactive form is the only correct fallback.
            elif grep -q '"vitest"' package.json 2>/dev/null; then printf 'npx vitest run'
            elif grep -q '"jest"' package.json 2>/dev/null; then printf 'npx jest'; fi ;;
          test_integration) [ -n "$(pkg_script 'test:integration')" ] && pkg_run 'test:integration' ;;
          test_one)
            if [ -n "$(pkg_script test)" ]; then
                case "$(detect_js_pm)" in
                  yarn) printf 'yarn test {path}' ;;
                  bun)  printf 'bun run test -- {path}' ;;
                  pnpm) printf 'pnpm test -- {path}' ;;
                  *)    printf 'npm test -- {path}' ;;
                esac
            elif grep -q '"vitest"' package.json 2>/dev/null; then printf 'npx vitest run {path}'
            elif grep -q '"jest"' package.json 2>/dev/null; then printf 'npx jest {path}'; fi ;;
          build) [ -n "$s" ] && pkg_run build ;;
          lint)
            if [ -n "$s" ]; then pkg_run lint
            elif [ -f biome.json ] || [ -f biome.jsonc ]; then printf 'npx biome check .'
            elif ls eslint.config.* >/dev/null 2>&1 || ls .eslintrc* >/dev/null 2>&1; then printf 'npx eslint .'; fi ;;
          # `npm run format` rewrites files, so it cannot be the gate. Only a declared
          # format:check earns that slot; the writing one is recorded as format_fix, which is
          # what a refusal names as the remedy.
          format)
            if [ -n "$(pkg_script 'format:check')" ]; then pkg_run 'format:check'
            elif [ -f biome.json ] || [ -f biome.jsonc ]; then printf 'npx biome format .'
            elif ls .prettierrc* prettier.config.* >/dev/null 2>&1; then printf 'npx prettier --check .'; fi ;;
          format_fix)
            if [ -n "$(pkg_script format)" ]; then pkg_run format
            elif [ -f biome.json ] || [ -f biome.jsonc ]; then printf 'npx biome format --write .'
            elif ls .prettierrc* prettier.config.* >/dev/null 2>&1; then printf 'npx prettier --write .'; fi ;;
          typecheck)
            # A declared script wins. It was previously detected and then discarded for the generic
            # command, which is a different thing on any project whose script passes flags or names
            # a second tsconfig.
            if [ -n "$(pkg_script typecheck)" ]; then pkg_run typecheck
            elif [ -n "$(pkg_script type-check)" ]; then pkg_run type-check
            elif [ -f tsconfig.json ]; then printf 'npx tsc --noEmit'; fi ;;
          e2e) [ -n "$(pkg_script 'test:e2e')" ] && pkg_run 'test:e2e' ;;
        esac ;;
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all ten new assertions, and on the existing
`reads the test command from package.json` assertion, which still expects `npm test` and must not
have changed. Then `tests/run-tests.sh` in the background and the lint command from Global
constraints.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git commit -m "feat(detect): pnpm, yarn and bun, and the tooling a JS repo declares"
```

---

### Task 6: Python, without assuming pytest

**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: the `detect_py_pm` stub from task 1, which this task replaces.
- Produces: `detect_py_pm()`, prints `uv`, `poetry`, `pdm`, `pipenv` or `pip`. `py_run()`, prints the
  prefix that runs a tool inside the project environment, empty for plain pip.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`:

```bash
# ---- python tooling --------------------------------------------------------
# pytest was written into every Python profile, declared or not. On a project that uses unittest
# `keel doctor` then fails on a command the project never had, which is the check crying wolf.
d="$(fixture python)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ -z "$(verify_of "$d" test)" ] && ok "python without pytest declared gets no test command" \
  || bad "python" "test was guessed as '$(verify_of "$d" test)'"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '[project]\nname = "f"\ndependencies = []\n\n[dependency-groups]\ndev = ["pytest", "ruff", "pyright"]\n' > pyproject.toml
  : > uv.lock )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json'))['stack']['package_manager'])" 2>/dev/null)" = "uv" ] \
  && ok "a uv.lock means uv" || bad "python" "package manager was not uv"
[ "$(verify_of "$d" test)" = "uv run pytest" ] && ok "uv runs pytest inside the project environment" \
  || bad "python" "test was '$(verify_of "$d" test)'"
[ "$(verify_of "$d" typecheck)" = "uv run pyright" ] && ok "pyright is honoured as the type checker" \
  || bad "python" "typecheck was '$(verify_of "$d" typecheck)'"
[ "$(verify_of "$d" lint)" = "uv run ruff check ." ] && ok "ruff is honoured under the project runner" \
  || bad "python" "lint was '$(verify_of "$d" lint)'"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf 'pytest\nflake8\nmypy\n' > requirements.txt
  mkdir -p tests )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "pytest" ] && ok "plain pip runs pytest with no prefix" \
  || bad "python" "test was '$(verify_of "$d" test)'"
[ "$(verify_of "$d" lint)" = "flake8" ] && ok "flake8 in requirements.txt is the lint command" \
  || bad "python" "lint was '$(verify_of "$d" lint)'"
[ "$(verify_of "$d" typecheck)" = "mypy ." ] && ok "mypy is still honoured" \
  || bad "python" "typecheck was '$(verify_of "$d" typecheck)'"
rm -rf "$d"

# A project with a tests/ directory and no pytest anywhere runs the standard library runner.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '[project]\nname = "f"\n' > pyproject.toml
  mkdir -p tests && printf 'import unittest\n' > tests/test_f.py )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "python -m unittest discover" ] && ok "a tests dir with no pytest gets unittest" \
  || bad "python" "test was '$(verify_of "$d" test)'"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on `python without pytest declared gets no test command` (`got 'pytest'`), on all four
uv assertions, on the flake8 assertion, and on the unittest assertion. `mypy` and plain `pytest`
under pip will pass already; that is expected, they are the two cases the current code gets right and
they are asserted so this task does not break them.

- [x] **Step 3: Write the minimal implementation**

Replace the `detect_py_pm` stub from task 1 with the real one, and add `py_run` beside it:

```bash
# The manager this project actually uses, from its lockfile or its pyproject table.
detect_py_pm() {
    if [ -f uv.lock ]; then printf 'uv'
    elif [ -f poetry.lock ] || grep -qs '\[tool.poetry\]' pyproject.toml; then printf 'poetry'
    elif [ -f pdm.lock ]; then printf 'pdm'
    elif [ -f Pipfile ]; then printf 'pipenv'
    else printf 'pip'; fi
}

# The prefix that runs a tool inside the project environment, empty under plain pip. Without it
# every command assumes the developer has already activated a virtualenv, which is the single most
# common reason a verify command works on one machine and not the next.
py_run() {
    case "$(detect_py_pm)" in
      uv)     printf 'uv run ' ;;
      poetry) printf 'poetry run ' ;;
      pdm)    printf 'pdm run ' ;;
      pipenv) printf 'pipenv run ' ;;
    esac
}

# Whether a tool is named anywhere the project declares its dependencies.
py_declares() {   # py_declares <name>
    grep -qs "$1" pyproject.toml requirements.txt requirements-dev.txt Pipfile setup.cfg tox.ini
}
```

Replace the `python` branch of `detect_verify` with:

```bash
      python)
        local r; r="$(py_run)"
        case "$what" in
          test)
            if py_declares pytest || [ -f pytest.ini ]; then printf '%spytest' "$r"
            # No pytest anywhere, but a tests directory: the standard library runner is the only
            # thing that is certainly present. Previously `pytest` was written regardless, and
            # doctor then failed on a command the project never had.
            elif [ -d tests ] || [ -d test ]; then printf '%spython -m unittest discover' "$r"; fi ;;
          test_one)
            if py_declares pytest || [ -f pytest.ini ]; then printf '%spytest {path}' "$r"
            elif [ -d tests ] || [ -d test ]; then printf '%spython -m unittest {name}' "$r"; fi ;;
          lint)
            if [ -f .ruff.toml ] || [ -f ruff.toml ] || py_declares ruff; then printf '%sruff check .' "$r"
            elif [ -f .flake8 ] || py_declares flake8; then printf '%sflake8' "$r"
            elif [ -f .pylintrc ] || py_declares pylint; then printf '%spylint .' "$r"; fi ;;
          typecheck)
            if py_declares mypy; then printf '%smypy .' "$r"
            elif [ -f pyrightconfig.json ] || py_declares pyright; then printf '%spyright' "$r"; fi ;;
          # Declared tools only. Nothing ships a formatter with the runtime here, so an assumed
          # one is a command that fails the first time a gate runs it.
          format|format_fix)
            local w=--check; [ "$what" = format_fix ] && w=
            if [ -f .ruff.toml ] || [ -f ruff.toml ] || py_declares ruff; then
                printf '%sruff format %s.' "$r" "${w:+$w }"
            elif py_declares black; then
                printf '%sblack %s.' "$r" "${w:+$w }"
            fi ;;
        esac ;;
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all ten assertions, and on the existing `detects python as python` assertion. Then
`tests/run-tests.sh` in the background and the lint command from Global constraints.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git commit -m "feat(detect): read Python's runner and tools rather than assuming pytest"
```

---

### Task 7: PHP, Go and Java, from what the repository declares

**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `pkg_script` (existing, JSON-only, so PHP needs its own reader).
- Produces: `composer_declares(<name>)`, returns 0 when a package is named in `composer.json`.

- [x] **Step 1: Write the failing test**

Append to `tests/test-keel.sh`:

```bash
# ---- php, go and java, from declarations rather than from the machine -------
# PHP got no test command at all unless vendor/ happened to be installed, and vendor/ is gitignored
# on essentially every PHP project, so a fresh clone always produced an empty profile.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f/f","require-dev":{"phpunit/phpunit":"^11","phpstan/phpstan":"^2"}}\n' > composer.json )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "vendor/bin/phpunit" ] && ok "phpunit in composer.json is enough, with no vendor dir" \
  || bad "php" "test was '$(verify_of "$d" test)'"
[ "$(verify_of "$d" typecheck)" = "vendor/bin/phpstan analyse" ] && ok "phpstan is the PHP type checker" \
  || bad "php" "typecheck was '$(verify_of "$d" typecheck)'"
rm -rf "$d"

# Pest is a different runner and a different binary. A project that declares it must not be told
# to run phpunit.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f/f","require-dev":{"pestphp/pest":"^3"}}\n' > composer.json )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" test)" = "vendor/bin/pest" ] && ok "a Pest project runs Pest" \
  || bad "php" "test was '$(verify_of "$d" test)'"
rm -rf "$d"

# Go's lint command depended on golangci-lint being installed on the machine running init, which
# freezes one laptop's answer into a file every teammate reads. The config file is the declaration.
d="$(fixture go)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ -z "$(verify_of "$d" lint)" ] && ok "Go with no linter config gets no lint command" \
  || bad "go" "lint was '$(verify_of "$d" lint)', which came from this machine rather than the repo"
rm -rf "$d"

d="$(fixture go)"
printf 'linters:\n  enable: [errcheck]\n' > "$d/.golangci.yml"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(verify_of "$d" lint)" = "golangci-lint run" ] && ok "a .golangci.yml is the declaration golangci-lint needs" \
  || bad "go" "lint was '$(verify_of "$d" lint)'"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on both PHP-without-vendor assertions and the Pest assertion (all empty), and on
`a .golangci.yml is the declaration golangci-lint needs` (empty on a machine without golangci-lint,
or passing for the wrong reason on one that has it). `Go with no linter config gets no lint command`
fails on any machine that has golangci-lint installed, which is the point of the assertion.

- [x] **Step 3: Write the minimal implementation**

Add above `detect_verify`:

```bash
# Whether composer.json requires a package. The declaration is the manifest, not the vendor
# directory: vendor/ is gitignored on essentially every PHP project, so a detector that waits for
# it produces an empty profile on every fresh clone.
composer_declares() {   # composer_declares <package>
    grep -qs "\"$1" composer.json
}
```

Replace the `php` branch of `detect_verify` with:

```bash
      php)
        case "$what" in
          test)
            if [ -f artisan ]; then printf 'php artisan test'
            elif composer_declares 'pestphp/pest'; then printf 'vendor/bin/pest'
            elif composer_declares 'phpunit/phpunit' || [ -f phpunit.xml ] || [ -f phpunit.xml.dist ]; then
                printf 'vendor/bin/phpunit'; fi ;;
          test_one)
            if composer_declares 'pestphp/pest'; then printf 'vendor/bin/pest {path}'
            elif composer_declares 'phpunit/phpunit' || [ -f phpunit.xml ] || [ -f phpunit.xml.dist ]; then
                printf 'vendor/bin/phpunit {path}'; fi ;;
          typecheck)
            if composer_declares 'phpstan/phpstan' || [ -f phpstan.neon ]; then printf 'vendor/bin/phpstan analyse'
            elif composer_declares 'vimeo/psalm' || [ -f psalm.xml ]; then printf 'vendor/bin/psalm'; fi ;;
          format)
            if composer_declares 'laravel/pint' || [ -f pint.json ]; then printf 'vendor/bin/pint --test'
            elif composer_declares 'friendsofphp/php-cs-fixer'; then printf 'vendor/bin/php-cs-fixer fix --dry-run --diff'
            elif composer_declares 'squizlabs/php_codesniffer'; then printf 'vendor/bin/phpcs'; fi ;;
          format_fix)
            if composer_declares 'laravel/pint' || [ -f pint.json ]; then printf 'vendor/bin/pint'
            elif composer_declares 'friendsofphp/php-cs-fixer'; then printf 'vendor/bin/php-cs-fixer fix'
            elif composer_declares 'squizlabs/php_codesniffer'; then printf 'vendor/bin/phpcbf'; fi ;;
        esac ;;
```

**Deviation, made while executing.** As written, that branch drops the `vendor/bin/pint` signal the
old one had, and an existing assertion covers it (`php with pint installed gets pint --test`, and the
`format_fix` one beside it). Those two turned red. An installed vendor binary is not a lookup on the
machine's PATH: it is inside the project and it is there because the manifest asked for it, so it is
a declaration read indirectly. The two binaries the old branch used, `vendor/bin/phpunit` and
`vendor/bin/pint`, were therefore kept as an extra `||` arm in `test`, `test_one`, `format` and
`format_fix`, which makes the new branch a superset of the old rather than a swap for it.

In the `go` branch, replace the `lint` line:

```bash
          # The config file in the repository is the declaration, not the binary on this machine.
          # Checking the PATH here freezes one laptop's answer into a file every teammate reads,
          # which is the same mistake the gofmt comment below exists to avoid.
          lint) { [ -f .golangci.yml ] || [ -f .golangci.yaml ] || [ -f .golangci.toml ]; } && printf 'golangci-lint run' ;;
```

In the `java` branch, add the two lint cases to its `case "$what:$g" in`:

```bash
          lint:gradle) grep -qs checkstyle build.gradle build.gradle.kts && printf './gradlew checkstyleMain' ;;
          lint:maven)  grep -qs maven-checkstyle-plugin pom.xml && printf 'mvn checkstyle:check' ;;
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all five assertions, including `Go with no linter config gets no lint command` on a
machine that has golangci-lint installed. Then `tests/run-tests.sh` in the background and the lint
command from Global constraints.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git commit -m "feat(detect): read PHP, Go and Java tooling from the repository, not the machine"
```

---

## After the last task

Not part of any task, and not to be done inside one:

1. `keel doctor` on this repository. It detects as `unknown` today, because bash is not a language in
   the table and was excluded from scope. That is expected and it is not a regression.
2. Run `keel init --force` in a scratch clone of a real project per new language if one is available,
   and check the profile by eye. The fixtures prove the branches; only a real repository proves the
   commands are the ones a person would have typed.
3. `review-code`, then `ship`.

## Found in review, and not fixed here

Four findings from the review pass were judged not worth holding the change for. Each is a real
edge, none produces a wrong command on a repository the plan set out to serve, and each would be a
small change on its own.

| Where | What | Why it waits |
|---|---|---|
| `lib/detect-stack.sh`, `lang_profile` csharp arm | `grep -rqs 'Microsoft.AspNetCore' --include='*.csproj' .` walks the whole tree, including `.git`, `bin/` and `obj/`, with no depth bound, while `find_marker` beside it is bounded and says why | Runs only once a C# marker has already matched, and `--include` reads no file it does not match. Measured at hundredths of a second on a tree of a few hundred packages |
| `lib/detect-stack.sh`, `detect_verify` lua arm | `grep -qrs busted --include='*.rockspec' .` does the same, twice per profile write | As above, and Lua repositories are small |
| `lib/detect-stack.sh`, `detect_verify` kotlin arm | Hardcodes `./gradlew` while `lang_profile` reports `maven` when a `pom.xml` is present, so a repository carrying both files gets `"package_manager": "maven"` beside Gradle commands | Needs the `$what:$g` dispatch the java arm already has. A repository with both build systems is rare enough to schedule rather than rush |
| `lib/detect-stack.sh`, `lang_profile` swift arm | `pm=xcode` can only fire when `Package.swift` and an `.xcodeproj` are both present, because `Package.swift` is the only Swift marker. An `.xcodeproj`-only project is not detected as Swift at all | Fixing it means adding `*.xcodeproj` as a marker, which then needs a decision about what to emit for a project whose scheme name is not in the repository. That is the question the swift arm's comment already declines to answer |

`detect_languages` is also re-run five or six times per `keel init`, once per caller. The `find`
calls inside it now prune rather than filter, which was the expensive half; memoising the rest is a
separate change.

## Open questions

None. Both scope questions were settled before this plan was written and are recorded under
Decisions taken.
