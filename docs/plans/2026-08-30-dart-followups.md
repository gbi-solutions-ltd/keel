# Plan: close the Dart and Flutter follow-ups

Written 2026-08-30, after PRs #49 and #50 merged. Twelve items were outstanding: six from the
execution plan's own follow-up table, two from its "review findings not acted on" table, two found
in the review of PR #49 and never recorded, and the PRD's two open questions.

**There are no stories behind this plan, and that is a deviation worth naming.** `write-plan`
normally reads `docs/stories/<slug>.md`. These are measured defects with evidence already attached,
plus four decisions taken on 2026-08-30, so the inputs are the follow-up tables and those decisions
rather than a story set. If anyone wants stories, they should be written before task 3, which is the
only task that changes what keel claims about a project rather than correcting something already
wrong.

## Progress

Updated as each task lands. A tick here means its `Done when:` command was run and its output read.

| Task | | Landed |
|---|---|---|
| 1 | `project_kind` recognises a Dart source tree | [x] |
| 2 | Tighten the `mongodb` datastore pair | [x] |
| 3 | Report the Dart datastores that map onto a real backend | [x] |
| 4 | Stop routing browser coding standards at a Flutter application | [x] |
| 5 | Make the detection matrix true about the two pairs it is still wrong about | [x] |
| 6 | Two checks that are quietly weaker than they read | [x] |
| 7 | Record what changed and what stays open | [x] |

## The four decisions this plan rests on

Taken by Bernard, 2026-08-30, each asked as a choice.

| # | Question | Decision |
|---|---|---|
| D1 | `has_ui` routes browser-specific coding standards at Flutter | **Narrow the one caller.** Gate `frontend.md` on `has_ui` and the framework not being `flutter`, the shape PR #49 used for `playwright`. The field stays overloaded |
| D2 | The Dart datastore list under-reports | **Widen to the mapped ones only.** `drift` and `sembast` to sqlite, `supabase_flutter` to postgres, `cloud_firestore` to its own backend. `hive`, `isar` and `objectbox` stay unreported |
| D3 | The `mongodb` pair matches a bare `mongo`, so `mongol` is MongoDB | **Tighten it, with a full regression run.** Its own task, because the pair is shared by all fifteen languages |
| D4 | `dart format .` descends into `build/` | **Leave it.** Exposure is zero across 13 local Flutter repositories, and narrowing to `lib test` would stop checking `bin/` and `tool/` |

## Global constraints

- `lib/detect-stack.sh` uses no `sed`, `sort`, `uniq` or `tr`, asserted by four cases in the suite.
  Nothing here may be the change that introduces them.
- `detect_datastores` is **not language scoped**. It greps every manifest it finds with one pattern
  per pair, and the `lang` argument is used only for the PL/SQL branch. Every pattern widened in
  task 3 therefore widens for all fifteen languages, which is why task 3 carries its own regression
  assertions rather than leaning on task 2's.
- The verify commands come from `.keel/profile.json`: `verify.test` is `tests/run-tests.sh`, and a
  single file is run as `tests/<name>`. `verify.lint` is shellcheck and **is not installed on this
  machine**, so every task's lint gate is CI's. Say so on handover rather than reporting it passed.
- No em dashes anywhere, including in the code comments these tasks add.

## What this plan does not settle

**D2 introduces one new datastore name, `firestore`.** No other language emits it, and the option
Bernard chose said "cloud_firestore to their real backends" while its label said "the mapped ones
only". Firestore is a real named product rather than an embedded library, which is what separates it
from the skipped `hive`, `isar` and `objectbox`, so it is built here. It is isolated in its own step
of task 3 so it can be dropped without unpicking the rest.

**PRD Q3, the nested path-dependency `pubspec.yaml`.** `detect_languages` reads the root only, so a
nested manifest is invisible to every task here. Still no instance forces it. Task 7 records that
rather than closing it.

**PRD Q4, whether `verify.test` should be null where the only test is the generated
`widget_test.dart`.** The position is `A3`, no, on consistency with every other language. Task 7
records that the question stays open for anyone who disagrees.

