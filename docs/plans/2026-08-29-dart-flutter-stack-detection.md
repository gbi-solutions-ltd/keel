# Dart and Flutter stack detection Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `keel init` on a Dart repository produces a profile that names the language, the framework,
the package manager, the datastore and five verify commands, and leaves the `stack` and `verify`
blocks of every repository that is not one exactly as they are today.

**Stories:** S-01 to S-11, `docs/stories/dart-flutter-stack-detection.md`
**PRD:** `docs/prd/dart-flutter-stack-detection.md`, approved 2026-08-29
**ADRs:** none. ADR-0001 governs skill body length and no skill body is edited here.
**Architecture:** a fifteenth language arm in `lib/detect-stack.sh`, following the fourteen already
there. One new helper, `is_flutter`, separates a Flutter application from a plain Dart package, and
three existing shared functions gain a Dart branch. No file is created: fixtures are generated inside
`tests/test-keel.sh`, which is what this repository does.

**Reviewed against the repository on 2026-08-29**, by a reviewer that applied every edit below to a
scratch copy and ran the suite: **369 passed, 0 failed**, against a 337-pass baseline, and **17
failures** when the same assertions run against the unpatched library. Its blocking findings are
fixed in this revision and its rejected findings are recorded at the end.

## Global constraints

Copied verbatim from `.keel/profile.json`, the PRD and the stories. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
- `format`, `format_fix`, `typecheck`, `build`, `e2e` and `security` are all `null` in this project.
  Do not invent one.
- Never start on `main`. This repository does all work on `sandbox` and PRs it.

**`shellcheck` is not installed on this machine.** Checked 2026-08-29: `command -v shellcheck` finds
nothing, and there is no binary under `/opt/homebrew` or `/usr/local`. `tests/run-tests.sh:54-56`
handles that by printing `SKIP  shellcheck is absent locally. CI will run it` and staying green, so
**a green full suite here does not mean the lint passed.** Two consequences, and neither is optional:

- No task's `Done when` gates on shellcheck. Where a task says to run it, it says "if installed".
- **The lint gate is CI's, and CI's shellcheck is older than a current local one.** Where a function
  is only ever invoked indirectly, disable **both** `SC2329` and `SC2317` on one line: the older
  shellcheck emits the second and the newer the first. Install it with `brew install shellcheck` to
  see what CI sees before pushing; this repository has gone red twice while clean on a laptop.

**`grep` in an agent harness may be a shell function, not the binary.** Confirmed 2026-08-29: run
through this harness, `grep -c 'out="$out'` returns `0` and exit 1, because the wrapper treats the
mid-pattern `$` as a basic-regex anchor. **Every investigative `grep` in this plan is written
`/usr/bin/grep` for that reason.** Inside `tests/test-keel.sh` plain `grep` is correct and is left
alone: that file runs under `#!/usr/bin/env bash`, where `grep` resolves to the binary.

- **`NFR-01`: `lib/detect-stack.sh` uses no `sed`, no `sort`, no `uniq` and no `tr`, and no YAML
  parser.** Its own comment at `lib/detect-stack.sh:102-104` says a change must not be the one that
  introduces them. Every marker in this plan is a `grep` or a `[ -f ]`.
- **`CON-05`: `pubspec.yaml` is read with `grep`, never parsed.** A `sqflite` inside a comment
  matches. That is accepted, `A2`.
- Writing style: no em dashes, no en dashes. Commit messages carry no attribution footer, no robot
  emoji, no generated-with line.
- **The full suite takes about two minutes, not the 10+ this line first claimed.** Measured
  2026-08-30 at the final checkpoint: 2m05s wall clock, against roughly 175s of per-file time, because
  `run-tests.sh` runs its jobs four-way concurrent. The 10+ figure was carried from an older handoff
  note and never re-measured. Still run it in the background and never pipe it through `tail`: that
  buffers the whole run, and the log stays empty until the run nearly ends anyway, because the jobs
  are replayed in order at the finish. Both read like a hang and neither is one.
- **Test pacing:** run `tests/test-keel.sh` (1m42s) per task, and the full suite only at the
  checkpoints below. A previous plan in this repository ran the full suite 28 times and spent 2.8
  hours doing it.
- **Full-suite checkpoints:** after task 4, after task 7, and after task 11. Nowhere else.
- A local run 5 to 10 times slower than usual has so far always meant the machine slept mid-run.
  Check `pmset -g log | /usr/bin/grep -i 'sleep\|wake'` before suspecting the suite.
- **`prof_of` prints one value per line, not a space-separated row.** Reading several fields in one
  call therefore uses the `{ read -r a; read -r b; } <<EOF ... EOF` idiom, which is what
  `tests/test-keel.sh:1877-1879` already does. A plain `[ "$(prof_of "$d" a b)" = "x y" ]` never
  matches, which is how an earlier draft of this plan was wrong.
- **Never append to a template under `$FIXTURE_CACHE`.** `fixture()` hands out a copy
  (`tests/test-keel.sh:28-35`); writing to the template instead poisons every later case silently.
  Task 4's third case appends to `$d`, the copy, which is why it is safe.

**Concurrent batches:** tasks 1 and 2 both say `Depends on: none` and name no file in common, so they
may run at the same time. Nothing else may: tasks 3 to 9 all touch `lib/detect-stack.sh` or
`tests/test-keel.sh`, most of them both. **The batch is declared for completeness rather than for
speed:** both tasks are minutes.

## What this plan does not settle

`Q3` of the PRD, whether a local path-dependency plugin with its own `pubspec.yaml` needs a rule.
`detect_languages` reads the root only, so a nested pubspec is invisible to every task here. That is
current behaviour rather than a decision, and it stays out of scope until an instance forces it.

---

### Task 1: Decide where `dart` sits in the marker chain, and record it

**Story:** S-11
**Files:**
- Modify: `docs/prd/dart-flutter-stack-detection.md`

**Interfaces:**
- Produces: the chain position that task 3 implements. Nothing in code.

**Depends on:** none

**Done when:** `/usr/bin/grep -q 'Position decided 2026-08-29' docs/prd/dart-flutter-stack-detection.md`
exits 0, and `tests/test-doc-claims.sh` prints `5 passed, 0 failed`.

- [x] **Step 1: Write the decision into `FR-19`'s Evidence column**

The position is **first in the chain, before the `package.json` block**. It is forced by `FR-19`,
which requires that a repository detected as `dart` reports `dart` as its primary language:
`detect_languages`' comment at `lib/detect-stack.sh:303-305` states that the first line is the
primary and drives the verify commands, so any later position would hand a Dart project another
language's test command.

It is safe because a `pubspec.yaml` at the **root** is an unambiguous declaration that the root is a
Dart package. `detect_languages` reads the root only, so a Flutter application in a subdirectory of a
Node repository is not seen at all and cannot claim it.

Replace `FR-19`'s Evidence cell with:

```markdown
| FR-19 | A repository detected as `dart` must report `dart` as its primary language, and must not suppress any other language whose manifest is also present. | inferred | `detect_languages` is a chain whose first line is the primary, `lib/detect-stack.sh:303-305`, and `detect_also` is everything after it, `:442-445`. **Position decided 2026-08-29, S-11: first, before the `package.json` block.** Later positions were rejected because they hand a Dart project another language's verify commands. It is safe at the front because the check reads the root only, so a `pubspec.yaml` there means the root is a Dart package; a Flutter app in a subdirectory is invisible to it either way. Where both manifests are present, `dart` is `stack.language` and the other is in `stack.also`, which is the shape the existing polyglot row already describes. No collision exists in current work to test against, which is why this is a decision and not an observation |
```

- [x] **Step 2: Run the checks and watch them pass**

Run: `/usr/bin/grep -c 'Position decided 2026-08-29' docs/prd/dart-flutter-stack-detection.md && tests/test-doc-claims.sh && tests/no-internal-leaks.sh`
Expected: `1`, then `5 passed, 0 failed`, then `OK    no project-specific identifiers`.

**The first command is the point.** An earlier draft of this task gated on the doc suites alone,
which pass identically whether or not the sentence was written, so the gate checked nothing. There is
still no failing-test step, and that is honest rather than skipped: this task produces a sentence.
The test that proves the decision is task 3's polyglot case, which fails until the position is
implemented.

- [x] **Step 3: Hand over**

```bash
git add docs/prd/dart-flutter-stack-detection.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.**

**Executed 2026-08-29, delegated, model `inherit`. Spec review COMPLIES; code-quality pass skipped,
stated rather than silent: this task changes one line of markdown, and pass one had already matched
it byte for byte against the dictated text and re-run all three commands itself.**

**Ticked on the subagent's output, with one note: no step here was witnessed failing first.** The
task says there is none to witness, and both doc suites pass identically before and after. The
`/usr/bin/grep -c` returned `1` and `tests/test-doc-claims.sh` returned `5 passed, 0 failed`.

**Review finding carried to task 10:** the new Evidence cell ends "which is the shape the existing
polyglot row already describes", and no row in the PRD describes it. The row is real but lives in
`docs/03-install-and-distribution.md`, which this plan does not make the PRD name. Task 10 step 3
now corrects the clause. The wording was dictated by this plan, so the implementer was right to
copy it verbatim.

---

### Task 2: Add the `dart` rows to the tool table

**Story:** S-01
**Files:**
- Modify: `skills/keel/references/tool-choices.md`

**Interfaces:**
- Produces: the rows `tests/validate-skills.sh` requires before `dart` may be detected at all.

**Depends on:** none

**Done when:** `tests/validate-skills.sh` ends `OK    24 skills validated, descriptions about 1066
tokens, 5 warning(s)` and `tests/test-validate-skills.sh` passes.

**Why this comes before task 3.** `tests/validate-skills.sh:414-429` extracts the language list out
of `detect_languages` and fails when a language has no row here. The suite goes red the moment
`out="$out dart"` lands without these rows, so this is a hard ordering and not a preference. The
converse is not checked, which is why this task can land alone and leave the suite green.

- [x] **Step 1: See the rule's current input**

Run: `awk '/^detect_languages\(\)/{f=1} f&&/^}/{f=0} f' lib/detect-stack.sh | /usr/bin/grep -c 'out="$out'`
Expected: `14`, the languages the rule checks today. After task 3 it is `15`.

**`/usr/bin/grep`, not `grep`.** Through an agent harness the wrapper returns `0` and exit 1 here,
because it reads the mid-pattern `$` as an anchor. Verified both ways on 2026-08-29.

**The rows below are the second version.** The first attempt was implemented faithfully and its
review then disproved two claims in the text this plan had dictated, against the SDK on this machine:
"the SDK ships the runner" is false for Dart, which ships the `dart test` command but not
`package:test`, and "they are not interchangeable" is only true in one direction, since `flutter test`
runs in a plain package. That attempt was discarded rather than amended. **The `dart test`
precondition it uncovered also reaches `FR-08` and task 5**, and is settled there rather than here.

- [x] **Step 2: Add the three rows**

In the **Test** table, after the `plsql` row:

```markdown
| `dart` | `flutter test` for a Flutter project, `dart test` for a plain package | none | Both are SDK commands, but only Flutter bundles its runner. `flutter test` needs no dev dependency; `dart test` fails with "Could not find package `test`" unless the pubspec declares `package:test`. The lock is one-directional, measured 2026-08-29: `dart test` cannot drive a Flutter project, because the plain VM has no `dart:ui`, while `flutter test` does run in a plain package. `dart test` is still the right answer there, so that testing a plain package does not drag in the Flutter SDK |
```

In the **Lint and format** table, after the `plsql` row:

```markdown
| `dart` | `dart analyze` with `dart format` | none | Both ship with the SDK and both run with no configuration, which is why `verify.lint` is not gated on `analysis_options.yaml`: measured 2026-08-29, `dart analyze` reports real type errors in a package that has no such file. `flutter analyze` is the same analyzer invoked through the Flutter SDK. `flutter format` was removed; `dart format` is the only spelling left |
```

In the **Typecheck** table, after the `plsql` row:

```markdown
| `dart` | none | The analyzer is the type checker and it is already the lint command, so `verify.typecheck` stays `null` rather than running the same analysis twice under a second name |
```

- [x] **Step 3: Run the validator and watch it pass**

Run: `tests/validate-skills.sh && tests/test-validate-skills.sh`
Expected: `OK    24 skills validated, descriptions about 1066 tokens, 5 warning(s)`. **Five, not six.**
A sixth means a skill body was touched, which this task does not do.

- [x] **Step 4: Hand over**

```bash
git add skills/keel/references/tool-choices.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.**

**Executed 2026-08-29, delegated, model `inherit`. Second attempt; the first was discarded, not
amended.** Its review executed correctly and then disproved two claims in the text this plan had
dictated, so the fault was the plan's. The rows above are the corrected version.

