#!/usr/bin/env bash
# Tests for bin/keel, part 1 of 5: stack detection, init, profile and sync, and doctor's basics.
# Shared helpers and fixtures are in tests/keel-test-lib.sh, which says why SC2015 is safe here.
#
# Run from the repository root.

# shellcheck disable=SC2015
# shellcheck disable=SC2016
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
# shellcheck source=tests/keel-test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/keel-test-lib.sh"

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

# ---- verify.e2e is named and never run, verify.security runs only in full doctor ---------------
# verify.e2e and verify.security were written into every profile by write_profile and read by
# nothing, so a user saw a real command sitting in a real field with nothing behind it. Doctor
# names e2e without running it, because it needs an environment doctor cannot provide. security
# reaches the network, so full doctor runs it and --fast only names it.
#
# fixture node-ts, NOT a bare git init. An empty directory detects as project.kind "docs", and the
# whole verify block including this loop sits inside doctor's `kind != docs` guard, so on a bare
# fixture doctor prints no verify line at all and the cases below would fail forever while looking
# like a bug in the new loop. Confirmed by running it on 2026-09-07.
we="$(fixture node-ts)"
( cd "$we" && "$KEEL" init -y >/dev/null 2>&1 )
# verify.e2e is a command that leaves evidence behind, not a plausible-looking one. The e2e sentinel
# cases below assert doctor did not run it, and the only way to assert that without trusting the
# output string is to give it something whose having run is a fact on disk. Relative, because
# doctor's `( eval "$c" )` inherits the cwd this subshell sets.
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
# null reports as ok, not WARN. keel detects security only from an npm, pnpm or yarn 2+ lockfile and
# e2e only from a node test:e2e script, so a warning here fires on nearly every project and no keel
# command can clear it; docs/standards.md:87 calls that the unrecoverable kind of wrong. Asserting
# the `ok` prefix, because asserting the bare sentence would pass a WARN too and that is the whole
# distinction this case exists to hold.
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
# nothing asserted under --fast can see such a path. Plain doctor costs about a second on this
# fixture, measured 2026-09-08: npm test, lint, typecheck and build each fail immediately with no
# node_modules installed. e2e must never run. security runs in full doctor and only there, by
# decision on 2026-09-25, so it carries a sentinel under --fast and another without.
( cd "$we" && "$KEEL" profile set verify.security 'touch security-ran-sentinel' >/dev/null 2>&1 )
( cd "$we" && "$KEEL" doctor --fast >/dev/null 2>&1 )
[ -e "$we/security-ran-sentinel" ] \
  && bad "doctor --fast does not execute verify.security" "the sentinel file exists, so the command ran" \
  || ok "doctor --fast does not execute verify.security"
full="$( cd "$we" && "$KEEL" doctor 2>&1 )"
[ -e "$we/e2e-ran-sentinel" ] \
  && bad "doctor never runs verify.e2e, even without --fast" "$full" \
  || ok "doctor never runs verify.e2e, even without --fast"
[ -e "$we/security-ran-sentinel" ] \
  && ok "full doctor runs verify.security" \
  || bad "full doctor runs verify.security" "no sentinel, so the command never ran: $full"
rm -rf "$we"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