**`is_flutter` is still not memoised**, and `dart_has_test_files` now adds a bounded `find` beside
its dozen greps. Previously accepted on the grounds that the two existing caches each exist for a
tree walk rather than a dozen greps. No task, and task 7 records the added `find` so the next
person judging it has the current cost rather than the old one.

---

### Task 1: `project_kind` recognises a Dart source tree

**Follow-up:** item 7
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Produces: nothing other tasks consume.

**Depends on:** none

**Why this is here at all.** The execution plan recorded this finding and rejected it: "Checked and
not reproduced. `bin/keel:364` returns `service` as soon as `detect_stack`'s first field is not
`unknown`, and after task 4 a Dart repository's is `dart`." That rebuttal is correct for a
repository **with** a `pubspec.yaml` and answers a different case from the one raised. The extension
fallback is reached only when the language is `unknown`, which is exactly the `dart-orphan` shape
the suite already has a fixture for: ten `.dart` files and no manifest. Verified 2026-08-30 by
reading `bin/keel:366`, whose alternation has no `dart`.

**This is not a regression.** Dart was not detected at all before PR #49, so the same tree got
`docs` then too. It is a gap the Dart work made worth closing, not one it opened.

**Step 1: Write the failing test**

Append to the dart block in `tests/test-keel.sh`, after the `dart-orphan` case that already asserts
the tree detects as no language:

```bash
# A directory of Dart source with no manifest detects as no language, asserted above, which drops
# project_kind through to its extension census. That alternation had no `dart`, so a tree of source
# was classified `docs` and doctor then stopped asking it for a test command. Not a regression:
# before PR #49 nothing detected Dart either. Found in the review of PR #49, 2026-08-30.
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
```

The profile-exists guard is not ceremony: `prof_of` swallows every error and returns the empty
string, so without it a crashed `keel init` produces `got=''`, which is not `service`, and the case
would fail for the wrong reason rather than saying so.

**Step 2: Run it and watch it fail**

```
tests/test-keel.sh
```

Expect `FAIL  project_kind: dart-orphan got project.kind 'docs', want service`.

**Step 3: Write the minimal implementation**

In `bin/keel`, in `project_kind`, add `dart` to the alternation:

```bash
    src=$(git ls-files 2>/dev/null | grep -cE '\.(ts|js|py|go|java|kt|php|rs|rb|cs|swift|lua|dart|c|cc|cpp|h|hpp)$' || true)
```

Placed before `c`, so the single-letter extensions stay together at the end where they are easy to
read as a group.

**Step 4: Run it and watch it pass**

```
tests/test-keel.sh
```

Expect the new case to pass and the count to rise by one.

**Step 5: Hand over**

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`/usr/bin/grep -q "lua|dart" bin/keel` exits 0.

---

### Task 2: tighten the `mongodb` datastore pair

**Follow-up:** item 1, decision D3
**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Produces: the tightened pair. Task 3 edits the same `for pair in` list and must land after it.

**Depends on:** none

**The blast radius is the whole point of the separation.** This pair is read for every one of the
fifteen languages, so it gets its own task and its own regression run rather than riding along with
task 3's Dart widening. A reviewer may reasonably approve one and reject the other.

**Step 1: Write the failing test**

Append to the datastore block in `tests/test-keel.sh`:

```bash
# The pair matched a bare `mongo` under -i, so any package whose name merely starts with those five
# letters was profiled as MongoDB. `mongol`, a real pub.dev package for Mongolian vertical text,
# was the instance found, over a corpus of about 100 real pub.dev names. Tightened 2026-08-30, D3.
d="$(fixture dart-pure)"
printf '  mongol: ^2.0.0\n' >> "$d/pubspec.yaml"
got="$( cd "$d" && bash -c '. "$1"; detect_datastores | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
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
    got="$( cd "$d" && bash -c '. "$1"; detect_datastores | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
    case "$got" in
      *mongodb*) ok "$fx still detects a real MongoDB declaration" ;;
      *)         bad "datastores" "$fx lost mongodb: '$got'" ;;
    esac
    rm -rf "$d"
done
```

**Step 2: Run it and watch it fail**

```
tests/test-keel.sh
```

Expect exactly one failure, `mongol was profiled as mongodb`. The four regression cases pass before
the change, which is what makes them regression guards rather than evidence: say so on handover
rather than counting them among the failures.