**Ticked on the subagent's output, with two notes.** No step was witnessed failing: the validator
checks only that every detected language has a row and not the converse, so it is green with and
without these rows until task 3 lands `out="$out dart"`. And `shellcheck` was not run, because it is
absent on this machine and this task changes no shell file.

**Accepted on a byte comparison rather than a third review dispatch, stated rather than assumed.**
All three rows matched the dictated text character for character, `git diff --cached --numstat` was
`3  0`, and no line was added that this plan did not dictate. The claims themselves had already been
measured against the SDK by the first attempt's review, which is what produced the correction.

**The subagent noticed the plan file was already modified in the working tree and left it unstaged**,
which is correct: the plan is the coordinator's and no task names it.

---

### Task 3: Detect `dart` from a declared `pubspec.yaml`

**Story:** S-02
**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Produces: `dart` in `detect_languages`' output. Tasks 4 to 9 all branch on it.
- Produces: the four fixtures `dart-flutter`, `dart-pure`, `dart-orphan` and `dart-polyglot`,
  consumed by every task below.

**Depends on:** task 1, task 2

**Done when:** `tests/test-keel.sh` passes with **six** more passes than before, `343 passed, 0 failed`
against a 337 baseline, and `tests/validate-skills.sh` still ends `OK`.

**Six, not five.** This line read "five" until 2026-08-29 and contradicted step 4, which said six.
Six is the achievable number: the block below holds six live assertions and all six pass once the
marker exists. Five is the *failure* count at step 2, where the orphan guard already passes. Caught
by task 3's spec review, which noticed the plan disagreeing with itself.

- [x] **Step 1: Write the failing test**

Add four fixtures to `fixture_build`'s `case` in `tests/test-keel.sh`, immediately before the
`bare) : ;;` arm:

```bash
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
          # bare-word `flutter` match call this package a Flutter application, and task 4 adds it
          # back in one case to hold that line.
          cat > pubspec.yaml <<'P'
name: f
environment:
  sdk: ">=3.0.0 <4.0.0"
dev_dependencies:
  test: ^1.24.0
P
          mkdir -p test lib
          printf "void main() {}\n" > test/f_test.dart ;;
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
```

Then add the assertions, **immediately after the per-language detection loop that ends at
`tests/test-keel.sh:191`**.

**Every assertion here reads `detect_languages`, never `detect_stack`, and that is load-bearing.**
`detect_stack` is `lang_profile "$(detect_languages | head -n 1)"`, and `lang_profile` has no `dart`
arm until task 4, so a `detect_stack`-shaped assertion in this task cannot pass however correct the
marker is. **The first attempt at this task was discarded over exactly that**: it was implemented
faithfully, the marker worked, and two assertions this plan had written at the wrong level left the
suite at `341 passed, 2 failed`. Primacy is a property of the chain, so `detect_languages | head -n 1`
tests it directly rather than through a function this task does not build. Task 4 asserts the tuple.

```bash
# ---- dart -----------------------------------------------------------------
# Dart is read from pubspec.yaml, which is a declaration, so it needs none of the inference PL/SQL
# does. The orphan case is the one that matters: ten .dart files and no manifest must detect as
# nothing, because a marker keyed on source files would have called it Dart.
#
# These read detect_languages and not detect_stack: lang_profile gains its dart arm in the next
# task, so detect_stack answers `unknown` here no matter how well the marker works.
d="$(fixture dart-flutter)"
got="$(detect_in "$d" 'detect_languages | tr "\n" " "')"
case "$got" in
  *dart*) ok "a Flutter project detects as dart" ;;
  *)      bad "dart" "got '$got', want dart" ;;
esac
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

d="$(fixture dart-polyglot)"
got="$(detect_in "$d" 'detect_languages | head -n 1')"
[ "$got" = "dart" ] && ok "dart is primary when another manifest is also present" \
  || bad "dart" "polyglot got '$got', want dart"
got="$(detect_in "$d" 'detect_also | tr "\n" " "')"
case "$got" in
  *typescript*) ok "the other language is kept in stack.also" ;;
  *)            bad "dart" "also got '$got', want typescript" ;;
esac
rm -rf "$d"

# The build rule in tests/validate-skills.sh extracts languages by matching this exact spelling.
# A rename inside detect_languages disables that rule silently rather than breaking it, which is
# why the spelling is pinned here rather than left to review. FR-03.
awk '/^detect_languages\(\)/{f=1} f&&/^}/{f=0} f' "$ROOT/lib/detect-stack.sh" \
  | grep -q 'out="$out dart"' \
  && ok "dart uses the accumulator spelling the tool-table rule extracts" \
  || bad "dart" "detect_languages does not contain out=\"\$out dart\""
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, **five** new failures, the first reading `FAIL  dart: got '', want dart`.

**Five and not six.** The `dart-orphan` case passes beforehand, because a tree nothing detects
already returns an empty language list. A test that passes before the code exists is not evidence,
and counting it as a failure here would have hidden that. Measured on the discarded first attempt:
`338 passed, 5 failed` at this step against a 337-pass baseline.

- [x] **Step 3: Write the minimal implementation**

In `detect_languages`, immediately after `local out=""` and **before** the `if [ -f package.json ]`
block:

```bash
    # Dart, first in the chain because the first line is the primary and drives the verify commands.
    # A pubspec.yaml at the root is an unambiguous declaration that the root is a Dart package, and
    # this check reads the root only, so a Flutter app inside a Node repository cannot claim it.
    # Position decided 2026-08-29, S-11. FR-01, FR-19.
    [ -f pubspec.yaml ] && out="$out dart"
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, six more passes than the pre-task baseline.

Then, **if shellcheck is installed**, the lint command from Global constraints; expected no output.
If it is absent, say so in the report rather than ticking a box for a check that did not run.

- [x] **Step 5: Tighten two assertions, and correct a count this change falsifies**

**Added 2026-08-29 by task 3's code-quality review, after steps 1 to 4 had passed.** Both findings
are about this task's own diff and belong in its commit rather than in task 10.

First, `lib/detect-stack.sh:93` reads "a repository declaring any of **the thirteen** never reaches
this function at all". Thirteen was exact before this task and is now fourteen. It is the comment
documenting the short-circuit that `[ -f pubspec.yaml ]` has just joined, so it is wrong in the same
file and the same function chain this task edits. Change `the thirteen` to `the fourteen` on that
line, and nothing else in that comment.

Second, two of the six new assertions test with a substring where this file tests with equality
everywhere else. `tests/test-keel.sh:975` is the precedent: `[ "$got" = "typescript python" ]`. The
fixtures are deterministic and the exact answer is known, so `*dart*` also passes on `dart javascript`
and the `also` check passes on a duplicated entry. Replace:

```bash
got="$(detect_in "$d" 'detect_languages | tr "\n" " "')"
case "$got" in
  *dart*) ok "a Flutter project detects as dart" ;;
  *)      bad "dart" "got '$got', want dart" ;;
esac
```

with:

```bash
got="$(detect_in "$d" 'detect_languages | tr "\n" " "')"
[ "$got" = "dart " ] && ok "a Flutter project detects as dart, and only dart" \
  || bad "dart" "got '$got', want 'dart '"
```

and replace:

```bash
got="$(detect_in "$d" 'detect_also | tr "\n" " "')"
case "$got" in
  *typescript*) ok "the other language is kept in stack.also" ;;
  *)            bad "dart" "also got '$got', want typescript" ;;
esac
```

with:

```bash
got="$(detect_in "$d" 'detect_also | tr "\n" " "')"
[ "$got" = "typescript " ] && ok "the other language is kept in stack.also, and nothing else is" \
  || bad "dart" "also got '$got', want 'typescript '"
```

**Leave the `dart-orphan` case as a `case` statement.** It asserts an absence, where substring
absence is the right semantic, and the review did not flag it.

- [x] **Step 6: Run it and watch it still pass**

Run: `tests/test-keel.sh`
Expected: `343 passed, 0 failed`, unchanged. The count does not move: these tighten two existing
assertions rather than adding any.

**Prove the tightened assertions can fail**, since a stricter test that never fails is no stricter:
temporarily change the expected string in one of them to `"dart x "`, re-run, confirm
`FAIL  dart: got 'dart ', want 'dart x '`, then put it back.

- [x] **Step 7: Hand over**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

**Executed 2026-08-29, delegated, model `inherit`. Second attempt; the first was discarded.** The
first was implemented faithfully and this plan's own step 1 was wrong: two assertions read
`detect_stack`, which routes through a `lang_profile` arm task 4 has not added yet, leaving
`341 passed, 2 failed`. Relevelled to `detect_languages`, which is what this task builds.

**Every number here was witnessed.** Baseline `337 passed, 0 failed`; step 2 `338 passed, 5 failed`
with `dart-orphan` the one new case passing beforehand; step 4 and step 6 both `343 passed, 0 failed`.
The spec review reproduced the red state independently, by archiving `HEAD` and dropping only the
staged test file on top, rather than taking the report's word for it.

**shellcheck did not run and no box is ticked for it.** It is absent on this machine, so CI is the
lint gate for this change.

**Steps 5 and 6 were added after steps 1 to 4 had passed**, from the code-quality review, and applied
by a fresh dispatch rather than by the coordinator. The stale "thirteen" was in the same file and the
same short-circuit this task edits, so it belonged here rather than in task 10. The tightened
assertions were proved able to fail: deliberately breaking one gave `342 passed, 1 failed`.

**Carried to ship: this commit alone regresses a root-polyglot Dart repository.** Measured by the
code-quality review on a tree with `pubspec.yaml` and `package.json` at the root: `stack.language`
and every verify command go blank, because `dart` is now first in the chain and `lang_profile` has no
arm for it until task 4. Pure Dart and non-Dart trees are unaffected. **Tasks 3 and 4 must reach
`main` together**, which they will, since everything lands on `sandbox` behind one pull request.

---

### Task 4: Emit the stack tuple, and prove it reaches the profile

**Story:** S-03
**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Produces: `is_flutter`, taking no arguments, returning 0 when `pubspec.yaml` declares the Flutter
  SDK dependency and 1 otherwise. Consumed by task 5.
- Produces: `lang_profile dart`, emitting `dart dart <framework> pub`.

**Depends on:** task 3

**Done when:** `tests/test-keel.sh` passes. **Full-suite checkpoint: run `tests/run-tests.sh` in the
background after this task.**

- [x] **Step 1: Write the failing test**

Append to the `---- dart ----` block added in task 3:

```bash
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
printf 'dev_dependencies:\n  flutter_lints: ^3.0.0\n' >> "$d/pubspec.yaml"
got="$(detect_in "$d" 'detect_stack | cut -d" " -f3')"
[ "$got" = "none" ] && ok "flutter_lints alone does not make a package a Flutter application" \
  || bad "dart" "got framework '$got', want none"
rm -rf "$d"

# The end to end claim, which no assertion above makes: the tuple has to survive write_profile to be
# worth anything. The PL/SQL work added exactly this after a run where the detector had classified a
# repository correctly and the profile still said `unknown`. S-03 scenario 3.
d="$(fixture dart-flutter)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
{ read -r p_lang; read -r p_fw; read -r p_pm; } <<EOF
$(prof_of "$d" stack.language stack.framework stack.package_manager)
EOF
[ "$p_lang $p_fw $p_pm" = "dart flutter pub" ] \
  && ok "keel init writes the Dart stack into the profile" \
  || bad "dart" "profile got '$p_lang $p_fw $p_pm', want 'dart flutter pub'"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, **three** new failures. `FAIL  dart: got 'unknown unknown none none', want 'dart dart
flutter pub'` first.

**Three and not four.** The `flutter_lints` case passes beforehand, because field 3 of
`unknown unknown none none` is already `none`. **Prove it can fail** before accepting it:
temporarily change `is_flutter`'s pattern to a bare `flutter`, re-run, confirm the case reports
`got framework 'flutter', want none`, then put it back.

- [x] **Step 3: Write the minimal implementation**

Add the helper immediately after `composer_declares` (`lib/detect-stack.sh:450-452`), the nearest
thing to it in the file:

```bash
# True when pubspec.yaml declares the Flutter SDK dependency, which is what separates a Flutter
# application from a plain Dart package. The two take different commands, and the asymmetry is
# measured rather than assumed: `dart test` cannot drive a Flutter project, exiting non-zero on
# `dart:ui` even once `package:test` is declared, while `flutter test` does run in a plain package.
# So the split is not about what is possible. It is so a plain package is not made to depend on the
# Flutter SDK to run its own tests.
#
# Matched as the `sdk: flutter` line rather than the bare word. `flutter_lints` is a dev dependency
# in 7 of the 15 repositories the requirement was measured against on 2026-08-29, and a bare-word
# match calls every one of them Flutter whether or not they are. Verified the other way too: the
# `sdk: flutter` form matched 15 of 15 real Flutter applications.
#
# grep and not a parse, because this file has no YAML parser and must not gain one. CON-05, NFR-01.
is_flutter() {
    grep -qE '^[[:space:]]*sdk:[[:space:]]*flutter' pubspec.yaml 2>/dev/null
}
```

