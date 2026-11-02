#!/usr/bin/env bash
# The shared half of the tests for bin/keel: counters, reporting helpers and fixtures, sourced by
# tests/test-keel.sh and tests/test-keel-2.sh to tests/test-keel-5.sh. Fixtures are generated per
# case rather than committed, so they cannot go stale against the code they exercise.
#
# The cases were one file until it ran 771 of them serially for over eight minutes and set the
# whole suite's wall clock. Split at section headers so tests/run-tests.sh runs the parts in
# parallel; each part sources this file and reports its own totals.
#
# The `condition && report_pass || report_fail` idiom is used throughout the parts. It is safe there,
# and only there, because every reporting helper returns 0 explicitly: see the `return 0` on each
# below. That makes the invariant shellcheck cannot see a stated fact in the code rather than an
# assumption.
# shellcheck disable=SC2034
# KEEL and the counters are read by the parts that source this file, not by this file.
# shellcheck disable=SC2015
# shellcheck disable=SC2016
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEL="$ROOT/bin/keel"
pass=0
fail=0

ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad()  { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# keel doctor asks the installed Claude Code for its version through KEEL_CLAUDE, so without a stub
# every doctor run in these files prints one line on a machine with claude and another on CI with
# none. This one prints the ledger's current minimum, read from the ledger rather than written here,
# so a row that moves the minimum does not leave the suite behind. Test files that run doctor
# without this library export the same.
KEEL_CLAUDE="$(mktemp -d)/claude"
printf '#!/bin/sh\necho "%s (Claude Code)"\n' \
  "$(bash -c ". '$ROOT/lib/harness/resolve.sh'; harness_min_version")" > "$KEEL_CLAUDE"
chmod +x "$KEEL_CLAUDE"
export KEEL_CLAUDE

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

# gates.coding_standards defaults to required (bin/keel#gates.coding_standards is a promise about a
# document), so a fixture that never runs coding-standards fails doctor on that alone. Cases that are
# not about coding_standards itself call this right after `init -y` so their own assertion is not
# confounded by a second, unrelated FAIL; the dedicated required/warn/off coverage lives in the
# "gates.coding_standards" case below and never calls this.
seed_standards() {   # seed_standards <fixture-dir>
    mkdir -p "$1/docs/keel"
    printf '# Standards\n\nSeeded for the test fixture.\n' > "$1/docs/keel/standards.md"
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
        dart-flutter)
          cat > pubspec.yaml <<'P'
name: f
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
dev_dependencies:
  flutter_lints: ^3.0.0
P
          mkdir -p test android ios lib
          printf "void main() {}\n" > test/widget_test.dart ;;
        dart-pure)
          # No Flutter SDK dependency, so the commands must use the `dart` spelling. FR-07.
          # flutter_lints is deliberately absent here: it is the dev dependency that would make a
          # bare-word `flutter` match call this package a Flutter application. One assertion appends
          # it to a copy of this fixture to hold that line.
          cat > pubspec.yaml <<'P'
name: f
environment:
  sdk: ">=3.0.0 <4.0.0"
dev_dependencies:
  test: ^1.24.0
P
          mkdir -p test lib
          printf "void main() {}\n" > test/f_test.dart ;;
        dart-pure-notest)
          # A plain Dart package that never added package:test. `dart test` fails here with
          # "Could not find package `test`", measured 2026-08-29, so verify.test must be null and
          # the skill must ask. The analyzer still runs, so verify.lint is not null.
          cat > pubspec.yaml <<'P'
name: f
environment:
  sdk: ">=3.0.0 <4.0.0"
P
          mkdir -p lib ;;
        dart-orphan)
          # Dart source with no manifest at any level. The false positive the marker exists to
          # survive: a real directory of this shape was found on 2026-08-29.
          mkdir -p lib/screens
          i=1; while [ "$i" -le 10 ]; do printf 'void f%s() {}\n' "$i" > "lib/screens/s$i.dart"; i=$((i+1)); done ;;
        dart-polyglot)
          # Both manifests at one root. Nothing in current work has this shape, so this fixture is
          # the only thing that pins FR-19's ordering.
          cat > pubspec.yaml <<'P'