**Step 3: Write the minimal implementation**

In `lib/detect-stack.sh`, replace the `mongodb` pair:

```bash
                'mongodb:mongodb|mongoose|pymongo|mongoid|mongo_dart|mongo-driver|(^|[^a-zA-Z])mongo([^a-zA-Z]|$)' \
```

and put the reasoning above the `for pair in` line, beside the note the `"pg"` quoting trick already
carries:

```bash
    # `mongo` is not a bare token either, for the same reason `"pg"` is quoted: it is a prefix of
    # ordinary words. `mongol`, a real pub.dev package for Mongolian vertical text, was profiled as
    # MongoDB. The driver names are listed because no suffix rule separates them from the false
    # positive: mongodb, mongoose and mongol are all `mongo` plus letters. The last alternative
    # catches the bare declaration in every manifest shape, `gem "mongo"`, `image: mongo:5`, by
    # requiring a non-letter on each side. Written [^a-zA-Z] rather than [^a-z] because the search
    # is -i, and a negated class under -i excludes both cases.
```

**Step 4: Run it and watch it pass, and prove the guards bite**

```
tests/test-keel.sh
```

All five new cases pass. Then prove the four regression cases can fail, by temporarily replacing the
pair with `'mongodb:zzzz'` and re-running: expect four failures naming each fixture. Restore it.

**Step 5: Hand over**

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`/usr/bin/grep -q 'mongo_dart' lib/detect-stack.sh` exits 0.

---

### Task 3: report the Dart datastores that map onto a real backend

**Follow-up:** item 3, decision D2
**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `tests/test-keel.sh`
- Modify: `docs/prd/dart-flutter-stack-detection.md`

**Interfaces:**
- Consumes: task 2's edit to the same `for pair in` list.
- Produces: the `firestore` datastore name, which nothing else emits.

**Depends on:** Task 2

**This is the only task that changes what keel claims**, rather than correcting something already
wrong. `FR-15` names `sqflite` only, so this amends a requirement and the PRD is edited in step 4
rather than left to the closing task.

**Step 1: Write the failing test**

Append to the datastore block:

```bash
# FR-15 named sqflite only, and a realistic 30-package pubspec reported nothing for seven common
# stores. Widened 2026-08-30, D2, to the ones that map onto a backend keel already names, plus
# firestore. hive, isar and objectbox stay unreported: they are embedded libraries with no server
# product behind them, so there is no existing name to map them onto and inventing three would be a
# vocabulary decision rather than a detection one.
d="$(fixture dart-pure)"
cat >> "$d/pubspec.yaml" <<'P'
  drift: ^2.14.0
  sembast: ^3.5.0
  supabase_flutter: ^2.0.0
  cloud_firestore: ^4.13.0
P
got="$( cd "$d" && bash -c '. "$1"; detect_datastores | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
for want in sqlite postgres firestore; do
    case "$got" in
      *"$want"*) ok "a Flutter pubspec naming its store reports $want" ;;
      *)         bad "datastores" "wanted $want in '$got'" ;;
    esac
done
rm -rf "$d"

# The three deliberately left out. This case is what stops someone adding them without a decision:
# it fails loudly if they appear, rather than going quietly out of date.
d="$(fixture dart-pure)"
cat >> "$d/pubspec.yaml" <<'P'
  hive: ^2.2.3
  isar: ^3.1.0
  objectbox: ^2.5.0
P
got="$( cd "$d" && bash -c '. "$1"; detect_datastores | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
if [ ! -f "$d/pubspec.yaml" ]; then
    bad "datastores" "the fixture lost its pubspec.yaml, so this case proves nothing"
elif [ -n "$got" ]; then
    bad "datastores" "an embedded-store pubspec reported '$got', want nothing. If this is deliberate, it is a vocabulary decision and needs one"
else
    ok "hive, isar and objectbox stay unreported, as D2 decided"
fi
rm -rf "$d"
```

**Step 2: Run it and watch it fail**

```
tests/test-keel.sh
```

Expect three failures, one per wanted store. The embedded-store case passes before the change and is
a guard, not evidence.