Then the `lang_profile` arm, immediately before the `plsql)` arm:

```bash
      dart)
        # Flutter is the framework and Dart the language, which is the shape every other row uses.
        # runtime is `dart` and not `flutter`, mirroring `php php`, `python python`, `ruby ruby`
        # and `rust rust`: the runtime is the language's own VM. FR-04, FR-05.
        local fw=none
        is_flutter && fw=flutter
        printf 'dart dart %s pub\n' "$fw" ;;
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, four more passes.

Then, if shellcheck is installed, the lint command. If it reports `SC2329` or `SC2317` against
`is_flutter`, put **both** codes on one `# shellcheck disable=` line above it.

Then the full-suite checkpoint, in the background:
`tests/run-tests.sh > /tmp/keel-suite.log 2>&1 &`, and read `/tmp/keel-suite.log` when it exits.
**Do not pipe it through `tail`.** Expect `SKIP` on the lint job unless shellcheck is installed.

- [x] **Step 5: Close four findings from this task's own reviews**

**Added 2026-08-29 after steps 1 to 4 passed.** Two are false claims this task created, one is an
assertion that was proved vacuous, and one records a measurement so the next reader does not repeat it.

**(a) The `flutter_lints` assertion is vacuous and must compare the whole tuple.** The reviewer
removed the `dart)` arm from a copy of the library and this assertion still reported PASS, because
`cut -d" " -f3` of `unknown unknown none none` is also `none`. It cannot tell "Dart, and not Flutter"
from "nothing detected at all". The same edit fixes the fixture being invalid YAML: appending a
second `dev_dependencies:` block is a duplicate mapping key that `pub get` rejects, so append only
the indented entry, which lands under the block already there. Replace:

```bash
printf 'dev_dependencies:\n  flutter_lints: ^3.0.0\n' >> "$d/pubspec.yaml"
got="$(detect_in "$d" 'detect_stack | cut -d" " -f3')"
[ "$got" = "none" ] && ok "flutter_lints alone does not make a package a Flutter application" \
  || bad "dart" "got framework '$got', want none"
```

with:

```bash
printf '  flutter_lints: ^3.0.0\n' >> "$d/pubspec.yaml"
got="$(detect_in "$d" 'detect_stack')"
[ "$got" = "dart dart none pub" ] && ok "flutter_lints alone does not make a package a Flutter application" \
  || bad "dart" "got '$got', want 'dart dart none pub'"
```

**(b) The end-to-end assertion omits the one field its own comment defends.** `lang_profile`'s new
arm argues specifically for runtime `dart` over `flutter`, and the profile check does not read
`stack.runtime`. The PL/SQL end-to-end at `tests/test-keel.sh:443-450` pins both. Replace the three
`read`s with four:

```bash
{ read -r p_lang; read -r p_rt; read -r p_fw; read -r p_pm; } <<EOF
$(prof_of "$d" stack.language stack.runtime stack.framework stack.package_manager)
EOF
[ "$p_lang $p_rt $p_fw $p_pm" = "dart dart flutter pub" ] \
  && ok "keel init writes the Dart stack into the profile" \
  || bad "dart" "profile got '$p_lang $p_rt $p_fw $p_pm', want 'dart dart flutter pub'"
```

**(c) Two comments in `tests/test-keel.sh` are now false, and this task falsified them.**
`docs/standards.md:155` requires shipped prose to state the current state. The header of the dart
block says the cases read `detect_languages` and not `detect_stack` because `lang_profile` gains its
arm "in the next task"; four `detect_stack` cases now sit under it. Replace those two lines with:

```bash
# The first cases read detect_languages rather than detect_stack, deliberately: they test the marker
# and the chain position that puts dart first. The detect_stack cases below test the tuple
# lang_profile builds from it. Both levels are asserted because a correct marker with no
# lang_profile arm was a real intermediate state here, and it looked green at one level.
```

And the `dart-pure` fixture comment ends "and task 4 adds it back in one case to hold that line",
which is narration keyed to a plan task number that outlives the plan. Replace that clause with
"One assertion appends it to a copy of this fixture to hold that line."

**(d) Record why `is_flutter` is not memoised, and why it has no end anchor.** This file states that
reasoning where it applies: `is_plsql_tree` spends eighteen lines on it. Append to `is_flutter`'s
comment block:

```bash
# Not memoised, unlike PKG_SCRIPTS and DETECTED_LANGS, and that is measured rather than assumed: one
# `keel init` on a Flutter project calls lang_profile five times, so five greps of a ten-line file,
# about 10 ms. Those two caches exist for a 24 ms tree walk and a 102 ms one. A third would also need
# write_profile's priming to survive the subshell, which is real complexity for 10 ms.
#
# There is deliberately no end anchor. A CRLF checkout ends the line `flutter\r`, so tightening this
# to `flutter[[:space:]]*$` would silently stop matching every repository checked out on Windows.
```

- [x] **Step 6: Run it and watch it still pass**

Run: `tests/test-keel.sh`
Expected: `347 passed, 0 failed`, unchanged. These tighten and re-comment; they add no assertion.

**Prove the tightened `flutter_lints` case can now fail where it could not before.** Temporarily
delete the `dart)` arm from `lang_profile`, re-run, and confirm this case now reports
`FAIL  dart: got 'unknown unknown none none', want 'dart dart none pub'` where the old `cut -f3`
form reported PASS. Restore the arm.

- [x] **Step 7: Hand over**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

**Executed 2026-08-29, delegated, model `inherit`. Spec review COMPLIES, code-quality review no
blockers. Both passes ran, and both found something.**

**Witnessed:** step 2 `344 passed, 3 failed`, tuple case first; step 4 and step 6 both
`347 passed, 0 failed`. The full-suite checkpoint ran and was green: 13 test files, zero FAIL lines,
lint `SKIP`. The spec review re-ran both suites itself rather than reading the report.

**The step 2 proof was actually performed.** `is_flutter` did not exist when the proof was due, so
the implementer built it with the deliberately wrong bare-word pattern, watched the `flutter_lints`
guard fail with exactly `FAIL  dart: got framework 'flutter', want none`, then replaced it with the
real pattern. That is the proof done rather than asserted.

**Four corrections after the reviews, applied by a fresh dispatch, not by the coordinator.**
- A false sentence this plan dictated into `is_flutter`'s comment, that `flutter test` "is not
  available to a plain package". **Measured false**: it exits 0 in a package with zero `flutter`
  references. The split is still right, for a different reason, and the comment now says which.
- The `flutter_lints` assertion was **vacuous**, proved by deleting the `dart)` arm and watching it
  still report PASS: `cut -d" " -f3` of `unknown unknown none none` is also `none`. It now compares
  the whole tuple, and the same edit stopped the fixture being invalid YAML.
- The end-to-end assertion did not read `stack.runtime`, the one field the new arm's comment argues
  for. It reads four fields now.
- Two comments this task falsified, both narrating "the next task", rewritten to the current state
  per `docs/standards.md:155`.

**The tightening was proved to bite.** With the `dart)` arm deleted the suite reports
`343 passed, 4 failed` and the `flutter_lints` case is among them, where the old form passed.

**shellcheck did not run and no box is ticked for it.** No `SC2329`/`SC2317` disable was added:
`is_flutter` is invoked directly from the same file. CI is the gate that settles it.

**Correction to a claim made in review:** the implementer justified the helper's placement by
citing `composer_declares` and `find_marker` as also defined after their callers. They are not; both
are defined before theirs. `is_flutter` is the only helper in this file defined after its call site.
Harmless in a sourced library, and this plan dictated the placement.

**Carried to task 6:** `is_flutter` answers "declares the Flutter SDK", not "is a Flutter
application", so a package declaring only `flutter_test` under `dev_dependencies` will get
`has_ui: true`. Recorded there as a known limit under `CON-05`, deliberately not chased.

---

### Task 5: Write the `dart` arm of `detect_verify`, and prove the null keys stay null

**Stories:** S-04, S-05, S-06
**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `is_flutter`, defined in task 4.
- Produces: `dart_declares_test`, taking no arguments, returning 0 when `pubspec.yaml` declares a
  dependency on `package:test`. Used only by this task.
- Produces: the `dart)` arm of `detect_verify`. Nothing below extends it.
- Produces: the `dart-pure-notest` fixture.

**Depends on:** task 4

**Done when:** `tests/test-keel.sh` passes.

**Three stories in one task, deliberately.** They are the same `case` arm in the same function
against the same fixtures, and S-05's own note argues the point: splitting them produces tasks that
edit the same lines and forces the second to restate the first's code in full. A reviewer can still
reject one command without rejecting the arm.

**`dart test` is gated, and `flutter test` is not.** Task 2's review measured that `dart test` exits
non-zero with "Could not find package `test`" unless the pubspec declares it, while Flutter bundles
`flutter_test` and needs no declaration. An ungated `dart test` is therefore a guessed command that
does not run, which `CON-02` forbids, and gating is the house pattern: `python` gates on
`py_declares pytest`, `php` on `composer_declares`, `ruby` on a `spec/` directory, `lua` on
`.busted`. **Decided by Bernard, 2026-08-29, asked as a choice.** It amends `FR-08`, which task 10
records.

- [x] **Step 1: Write the failing test**

First add one more fixture to `fixture_build`'s `case`, beside the four task 3 added: a plain package
that has **not** declared the runner, which is what the gate exists for.

```bash
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
```

Then append to the `---- dart ----` block:

```bash
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
v_lint="$(detect_in "$d" 'detect_verify lint')"
v_fmt="$(detect_in "$d" 'detect_verify format')"
[ "$v_test" = "dart test" ] && ok "a pure Dart package's test command" \
  || bad "dart" "test got '$v_test', want 'dart test'"
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
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, **ten** new failures out of seventeen new cases. **Seven pass beforehand**, because
an arm that does not exist emits nothing: the five `verify.<key> is null` cases and the two
`dart-pure-notest` null cases. That is the gate's awkwardness and it is worth naming, since a test
asserting an absence looks identical before and after the code that creates the absence deliberately.

**Prove they can fail** before accepting any of the seven. Temporarily add
`build) printf 'flutter build apk' ;;` to the arm written in step 3 and confirm
`FAIL  dart: verify.build got 'flutter build apk', want empty`; then temporarily drop the
`dart_declares_test` gate so `dart test` is emitted unconditionally, and confirm
`FAIL  dart: test got 'dart test', want empty` on the `dart-pure-notest` fixture. Undo both.

- [x] **Step 3: Write the minimal implementation**

First add the gate helper, immediately after `is_flutter` from task 4:

```bash
# True when pubspec.yaml declares a dependency on package:test, which `dart test` needs and which the
# Dart SDK does not ship. Measured 2026-08-29: in a package that has not declared it, `dart test`
# exits non-zero with "Could not find package `test`". Flutter bundles `flutter_test`, so this gate
# applies to the plain Dart branch only.
#
# The pattern requires leading whitespace, so `test:` under dependencies or dev_dependencies matches
# and a top-level `name: test` does not. `flutter_test:` does not match either, because the character
# before `test:` is an underscore rather than whitespace.
dart_declares_test() {
    grep -qE '^[[:space:]]+test:' pubspec.yaml 2>/dev/null
}
```

Then, in `detect_verify`, add an arm immediately before the closing `esac` of the language `case`,
alongside `lua)`:

```bash
      dart)
        # The analyzer and the formatter ship with the SDK and need no declaration, so they are
        # unconditional. The runner is not: `flutter test` is bundled, `dart test` is a command
        # whose package must be declared, so the plain branch is gated and the Flutter branch is
        # not. FR-07, FR-08 as amended 2026-08-29.
        #
        # build, typecheck, e2e, security and test_integration have no branch and that is the
        # requirement, not an omission. `flutter build` needs a target and there are eight; the
        # analyzer is already lint. FR-13, FR-14.
        local dc=dart runner=
        is_flutter && dc=flutter
        { [ "$dc" = flutter ] || dart_declares_test; } && runner="$dc"
        case "$what" in
          test)     [ -n "$runner" ] && printf '%s test' "$runner" ;;
          test_one) [ -n "$runner" ] && printf '%s test {path}' "$runner" ;;
          # Ungated by analysis_options.yaml: the analyzer applies the SDK's default lint set with
          # or without it, and 8 of the 15 repositories measured have no such file. FR-10.
          lint)     printf '%s analyze' "$dc" ;;
          # `dart` for both kinds of project: `flutter format` was removed from the SDK, so there is
          # only one spelling left. Check-only, because a command that rewrites cannot gate. NFR-04.
          format)     printf 'dart format --output=none --set-exit-if-changed .' ;;
          format_fix) printf 'dart format .' ;;
        esac ;;