name: f
dependencies:
  flutter:
    sdk: flutter
P
          printf '{"name":"f","devDependencies":{"typescript":"^5"}}\n' > package.json
          echo '{}' > tsconfig.json ;;
        dart-polyglot-web)
          # The same two manifests, plus the browser UI the Node half really has. Separate from
          # dart-polyglot because that fixture pins the marker order and this one pins what the
          # plugin list does with it: dart wins the primary slot either way, and the web app still
          # needs a browser driver.
          cat > pubspec.yaml <<'P'
name: f
dependencies:
  flutter:
    sdk: flutter
P
          printf '{"name":"f","devDependencies":{"typescript":"^5"}}\n' > package.json
          echo '{}' > tsconfig.json
          echo 'module.exports = {}' > next.config.js
          mkdir -p public ;;
        dart-flutter-notests)
          # A Flutter package that has not written a test yet. `flutter test` is bundled and needs
          # no dev dependency, which is why it was ungated, but bundled is not the same as runnable:
          # measured 2026-08-30, it exits 1 with `Test directory "test" not found.`
          cat > pubspec.yaml <<'P'
name: f
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
P
          mkdir -p lib ;;
        dart-flutter-nottests)
          # A test/ directory holding no test file. The SDK names the condition itself: "Test files
          # must be in that directory and end with the pattern "_test.dart"". Measured 2026-08-30,
          # this exits 1 too, which is why the gate cannot be `[ -d test ]`.
          cat > pubspec.yaml <<'P'
name: f
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
P
          mkdir -p lib test
          printf 'int helper() => 1;\n' > test/helper.dart ;;
        dart-flutter-nested)
          # Tests one directory down, which is an ordinary Dart layout. The counter-case to the two
          # above: the gate must not be so shallow that it nulls a project that does have tests.
          cat > pubspec.yaml <<'P'
name: f
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
P
          mkdir -p lib test/unit
          printf "void main() {}\n" > test/unit/widget_test.dart ;;
        dart-pure-notestfiles)
          # Declares package:test and never wrote a test. The plain branch fails the same way the
          # Flutter one does, rc=65: "No test files were passed and the default "test/" directory
          # doesn't exist." Measured 2026-08-30. The dependency gate alone does not catch it.
          cat > pubspec.yaml <<'P'
name: f
environment:
  sdk: ">=3.0.0 <4.0.0"
dev_dependencies:
  test: ^1.24.0
P
          mkdir -p lib ;;
        dart-melos)
          # A melos workspace root, which is the common Dart monorepo layout. It declares a script
          # named `test` and no dependency on package:test, so `dart test` fails here exactly as it
          # does in dart-pure-notest. Measured against the real SDK on 2026-08-30:
          # "Could not find package `test` or file `test:test`".
          cat > pubspec.yaml <<'P'
name: workspace
environment:
  sdk: ">=3.0.0 <4.0.0"
dev_dependencies:
  melos: ^3.0.0
melos:
  scripts:
    test: melos exec -- dart test
P
          mkdir -p packages ;;
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


# One verify command out of a profile, with null read as the empty string so a missing command and
# an empty one compare the same way.
verify_of() {   # verify_of <dir> <key>
    python3 -c "import json;v=json.load(open('$1/.keel/profile.json'))['verify']['$2'];print('' if v is None else v)" 2>/dev/null
}

# The plugin ids a fixture's .claude/settings.json enables, space separated.
plugins_of() {   # plugins_of <dir>
    python3 -c "import json;print(' '.join(json.load(open('$1/.claude/settings.json'))['enabledPlugins']))" 2>/dev/null
}

# Each part builds its own fixture cache, so each removes its own on the way out.
trap 'rm -rf "$FIXTURE_CACHE" "$(dirname "$KEEL_CLAUDE")"' EXIT