**Step 3: Write the minimal implementation**

In `lib/detect-stack.sh`, in the `for pair in` list:

```bash
                'postgres:postgres|psycopg|pgx|npgsql|supabase|"pg"' \
                ...
                'sqlite:sqlite|sqflite|drift|sembast' \
                'firestore:cloud_firestore|firebase_firestore' \
```

with the reasoning above the list:

```bash
    # The Dart names, added 2026-08-30 under D2. Each maps onto the backend it actually talks to
    # rather than onto its own package name: drift and sembast are SQLite, supabase is Postgres.
    # `supabase` is deliberately unanchored to Dart, because supabase-js is Postgres too and this
    # loop is not language scoped. hive, isar and objectbox are left out: they are embedded
    # libraries with no server behind them, so there is nothing to map them onto.
```

`firestore` is a new store name that no other language emits. It is on its own line so it can be
dropped without touching the two widened pairs.

**Step 4: Amend `FR-15` in the PRD**

Replace the `FR-15` row's requirement text so it says what is true now, and add to its evidence
column:

```
**Amended 2026-08-30 by Bernard, asked as a choice.** sqflite alone under-reported: a realistic
30-package pubspec named seven stores and keel reported one. Widened to the packages that map onto
a backend keel already names, plus firestore. hive, isar and objectbox stay unreported by decision,
not by oversight.
```

**Step 5: Run it and watch it pass**

```
tests/run-tests.sh
```

All test files pass. Confirm `tests/test-doc-claims.sh` still prints `5 passed, 0 failed`, since the
PRD edit is prose and must not have moved a counted claim.

**Step 6: Hand over**

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`/usr/bin/grep -q 'firestore:cloud_firestore' lib/detect-stack.sh` exits 0.

---

### Task 4: stop routing browser coding standards at a Flutter application

**Follow-up:** item 5, decision D1
**Files:**
- Modify: `skills/coding-standards/references/house-defaults.md`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Produces: nothing other tasks consume.

**Depends on:** none

`house-defaults.md:27` gates `frontend.md` on `profile.stack.has_ui` alone, and that reference is
about bundle supply chain, CDN caching, browser history and referrer headers. PR #49 fixed the same
root cause in the plugin caller because that one wrote wrong output into a settings file; this one
routes prose. D1 narrows the caller rather than splitting the field, so `has_ui` stays overloaded
and this is the second of three callers patched individually.

**Step 1: Write the failing test**

Append to the dart block:

```bash
# D1. frontend.md is browser-specific prose, and its gate read has_ui alone, which PR #49 set true
# for Flutter. The condition is pinned here rather than left to review because it is one table cell
# in a reference file, which is exactly the kind of line an unrelated edit reformats away.
hd="$ROOT/skills/coding-standards/references/house-defaults.md"
row="$(grep -F '[frontend.md](frontend.md)' "$hd" | head -1)"
if [ -z "$row" ]; then
    bad "coding-standards" "no frontend.md row in house-defaults.md, so this case proves nothing"
elif printf '%s' "$row" | grep -q 'flutter'; then
    ok "the frontend.md gate excludes flutter, whose UI is not browser-rendered"
else
    bad "coding-standards" "the frontend.md gate still reads has_ui alone: $row"
fi
```

**Step 2: Run it and watch it fail**

```
tests/test-keel.sh
```

Expect `FAIL  coding-standards: the frontend.md gate still reads has_ui alone`.

**Step 3: Write the minimal implementation**

In `skills/coding-standards/references/house-defaults.md`, replace line 27:

```
| [frontend.md](frontend.md) | `profile.stack.has_ui` is true and `profile.stack.framework` is not `flutter` |
```

**Step 4: Run it and watch it pass**

```
tests/run-tests.sh
```

`validate-skills.sh` must still report `24 skills validated`. This edit is in a reference rather
than a skill body, so it does not count against the ADR-0001 word ceiling, and the five existing
warnings must be unchanged. If a sixth appears, the edit went into the wrong file.

**Step 5: Hand over**

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`/usr/bin/grep -q 'is not `flutter`' skills/coding-standards/references/house-defaults.md` exits 0.

---

### Task 5: make the detection matrix true about the two pairs it is still wrong about