```

The `[ -n "$runner" ] && printf` shape leaves the arm's exit status non-zero when the gate is shut.
That is the same shape the `lua` arm already uses for `.busted`, and `write_profile` reads the
captured output rather than the status, so an empty string becomes `null` in the profile.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, seventeen more passes. Then the lint command if shellcheck is installed. If it reports
SC2329 or SC2317 against `dart_declares_test`, put both codes on one `# shellcheck disable=` line.

- [x] **Step 5: Check the commands against the real SDK, by hand**

S-04 scenario 4 and S-05 scenarios 3 and 4 assert that these commands actually run, which no unit
test here does. `flutter` and `dart` are on this machine's PATH, so check once, by hand, in a scratch
copy of a real Flutter repository, and **paste the output into the report**:

```bash
flutter test            # expect: exit 0 on a project with a widget test
dart format --output=none --set-exit-if-changed .   # expect: exit 1 where a file is unformatted, and the file unchanged
dart format .           # expect: the file rewritten
```

If the SDK is not available where this task runs, say so and leave the box unticked. **Do not tick
it on the unit tests alone:** they prove the profile carries the string, not that the string runs.

- [x] **Step 6: Close five findings from this task's code-quality review**

**Added 2026-08-30.** One is a coverage hole proved by mutation, one is a comment this task falsified,
and three are cost and accuracy.

**(a) A plain package's `test_one` is asserted by nothing.** Proved: replacing
`printf '%s test {path}' "$runner"` with a hardcoded `flutter test {path}` left the suite at
`364 passed, 0 failed`. `dart-pure` asserts `test`, `lint` and `format` but never `test_one`, and
`dart-pure-notest` only asserts it is empty, so the string `dart test {path}` is produced by the code
and checked by nothing. In the `dart-pure` block, beside the existing `v_test` and `v_lint` reads,
add:

```bash
v_one="$(detect_in "$d" 'detect_verify test_one')"
[ "$v_one" = "dart test {path}" ] && ok "a pure Dart package's single-test command" \
  || bad "dart" "test_one got '$v_one', want 'dart test {path}'"
```

**(b) Move the gate inline, and delete `runner`.** It is hoisted out of the only two branches that
read it, so it runs for all ten verify keys: 14 discarded `grep` forks per `keel init` on a plain
package, measured at 50.3 ms. The neighbouring arms gate inline in the branch that needs it, which is
`ruby`'s `{ [ -f .rubocop.yml ] || grep -qs rubocop Gemfile; } &&` and `lua`'s stylua pair. Replace
the `local dc=dart runner=` line, the `{ ... } && runner="$dc"` line, and the two `[ -n "$runner" ]`
branches with:

```bash
        local dc=dart
        is_flutter && dc=flutter
        case "$what" in
          test)     { [ "$dc" = flutter ] || dart_declares_test; } && printf '%s test' "$dc" ;;
          test_one) { [ "$dc" = flutter ] || dart_declares_test; } && printf '%s test {path}' "$dc" ;;
```

Leave the `lint`, `format` and `format_fix` branches exactly as they are.

**(c) `is_flutter`'s non-memoisation comment is now false, and this task falsified it.** It says one
`keel init` "calls lang_profile five times, so five greps". Measured 2026-08-30 by shadowing `grep`
on `PATH`: **15 `is_flutter` greps**, because `detect_verify` adds ten on top of `lang_profile`'s
five, plus **10 `dart_declares_test` greps** on a plain package, which (b) reduces to 2. Correct the
numbers in that comment and keep its conclusion, which is unchanged: still do not memoise. Add the
`detect_verify` contribution as the reason the number is what it is.

**(d) `dart_declares_test`'s comment gives a reason that does not fit its own example.** It says the
leading-whitespace requirement is why "a top-level `name: test` does not" match. `name: test` is
excluded because it contains no `test:` at all. What the whitespace clause actually excludes is a key
named `test:` at column zero. Say that instead, so a reader who checks the claim finds it holds.

**(e) Measure whether `dart format .` walks `build/`.** `verify.format` is a gate, and if the
formatter descends into `build/` and generated `*.g.dart` or `*.freezed.dart` files, the gate can be
red on a clean checkout for reasons that are not the developer's code. `build/` is not hidden, so it
is not skipped the way `.dart_tool/` is. Check it against a real Flutter repository that uses
`build_runner`, in a scratch copy outside this repo, and **report the finding rather than changing
the command**: if it reproduces, it is a defect in `FR-11` and the coordinator will decide, not this
task.

- [x] **Step 7: Run it and watch it still pass**

Run: `tests/test-keel.sh`
Expected: `365 passed, 0 failed`. One more than before, because (a) adds one assertion; (b), (c) and
(d) add none.

**Prove (a) closed the hole it names.** Hardcode `printf 'flutter test {path}'` in the `test_one`
branch again, re-run, and confirm the new assertion now reports
`FAIL  dart: test_one got 'flutter test {path}', want 'dart test {path}'` where the suite previously
stayed green. Undo it.

- [x] **Step 8: Hand over**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

**Executed 2026-08-29 and 2026-08-30, delegated, model `inherit`. Spec review COMPLIES,
code-quality review no blockers. Three stories closed: S-04, S-05, S-06.**

**Witnessed:** step 2 `354 passed, 10 failed`, the predicted ten of seventeen; step 4
`364 passed, 0 failed`; step 7 `365 passed, 0 failed` after the review added one assertion.

**Both step 2 proofs performed.** A temporary `build)` branch gave
`FAIL  dart: verify.build got 'flutter build apk', want empty`, and it was caught twice, by the key
assertion and by the profile assertion. Dropping the gate gave the two `want empty` failures on
`dart-pure-notest`. The spec review then proved the other four null keys falsifiable itself, by
patching the arm to emit all four and watching exactly four new failures.

**Step 5 ran against the real SDK, outside the repository.** `flutter test` exit 0 on a scratch copy
of a real app; the check-only format exit 1 with the file byte-identical afterwards; `dart format .`
exit 0 and the file rewritten. The gate's premise was reconfirmed: `dart test` exit 65 in a package
with no `test` dependency, `dart analyze` exit 0 in the same package.

**Five corrections after review, applied by a fresh dispatch.**
- **A coverage hole, found by mutation:** a plain package's `test_one` was asserted by nothing.
  Hardcoding `flutter test {path}` left the suite green at `364 passed, 0 failed`. One assertion
  closes it, and it was proved to bite: the same mutation now gives `364 passed, 1 failed`.
- The gate was hoisted out of the two branches that read it, running for all ten verify keys: 14
  discarded `grep` forks per init, 50.3 ms. Moved inline, matching `ruby` and `lua`, and `runner`
  deleted.
- **`is_flutter`'s non-memoisation comment, added by task 4 to record a measurement, was already
  false.** It said five greps per init; measured 15, because `detect_verify` adds ten on top of
  `lang_profile`'s five. Corrected, conclusion unchanged.
- `dart_declares_test`'s comment justified excluding `name: test` by the leading-whitespace rule,
  which is not why it is excluded. Corrected.

**`FR-11` was measured and kept.** `dart format .` does descend into `build/`: a misformatted
generated file there turns the gate red on an otherwise clean tree, and `format_fix` rewrites it. The
identical file under `.dart_tool/` is skipped, so hidden directories are excluded and `build/` is not.
**Exposure is nil in practice: none of the 13 local Flutter repositories has any `.dart` file under
`build/`**, since Flutter puts compiled Android and iOS artifacts there and `build_runner` writes to
`lib/` or to the hidden `.dart_tool/build/generated`. Narrowing the command to `lib test` would stop
checking `bin/` and `tool/`, trading a measured-zero risk for a real gap. No change; recorded here
and in the PRD by task 10.

**shellcheck did not run and no box is ticked for it.** The spec review corrected the implementer's
claim that `dart_declares_test` is invoked indirectly: it is called directly, so SC2329 and SC2317 do
not apply and no disable was added.

---

### Task 6: Stop reporting a Flutter application as having no user interface

**Story:** S-07
**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: the framework emitted by `lang_profile dart`, task 4.

**Depends on:** task 4

**Done when:** `tests/test-keel.sh` passes.

**Known limit, measured by task 4's code-quality review and accepted rather than fixed here.**
`is_flutter` matches `sdk: flutter` anywhere in `pubspec.yaml`, so what it really answers is
"declares the Flutter SDK", not "is a Flutter application". A plain package declaring only
`flutter_test:` with `sdk: flutter` under `dev_dependencies` therefore gets `framework: flutter` and,
through this task, `has_ui: true` on a package with no user interface. It is accepted because
`CON-05` already accepts this class: the file has no YAML parser, so the alternative is a structural
check it cannot perform. **Do not widen this task to chase it.** If it ever fires on a real
repository, that instance is what would justify revisiting `CON-05`.

**The blast radius is wider than `framework` and `has_ui`, measured 2026-08-30 by this task's
review.** On such a package `detect_verify` also returns `flutter test` and `flutter analyze`, from
task 5's `dc=flutter` branch. So the cost of the limit is a package being told to drive its tests
through the Flutter SDK, not merely a wrong boolean. Still accepted, and still the same `CON-05`
class, but the record said less than the truth and now says it.

- [x] **Step 1: Write the failing test**

Add to the `---- has_ui ----` block that begins at `tests/test-keel.sh:910`, after the existing
cases:

```bash
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
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, one new failure: `FAIL  has_ui: Flutter project got 'false', want true`.

- [x] **Step 3: Write the minimal implementation**

One word, in `detect_has_ui` at `lib/detect-stack.sh:704`:

```bash
    case "$fw" in next|react|vue|svelte|angular|apex|flutter) printf 'true'; return 0 ;; esac
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, two more passes, and **every existing `has_ui` case still passing**. That is S-07's
third scenario and it needs no new code: those cases are already in this file.

- [x] **Step 5: Give `flutter` the same one-line reason `apex` has**

**Added 2026-08-30 by this task's code-quality review.** The comment above the changed line explains
why `apex` needs a non-web entry and reads as though it is the only such member. `flutter` is a
second one with the identical property, and its reason lives only in a test comment, so a reader
arriving at this line from the `lib/` side gets no explanation for it. This file's convention is a
why-comment beside every such decision. Replace the two comment lines above the `case` with:

```bash
# apex and flutter are both user interfaces that are not local web ones: an APEX application's
# pages live in the database, and a Flutter application's are `lib/main.dart`. Either can be a
# genuine UI with no public/ or index.html for the fallback below to find.
```

- [x] **Step 6: Run it and watch it still pass**

Run: `tests/test-keel.sh`
Expected: `367 passed, 0 failed`, unchanged. This is a comment, so any movement means something else
was touched.

- [x] **Step 7: Hand over**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

**Executed 2026-08-30, delegated, model `inherit`. Both review briefs were run by one agent for a
one-word change, stated rather than quietly merged: the split exists because a single reviewer drifts
to style and skips whether the right thing was built, so both question sets were given explicitly and
answered separately. COMPLIES, no blockers.**

**Witnessed:** step 2 `366 passed, 1 failed`, the single predicted failure; steps 4 and 6 both
`367 passed, 0 failed`. The implementer confirmed rather than assumed S-07's third scenario, by
grepping the run for every pre-existing `has_ui` case, including the NestJS-false one.

**The one behaviour in this whole change that was wrong rather than absent is now right.** One word.

**The known limit was verified in both directions rather than trusted.** The review built a pubspec
whose only Flutter reference is `flutter_test:` under `dev_dependencies` and measured
`dart dart flutter pub` with `has_ui: true`, and confirmed `flutter_lints` alone still does not
trigger it. The limit as recorded is accurate, and **it was also understated**: on such a package
`detect_verify` returns `flutter test` and `flutter analyze` too, so the cost is a package told to
drive its tests through the Flutter SDK, not just a wrong boolean. Recorded above, and task 10
carries it to the PRD.

**The one-word addition is unreachable outside Dart, checked rather than assumed.** All fourteen
`lang_profile` arms draw field 3 from closed literal sets, and a `package.json` depending on a
package literally named `flutter` yields `javascript node none npm`.

**Left alone, correctly:** a Dart package with a `public/` directory gets `has_ui: true` through the
generic fallback. Pre-existing, identical for Go, Rust and Python, and chasing it here would be the
scope-widening this task forbids.

**One correction after review:** the comment above the framework list explained `apex` and read as
though it were the only non-web member. It now names both.