**Follow-up:** items 9 and 6
**Files:**
- Modify: `docs/03-install-and-distribution.md`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: the row-order assertion PR #49 added, which this extends.

**Depends on:** none

Two separate wrongnesses in one table, both pre-existing and neither created by the Dart work:

1. **Java is listed above Kotlin** (lines 218 and 219) while `detect_languages` matches `kotlin`
   first and says so in its own comment: "Kotlin before java, because a Gradle build is the marker
   for both and Kotlin is the specific case." The table's polyglot row says the first listed wins,
   so the table is wrong about that pair the same way it was about Dart before PR #49.
2. **The `has_ui` row prescribes an outcome for a condition its left column does not list.** The
   left column names `next.config`, `vite.config`, `angular.json` and `public/`, none of which is a
   Flutter or an APEX signal, while the right column now talks about both.

**Step 1: Write the failing test**

Extend the matrix assertion PR #49 added, immediately after it:

```bash
# The same rule for the other pair the table gets wrong. detect_languages matches kotlin before
# java, and its own comment says why, so a table claiming the reverse misleads a reader about the
# case its polyglot row exists to explain. Pre-existing, and out of scope for the Dart work that
# added the assertion above.
kt="$(grep -n '^| `build.gradle.kts`' "$mtx" | head -1 | cut -d: -f1)"
jv="$(grep -n '^| `pom.xml` or `build.gradle`' "$mtx" | head -1 | cut -d: -f1)"
if [ -z "$kt" ] || [ -z "$jv" ]; then
    bad "docs" "the detection matrix has no kotlin or java row, so this case proves nothing"
elif [ "$kt" -lt "$jv" ]; then
    ok "the detection matrix lists kotlin above java, as the chain orders them"
else
    bad "docs" "kotlin is listed at line $kt, below java at $jv, but detect_languages matches kotlin first"
fi
```

**Step 2: Run it and watch it fail**

```
tests/test-keel.sh
```

Expect `FAIL  docs: kotlin is listed at line 219, below java at 218`.

**Step 3: Write the minimal implementation**

Swap the two rows in `docs/03-install-and-distribution.md` so Kotlin precedes Java, and rewrite the
`has_ui` row's left column so it lists the conditions the right column answers:

```
| any of `next.config`, `vite.config`, `angular.json`, a `public/` dir, an APEX manifest, or a Flutter framework | has a UI, so recommend `frontend-design`, and `playwright` where that UI is browser-rendered. A Flutter application gets `frontend-design` only: `playwright` drives browsers and Flutter's own end-to-end tool is the SDK's `integration_test`. Unless the same root also carries a browser UI of its own, a `public/` dir or an `index.html`, in which case it gets both: the exclusion is about there being no browser to drive, not about Flutter being present |
```

**Step 4: Run it and watch it pass**

```
tests/run-tests.sh
```

Both matrix assertions pass, and the Dart one must still pass: swapping two rows below it does not
move `pubspec.yaml` above `package.json`, and the assertion re-reads line numbers on every run, so a
green result here is evidence rather than luck.

**Step 5: Hand over**

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and the suite reports both
`lists pubspec.yaml above package.json` and `lists kotlin above java`.

---

### Task 6: two checks that are quietly weaker than they read

**Follow-up:** items 10 and 4
**Files:**
- Modify: `tests/validate-skills.sh`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Produces: nothing other tasks consume.

**Depends on:** Task 3

Neither is a defect in shipped behaviour. Both are checks or comments that say something no longer
true, which is the class this repository keeps rediscovering the hard way.

1. `tests/validate-skills.sh:409` explains that reading `lang_profile`'s case labels would "yield
   `nest` as a fourteenth language". `detect_languages` now yields fifteen, so `nest` would be the
   sixteenth. The rule itself is correct; its explanation is off by two.
2. The `psycopg` regression guard at `tests/test-keel.sh:791` matches `*postgres*`, so it would not
   notice an extra store appearing beside postgres. Task 3 widens the postgres pair with
   `supabase`, which makes an exact assertion worth more than it was.

**Depends on task 3** because the exact-match assertion has to be written against the widened pair,
not the current one.

**Step 1: Write the tightened assertions**

In `tests/test-keel.sh`, replace the psycopg case:

```bash
got="$( cd "$d" && bash -c '. "$1"; detect_datastores | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
# Exact, not a substring. A `*postgres*` match passes while a second store appears beside it, and
# task 3 widened the postgres pair, so the thing this case is least able to afford is silence about
# what else it now matches.
[ "$got" = "postgres " ] && ok "the existing manifest-based datastore detection still works" \
  || bad "datastores" "a psycopg project gave '$got', want exactly 'postgres '"
```

In `tests/validate-skills.sh`, correct the ordinal on line 409:

```
# yield `nest` as a sixteenth language and this rule would demand a tool row for NestJS. Checked
```

**Step 2: Run them and watch them pass**

```
tests/run-tests.sh
```

Both pass. The psycopg case is a `verify` change: it asserts behaviour believed correct, so it
passing first time is the expected result and not evidence the tightening did anything.

**Step 3: Prove the tightened guard bites**

Temporarily add a second store to the python fixture's `requirements.txt` inside that case and
re-run, then remove it.

**Corrected during execution, 2026-08-30.** This step first said to add `supabase`, and that proves
nothing: task 3 maps `supabase` onto `postgres`, the same name `psycopg` already produces, so the
list stays exactly `postgres ` and the case passes. The mutation has to name a store that is not
postgres. `redis==5.0` was used, and the case then failed with
`a psycopg project gave 'postgres redis ', want exactly 'postgres '`. A mutation that cannot fail is
the same defect this step exists to catch, one level up.
Without this step the exactness is asserted and unproven, which is the same shape as the guards
task 10 of the previous plan had to repair.

**Step 4: Hand over**

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`/usr/bin/grep -q 'sixteenth language' tests/validate-skills.sh` exits 0.

---

### Task 7: record what changed and what stays open

**Follow-up:** items 2, 8, 11, 12, and the corrected rebuttal from task 1
**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/prd/dart-flutter-stack-detection.md`
- Modify: `docs/plans/2026-08-29-dart-flutter-stack-detection.md`

**Interfaces:**
- Consumes: every task above.

**Depends on:** Tasks 1, 2, 3, 4, 5, 6

**Step 1: Add the CHANGELOG entries**

Under `## Unreleased`, one entry per behaviour change: the `mongodb` tightening with `mongol` named
as the instance, the Dart datastore widening with the three deliberate omissions named, the
`project_kind` extension, and the `frontend.md` gate. The two documentation-only tasks get one entry
between them.

**Step 2: Close what the PRD can close, and say what stays open**

In `docs/prd/dart-flutter-stack-detection.md`:

- `Q3` stays open. Add: **Still open 2026-08-30 after the follow-up plan. No task here changed
  `detect_languages`, which still reads the root only, so a nested `pubspec.yaml` remains invisible
  and no instance forces a rule.**
- `Q4` stays open with position `A3`. Add: **Reaffirmed 2026-08-30. The follow-up plan did not
  revisit it, and `dart_has_test_files` now makes the position sharper rather than softer: a
  generated `widget_test.dart` is a test file, and `verify.test` is filled because of it.**

**Step 3: Correct the record in the previous plan**

In `docs/plans/2026-08-29-dart-flutter-stack-detection.md`, in the "Review findings not acted on"
table, replace the `project_kind` row's verdict. It currently reads "Checked and not reproduced",
which is true of a repository with a `pubspec.yaml` and false of the manifest-less tree the reviewer
meant. Replace with:

```
**Reproduced after all, and fixed on 2026-08-30.** The rebuttal answered a different case: a
repository *with* a pubspec.yaml never reaches the extension fallback, which is what it checked, but
the `dart-orphan` shape has no manifest, detects as no language by design, and did reach it. Not a
regression, since nothing detected Dart before this work either.
```

Add to the same plan's follow-up table the two items its own review never recorded, marked closed by
this plan, so that table is a complete account rather than a partial one: the matrix row order and
the `validate-skills.sh` ordinal.

**Step 4: Record the three that stay open**

Add a short section to this plan naming what is deliberately not built: D4's `dart format` decision,
`is_flutter` memoisation with its now-larger cost, and the `has_ui` field still being overloaded
after D1 patched its second caller. State the trigger for revisiting each rather than leaving them
as a list.