**shellcheck did not run and no box is ticked for it.**

---

### Task 7: Read `pubspec.yaml` for datastore dependencies

**Story:** S-08
**Files:**
- Modify: `lib/detect-stack.sh`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Produces: `sqlite` in `detect_datastores`' output for a Dart project declaring `sqflite`.

**Depends on:** task 3

**Done when:** `tests/test-keel.sh` passes. **Full-suite checkpoint: run `tests/run-tests.sh` in the
background after this task.**

**This is the only task that edits a function shared by every language**, which is why the checkpoint
is here and why task 9 exists.

- [x] **Step 1: Write the failing test**

Add to the `---- datastores ----` block that begins at `tests/test-keel.sh:955`, using the
`stores_of` helper defined there rather than a fresh inline reader:

```bash
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
{ [ -f "$d/.keel/profile.json" ] && [ -z "$got" ]; } \
  && ok "a Dart package with no store dependency names no datastore" \
  || bad "datastores" "got '$got', want nothing, from a profile that exists"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, one new failure: `FAIL  datastores: got '', want sqlite`.

- [x] **Step 3: Write the minimal implementation**

Two edits in `detect_datastores`. Add `pubspec.yaml` to the manifest list. It goes at the end of the
**second** line of the `for f in` continuation, `lib/detect-stack.sh:729`, and that line is therefore
one of the two the diff touches:

```bash
    for f in package.json requirements.txt pyproject.toml Pipfile go.mod composer.json Gemfile \
             Cargo.toml pom.xml build.gradle build.gradle.kts pubspec.yaml \
             docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
```

Extend the `sqlite` pair at `:745`, and nothing else in that list:

```bash
                'sqlite:sqlite|sqflite' \
```

**`sqflite` is a separate alternative and not a typo.** It does not contain the substring `sqlite`:
the letters are `s q f l i t e`. The existing pair could never have matched it.

**Why this cannot change a mono-language project's result, `NFR-02`:** the loop adds a filename to
`files` only when `[ -f "$f" ]` holds, and `pubspec.yaml` is exclusive to Dart among the fourteen. The
new alternative is a Dart package name and appears in no other ecosystem's manifest. Task 9 is what
holds that rather than the argument.

**The polyglot root is the exception, and it is correct rather than a regression.** Measured by this
task's review: a Node repository with both `package.json` and a `pubspec.yaml` declaring `sqflite`
moves from `''` to `sqlite`. That is the right answer, since the repository really does use sqflite,
and `dart-polyglot` proves that shape is in the design space. An earlier wording here claimed "a
repository that is not a Dart project has no `pubspec.yaml`", which is false of exactly that shape.
`A4` in the PRD already records it honestly as untested rather than proven, and task 10 aligns
`NFR-02`'s wording with this.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, two more passes, and **every existing datastore case still passing**, including the
`psycopg` case and the `ts-migrations` case.

Then the full-suite checkpoint, in the background, as in task 4.

- [x] **Step 5: Guard the absence assertion against a crashed init**

**Added 2026-08-30 by this task's review, which measured it.** `stores_of` swallows every error with
`2>/dev/null` and returns the empty string when `.keel/profile.json` is missing or malformed, so the
`dart-pure` case as written passes when `keel init` fell over and wrote no profile at all. That is
why it passed on arrival at step 2. Apply the guard shown in step 1 above: bind `got` once, and
require `[ -f "$d/.keel/profile.json" ]` alongside `[ -z "$got" ]`.

The same pattern is task 9's primary regression guard across four fixtures, and it has been corrected
there too, before that task runs.

- [x] **Step 6: Run it and watch it still pass**

Run: `tests/test-keel.sh`
Expected: `369 passed, 0 failed`, unchanged. This tightens one assertion and adds none.

**Prove the guard bites.** Temporarily make the case delete `$d/.keel/profile.json` after the init,
re-run, and confirm it now reports `FAIL  datastores: got '', want nothing, from a profile that
exists` where the old form passed. Undo it.

- [x] **Step 7: Hand over**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

**Executed 2026-08-30, delegated, model `inherit`. Both briefs reviewed, COMPLIES, no blockers.**

**Witnessed:** step 2 `368 passed, 1 failed`, `FAIL  datastores: got '', want sqlite`; steps 4 and 6
both `369 passed, 0 failed`. The 368 rather than 367 is explained and correct: the `dart-pure` case
asserts an absence and passed on arrival.

**The red state was reproduced by the review rather than taken on report.** The coordinator did not
witness it, because this task's implementer stopped mid-checkpoint and reported only after the fact.
The reviewer reverted the two source lines on a scratch copy, left the tests intact, and got the same
count and the same message.

**The full-suite checkpoint was verified twice, once by the reviewer and once by the coordinator
reading the log directly:** exit 0, 13 files, zero FAIL lines anywhere, lint `SKIP`. The three
pre-existing datastore cases pass, including the `psycopg` and `ts-migrations` guards this task most
risked.

**The blast radius was tested, not argued.** A mono-language non-Dart project is provably unaffected:
`pubspec.yaml` enters the file list only under `[ -f ]` and is exclusive to Dart among the fourteen.
A realistic 30-package Flutter pubspec produced exactly `sqlite` and no spurious match. Other pairs
now firing on Dart is the intended consequence: a pubspec declaring `postgres`, `redis` and
`mongo_dart` correctly yields all three.

**One correction after review, and it reached forward.** The `dart-pure` absence assertion passed
when `keel init` crashed, because `stores_of` silences its own errors and returns empty. Guarded on
the profile existing, and proved to bite: deleting the profile now gives
`FAIL  datastores: got '', want nothing, from a profile that exists` where the old form passed.
**The identical pattern was task 9's primary regression guard across four fixtures, and was corrected
there before task 9 ran.**

**One false claim in this plan was corrected.** The `NFR-02` rationale said a repository that is not
a Dart project has no `pubspec.yaml`. A polyglot root does, measured: a Node repository with both
manifests and `sqflite` declared moves from `''` to `sqlite`, which is the right answer. Task 10
aligns the requirement's wording.

**Three findings recorded as follow-ups rather than built**, in the table at the end of this plan:
the `mongodb` pair matching a bare `mongo` and so catching `mongol`, `dart format` descending into
`build/`, and the datastore list under-reporting `drift`, `hive` and `supabase_flutter`.

**shellcheck did not run and no box is ticked for it.**

---

### Task 8: Prove a Dart project is recommended no language server

**Story:** S-09
**Files:**
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `detect_plugins` and `lang_lsp`, both unchanged.
- Produces: nothing. This task adds no branch.

**Depends on:** task 3

**Done when:** `tests/test-keel.sh` passes.

**A `verify` story, so this writes a test for behaviour believed correct and adds no code.** If the
test fails, stop and report: this becomes a `fix` and the plan is wrong, not the code.

- [x] **Step 1: Write the test**

Append to the `---- dart ----` block:

```bash
# CON-03: there is no Dart language server in claude-plugins-official. Checked 2026-08-29 against
# the catalogue: twelve language server ids, the same twelve lang_lsp maps, none for Dart. An id
# that does not resolve fails in settings.json, which lang_lsp's own comment calls worse than
# suggesting nothing. FR-18.
d="$(fixture dart-flutter)"
got="$(detect_in "$d" 'detect_plugins | tr "\n" " "')"
case "$got" in
  *dart*) bad "dart" "a Dart project was recommended a plugin: '$got'" ;;
  *)      ok "a Dart project is recommended no language server" ;;
esac

# S-09 scenario 2: what detect_plugins feeds. The settings file is what a user actually gets, and an
# unresolvable id fails there rather than in the function.
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
if grep -qi dart "$d/.claude/settings.json" 2>/dev/null; then
    bad "dart" "settings.json names a dart plugin"
else
    ok "keel init writes no dart language server into settings.json"
fi
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, two more passes.

**Prove the assertion can fail** before accepting it: temporarily add `dart) printf 'dart-lsp' ;;` to
`lang_lsp`, re-run, confirm both cases report `bad`, then remove it.

- [x] **Step 3: Make both assertions fail loudly when their subject produces nothing**

**Added 2026-08-30 by this task's review.** Both are absence assertions sitting behind error
suppression, which is the third instance of this class in this plan. `detect_in` ends `2>/dev/null`,
so an errored `detect_plugins` yields `""` and `case "" in *dart*)` takes the `ok` branch. Worse,
the second case was measured: **if `keel init` fails to run at all, `grep` on the missing
`settings.json` exits non-zero and the test reports PASS.** Every neighbouring plugin test asserts
positive membership and so fails loudly on an empty result; these two do not.

Also tighten what the first one measures. It tests "no plugin id containing `dart`", while its
message claims "no language server". Every id in the catalogue ends `-lsp`, so matching that reads as
the message does. The falsifiability proof used `dart-lsp`, which contains both, so it could not tell
the two readings apart.

Replace the block added in step 1 with:

```bash
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
```

- [x] **Step 4: Run it and watch it still pass, and prove both guards bite**

Run: `tests/test-keel.sh`
Expected: `371 passed, 0 failed`, unchanged. This tightens two assertions and adds none.

Three proofs, because the two guards and the original regression are three different failures:
1. Re-add `dart) printf 'dart-lsp' ;;` to `lang_lsp`, confirm both cases still report `bad`, remove it.
2. Temporarily `rm -f "$d/.claude/settings.json"` after the init, confirm
   `FAIL  dart: keel init wrote no settings.json, so this case proves nothing`, undo.
3. Temporarily make the first probe return empty, confirm
   `FAIL  dart: detect_plugins produced nothing, so this case proves nothing`, undo.

- [x] **Step 5: Hand over**

```bash
git add tests/test-keel.sh
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.**

**Executed 2026-08-30, delegated, model `inherit`. Both briefs reviewed, COMPLIES, no blockers.**

**A `verify` story, and it verified: the test passed on arrival and no production code was added.**
`369` before, `371 passed, 0 failed` after, exactly two new passes. The review confirmed
`lib/detect-stack.sh` is byte-identical to `HEAD` four separate ways rather than trusting the
implementer's md5, because this task's proof required temporarily editing that file.

**The proof showed the two cases are genuinely independent.** Injecting `dart-lsp` into `lang_lsp`
failed both: the id propagated all the way through `keel init` into `.claude/settings.json`, so the
end-to-end case is doing real work rather than echoing the function-level one.

**Two corrections after review, both about assertions that could pass on nothing.** This is the third
instance of that class in this plan, after task 7's and task 4's.
- Measured: **when `keel init` never ran, `grep` on the missing settings file exited non-zero and the
  test reported PASS.** Both cases are now guarded on their subject having produced something.
- The first case tested "no id containing `dart`" while claiming "no language server". It matches
  `*-lsp*` now, which is what every catalogue id ends with and what the message says.

**Three separate proofs, because three different failures were involved:** re-injecting `dart-lsp`
still fails both cases, so tightening did not weaken the original guard; deleting the settings file
gives `FAIL  dart: keel init wrote no settings.json, so this case proves nothing`; forcing the first
probe empty gives its equivalent. All three undone, suite back to `371 passed, 0 failed`.

**The proof output is what found the defect task 9 now fixes.** It read
`'dart-lsp frontend-design playwright '`, which is how a browser test tool being recommended to a
mobile application came to light. A falsifiability check earning its keep twice.

**shellcheck did not run and no box is ticked for it.**

---

### Task 9: Stop recommending a browser test tool to a Flutter application

**Story:** none. This closes a defect **this plan introduced**, found by task 8's review, and decided
by Bernard on 2026-08-30 rather than deferred.

**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `docs/03-install-and-distribution.md`
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: the framework emitted by `lang_profile dart`, task 4.
- Produces: nothing new.

**Depends on:** task 6

**Done when:** `tests/test-keel.sh` passes with three more passes than before, and
`tests/test-doc-claims.sh` prints `5 passed, 0 failed`.

**What is wrong, measured.** Task 6 set `has_ui: true` for Flutter, and `detect_plugins` recommends
`frontend-design` and `playwright` on exactly that signal. Before task 6 a Flutter fixture produced
`[]`; it now produces both, and `keel init` writes them into `.claude/settings.json` **and** into
`.keel/profile.json`'s `plugins.recommended`, which `doctor` then reads, so a Flutter project that
does not install Playwright is nagged for it.

**Playwright drives browsers.** It has no driver for an Android or iOS application binary, and a
Flutter app's UI is painted by the Flutter engine rather than emitted as DOM. Flutter's own
end-to-end story is the SDK's `integration_test` package, run with `flutter test integration_test/`.
keel already asserts `verify.e2e` is `null` for Dart, so without this it says there is no e2e command
and recommends a browser e2e tool in the same run.

**keel's own strategy document already says the right thing**, and the code disagrees with it:
`docs/04-plugin-strategy.md:18` scopes `playwright` to "Only where there are **browser flows** worth
testing". `has_ui` is a different predicate. `apex` satisfies both, because APEX pages really are
browser-rendered; Flutter is the first UI to reach that line that is not a browser at all. **This
fixes the code to match the documented rule rather than inventing a new one.**

**`frontend-design` stays.** `docs/04-plugin-strategy.md:17` scopes it to "Only where there is a UI",
with no browser qualifier, and Flutter is a UI toolkit. Only the browser-specific recommendation is
wrong.

- [x] **Step 1: Write the failing test**

Add to the `---- dart ----` block:

```bash
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
rm -rf "$d"