**Step 5: Run the document checks**

```
tests/run-tests.sh
```

`tests/test-doc-claims.sh` prints `5 passed, 0 failed`, and no counted README claim moved.

**Step 6: Hand over**

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`/usr/bin/grep -q 'Reproduced after all' docs/plans/2026-08-29-dart-flutter-stack-detection.md`
exits 0.

---

## Follow-up coverage

| # | Item | Task |
|---|---|---|
| 1 | `mongodb` matches a bare `mongo` | 2 |
| 2 | `dart format .` descends into `build/` | none, D4 leaves it. Recorded by task 7 |
| 3 | Dart datastore list under-reports | 3 |
| 4 | `psycopg` guard is a substring match | 6 |
| 5 | `has_ui` routes browser standards at Flutter | 4 |
| 6 | Matrix `has_ui` row prescribes an unlisted condition | 5 |
| 7 | `project_kind` has no `dart` | 1 |
| 8 | `is_flutter` not memoised | none, previously accepted. Recorded by task 7 with its new cost |
| 9 | Matrix lists Java above Kotlin | 5 |
| 10 | `validate-skills.sh` ordinal is stale | 6 |
| 11 | PRD Q3, nested `pubspec.yaml` | none, stays open. Recorded by task 7 |
| 12 | PRD Q4, generated `widget_test.dart` | none, position `A3` reaffirmed by task 7 |

Nine of the twelve are built. Three are recorded as deliberately not built, each with the trigger
that would reopen it.

## Deliberately not built, and what would reopen each

Three of the twelve get no task. Each has a trigger rather than a hope that someone remembers.

| Item | Why not | What reopens it |
|---|---|---|
| **`dart format .` descends into `build/`** and would rewrite generated `*.g.dart` there, so `verify.format` can be red on a clean checkout | D4. Exposure is zero: none of the 13 local Flutter repositories has a `.dart` file under `build/`, because Flutter puts compiled artifacts there and `build_runner` writes to `lib/` or the hidden `.dart_tool/`. Narrowing to `lib test` would stop checking `bin/` and `tool/`, trading a measured-zero risk for a real gap | The first repository measured with a `.dart` file under `build/`, or a `keel doctor` run that goes red on `verify.format` with no source edit behind it |
| **`is_flutter` is not memoised**, and `dart_has_test_files` now adds a bounded `find` beside its dozen greps per `init` | Previously accepted on the grounds that `PKG_SCRIPTS` and `DETECTED_LANGS` each exist for an interpreter start or a tree walk, not for a dozen greps of a ten-line file. The `find` is depth-bounded to 3 under `test/`, so it is not the walk those caches exist for. **The cost has grown since that judgement was made**, which is why it is restated here rather than left at its old figure | `keel init` on a Dart repository measured as slow, against the 24 ms and 102 ms figures the two existing caches were built for |
| **`has_ui` answers one question for three callers.** D1 patched the second; the field is still overloaded | Splitting it means a new profile key, a migration for every initialised profile, and `profile-keys.md`. Two of the three callers are now correct, and the third is `detect_has_ui` itself, which is the field's definition rather than a consumer of it | A fourth caller, or a case where the two patched call sites disagree about what "has a UI" means |

## Dependency order

```
Task 1  ──┐
Task 4  ──┤
Task 5  ──┼──> Task 7
Task 2 ──> Task 3 ──> Task 6 ──┘
```

**Concurrent batch: tasks 1, 4 and 5.** They depend on nothing outstanding, and no two name the same
file: task 1 writes `bin/keel`, task 4 writes `skills/coding-standards/references/house-defaults.md`,
task 5 writes `docs/03-install-and-distribution.md`. All three also append to `tests/test-keel.sh`,
which is why they are a batch rather than three parallel branches: run them concurrently only if
each appends to a distinct block, otherwise run them in order and accept the two minutes it costs.

Tasks 2, 3 and 6 are strictly serial. Both 2 and 3 edit the same `for pair in` list, and 6's exact
assertion has to be written against the pair 3 leaves behind.

Task 7 depends on all six.