# The other side of the same rule: a browser-rendered UI still gets playwright. apex is the case
# that most resembles Flutter and must keep it, because APEX pages really are browser-rendered.
d="$(fixture apex-export)"
got="$(detect_in "$d" 'detect_plugins | tr "\n" " "')"
case "$got" in
  *playwright*) ok "a browser-rendered UI still gets playwright" ;;
  *)            bad "dart" "apex lost playwright: '$got'" ;;
esac
rm -rf "$d"
```

**If no `apex-export` fixture exists under that name**, find the fixture the existing
`an APEX export has has_ui true` case uses and use that one. Do not create a new fixture: this task
adds no fixture.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL, **one** new failure,
`FAIL  dart: a Flutter project was recommended playwright: 'frontend-design playwright '`. The other
two cases pass beforehand: `frontend-design` is already emitted, and `apex` already keeps
`playwright`. Both are regression guards for this change, not evidence it works, and step 4 proves
they can fail.

- [x] **Step 3: Write the minimal implementation**

In `detect_plugins`, replace the single `if` line with:

```bash
    if [ "$(detect_has_ui)" = true ]; then
        printf 'frontend-design\n'
        # playwright drives browsers. A Flutter application's UI is painted by the engine on a
        # device, so there is no page for it to open, and its end-to-end story is the SDK's
        # integration_test package. docs/04-plugin-strategy.md scopes this plugin to "browser flows
        # worth testing", which apex satisfies and flutter does not; has_ui alone was answering a
        # different question. Added 2026-08-30, after keel init on a Flutter repository was measured
        # writing playwright into settings.json and plugins.recommended.
        case "$fw" in flutter) ;; *) printf 'playwright\n' ;; esac
    fi
```

**Bind `fw` once at the top of the function** rather than calling `detect_stack` a second time:
`detect_has_ui` already makes that call, and the cache note at `lib/detect-stack.sh:82-88` records
that the tree cache cannot be filled from inside a `$( )`, which `detect_plugins` runs inside. Add
`local fw` to the existing `local` line and set it from `detect_stack | cut -d' ' -f3` before the
`if`, so the function makes one extra call rather than one per branch.

- [x] **Step 4: Run it and watch it pass, and prove the guards bite**

Run: `tests/test-keel.sh`
Expected: PASS, three more passes than before.

Then prove the two beforehand-passing cases can fail: temporarily drop the `printf 'frontend-design'`
line and confirm the second case reports `bad`; temporarily change the `case` arm to `apex)` and
confirm the apex case reports `bad`. Undo both.

- [x] **Step 5: Correct the detection matrix, which this makes wrong**

`docs/03-install-and-distribution.md` states the rule as "has a UI, so recommend `frontend-design`
and `playwright`". That is now false for Flutter. Change that row to read:

```markdown
| any of `next.config`, `vite.config`, `angular.json`, a `public/` dir | has a UI, so recommend `frontend-design`, and `playwright` where that UI is browser-rendered. A Flutter application gets `frontend-design` only: `playwright` drives browsers and Flutter's own end-to-end tool is the SDK's `integration_test` |
```

- [x] **Step 6: Close four findings from this task's review, one of which is this plan's error**

**Added 2026-08-30.** The binding instruction in step 3 was wrong, and its comment states a false
reason. The review measured both.

**(a) Move the `fw` binding inside the `if`, and correct its comment.** Step 3 said to bind it at the
top "because a second call inside the `if` would be a second tree walk". **That is backwards.** `fw`
has exactly one use site, inside that one `if`, so there is no branch to multiply: binding it there
costs the same single extra `detect_stack` call when `has_ui` is true, and nothing at all when it is
false. Measured cost of the eager form: **+56 ms per `detect_plugins` call on a 1,100-file tree with
no UI, +42%**, and `expected_plugins` calls it twice per `init`. Every backend repository pays that
for a value it never reads. Move the binding to the first line inside the `if`, keep `fw` on the
`local` line, and replace the comment with:

```bash
        # Bound here rather than at the top: this is its only use site, so a repository with no UI
        # never pays for it. detect_has_ui has already called detect_stack by this point, and the
        # cache note above records that the tree cache cannot be filled from inside a $( ), which is
        # where this function runs, so this is one more walk on the init path either way.
```

**(b) Write the empty arm as `flutter) : ;;`.** Same semantics, and the explicit no-op reads as
deliberate rather than as a dropped line.

**(c) Pin the fix where the defect actually lived.** All three new assertions read `detect_plugins`,
but the defect was in `.claude/settings.json` and `plugins.recommended`. A refactor of
`expected_plugins` could reintroduce it with all three green. Add, after the existing Flutter case:

```bash
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
```

Move the existing `rm -rf "$d"` to after this block.

**(d) Do not repeat the handover's mistake about Break A.** The report said a downstream plugin-set
case also failed. It did not: all three failures were in this block, because `lang_lsp` has no `dart`
arm, so `frontend-design` is the whole of `detect_plugins`' output for a Flutter fixture and deleting
it empties the output. There is no coupling outside Dart.

- [x] **Step 7: Run it and watch it still pass**

Run: `tests/test-keel.sh` and `tests/test-doc-claims.sh`
Expected: `375 passed, 0 failed`, one more than before, because (c) adds one assertion. Doc claims
`5 passed, 0 failed`. **Report the doc-claims output**, which the first pass of this task omitted even
though it is half the `Done when`.

**Prove (c) bites:** temporarily change the `case "$fw"` arm back to `apex)`, re-run, and confirm the
new settings assertion reports `FAIL  dart: settings.json recommends playwright to a Flutter
project`. Undo it.

- [x] **Step 8: Hand over**

```bash
git add lib/detect-stack.sh tests/test-keel.sh docs/03-install-and-distribution.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

**Executed 2026-08-30, delegated, model `inherit`. Both briefs reviewed, COMPLIES, nothing blocks.**
**Added mid-run and decided by Bernard rather than deferred**, after task 8's falsifiability proof
printed `'dart-lsp frontend-design playwright '` and exposed it.

**Witnessed:** step 2 `373 passed, 1 failed`, the single predicted failure; step 4 `374 passed, 0
failed`; step 7 `375 passed, 0 failed` after the review added one assertion, plus
`5 passed, 0 failed` on doc claims. The review ran its own baseline from a reverted tree,
`371 passed, 0 failed`, rather than accepting the number it was handed.

**Both regression guards were proved able to fail**, and the review confirmed the apex counter-case
is load-bearing for the right reason: that fixture has no `public/` and no `index.html`, so its only
route to `has_ui: true` is the `apex` arm. It cannot pass incidentally.

**This plan's own instruction was wrong, and the review measured it.** Step 3 said to bind `fw` at
the top of `detect_plugins` because a call inside the `if` "would be a second tree walk". Backwards:
`fw` has one use site, inside that one `if`, so there is no branch to multiply. The eager form cost
**+56 ms per call, +42%, on a 1,100-file tree with no UI**, paid twice per `init` by every backend
repository for a value it never reads. Moved inside the `if`, and the false comment replaced.

**One assertion was added where the defect actually lived.** All three original cases read
`detect_plugins`, but the defect was in `.claude/settings.json` and `plugins.recommended`, so a
refactor of `expected_plugins` could have reintroduced it with all three green. The new case bites
independently, proved by re-breaking the arm.

**A claim in the first handover was wrong and is corrected here.** It reported that a downstream
plugin-set case failed under the `frontend-design` break. None did: all three failures were inside
this block, because `lang_lsp` has no `dart` arm, so `frontend-design` is the whole of
`detect_plugins`' output for a Flutter fixture and deleting it empties the output. **There is no
coupling outside Dart**, confirmed by baseline and staged runs matching everywhere else.

**shellcheck did not run and no box is ticked for it.**

---

### Task 10: Prove no existing stack's profile changed

**Story:** S-10
**Files:**
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: everything tasks 3 to 9 produced.
- Produces: nothing.

**Depends on:** task 9

**Done when:** `tests/test-keel.sh` passes.

**What "unchanged" means here, because "byte-identical" is not achievable and the story said it
was.** A generated profile carries `keel_version` and a `project.name` derived from `mktemp`, so two
runs differ in bytes for reasons that have nothing to do with this change. The property this task
asserts is narrower and is the one the change could actually break: **the `stack` and `verify` blocks
of a repository that is not a Dart project**, against recorded expectations, on the four fixtures
that exercise the two shared functions this plan edited. Task 11 records that refinement in `NFR-02`
so the PRD stops claiming more than is testable.

- [x] **Step 1: Write the test**

**Append at the END of the `---- datastores ----` block**, after its last `rm -rf "$d"` and before
the `# ---- profile ----` header. **Not** to the `---- dart ----` block, which is where an earlier
version of this step said, and which is unbuildable.

**Why, measured by this task's first implementer, which stopped rather than improvising.**
`tests/test-keel.sh` is a linear bash script. `prof_of` is defined at line 213 and the `---- dart ----`
block starts at 247, so the profile half would work there. **`stores_of` is defined at line 1260**,
786 lines after the dart block ends. Under `set -uo pipefail` with no `-e`, calling an undefined
function exits 127 with empty stdout, so `$stores` would be empty for a reason that has nothing to do
with the profile, the guard would see a profile that exists and an empty string, and **all four
datastore assertions would pass unconditionally.** Demonstrated standalone against a profile
declaring `postgres`: `FALSE PASS: guard said 'empty datastore list' though the profile declares
postgres`.

That would have made the primary regression guard for this whole change structurally incapable of
failing, which is what the block's own comment says it cannot afford to be. Placing it at the end of
the datastores block puts both helpers in scope and needs no other change.

The two rejected alternatives, recorded so they are not re-proposed: splitting the block so the
purity loop lives with the dart cases buys nothing and separates one coherent guard; hoisting
`stores_of`'s definition edits existing test infrastructure, which a `verify` story that adds only
assertions should not do.

The block to append:

```bash
# NFR-01. lib/detect-stack.sh uses no sed, sort, uniq or tr, and its own comment says a change must
# not be the one that introduces them. The same property assertion tests/test-apex-export.sh makes
# about lib/apex_render.py, for the same reason: a property nobody checks is one that drifts.
for cmd in sed sort uniq tr; do
    # Full-line comments are stripped before the search. Without that this check fails on
    # unmodified code: the comment at lib/detect-stack.sh:102-104 names all four commands in prose,
    # so a whole-file grep matches the very sentence that forbids them. Verified against the
    # unmodified file before this was written into the plan.
    if grep -v '^[[:space:]]*#' "$ROOT/lib/detect-stack.sh" | grep -qE "(^|[^-_a-zA-Z])$cmd "; then
        bad "detect-stack purity" "lib/detect-stack.sh now invokes $cmd"
    else
        ok "lib/detect-stack.sh still invokes no $cmd"
    fi
done

# NFR-02, in the form stated at the head of this task. Four fixtures, chosen because each reaches at
# least one of the two shared functions this plan edited: detect_has_ui and detect_datastores.
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
    { [ -f "$d/.keel/profile.json" ] && [ -z "$stores" ]; } \
      && ok "$f keeps an empty datastore list" \
      || bad "regression" "$f datastores got '$stores', from a profile that exists"
    rm -rf "$d"
done
```

- [x] **Step 2: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS, **twelve** more passes, `387 passed, 0 failed` against the 375 baseline. Four purity
cases, four stack cases, four datastore cases.

If the purity check fires, the offending command was introduced by an earlier task in this plan and
must come out. It is not a reason to relax the check. If a fixture's expected string is wrong, record
what it actually produced and fix the expectation rather than the code: these are recorded
observations of today's behaviour, not requirements.

- [x] **Step 3: Close four findings, three of them false statements in this block's own comments**

**Added 2026-08-30 by this task's review, which proved every one of the twelve assertions can fail by
mutating the code under them.** The guard works. What is wrong is what it says about itself.

**(a) The missing-profile branch prints a message asserting the opposite of what happened.** Both
failure directions share one `bad` string, so when the profile is absent it prints
`got '', from a profile that exists`. The block spends five lines explaining that telling those two
cases apart is the point, and the diagnostic then collapses them, pointing a reader at the datastore
logic when the fault is a crashed `keel init`. Replace the datastore assertion with:

```bash
    if [ ! -f "$d/.keel/profile.json" ]; then
        bad "regression" "$f wrote no .keel/profile.json; keel init failed"
    elif [ -n "$stores" ]; then
        bad "regression" "$f datastores got '$stores', want nothing"
    else
        ok "$f keeps an empty datastore list"
    fi
```

**Apply the same split to the `dart-pure` case in the `---- datastores ----` block above**, which
task 7 wrote with the identical wording. It is the same copied defect and it should not be fixed in
one place only.

**(b) "the two shared functions this plan edited" is false. Four were edited:** `detect_languages`
(the marker, evaluated on every repository), `detect_datastores` (the manifest list and the `sqlite`
pair), `detect_has_ui` (the framework list) and `detect_plugins` (the `fw` binding and the
`playwright` arm). `is_plsql_tree` changed by a comment only. This matters because that sentence is
the stated basis for choosing the four fixtures. Name all four.

**(c) The fixture-selection reason does not discriminate, and the real one is better.** Every fixture
in the suite reaches `detect_has_ui`, so "reaches one of the shared functions" selects nothing. What
actually bites is `detect_datastores`' manifest gate: these four contribute `package.json`,
`pyproject.toml`, `go.mod` and `Gemfile`, so all four reach the eight-pair grep loop, whereas
`csharp`, `swift`, `cpp` and `lua` hit `[ -z "$files" ] && return 0` and would prove nothing. Say
that instead. Add the honest limit with it: **all four expect `has_ui false`, so this block never
reaches `detect_plugins`' edited branch**, which is gated on `has_ui` being true. That branch is
covered by the apex case in the `---- dart ----` block, not here.

**(d) The comment-stripping rationale overstates its own measurement.** It says the file's comment
"names all four commands in prose, so a whole-file grep matches the very sentence that forbids them".
Measured: only `tr` matches, because the prose reads "neither sed, sort, uniq" with commas and the
regex needs a trailing space. The stripping is still load-bearing, for that one command. Say "names
all four in prose, and the `nor tr` clause matches, so a whole-file grep fails on unmodified code."

**Also tighten the purity regex while you are in it.** It requires a trailing space, so a command at
the end of a line inside a broken pipeline escapes it: a scratch mutation with `sort |` on one line
and `uniq` on the next caught `sort` and missed `uniq`. Use `([[:space:]]|$)` in place of the literal
trailing space.

- [x] **Step 4: Run it and watch it still pass, and prove the split message**

Run: `tests/test-keel.sh`
Expected: `387 passed, 0 failed`, unchanged. These are comments, a message split and a regex widening;
none adds or removes an assertion.

**Prove the new missing-profile message appears.** Temporarily `rm -f "$d/.keel/profile.json"` after
one fixture's init, re-run, and confirm it reports `wrote no .keel/profile.json; keel init failed`
rather than the old "from a profile that exists". Undo it.

**Prove the widened regex catches what the old one missed.** Temporarily add a two-line pipeline to a
scratch copy of `lib/detect-stack.sh` with `uniq` at the end of a line, confirm the purity check now
fails on it, and undo. If you cannot arrange that safely, say so and leave the box unticked.

- [x] **Step 5: Hand over**

```bash
git add tests/test-keel.sh
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.**

**Executed 2026-08-30, delegated, model `inherit`. Both briefs reviewed, COMPLIES, nothing blocks.**

**The first attempt stopped without editing anything, and was right to.** This plan told it to append
the block to the `---- dart ----` block, where `stores_of` is not defined for another 786 lines. Under
`set -uo pipefail` with no `-e`, an undefined function exits 127 with empty stdout, so all four
datastore assertions would have seen a profile that exists and an empty string and **passed
unconditionally**. It proved that standalone rather than inferring it:
`FALSE PASS: guard said 'empty datastore list' though the profile declares postgres`. **The primary
regression guard for this entire change was one placement away from being incapable of failing.**

**Witnessed after the correction:** `387 passed, 0 failed`, twelve more than the 375 baseline, four
purity, four stack, four datastore, each listed.

**Every one of the twelve was proved able to fail, by mutation rather than by argument.** The review
introduced a real `sed`, `sort`, `uniq` and `tr` in turn and watched each purity case fail; broke the
`go` detector and the `has_ui` whitelist and watched the stack cases fail with useful messages; made a
fixture declare `postgres` and watched the datastore case fail; and deleted the profile and watched
the guard fire rather than pass.

**The guard works. Everything it said about itself was wrong, and that is what was fixed.**
- Its failure message printed "from a profile that exists" on the path where the profile does not
  exist, collapsing the two cases the block spends five lines distinguishing. Split, in both places:
  task 7's `dart-pure` case carried the same copied wording.
- It named "the two shared functions this plan edited" when **four** were: `detect_languages`,
  `detect_datastores`, `detect_has_ui`, `detect_plugins`.
- Its fixture-selection reason selected nothing, since every fixture reaches `detect_has_ui`. The
  real criterion is `detect_datastores`' manifest gate, and the honest limit is now stated: all four
  expect `has_ui false`, so this block never reaches `detect_plugins`' edited branch.
- Its comment-stripping rationale claimed all four commands match the file's own prose. Only `tr`
  does, because the sentence reads "neither sed, sort, uniq" with commas.

**The purity regex missed a real invocation, found by mutation.** A two-line pipeline with `sort |`
on one line and `uniq` on the next caught `sort` and missed `uniq`, because the pattern required a
trailing space. Widened to `([[:space:]]|$)` and both are caught.

**`NFR-02`'s replacement wording was corrected before it was written.** Task 11 was going to record
"the `stack` and `verify` blocks", which is still wider than the guard: `stack` has seven keys and
`verify` ten, and this block reads three and none. It now names the three and says why the rest is
protected by construction.

**shellcheck did not run and no box is ticked for it.**

---

### Task 11: Update the documents this change makes wrong

**Story:** none directly. `CLAUDE.md` makes documentation part of the gate: a change lands with the
documents it makes wrong, each stating what is true now.
**Files:**
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/prd/dart-flutter-stack-detection.md`
- Modify: `docs/ideas/dart-flutter-stack-detection.md`

**Interfaces:**
- Consumes: the measured outcomes of tasks 3 to 10.

**Depends on:** task 10

**Done when:** `tests/test-doc-claims.sh` prints `5 passed, 0 failed`, `tests/no-internal-leaks.sh`
prints `OK    no project-specific identifiers`, and `tests/run-tests.sh` is green in full. **Final
full-suite checkpoint.**

- [x] **Step 1: Add the Dart row to the detection matrix**

`docs/03-install-and-distribution.md:210-227` is a `Signal | Inferred` table with one row per
detected language. It enumerates all fourteen, so this change makes it wrong. The PL/SQL work amended
the same table. Insert after the `.luarc.json` row and before the PL/SQL row:

```markdown
| `pubspec.yaml` | Dart, `flutter test` or `dart test`, the analyzer and `dart format`, and no language server, because none exists for it. `flutter` as the framework where the manifest declares the Flutter SDK, which also sets `has_ui` |
```

- [x] **Step 2: Add the CHANGELOG entry**

Under a new `## Unreleased` heading above `## 0.16.1 - 2026-08-20`. Write what was measured, not what
was intended:

```markdown
## Unreleased

- **Dart is the fifteenth detected language and the fourteenth read from a declared manifest.** A
  `pubspec.yaml` at the root sets `stack.language` to `dart`, `stack.framework` to `flutter` where
  the Flutter SDK dependency is declared, and fills `test`, `test_one`, `lint`, `format` and
  `format_fix` from the SDK toolchain. `build`, `typecheck`, `e2e`, `security` and
  `test_integration` stay `null`: `flutter build` lists eight targets and choosing one is the guess
  the never-guesses doctrine forbids. **This reverses the 2026-08-14 deferral**, which excluded Dart
  for having no plugin language server. That half still holds and there is still no `dart` arm in
  `lang_lsp`; the other half, that such a language "would get a test command and nothing else", was
  false and is what changed.

- **`has_ui` was wrong rather than empty on every Flutter project**, because `detect_has_ui` keys on
  a framework list and then falls back to `public/` or `index.html`, and a Flutter application has
  neither. Fixed by one word in that list. It is the only field in this change that was corrected
  rather than added.

- `detect_datastores` reads `pubspec.yaml`, and its `sqlite` pair matches `sqflite`, which it never
  could before: `sqflite` does not contain the substring `sqlite`. Measured at 13 of 15 in the
  fleet the requirement was written against.

- The Flutter marker is the `sdk: flutter` line and not the word `flutter`, because `flutter_lints`
  is an ordinary dev dependency. Matched 15 of 15 real Flutter applications on 2026-08-29.

- **A Flutter project is no longer recommended `playwright`, and this release is what would
  otherwise have started recommending it.** Setting `has_ui` true reached `detect_plugins`, which
  keyed both frontend recommendations on that one signal, so `keel init` was measured writing a
  browser test tool into `.claude/settings.json` and into `plugins.recommended`, where `doctor` then
  nags for it. Playwright drives browsers and has no driver for an Android or iOS binary; Flutter's
  end-to-end tool is the SDK's `integration_test`. `docs/04-plugin-strategy.md` already scoped that
  plugin to "browser flows worth testing" and the code keyed on a different predicate, so this is
  the code catching up with the written rule rather than a new one. `frontend-design` is unaffected:
  its rule says "only where there is a UI", with no browser qualifier. `apex` keeps `playwright`,
  because APEX pages really are browser-rendered, and a test now pins both sides.
```

- [x] **Step 3: Correct `NFR-02` and close the upstream documents**

**Amend `FR-08` first.** It reads "`verify.test` must be `flutter test` for a Flutter project and
`dart test` for a pure Dart one". Task 2's review measured that `dart test` exits non-zero with
"Could not find package `test`" unless the pubspec declares it. Add to the requirement: "and `null`
for a plain package that does not declare `package:test`", and to its Evidence column: **"Amended
2026-08-29 by Bernard, asked as a choice, after task 2's review measured the precondition. Flutter
bundles `flutter_test` and needs no gate; the Dart SDK ships the `dart test` command but not the
package. An ungated `dart test` would be the guessed command `CON-02` forbids."** Amend `FR-09` the
same way, since `test_one` is gated with it.

`NFR-02` says a non-Dart profile must be "byte-identical". It cannot be: `keel_version` and
`project.name` vary between runs. **Do not replace it with "the `stack` and `verify` blocks" either.**
Task 10's review measured that too: `stack` has seven keys and `verify` has ten, and the guard reads
three of the seven and none of the ten. Writing the wider phrase would move the overclaim down a
level rather than remove it. The requirement must name what is actually asserted, and say why the
rest needs no assertion: Replace its requirement text with "`stack.language`,
`stack.has_ui` and `stack.datastores` must be unchanged for a repository that is not a Dart project",
and add to its Evidence column: **"Narrowed twice, 2026-08-29 and 2026-08-30, both times because the
wording claimed more than was asserted. 'Byte-identical' was untestable, since `keel_version` and a
`mktemp`-derived `project.name` vary per run. 'The stack and verify blocks' was still wider than the
guard, which reads three of `stack`'s seven keys and none of `verify`'s ten. The three named are
exactly the fields the shared, non-arm edits can reach: `detect_languages`, `detect_datastores`,
`detect_has_ui` and `detect_plugins`. The rest are protected by construction, because `lang_profile`
and `detect_verify` gained new `case` arms that no other language can enter, and the existing
`---- detection ----` cases already pin those tuples for all ten stacks."**

Then strike through `Q2` in the PRD with the position task 1 chose. Leave `Q3` and `Q4` open, each
with one line saying why: `Q3` has no instance forcing it, `Q4` is answered as `A3` and is kept for
anyone who disagrees.

**Also correct `FR-19`'s Evidence cell, which task 1's review found overreaching.** It ends "which is
the shape the existing polyglot row already describes", and no row in the PRD describes it. The row
is real but lives in the detection matrix this task edits in step 1. Replace that clause with:

```
which is the shape the polyglot row of the detection matrix in `docs/03-install-and-distribution.md` already describes
```

The wording came from this plan, so task 1's implementer was right to copy it verbatim rather than
improve it. Fixing it here rather than by hand is what keeps every edit in this run reviewed.

In `docs/ideas/dart-flutter-stack-detection.md`, set `Status` to `agreed, built 2026-08-29`, which is
the form `docs/ideas/profile-schema-drift.md` uses, and name this plan in the `Next` row.

- [x] **Step 4: Run the checks and watch them pass**

Run: `tests/test-doc-claims.sh && tests/no-internal-leaks.sh && tests/validate-skills.sh`
Expected: `5 passed, 0 failed`, `OK    no project-specific identifiers`, `OK    24 skills validated`
with **five** warnings.

Then the final full suite in the background. Expect `SKIP` on lint unless shellcheck is installed,
and say which in the report.

- [x] **Step 5: Close five findings, every one of them this plan's own text**

**Added 2026-08-30 by this task's review.** Four of the five are documents claiming more than the code
delivers, which is the exact failure this task exists to close, so they are fixed rather than
recorded. All five were written into the plan before its own later steps corrected the underlying
requirement, and transcribed faithfully.

**(a) The Dart matrix row and CHANGELOG entry 1 state a gated command as unconditional.** Both say
`test` is filled, and the row names "`flutter test` or `dart test`". For a plain package that does not
declare `package:test`, keel emits nothing, which is what `FR-08` says two files away and what
`dart-pure-notest` pins. Every other row in that table names a genuinely unconditional command.
In `docs/03-install-and-distribution.md`, replace the Dart row's command clause so it reads
`Dart, and `flutter test` for a Flutter project or `dart test` for a plain package that declares
`package:test``. In `CHANGELOG.md` entry 1, replace "fills `test`, `test_one`, `lint`, `format` and
`format_fix`" with "fills `lint`, `format` and `format_fix` unconditionally, and `test` and
`test_one` where the project has a runner: `flutter test` is bundled, `dart test` needs
`package:test` declared".

**(b) `NFR-02`'s evidence overstates what a named test block asserts.** It says the existing
`---- detection ----` cases "already pin those tuples for all ten stacks". That block runs
`detect_stack | cut -d" " -f1` and pins the **primary language only**. The tuples are pinned by
`---- framework detection ----` and the verify commands by `---- verify commands ----`. Replace that
clause with: "the existing `---- detection ----` cases pin the primary language for all ten stacks,
`---- framework detection ----` pins the tuples, and `---- verify commands ----` pins the commands".
**This is the amendment written to stop a requirement claiming more than is asserted, so an overclaim
inside it is the worst place for one.**

**(c) `NFR-02` calls its three fields "exactly the fields the shared, non-arm edits can reach" and
then lists `detect_plugins`, whose output field is `plugins.recommended`, not one of the three.** Add
after that list: "`detect_plugins` is the exception and is named for completeness: its edited branch
is gated on `fw` being `flutter`, which only `lang_profile`'s `dart)` arm sets, so no other language
reaches it, and the regression block says so itself."

**(d) "no language server, because none exists for it" is literally false of Dart.** The Dart Analysis
Server exists and drives every Dart IDE. What does not exist is a Dart LSP **plugin** in
`claude-plugins-official`, which is the precision `FR-18`, the idea record and the test all use. In
the Dart matrix row, change that clause to "and no language server plugin, because the catalogue has
none for it". Leave the PL/SQL row alone; it is not this change's.

**(e) The ideas record now contradicts itself.** Its `Next` row says `Q2` was answered by the plan,
while its own open question 2 body still reads "Still open, and now bounded rather than settled".
Strike that question through and close it with the position task 1 recorded, matching how questions
1, 3 and 4 are already struck in that file.

**Recorded, not fixed:** the review also noted that `docs/03`'s `has_ui` row still prescribes an
outcome under a left column that lists neither Flutter nor `apex`. This task's steps do not ask for
that reconciliation and restructuring the table is out of scope, so it stays in the follow-ups table
with the choice now explicit rather than silent.

- [x] **Step 6: Re-run the document checks**

Run: `tests/test-doc-claims.sh && tests/no-internal-leaks.sh && tests/validate-skills.sh`
Expected: `5 passed, 0 failed`, `OK    no project-specific identifiers`, and `OK    24 skills
validated` with **five** warnings. No code changed, so the full suite needs no second run; say that
rather than running it again.

- [x] **Step 7: Hand over**

```bash
git add docs/03-install-and-distribution.md CHANGELOG.md \
        docs/prd/dart-flutter-stack-detection.md docs/ideas/dart-flutter-stack-detection.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

**Executed 2026-08-30, delegated, model `inherit`. Documentation only, one review pass, COMPLIES.**

**The final full-suite checkpoint is green:** 13 test files, `All test files passed`, zero failures,
lint `SKIP`. `test-keel.sh` at 387. Reproduced by the reviewer at 1m50s wall clock.

**The review verified every amended claim against the code rather than reading for shape**, which is
what a task that edits an approved requirements document needs. It confirmed `NFR-02` now names
exactly the three fields the guard asserts, that `lang_profile` and `detect_verify` gained only new
`dart)` arms so no other language can enter them, that the `FR-08` precondition matches
`dart_declares_test`, and that every number in the CHANGELOG holds.

**It then found six inaccuracies, and every one of them was this plan's text, transcribed
faithfully.** Five were fixed, one recorded.
- **The Dart matrix row and the CHANGELOG stated a gated command as unconditional**, contradicting
  the `FR-08` amendment made in the same commit. This plan's step 1 and step 2 text predated its own
  step 3 and were never reconciled.
- **`NFR-02`'s evidence overclaimed what a test block asserts**, saying the `---- detection ----`
  cases pin the tuples when they pin the primary language only. **In the amendment written to stop a
  requirement claiming more than is asserted.**
- `NFR-02` called its three fields exhaustive and then named `detect_plugins`, whose field is not
  among them.
- "no language server, because none exists for it" is **literally false**: the Dart Analysis Server
  exists. What does not is a plugin in the catalogue, the precision `FR-18` and the test both use.
  The phrasing was copied from the PL/SQL row, where it is closer to true.
- The idea record's `Next` row said `Q2` was answered while its own question 2 still read "still
  open". Struck and closed.

**Two seams from applying that correction verbatim were reported rather than silently improved**, and
one was a correctness problem: the CHANGELOG briefly read "`dart test` needs `package:test` declared
**from the SDK toolchain**", which asserts the opposite of the fact the gate rests on. Both fixed.

**Recorded, not fixed:** `docs/03`'s `has_ui` row still prescribes an outcome under a left column
naming neither Flutter nor `apex`. Reconciling it means restructuring a table older than this work.
In the follow-ups, with the choice explicit.

---

## Story coverage

| Story | Kind | Task |
|---|---|---|
| S-11 | decide | 1 |
| S-01 | build | 2 |
| S-02 | build | 3 |
| S-03 | build | 4 |
| S-04 | build | 5 |
| S-05 | build | 5 |
| S-06 | build | 5 |
| S-07 | fix | 6 |
| S-08 | build | 7 |
| S-09 | verify | 8 |
| S-10 | verify | 10 |

Eleven stories, eleven tasks. Task 5 carries three stories because they are one `case` arm. Two
tasks carry none: task 9, which closes a defect this plan introduced and Bernard chose to fix rather
than defer, and task 11, which exists because `CLAUDE.md` makes documentation part of the gate. No
story is uncovered.

## Dependency order

```
1 ──┐
2 ──┴─→ 3 ─┬─→ 4 ─┬─→ 5
           │      └─→ 6 ─→ 9
           ├─→ 7 ──────────┴─→ 10 ─→ 11
           └─→ 8
```

Critical path: 2 → 3 → 6 → 9 → 10 → 11. Tasks 5 and 8 hang off it and hold nothing else up.
**Task 9 was added on 2026-08-30**, after task 8's review measured that this plan had introduced a
wrong plugin recommendation. The old tasks 9 and 10 became 10 and 11.

## Review findings not acted on

Recorded rather than dropped, because the reviewer read the code and may be right.

| Finding | Why not | 
|---|---|
| Merge task 2 into task 3, as the PL/SQL plan merged the tool rows with the detector | **Rejected, and the reviewer confirmed the split is safe:** `tests/validate-skills.sh` checks only that each detected language has a row, not the converse, so task 2 lands green on its own. Kept separate because the rows are prose about tool choice and the detector is code, and a reviewer may reasonably reject one while approving the other. The ordering it costs is one sentence |
| A Dart-only tree gets `project.kind: docs`, because `project_kind`'s extension list has no `dart` | **Reproduced after all, and fixed on 2026-08-30.** This rebuttal answered a different case. It is correct that a repository *with* a `pubspec.yaml` returns `service` at `bin/keel:364` and never reaches the extension fallback, which is what it checked. The `dart-orphan` shape has no manifest, detects as no language by design, and does reach it: measured on a scratch tree of ten `.dart` files, `project.kind = docs`, `stack.language = unknown`. Closed by task 1 of `docs/plans/2026-08-30-dart-followups.md`. **Not a regression**, since nothing detected Dart before this work either |
| `is_flutter` is not memoised, and runs about a dozen times per `init` | **Accepted as written.** It is one `grep` on a file of tens of lines, against `PKG_SCRIPTS` and `DETECTED_LANGS`, which exist because they were each starting an interpreter or walking a tree. Adding a third cache to save a dozen greps is the kind of change this file's own comments argue against. Revisit if `keel init` on a Dart repository is ever measured as slow |
| `pubspec.lock` in the `dart-flutter` fixture is never read | **Removed** from the fixture in this revision |

## Follow-ups raised during execution, deliberately not built here

Each was measured by a review, each is real, and each is out of scope for the requirement that was
approved. Recorded so they are not rediscovered from scratch.

| Finding | Evidence | Why not now |
|---|---|---|
| **The `mongodb` pair false-positives on Dart package names.** Its alternation is a bare `mongo` under `-i`, so `mongol`, a real pub.dev package for Mongolian vertical text, is profiled as MongoDB | Task 7's review, run over a corpus of about 100 real pub.dev names | The looseness is pre-existing and shared by all fourteen languages. Tightening a shared pair is exactly the blast radius task 7 exists to contain, and the file already solved this class once for `"pg"` with a quoting trick and a comment. Worth its own change, with its own regression run |
| **`verify.format` can be red on a clean checkout.** `dart format .` descends into `build/`, which is not hidden, and rewrites generated `*.g.dart` files there | Task 5's review, measured on a scratch copy: one misformatted generated file under `build/` turned the gate red on an otherwise clean tree | Exposure is nil today: none of the 13 local Flutter repositories has any `.dart` file under `build/`, since Flutter puts compiled artifacts there and `build_runner` writes to `lib/` or the hidden `.dart_tool/`. Narrowing to `lib test` would stop checking `bin/` and `tool/`, trading a measured-zero risk for a real gap |
| **The datastore list under-reports for real Flutter apps.** `hive`, `drift`, `isar`, `objectbox`, `sembast`, `cloud_firestore` and `supabase_flutter` all report nothing; `drift` is SQLite and `supabase_flutter` is Postgres | Task 7's review, probed against a realistic 30-package pubspec | `FR-15` names `sqflite` only, so the change is compliant. Widening the pair list is a requirement change, not an implementation detail, and belongs to whoever decides how much of the Dart datastore ecosystem keel should know |
| **The `psycopg` regression guard is a substring match** and would not notice an extra store appearing beside postgres | Task 7's review | Pre-existing, and task 10's exact-match checks partly close it |
| **`has_ui` also routes browser-specific coding standards to Flutter.** `skills/coding-standards/references/house-defaults.md:27` gates `references/frontend.md` on `profile.stack.has_ui`, and that reference is about bundle supply chain, CDN caching, browser history and referrer headers | Task 9's review | **The same root cause task 9 fixed, in a second consumer.** `has_ui` answers "does this have a UI" while three different callers ask three different questions of it. Task 9 patched the plugin caller because that one wrote wrong output into a user's settings file; this one routes prose a reader can ignore. Fixing it properly means deciding whether `has_ui` should be split, which is a design change and not this plan's |
| **The detection matrix listed Java above Kotlin**, while `detect_languages` matches `kotlin` first and says why in its own comment | The review of PR #49 | **Never recorded by this plan's own reviews, and added here for completeness.** Same defect the Dart row had before PR #49, in a pair that predates this work. Closed by task 5 of `docs/plans/2026-08-30-dart-followups.md` |
| **`tests/validate-skills.sh:409` called a hypothetical `nest` "a fourteenth language"** | The review of PR #49 | Also never recorded here. `detect_languages` now yields fifteen. The rule is correct and only its explanation was stale. Closed by task 6 of the same plan |
| **The detection matrix row prescribes an outcome for a condition it does not list.** Its left column names `next.config`, `vite.config`, `angular.json` and `public/`, none of which is a Flutter or an APEX signal | Task 9's and task 11's reviews | Partly pre-existing: `apex` was never in that column either. ~~**Left open deliberately, 2026-08-30.**~~ **Closed after all, by task 5 of `docs/plans/2026-08-30-dart-followups.md`.** Deferring it read as a table restructure; it turned out to be one left column, which now names the APEX manifest and the Flutter framework its right column had grown to talk about |
