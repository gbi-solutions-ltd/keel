# PL/SQL stack detection Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `keel init` on an Oracle PL/SQL repository writes `language: plsql` and
`datastores: [oracle]`, and stays silent on every repository that declares itself to be something
else, including a manifest-less PostgreSQL migrations tree.

**Stories:** S-01 to S-08, from `docs/stories/plsql-stack-detection.md`
**PRD:** `docs/prd/plsql-stack-detection.md`, approved 2026-08-18
**ADRs:** none. ADR-0001 governs skill body length and no skill body is touched.
**Architecture:** one new branch in `detect_languages`, one new arm in `lang_profile`, one addition
to `detect_datastores`, and three table rows. No new file, no new component, no new boundary, which
is why there is no architecture document.

## Global constraints

Copied in full rather than linked, because a task executed by a fresh agent that reads only its own
section must still obey them.

- Verify commands, from `.keel/profile.json`:
  - test: `tests/run-tests.sh`
  - one test: `tests/{name}`, for example `tests/test-keel.sh`
  - lint: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
  - format, typecheck, build, e2e, security: `null`. Nothing to compile and no formatter.
- `tests/test-keel.sh` takes about ten minutes on its own and `tests/run-tests.sh` about fifteen.
  Run the single test in steps 2 and 4; run the full suite before the commit step of tasks 1, 4
  and 7 only, not after every task.

  **Amended 2026-08-18, by the requester, after task 1 measured the real cost.** Tasks 3, 5 and 6
  change no detection logic: task 3 adds assertions and no implementation, task 5 adds one branch
  to `detect_datastores` that only fires on a language the earlier tasks already gate, and task 6
  asserts an absence. Their targeted `tests/test-keel.sh` covers what they change, and task 7's full
  suite is the gate before review. Tasks 1, 4 and 2 keep theirs because they change what
  `detect_languages` and `lang_profile` return, which every other suite reads indirectly.

  The saving is real rather than cosmetic: a full suite is about fifteen minutes and a targeted
  `tests/test-keel.sh` about ten, so this removes roughly forty-five minutes of wall clock from a
  plan whose remaining tasks are mostly assertions and prose.
- Never start on `main`. All keel work goes on the `sandbox` branch.
- **No em dashes, en dashes, or any dash longer than a hyphen**, in code, comments, documents or
  commit messages.
- **`NFR-03`: no new external command.** `lib/detect-stack.sh` currently uses `grep`, `find`,
  `awk`, `xargs`, `cut`, `head` and `tail`. It does **not** use `sed`, `sort`, `uniq` or `tr`, and
  this work must not introduce them. The census below is deliberately written as one `find` piped
  to one `awk` for that reason.
- **bash 3.2 is the floor.** It is the system bash on macOS, confirmed as
  `GNU bash, version 3.2.57(1)-release`. No associative arrays, no `${var,,}`, no `mapfile`.
- Commit style is `conventional`. No `Co-Authored-By` trailer, no robot emoji, no attribution
  footer.

## The marker, stated once

Every task refers to this. `plsql` is reported when **all four** hold:

1. No manifest exists for any of the thirteen currently detected languages.
2. `.sql` plus `.plsql` files together outnumber every other single extension.
3. There are at least ten of them.
4. At least one of them contains `VARCHAR2`, `DBMS_` or `PACKAGE BODY`, matched case-insensitively.

Clause 4 is why a manifest-less PostgreSQL migrations repository is not mislabelled. `%TYPE` and
`%ROWTYPE` are **not** in the token set and must not be added: PL/pgSQL supports both, so including
them readmits the false positive the clause exists to remove.

**These numbers were measured on fixtures on 2026-08-18**, with the code below:

| Fixture | `.sql` count | Largest other extension | Oracle token | Result |
|---|---|---|---|---|
| Oracle-shaped, no manifest | 13 | 1 | yes | `plsql` |
| PostgreSQL, `%TYPE` and `%ROWTYPE` only | 13 | 0 | no | silent |
| TypeScript with migrations | 20 | 40 | no | silent, on clause 1 |
| Nine `.sql` files | 9 | 0 | no | silent, on clause 3 |

---

## Task 1: The census, the filename marker, and the tool table rows

**Story:** S-01, S-07
**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `tests/test-keel.sh`
- Modify: `skills/keel/references/tool-choices.md`

**Interfaces:**
- Produces: `sql_census`, a function echoing two integers separated by one space, the `.sql` plus
  `.plsql` count and the largest count of any other single extension. Consumed by task 2.
- Produces: `plsql` in `detect_languages` output, consumed by tasks 3, 4 and 5.

**Done when:** `tests/test-keel.sh` passes including the five new detection assertions, and
`tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, extend the `fixture` helper's `case` with four new arms, placed
immediately before the `bare) : ;;` arm at `:64`:

```bash
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
```

Then, immediately after the existing detection loop that ends at `:87`, add:

```bash
# PL/SQL is the first language keel infers rather than reads from a manifest, so each clause of the
# marker gets its own assertion. A single happy-path test would pass with any one of them broken.
for stack in plsql plsql-small ts-migrations; do
    d="$(fixture "$stack")"
    got="$( cd "$d" && bash -c '. "$1"; detect_languages | tr "\n" " "' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
    case "$stack" in
      plsql)          want="plsql " ;;
      plsql-small)    want="" ;;
      ts-migrations)  want="typescript " ;;
    esac
    [ "$got" = "$want" ] && ok "detect_languages on $stack gives '${want:-nothing}'" \
      || bad "detects $stack" "got '$got', want '${want:-nothing}'"
    rm -rf "$d"
done
```

`tr` appears in the test only, not in `lib/detect-stack.sh`, so `NFR-03` is unaffected: the
constraint is on the library, and `tests/test-keel.sh` already uses `tr` at `:1747`.

- [x] **Step 2: Run it and watch it fail** (witnessed by the implementer: `FAIL detects plsql: got '', want 'plsql '`, one real failure, two assertions passing beforehand)

Run: `tests/test-keel.sh`
Expected: FAIL on `detects plsql`, with `got '', want 'plsql '`. The other two pass already, because
nothing reports `plsql` yet and silence is what they assert. Record that in the tick note: one of
the three is a real failure and two are assertions that pass before the change and earn their keep
after it.

- [x] **Step 3: Write the minimal implementation**

In `lib/detect-stack.sh`, immediately after `find_marker` ends at `:71`, add the census:

```bash
# Echo: two integers, the number of .sql plus .plsql files and the largest number sharing any other
# single extension. One find and one awk, because lib/detect-stack.sh uses neither sed, sort, uniq
# nor tr and this must not be the change that introduces them.
#
# Extensionless files are not counted on either side. They are not a competing extension, so a tree
# of 191 .sql files and 300 Makefiles is still SQL-dominant, which is the intended reading.
sql_census() {
    find . \( -name node_modules -o -name .git \) -prune -o -type f -print 2>/dev/null | awk '
        { n = split($0, p, "/"); base = p[n]
          if (index(base, ".") == 0) next
          ext = base; while (match(ext, /\./)) ext = substr(ext, RSTART+1)
          ext = tolower(ext)
          if (ext == "sql" || ext == "plsql") s++
          else { c[ext]++; if (c[ext] > m) m = c[ext] } }
        END { print s+0, m+0 }'
}
```

Then, immediately above `sql_census`, add the decision function:

```bash
# Whether this tree is a PL/SQL project. Clauses one to three of the marker; task 2 adds the fourth.
#
# NOT MEMOISED, AND THAT WAS TESTED RATHER THAN ASSUMED. bin/keel reaches detect_languages four
# times in one init, at :324, :345, :357 and :358, and this is the only language whose answer costs
# a tree walk rather than a handful of `[ -f ]` tests. A cache looks obviously right and delivers
# nothing: every one of those four calls sits inside its own `$( )`, so a cache written in one
# subshell is discarded before the next runs. Measured on 2026-08-18 on a 2,000 file SQL repository:
# four walks with a cache, four without, identical.
#
# What keeps the cost bounded is FR-04 instead. A repository that declares any of the thirteen never
# reaches this function at all, so the walk is paid only by a repository that is genuinely
# manifest-less, once, at init time. On the 2,000 file fixture that was about 0.9 seconds in total.
is_plsql_tree() {
    local census sqlc othermax
    census="$(sql_census)"
    sqlc="${census%% *}"; othermax="${census##* }"
    [ "$sqlc" -ge 10 ] && [ "$sqlc" -gt "$othermax" ]
}
```

Then in `detect_languages`, immediately before the word-splitting comment at `:207`, add:

```bash
    # PL/SQL, and it is the only inferred language here. Every branch above reads a file the project
    # declares; PL/SQL has no manifest format, so this infers from the shape of the tree instead.
    #
    # It runs last and only when nothing else matched, which is what makes it safe: any repository
    # carrying a manifest has already been classified and never reaches the census. That ordering is
    # a requirement, FR-04, not an optimisation.
    if [ -z "$out" ] && is_plsql_tree; then
        out="$out plsql"
    fi
```

`detect_languages` needs no new locals: `is_plsql_tree` declares its own.

Then add the three rows to `skills/keel/references/tool-choices.md`, one per table.

After the last row of the **Test runner** table, currently `` | `lua` | busted | ... ``:

```markdown
| `plsql` | utPLSQL | none | The only real option, and the ecosystem agrees on it. It runs inside the database, so `verify.test` stays `null` until somebody supplies a connection string, a schema and credentials, none of which belong in the repository |
```

After the last row of the **Lint and format** table, currently `` | `lua` | Stylua with luacheck | ... ``:

```markdown
| `plsql` | none | none | No linter ships outside vendor IDE tooling, and a rule set nobody can run in CI is not a lint step. Say `null` in the profile |
```

After the last row of the **Typecheck** table, currently `` | `javascript`, `lua` | none | ... ``:

```markdown
| `plsql` | none | The database is the compiler. A package body that does not compile fails at install time, so `verify.typecheck` stays `null` rather than repeating it |
```

An earlier draft of this plan added a `$PWD`-keyed cache here, on a measurement that turned out not
to describe how `keel` calls the code. It is gone, and the comment above records why so nobody
re-adds it.

- [x] **Step 4: Run it and watch it pass** (309 passed 0 failed; validator OK; shellcheck silent. Not witnessed by the coordinator, who read the reports)

Run: `tests/test-keel.sh`
Expected: PASS on all three new assertions, and the suite green at 309 passed, 0 failed.

**The PostgreSQL case is deliberately not asserted here**, and an earlier draft of this plan got
that wrong. It claimed a `plsql-nomarker` fixture would still pass at this point "because clause 4
does not exist yet", which is backwards: with clause 4 absent, a manifest-less tree of 13 `.sql`
files and nothing else satisfies clauses one to three and **is** reported as `plsql`, so an
assertion wanting silence fails. Task 1 cannot make that case pass and task 2 is where it belongs.
Caught by the implementer before committing, 2026-08-18.

Run: `tests/validate-skills.sh`
Expected: `OK`, with no missing tool-choices row. Without the three rows above it reports
`skills/keel/references/tool-choices.md has no row for 'plsql'`.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: no findings.

Then run the full suite: `tests/run-tests.sh`. Expected green.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh skills/keel/references/tool-choices.md
git commit -m "feat(detect): report plsql on a manifest-less, SQL-dominant tree"
```

---


**Task 1 review outcome, 2026-08-18.** Spec compliance: COMPLIES, verified by rebuilding all three
fixtures and reproducing both the red and the green state independently. Code quality: nothing
blocking, five findings, all verified and all scheduled rather than applied here, because task 1 was
already committed and each belongs with the code it touches. Findings 1, 4 and 5 land in task 2,
finding 3 in task 4, finding 2 in task 7.

One further gap was found by mutation testing after both reviews passed: deleting the dominance
comparison outright left every task 1 assertion green, so the clause had no coverage. It is now the
`plsql-notdominant` fixture in task 2. Neither review caught it, because a clause with no test
survives any review that only reads what is there.

## Task 2: The Oracle token, which is what makes the marker safe

**Story:** S-02, and the dominance coverage S-01 specified but task 1 omitted
**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `sql_census` and the `detect_languages` branch from task 1.
- Produces: `has_oracle_token`, a function returning 0 when a `.sql` or `.plsql` file in the tree
  contains an Oracle-exclusive token. Consumed by nothing else.

**Done when:** `tests/test-keel.sh` passes including the six token assertions and the
`plsql-nomarker`, `plsql-notdominant` and `plsql-pkg` cases, and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, add the PostgreSQL fixture arm to the `fixture` helper's `case`,
immediately before the `bare) : ;;` arm:

```bash
        plsql-nomarker)
          # PostgreSQL shaped: dominant .sql, no manifest, and PL/pgSQL syntax that must not count
          # as Oracle. This is the fixture clause 4 exists for, which is why it arrives with clause
          # 4 rather than with the filename marker in task 1.
          i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id integer);\n' "$i" > "m$i.sql"; i=$((i+1)); done
          mkdir -p sql
          printf 'DECLARE r mytable%%ROWTYPE; v mytable.col%%TYPE; BEGIN END;\n' > sql/fn.sql ;;
        plsql-pkg)
          # The idiomatic Oracle layout: package specs and bodies outnumber plain .sql. It must be
          # detected, and before the census change in this task it was not: those extensions
          # competed in the dominance test and won.
          # The Oracle token goes in the .sql files, not the .pkb ones: has_oracle_token scans
          # --include='*.sql' --include='*.plsql' only, so a token living in a .pkb is invisible to
          # it and this fixture would fail the token clause rather than exercising the denominator.
          i=1; while [ "$i" -le 30 ]; do printf 'PACKAGE p;\n' > "p$i.pks"; printf 'PACKAGE BODY p AS END;\n' > "p$i.pkb"; i=$((i+1)); done
          i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id VARCHAR2(9));\n' "$i" > "s$i.sql"; i=$((i+1)); done ;;
        plsql-notdominant)
          # Twelve .sql against forty .md, with the Oracle token present, so the count clause and
          # the token clause both hold and DOMINANCE is the only clause that fails. Story S-01
          # specified this case and task 1 did not implement it; a mutation test after task 1's
          # review deleted the dominance comparison entirely and all three of task 1's assertions
          # stayed green, which is what an untested clause looks like.
          i=1; while [ "$i" -le 12 ]; do printf 'CREATE TABLE t%s (id NUMBER);\n' "$i" > "s$i.sql"; i=$((i+1)); done
          printf 'CREATE OR REPLACE PACKAGE BODY p AS v VARCHAR2(9); END;\n' > s1.sql
          i=1; while [ "$i" -le 40 ]; do printf '# doc %s\n' "$i" > "d$i.md"; i=$((i+1)); done ;;
```

Then extend task 1's detection loop to cover both, changing its first line and adding two `case`
arms:

```bash
for stack in plsql plsql-nomarker plsql-notdominant plsql-pkg plsql-small ts-migrations; do
```

```bash
      plsql-nomarker)    want="" ;;
      plsql-notdominant) want="" ;;
      plsql-pkg)         want="plsql " ;;
```

Then, after that loop, add:

```bash
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

for probe in 'v VARCHAR2(30);:plsql :VARCHAR2' \
             'DBMS_OUTPUT.PUT_LINE(1);:plsql :DBMS_ prefix' \
             'CREATE OR REPLACE PACKAGE BODY p AS END;:plsql :PACKAGE BODY' \
             'v varchar2(30);:plsql :a lowercase token' \
             'DECLARE r t%ROWTYPE; v t.c%TYPE; BEGIN END;::PL/pgSQL %TYPE and %ROWTYPE' \
             'CREATE TABLE x (id integer);::plain SQL with no Oracle token'; do
    content="${probe%%:*}"; rest="${probe#*:}"; want="${rest%%:*}"; label="${rest#*:}"
    got="$(token_probe "$content")"
    [ "$got" = "$want" ] && ok "$label yields '${want:-nothing}'" \
      || bad "oracle token" "$label gave '$got', want '${want:-nothing}'"
done
```

- [x] **Step 2: Run it and watch it fail** (witnessed: 314 passed, 4 failed, exactly the four predicted)

Run: `tests/test-keel.sh`
Expected: FAIL three times on the false positive, seen from two angles:
`detects plsql-nomarker: got 'plsql ', want 'nothing'`, plus
`PL/pgSQL %TYPE and %ROWTYPE gave 'plsql ', want 'nothing'` and
`plain SQL with no Oracle token gave 'plsql ', want 'nothing'`. The first four token probes pass,
because task 1 reports `plsql` on any SQL-dominant tree.

`detects plsql-notdominant` **passes from the moment it is written**, because the dominance clause
already exists and already excludes it. It is not a red-to-green case; it is coverage for a clause
that had none. Say so rather than counting it as a witnessed failure. To confirm it can fail, delete
`&& [ "$sqlc" -gt "$othermax" ]` from `is_plsql_tree`, watch this one case go red while the rest stay
green, then restore it.

- [x] **Step 3: Write the minimal implementation**

**First, three corrections to what task 1 landed.** All three came out of task 1's code-quality
review and were verified before being written here.

Replace the body of `sql_census`'s `awk` program with this. Two things change: a leading-dot
basename is no longer treated as an extension, and the PL/SQL-adjacent extensions stop competing in
the denominator:

```bash
    find . \( -name node_modules -o -name .git \) -prune -o -type f -print 2>/dev/null | awk '
        { n = split($0, p, "/"); base = p[n]
          if (index(base, ".") <= 1) next
          ext = base; while (match(ext, /\./)) ext = substr(ext, RSTART+1)
          ext = tolower(ext)
          if (ext == "sql" || ext == "plsql") { s++; next }
          # Package specs and bodies do not count as evidence, because a machine-wide search on
          # 2026-08-18 found none anywhere and PRD A2 ruled them out as markers on that basis. They
          # must not count against the evidence either: 30 .pks plus 30 .pkb plus 12 .sql censused
          # as "12 30" and the most idiomatic Oracle layout there is went undetected. Same principle
          # the line above applies to extensionless files, applied to these.
          if (ext == "pks" || ext == "pkb" || ext == "prc" || ext == "fnc") next
          c[ext]++; if (c[ext] > m) m = c[ext] }
        END { print s+0, m+0 }'
```

Guard the two integers where they are read, in `is_plsql_tree`. The exact final line is given at the
end of this step, once `has_oracle_token` exists; apply it once rather than editing this line twice.

Without the defaults, an `awk` that fails to run leaves both empty and bash prints
`[: : integer expression expected` onto the user's terminal during `init`. The answer stays
correctly negative either way; the error message is the defect. `bin/keel:327` already uses this
idiom.

Then correct the `is_plsql_tree` comment, which is wrong in both of its numbers and in its
conclusion. Replace the paragraph beginning `NOT MEMOISED` with:

```bash
# NOT MEMOISED, AND THE REASON IS COST RATHER THAN IMPOSSIBILITY. One `keel init` calls this eight
# times, not the four an earlier version of this comment claimed: detect_stack reaches it from
# write_profile, from project_kind and three times from detect_has_ui, detect_also once, and
# detect_plugins twice through expected_plugins. Counted on 2026-08-18 by instrumenting sql_census
# and running a real init.
#
# A cache is possible, and the claim that it "delivers nothing" was wrong. It cannot be filled from
# inside this function, because every call sits in its own `$( )`, but pkg_scripts_load one file
# over solves exactly that by being called from write_profile's own shell at bin/keel:363, and the
# same shape here takes eight walks to one.
#
# It is not done because the cost does not warrant a new global and a second call site: one census
# measured 0.024 seconds on a 2,200 file tree, so eight of them are about 0.19 seconds, once, at
# init. FR-04 is what keeps that bounded, since a repository declaring any of the thirteen never
# reaches this function at all. Revisit if the census ever grows more expensive.
```

**Now the task's own work.** In `lib/detect-stack.sh`, immediately after `sql_census`, add:

```bash
# Whether any .sql or .plsql file carries a token no other SQL dialect uses. This is clause 4 of the
# PL/SQL marker and it is what stops a PostgreSQL migrations repository being called Oracle.
#
# The three tokens are Oracle-exclusive. %TYPE and %ROWTYPE were considered and rejected: PL/pgSQL
# supports both, so keying on them puts the false positive straight back. Do not add them.
#
# -q stops at the first match, which is FR-13: on a repository that is PL/SQL the scan ends at the
# first file, and only a tree with no Oracle token anywhere is read in full.
has_oracle_token() {
    grep -qriE 'VARCHAR2|DBMS_|PACKAGE[[:space:]]+BODY' \
        --include='*.sql' --include='*.plsql' \
        --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null
}
```

Then extend the condition inside `is_plsql_tree` to require it. This is the single final form of
that line, replacing both the version task 1 landed and the guarded version shown above; do not
apply them separately:

```bash
    [ "${sqlc:-0}" -ge 10 ] && [ "${sqlc:-0}" -gt "${othermax:-0}" ] && has_oracle_token
```

The grep sits behind the two cheap tests deliberately: a tree failing the count or the dominance
check never pays for it.

- [x] **Step 4: Run it and watch it pass** (318 passed 0 failed, shellcheck silent, full suite green. Read from the report, not witnessed by the coordinator)

Run: `tests/test-keel.sh`
Expected: PASS on all six token assertions and on `detect_languages on plsql-nomarker gives
nothing`, the latter for the right reason rather than by accident.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: no findings.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git commit -m "feat(detect): require an Oracle-exclusive token before reporting plsql"
```

---


**Task 2 outcome, 2026-08-18.** Committed as `fa43518`. `detects plsql-notdominant` passed without
first being seen to fail, as this task predicted; the implementer confirmed it can fail by deleting
the dominance clause and watching that one case go red while the other eleven stayed green, then
restored the file and byte-compared it. One edit beyond the plan text, accepted: the `is_plsql_tree`
header comment said "task 2 adds the fourth", which task 2 made false.

Two things noticed and correctly left alone. The `plsql` fixture comment claims the Oracle token
"sits in a subdirectory rather than the first file read", which `grep -r` does not guarantee; it
does not affect the assertion. And `has_oracle_token` is a second per-call walk: measured at 102 ms
over 800 `.sql` files with no token, about 0.8 seconds across one init. The cost decision is
recorded in task 4 rather than reopened.

## Task 2b: Close the set mismatch between the census and the token scan

**Story:** S-01, S-02. Corrective; added 2026-08-18 after task 2's code-quality review.
**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `tests/test-keel.sh`

**Interfaces:** no new function. `sql_census` and `has_oracle_token` keep their signatures.

**Done when:** `tests/test-keel.sh` passes including the three new mismatch assertions.

**Why this task exists.** Clauses 2 and 3 count one set of files and clause 4 scans a different one,
so a tree can satisfy the count and be invisible to the token check. The blocking case is uppercase:
`sql_census` lowercases the extension so `M1.SQL` counts, but `--include='*.sql'` is a case-sensitive
glob that `-i` does not touch. Verified 2026-08-18: 13 uppercase `.SQL` files with `PACKAGE BODY` and
`VARCHAR2` present censused as `13 0`, `has_oracle_token` exited 1, and detection returned nothing,
while the identical lowercase tree returned `plsql`. Uppercase is the most Oracle-flavoured
convention there is, being what SQL Developer and `exp` emit.

- [x] **Step 1: Write the failing test**

Add three fixture arms to `tests/test-keel.sh`, before `bare) : ;;`:

```bash
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
```

Extend the detection loop's stack list and its `case`:

```bash
for stack in plsql plsql-nomarker plsql-notdominant plsql-pkg plsql-small plsql-upper plsql-hidden plsql-dotend ts-migrations; do
```

```bash
      plsql-upper)       want="plsql " ;;
      plsql-hidden)      want="plsql " ;;
      plsql-dotend)      want="plsql " ;;
```

**Step 2: Run it and watch it fail.** Run `tests/test-keel.sh`. Expected: all three FAIL with
`got '', want 'plsql '`. `plsql-upper` fails on the token scan, the other two on the census.

- [x] **Step 3: Write the minimal implementation**

Replace the extension logic in `sql_census`. It now finds the **last** dot rather than the first, so
a dotted name with a real extension keeps it, and it skips an empty extension:

```bash
        { n = split($0, p, "/"); base = p[n]
          d = 0
          for (k = length(base); k > 1; k--) if (substr(base, k, 1) == ".") { d = k; break }
          if (d <= 1) next
          ext = tolower(substr(base, d + 1))
          if (ext == "") next
          if (ext == "sql" || ext == "plsql") { s++; next }
          if (ext == "pks" || ext == "pkb" || ext == "prc" || ext == "fnc") next
          c[ext]++; if (c[ext] > m) m = c[ext] }
```

`d <= 1` still skips `.gitignore`, whose only dot is at position 1, and now keeps `.oracle.sql`,
whose last dot is not.

Replace `has_oracle_token` entirely:

```bash
has_oracle_token() {
    local rc
    # Case-folded globs, not -i. The -i flag folds the pattern, never the --include glob, so an
    # all-uppercase Oracle tree passed the census and was invisible here. Verified on BSD grep
    # 2.6.0 and GNU grep 3.11: both match K.SQL, k.sql and k.PlSql, and reject k.txt.
    grep -qriE 'VARCHAR2|DBMS_|PACKAGE[[:blank:]]+BODY' \
        --include='*.[sS][qQ][lL]' --include='*.[pP][lL][sS][qQ][lL]' \
        --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null
    rc=$?
    [ "$rc" -eq 0 ] && return 0
    [ "$rc" -eq 1 ] && return 1
    # Anything above 1 means this grep rejected the options rather than finding nothing. busybox
    # grep does exactly that, so on an Alpine host every repository would be silently not-PL/SQL.
    # Fall back to a scan whose flags are all POSIX.
    find . \( -name node_modules -o -name .git \) -prune -o \
        -type f \( -name '*.[sS][qQ][lL]' -o -name '*.[pP][lL][sS][qQ][lL]' \) -print 2>/dev/null \
      | xargs grep -qiE 'VARCHAR2|DBMS_|PACKAGE[[:blank:]]+BODY' 2>/dev/null
}
```

`[[:blank:]]` rather than `[[:space:]]`, because grep is line-based and cannot match across a
newline; `[[:space:]]` implied a reach the code does not have.

Then correct two comments that claim more than the code delivers:

- The line calling the three tokens "Oracle-exclusive" is overstated. PostgreSQL's orafce extension
  really does provide `varchar2` and `dbms_output`, and a comment reading "these were VARCHAR2
  columns" matches too. Say they are not used natively by another dialect, outside comments and
  compatibility shims, and that this is an accepted heuristic.
- The `.pks`/`.pkb` exclusion comment says the idiomatic layout "went undetected", implying it is
  now detected in general. It is detected only when ten or more plain `.sql` also exist: 200 `.pkb`
  plus 9 `.sql` still censuses as `9 0` and returns nothing, because those extensions were removed
  from the denominator and never added to the evidence. Narrow the claim to what is true.

Finally, in `tests/test-keel.sh`, change `token_probe`'s loop encoding so it does not split on the
first colon. `:=` is PL/SQL's assignment operator, so the first probe containing `v NUMBER := 1;`
would silently truncate its own content and assert on something it never wrote. Use a separator that
cannot occur, such as `|`, or pass two positional arguments.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`. Expected: PASS on all three new cases and on every case task 1 and task 2
added, which must not regress.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`. Expected: no findings.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git commit -m "fix(detect): count and scan the same set of files"
```

---


**Task 2b outcome, 2026-08-18.** Committed as `9312ddb`, 321 passed 0 failed, shellcheck clean.

`plsql-hidden` **passed before the fix**, contradicting this task's prediction that all three would
fail. The implementer diagnosed it correctly: the old census skipped `.oracle.sql` but still counted
the twelve `m*.sql` as `12 0`, while the old `*.sql` glob did read `.oracle.sql` for the token, so
the old code returned `plsql` on evidence the census denied existed. That is the mismatch this task
describes, seen from the passing side. It is a regression guard, not a witnessed failure.

The implementer also surfaced a conflict this task created: shellcheck rejects `find | xargs`
without `-print0`/`-0` as SC2038, and this task required no findings. It kept the pipeline and added
a disable comment, and flagged the trade rather than choosing silently. That was the right call to
escalate, and the escalation was resolved against the plan: see task 3.

## Task 3: Prove the census costs nothing, and fix the fallback's filename handling

**Story:** S-03, plus a correction to task 2b
**Files:**
- Modify: `tests/test-keel.sh`
- Modify: `lib/detect-stack.sh`

**Interfaces:**
- Consumes: `sql_census` and `detect_languages` from tasks 1 and 2.
- Produces: nothing.

**Done when:** `tests/test-keel.sh` passes including the three cost assertions, and shellcheck is
clean with no `disable=SC2038` remaining in `lib/detect-stack.sh`.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, after the token block, add:

```bash
# NFR-01, NFR-02 and NFR-04, asserted as properties rather than as a clock. A timed test fails on a
# loaded CI runner for reasons unrelated to the code; these three do not.
#
# The census is not reached at all on a declared project. That is asserted by making the census
# impossible to run and checking detection still works: if the ordering ever inverts, this fails
# loudly instead of merely getting slower.
d="$(fixture ts-migrations)"
got="$( cd "$d" && bash -c '. "$1"; sql_census() { echo "CENSUS RAN"; exit 90; }; detect_languages | tr "\n" " "' \
        _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
[ "$got" = "typescript " ] \
  && ok "a declared project never reaches the census" \
  || bad "census ordering" "got '$got'; the census ran on a project with a manifest"
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
```

- [x] **Step 2: Run it and watch it fail** (no failure witnessed: all three passed, as this task predicted)

Run: `tests/test-keel.sh`
Expected: all three PASS, because tasks 1 and 2 already built the ordering and the prunes. These
assertions pin behaviour that is correct on the day they are written, which is the point: they fail
the day someone moves the census above the manifest checks or drops the `-prune`. Record in the tick
note that no failure was witnessed here, and confirm each can fail by temporarily removing the
`-prune` clause from `sql_census`, watching the second and third report, then restoring it. Do not
commit that removal.

- [x] **Step 3: Write the minimal implementation**

**Two corrections to `has_oracle_token`, and the first is a defect the previous fix would not have
caught.** Task 2b's code-quality review found both; both were reproduced before being written here.

**The fallback loses matches as soon as the file list needs more than one `xargs` batch.** `xargs`
runs the command once per batch and reports failure if **any** invocation exits non-zero, so
`xargs grep -q` returns non-zero whenever some batch lacks the token, even though an earlier batch
matched. Reproduced locally: 60 `.sql` files with the token in the first, forced into 20-file
batches, `rc=1`. busybox batches at roughly 200 files, and this marker already requires at least ten
`.sql` files, so on the layouts this feature targets the fallback would report not-PL/SQL on
essentially every real Oracle tree. **`-print0`/`-0` does not fix this**, which is what the previous
version of this task wrongly assumed: same tree, same forced batching, still `rc=1`.

Replace the fallback with a form that is tolerant of batching, and keep `-print0`/`-0` for the
filename handling that motivated the earlier rewrite:

```bash
    # -l into a non-empty test, not -q. xargs runs grep once per batch and fails if any batch fails,
    # so `xargs grep -q` loses a match found in an earlier batch: 60 files in 20-file batches with
    # the token in the first returned 1. Measured 2026-08-18. head -n 1 keeps the early stop.
    hit="$(find . \( -name node_modules -o -name .git \) -prune -o \
        -type f \( -name '*.[sS][qQ][lL]' -o -name '*.[pP][lL][sS][qQ][lL]' \) -print0 2>/dev/null \
      | xargs -0 grep -liE 'VARCHAR2|DBMS_|PACKAGE[[:blank:]]+BODY' 2>/dev/null | head -n 1)"
    [ -n "$hit" ]
```

Declare `hit` alongside `rc` on the existing `local` line, and delete the
`# shellcheck disable=SC2038`, which is no longer needed once `-print0` is used.

**Second, the comment above the dispatch is wrong.** It says anything above 1 means the grep rejected
the options. Both GNU and BSD grep also return 2 on an ordinary read error: reproduced with a
mode-000 file present and no match anywhere. So a permission-denied path on a mainstream platform
drops into the fallback too. Say that instead: a status above 1 means either the grep rejected
`--include` or something under the tree could not be read, that in both cases the answer is not
trustworthy, and that the fallback re-scans with flags every grep has.

**Third, simplify the census extension logic.** The loop added in task 2b is correct but its guard
`d <= 1` can never see 1, because the loop bound is `k > 1`, so the condition documents a rule the
bound already enforces. One `match` does the same job and folds both guards together:

```bash
        { n = split($0, p, "/"); base = p[n]
          if (!match(base, /\.[^.]+$/) || RSTART == 1) next
          ext = tolower(substr(base, RSTART + 1))
          if (ext == "sql" || ext == "plsql") { s++; next }
          if (ext == "pks" || ext == "pkb" || ext == "prc" || ext == "fnc") next
          c[ext]++; if (c[ext] > m) m = c[ext] }
```

Verified identical to the loop on eighteen name shapes, including `.sql`, `..sql`, `.a.sql`, `x.`,
`...`, `M1.SQL`, `weird.SqL`, `café.SQL` and `日本語.sql`. `RSTART == 1` is what excludes a bare
dotfile, and a name ending in a dot no longer needs its own `ext == ""` check because the pattern
requires at least one character after the dot.

**And add the sentence task 2b did not.** The change from `[[:space:]]` to `[[:blank:]]` rode in with
no comment, in a file whose standard is that every rule carries its reason. Say that grep is
line-based so a class including newline claims a reach the code does not have.

**One residual asymmetry stays, deliberately, and gets a comment rather than a fix.** A file named
exactly `.sql` is scanned by the token check but not counted by the census, so a tree could be
reported PL/SQL on evidence its own census does not acknowledge. The clean fix would be a glob
excluding bare dotfiles, and there is not a portable one: BSD matches `--include` against the full
path and GNU against the basename, so `?*.[sS][qQ][lL]` still matched `./.sql` here. The residue is
one file name, it can only produce a positive on a tree that is already SQL-dominant, and the
comment should say so.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all three.

- [x] **Step 5: Commit**

```bash
git add tests/test-keel.sh
git commit -m "test(detect): pin the census ordering and its prunes"
```

---


**Task 3 outcome, 2026-08-18.** Committed as `a7e8c45`, 324 passed 0 failed, shellcheck clean, no
`disable=SC2038` left. The implementer independently reproduced both review claims before writing
the code, including that `-print0`/`-0` does **not** fix the batching loss.

**The first cost assertion does not pin what it claims, and that is a defect in this task, not in
the implementation.** Its stub is `sql_census() { echo "CENSUS RAN"; exit 90; }`, and `exit 90` only
kills the command substitution inside `is_plsql_tree`; the caller then compares a non-numeric string
with `-ge 10`, the test errors, `is_plsql_tree` returns false, and the answer stays `typescript`.
Confirmed by building a mutant that calls `is_plsql_tree` as the first line of `detect_languages`,
the exact inversion the comment says it guards: the assertion still passed. A sentinel file survives
the substitution boundary and does detect it. The correction is in task 4.

This is the third check in this feature that could not fail for its stated reason, after the `FR-16`
doctor assertion and the validator's missing floor. All three were written by the planner, all three
read as coverage, and none of them was caught by reading.

**Task 3's code-quality pass was run by the coordinator, not independently, and that is a reduction
in rigour worth recording.** Two dispatched reviewers died on transient API 529 errors, the second
after being told what had already been covered. Rather than block, the coordinator ran the checks
itself: `local` not clobbering `$?` on bash 3.2.57, no SIGPIPE noise from `head -n 1`, no hang on an
empty tree or on `xargs -0` with empty input, the fallback finding a token in the last of 500 files
under forced 20-file batches, filenames containing a newline and a single quote, `find` and `grep`
pruning identically, `awk match()` on names with regex metacharacters, and agreement between the
primary and fallback paths on `x.SQL.bak`, `a.sql.tmp`, a directory named `dir.sql`, a symlink and a
hard link. Nothing blocking.

**busybox was exercised end to end for the first time**, in `alpine:latest`: `grep --include`
returns 2, the dispatch reaches the fallback, and it finds the token in a 501-file tree spanning
several batches while staying empty on a token-free tree. That is the blocking defect confirmed fixed
on the one platform the fallback exists for.

One residual accepted: if the only token sits in an unreadable directory the function reports no
token, which is indistinguishable from genuine absence. The direction is safe, since a false negative
means a skill asks. Every blocking finding in this work came from an independent reviewer and none
from the coordinator's own reading, so this pass should be treated as weaker evidence than the two
before it.

## Task 4: The stack row, and the APEX framework

**Story:** S-04
**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `plsql` from `detect_languages`.
- Produces: `lang_profile plsql` output `plsql oracle <framework> none`, consumed by `detect_stack`
  and written into the profile by `bin/keel`.

**Done when:** `tests/test-keel.sh` passes including the three stack assertions and the
end-to-end init assertion, and `tests/run-tests.sh` is green.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, after the cost block, add:

```bash
# The APEX marker is keel's own output: lib/apex_render.py writes manifest.json with an apex_version
# key, pinned by tests/test-apex-export.sh. Keying on a file keel writes itself is why this cannot
# false-positive, and the third case is what keeps any other manifest.json from claiming it.
for spec in 'none::an ordinary PL/SQL project' \
            'apex:{"apex_version":"23.2"}:an APEX export tree' \
            'none:{"name":"something-else"}:a manifest.json that is not an APEX export'; do
    want="${spec%%:*}"; rest="${spec#*:}"; manifest="${rest%:*}"; label="${rest##*:}"
    d="$(fixture plsql)"
    [ -n "$manifest" ] && printf '%s\n' "$manifest" > "$d/manifest.json"
    got="$( cd "$d" && bash -c '. "$1"; lang_profile plsql' _ "$ROOT/lib/detect-stack.sh" 2>/dev/null )"
    [ "$got" = "plsql oracle $want none" ] \
      && ok "$label gives framework $want" \
      || bad "lang_profile plsql" "$label gave '$got', want 'plsql oracle $want none'"
    rm -rf "$d"
done
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on all three, each reporting `gave 'unknown unknown none none'`. That is the
catch-all arm of `lang_profile`, which is what an unrecognised language gets today.

- [x] **Step 3: Write the minimal implementation**

**First, one comment correction.** The `NOT MEMOISED` paragraph in `is_plsql_tree` explains the cost
decision for `sql_census` only, and task 2 added a second walk beside it. Append to that paragraph:

```bash
# The same applies to has_oracle_token, which is the second walk and the more expensive one. Its
# worst case is a large manifest-less SQL tree with no Oracle token anywhere, where grep reads every
# file and finds nothing: measured on 2026-08-18 at 102 ms over 800 .sql files, so about 0.8 seconds
# across the eight calls of one init. A tree that fails the count or the dominance test never
# reaches it, and a tree that is genuinely PL/SQL stops at the first match.
```

**Now the task's own work.** In `lib/detect-stack.sh`, in `lang_profile`, add an arm immediately
before the `*)` catch-all:

```bash
      plsql)
        # The framework marker is keel's own apex-export output, written by lib/apex_render.py, so
        # it is self-declaring and cannot be claimed by another tool's manifest.json. The
        # apex_version key is what distinguishes it, not the filename.
        local fw=none
        grep -q '"apex_version"' manifest.json 2>/dev/null && fw=apex
        # No package manager exists for PL/SQL. `none` is the honest value and it is what a skill
        # reads to know not to look for one.
        printf 'plsql oracle %s none\n' "$fw" ;;
```

**First, replace task 3's broken ordering assertion.** As written it passes against an inverted
`detect_languages` and therefore pins nothing. Replace the whole `a declared project never reaches
the census` block with:

```bash
# The census must not run at all on a project that declares itself, FR-04. The stub records itself
# in a file rather than exiting: sql_census is called through census="$(sql_census)", so an exit
# inside it only kills the substitution and the caller carries on, which is why the previous version
# of this assertion passed even against a detect_languages that ran the census first. Verified
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
```

Confirm it can fail: move the `is_plsql_tree` call to the first line of `detect_languages`, watch
this one case report `the census ran`, then restore. The old version passed that mutant.

**Then** add the end-to-end assertion, in the style of the existing detection loop at `:70-87`,
because until this task nothing in the plan asserted the goal the plan states. Verified on 2026-08-18: before this
task, `keel init` on the `plsql` fixture writes `"language": "unknown"`, since `lang_profile` falls
through to its catch-all.

```bash
# The end to end claim, which no other assertion makes: init writes the language into the profile.
# detect_languages returning plsql is not the same thing, and until lang_profile gained its arm the
# profile said unknown on a repository the detector had already classified.
d="$(fixture plsql)"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(python3 -c "import json;s=json.load(open('$d/.keel/profile.json'))['stack'];print(s['language'],s['runtime'])" 2>/dev/null)"
[ "$got" = "plsql oracle" ] && ok "keel init writes plsql and oracle into the profile" \
  || bad "init plsql" "profile says '$got', want 'plsql oracle'"
rm -rf "$d"
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: no findings.

Then run the full suite: `tests/run-tests.sh`.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git commit -m "feat(detect): stack row for plsql, with apex as the framework on a keel export"
```

---

## Task 5: Oracle as the datastore

**Story:** S-05
**Files:**
- Modify: `lib/detect-stack.sh`
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: `detect_languages` from tasks 1 and 2.
- Produces: `oracle` in `detect_datastores` output.

**Done when:** `tests/test-keel.sh` passes including the three datastore assertions.

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, after the stack block, add:

```bash
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
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on the first, `got '', want 'oracle '`. The second and third pass already, and the
third is the regression guard for the existing route.

- [x] **Step 3: Write the minimal implementation**

In `lib/detect-stack.sh`, in `detect_datastores`, replace the early return at the line reading
`[ -z "$files" ] && return 0` with:

```bash
    # PL/SQL first, and outside the manifest loop below. That loop greps dependency files, and a
    # PL/SQL repository has none, so a ninth pair in the list could never fire. CON-04.
    case " $(detect_languages | xargs) " in
      *" plsql "*) printf 'oracle\n' ;;
    esac
    [ -z "$files" ] && return 0
```

`xargs` with no command joins the lines with spaces, and it is already used three times in this
file.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all three.

Run: `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: no findings.

- [x] **Step 5: Commit**

```bash
git add lib/detect-stack.sh tests/test-keel.sh
git commit -m "feat(detect): oracle as the datastore for a PL/SQL project"
```

---

## Task 6: Prove no verify command is invented

**Story:** S-06
**Files:**
- Modify: `tests/test-keel.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

**Done when:** `tests/test-keel.sh` passes the verify assertion.

The tool table rows moved to task 1, because the build gate couples them to the language. The full
suite is not run here: this task asserts an absence and changes no code, so task 7's run is the gate.

- [x] **Step 1: Write the failing test**

`S-06` is a `verify` story: the behaviour is believed correct already, because `detect_verify` is
keyed on manifests and a PL/SQL repository has none. The test is what is missing.

In `tests/test-keel.sh`, after the datastore block, add:

```bash
# CON-02 and FR-08. utPLSQL runs inside a database and the connection string, schema and credentials
# are nowhere in the repository, so no command can be written. The fixture carries a real utPLSQL
# suite on purpose: it is the case most likely to tempt a future change into guessing one.
d="$(fixture plsql)"
mkdir -p "$d/tests"
printf 'BEGIN ut.run(); END;\n/\n' > "$d/tests/run_all_tests.sql"
( cd "$d" && "$KEEL" init -y >/dev/null 2>&1 )
got="$(python3 -c "
import json
v=json.load(open('$d/.keel/profile.json'))['verify']
print(' '.join(k for k in ('test','test_one','lint','typecheck','build') if v.get(k) is not None))" 2>/dev/null)"
[ -z "$got" ] && ok "a PL/SQL project gets no invented verify command" \
  || bad "verify" "these were written rather than left null: $got"
rm -rf "$d"
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: PASS, for the reason in step 1. This asserts an absence, so it passes the day it is
written and earns its keep the day somebody adds a PL/SQL branch to `detect_verify`. Record that in
the tick note rather than claiming a failure you did not see.

To confirm it can fail, temporarily add `printf 'sqlplus @tests/run_all_tests.sql\n'` as the first
line of `detect_verify` in `lib/detect-stack.sh`, run the case, watch it report a written command,
then restore the file and confirm `git diff --stat lib/detect-stack.sh` is empty.

- [x] **Step 3: Write the minimal implementation**

There is none. This task asserts behaviour that is already correct: `detect_verify` is keyed on
manifests, so a PL/SQL repository yields nothing for every verify key.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on the verify assertion.

- [x] **Step 5: Commit**

```bash
git add tests/test-keel.sh
git commit -m "test(detect): pin null verify commands for a PL/SQL project"
```

---

## Task 7: Documentation and the release note

**Story:** none. Release hygiene, named as such rather than traced to a story it does not serve.
**Files:**
- Modify: `CHANGELOG.md`
- Modify: `templates/profile.schema.json`, and regenerate `docs/profile-keys.md`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `docs/06-repo-layout.md` if it enumerates the detected languages; check before editing

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

**Done when:** `tests/run-tests.sh` is green, which includes `tests/test-doc-claims.sh` and
`tests/no-internal-leaks.sh` against both files.

- [x] **Step 1: There is no test for this**

Release documentation. `tests/test-doc-claims.sh` and `tests/no-internal-leaks.sh` already run
against these files and are the only automatable checks that apply.

- [x] **Step 2: Run them and watch them pass**

Run: `tests/test-doc-claims.sh`
Expected: PASS, before the edit.

**The profile schema now states the opposite of what the code does, and this task is where it gets
fixed.** `templates/profile.schema.json` describes `stack.language` as "Detected from a declared
manifest such as package.json or go.mod, **never from counting source files**". This work is exactly
what falsifies that sentence, and the text is generated verbatim into `docs/profile-keys.md`.
Rewrite the description so it says what is true now, for example that it is read from a declared
manifest for every language except PL/SQL, which has no manifest format and is inferred from the
shape of the tree instead, and that `unknown` still means a skill asks rather than guessing. Then
regenerate the page with `bash tests/generate-profile-keys.sh > docs/profile-keys.md`.

Changing a description does not move `SCHEMA_VERSION`: the validator fingerprints key paths and not
descriptions, which `docs/prd/usable-profile.md` `CON-01` records.

`docs/03-install-and-distribution.md:210-227` is a `Signal | Inferred` table with a row per detected
language. Every existing row keys on a declared file and pairs the language with a language server;
PL/SQL has neither, so its row has to say so or it reads as an omission. Add this row immediately
after the `.luarc.json` row and before the `More than one of the above` row:

```markdown
| No manifest for any of the above, and `.sql` plus `.plsql` dominating the tree with an Oracle-exclusive token present | PL/SQL, `oracle` as the datastore, and no language server, because none exists for it |
```

**Do not go looking for a stated language count.** An earlier version of this step told you to grep
for `thirteen\|13 languages` and treat every hit as a document to update. That grep was run on
2026-08-18 and returns four hits, none of which is about the language count: `docs/03:177` is about
`CLAUDE_*` environment variables, `docs/runbooks/going-public.md:96` and `docs/07:137` are about a
rename that touched thirteen references, and `docs/05:3` is about the other thirteen requirements.
No document states how many languages are detected, so there is no count to update. The word
`thirteen` in `lib/detect-stack.sh` is correct as it stands and means the thirteen manifest-declared
languages, of which PL/SQL is deliberately not one.

- [x] **Step 3: Write the minimal implementation**

In `CHANGELOG.md`, under the unreleased heading, add to the existing `### Added` block:

```markdown
- PL/SQL detection. A repository with no manifest for any other language, where `.sql` and `.plsql`
  dominate the tree and at least one file carries an Oracle-exclusive token, is detected as `plsql`
  with `oracle` as its datastore. Every verify command stays `null`, because utPLSQL runs inside a
  database and the connection details are not in the repository, so the profile still needs
  finishing by hand.
```

Then update any document the grep in step 2 found, changing the count and naming PL/SQL as inferred
rather than declared.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: green, including `tests/test-doc-claims.sh` and `tests/no-internal-leaks.sh`.

- [x] **Step 5: Commit**

```bash
git add CHANGELOG.md docs/
git commit -m "docs(release): record PL/SQL detection"
```

---

## Story coverage

| Story | Kind | Tasks |
|---|---|---|
| S-01 Report `plsql` on a manifest-less, SQL-dominant tree | build | 1 |
| S-02 Require an Oracle-exclusive token | build | 2 |
| S-03 Pay nothing for the census on a declared project | build | 3 |
| S-04 Fill in the stack row | build | 4 |
| S-05 Record Oracle as the datastore | build | 5 |
| S-06 Leave every verify command null | verify | 6 |
| S-07 Answer PL/SQL in all three tool tables | build | 1 |
| S-08 Decide whether the token set is wide enough | decide | **none** |

Seven of eight stories map to a task. `S-08` deliberately does not: it is a `decide` story whose
answer needs a real Oracle repository that is not reachable from here, and it blocks nothing. It
stays in the backlog with an owner rather than being planned as work that cannot be done.

`S-07` sits in task 1 rather than in a task of its own, because `tests/validate-skills.sh` fails the
build the moment a language is added without its tooling answer. The gate is designed to make them
land together, so the plan does too.

## What this plan could not settle

- **`A7` remains unchecked**, and `S-08` owns it. An Oracle codebase of pure table DDL using none of
  `VARCHAR2`, `DBMS_` or `PACKAGE BODY` is missed by clause 4. Neither known Oracle repository was
  reachable while this was written, so the token set is reasoned rather than measured.
- **`A6` remains unchecked.** Whether two repositories justify a fourteenth language is not
  established anywhere, and nothing in this plan establishes it.
- **The floor of ten is a chosen number**, not a measured one. Both known instances are far above it,
  at 191 and 1,129 files, so no evidence distinguishes ten from five or twenty.

---

## Execution record, 2026-08-18

All eight tasks landed. Final gate: `tests/run-tests.sh` 616 assertions, 0 failures, supply chain
clean, shellcheck clean.

| Task | Commit |
|---|---|
| 1 and S-07 | `c7b88dd` |
| 2 | `fa43518` |
| 2b | `9312ddb` |
| 3 | `a7e8c45` |
| 4 | `4171d04` |
| 5 and 6 | `e75ff28` |
| 7 | this commit |

**Mode changed partway.** Tasks 1 to 3 ran delegated with two review passes each; tasks 4 to 7 ran
inline at the requester's direction, after delegated mode proved slower for comparable work. The
trade is real and worth recording: both blocking defects in this work were found by independent
reviewers and none by the coordinator's own reading. Inline kept mutation testing, which is what
caught the three checks that could not fail, but dropped the independent pass.

**Two deviations from the plan's own rules, neither hidden.**

Task 5's assertion was written after its implementation, so it was never witnessed failing in the
suite. It was proven to discriminate afterwards by running it against the previous commit's library.
That is reconstruction, not a witnessed red, and it happened because the coordinator worked ahead
during a test run.

Task 3's code-quality pass was run by the coordinator rather than an independent reviewer, after two
dispatched reviewers died on transient API errors.

**Thirteen plan defects were found and fixed during execution**, every one authored by the planner
rather than by an implementer. Three were checks that could not fail for their stated reasons; two
were fixes that themselves needed fixing; one was a claim about how `keel` calls its own code that
did not survive instrumentation. The parts of the plan that were prototyped end to end before
writing held up; the parts reasoned about in prose did not.

## Post-audit code review, 2026-08-18

`keel:ship`'s gate ran `security-audit --diff` (clean, `docs/audits/2026-08-18-security-plsql-stack-detection.md`)
then `code-review high 9b52a3a..HEAD`. The first delegated review died on a connection error; the
retry completed and returned 9 findings, 0 blocking. The user chose to fix all 9 before shipping.
Two were verified as real correctness/consistency gaps in this diff's own scope, confirmed by
reading the cited lines directly:

1. `detect_has_ui`'s framework allowlist did not include `apex`, so an APEX export (UI lives in the
   database, no local `public/`/`index.html`) got `has_ui: false`. **Fixed.**
2. `detect_datastores` re-ran the entire `detect_languages` cascade (including both PL/SQL tree
   walks) to test membership, contradicting the precedent `detect_verify` already set in this same
   file for exactly this reason (language passed in by the caller, which already knows it). **Fixed**:
   now takes `lang` as an optional first argument; `write_profile` (`bin/keel:358`) passes it.
3. `lang_profile`'s APEX marker was a bare substring grep on `manifest.json`, so a value equal to the
   string `apex_version` (not a key) would false-positive, contradicting the comment's own claim.
   **Fixed**: anchored to `"apex_version"[[:space:]]*:`.
4. `has_oracle_token`'s `xargs -0 grep` fallback can hang on empty input on GNU/Linux (BSD/macOS
   xargs does not invoke the command on empty stdin, which is why it went unnoticed on this dev
   machine). **Fixed**: a `-print -quit` presence check (the same idiom `find_marker` already uses)
   now runs before xargs is invoked at all. **The regression test for this could not be watched RED
   locally**: BSD xargs already returns quickly on empty input, so both the buggy and fixed code
   give the same observable result on this machine. The fix is verified by direct reasoning about
   GNU xargs's documented behaviour, not a locally-witnessed failure, the same category of disclosed
   gap as Task 5 above.
5. Three comments (the big block above `is_plsql_tree`, and two PL/SQL test fixtures) narrated the
   review history that produced them ("two earlier versions of this comment... were both wrong",
   "task 1 did not implement it", "before the census change in this task it was not"), violating this
   project's own `CLAUDE.md` rule that a document states what is true now. **Partially fixed**: the
   `is_plsql_tree` block is rewritten and its call count re-traced (now **eight**, not nine, since
   fix 2 above removes `detect_datastores`'s own walk. Re-traced with the same FUNCNAME
   instrumentation the original count used, not reasoned about). **Now fully fixed**: the
   `plsql-notdominant` and `plsql-pkg` fixture comments are rewritten to state what each fixture
   pins, and `plsql-nomarker`'s comment, which carried the same defect and was not in the review's
   list, was rewritten with them.
6. `sql_census` uses `-print` (newline-delimited) where its sibling `has_oracle_token`'s fallback
   deliberately uses `-print0`, flagged as an inconsistency. **Investigated, not applied as
   suggested**: switching `sql_census` to `-print0`/`RS="\0"` would break it on macOS's default
   `/usr/bin/awk`, confirmed directly: `printf 'a\0b\0c\0' | awk 'BEGIN{RS="\0"}{print}'` prints only
   the first record and silently drops the rest. Unlike `grep`/`xargs`, this project's `awk` cannot
   be assumed to support NUL-separated records portably. **Now fixed**: `sql_census`'s docstring
   carries a paragraph recording the reason, the reproduction, and what the choice costs (a filename
   containing a newline can move a count by one).
7. PRD `FR-01`'s wording omits the `.pks`/`.pkb`/`.prc`/`.fnc` exclusion `sql_census` actually
   implements. **Fixed**: `FR-01` now states that neither extensionless files nor the four package
   extensions count as a competing extension, with the "12 30" census that motivated it in the
   evidence column and a pointer to `A2`, which already ruled those extensions out as markers.
8. The `\( -name node_modules -o -name .git \) -prune -o` prune clause is now duplicated three times
   in `lib/detect-stack.sh` (one pre-existing in `find_marker`, two added by this diff). **Investigated
   a shared-variable extraction, decided against it**: passing the clause through a variable requires
   *unescaped* `(`/`)` in the variable (the shell only strips a literal `\(` typed on a command line,
   not one read back out of a variable via word-splitting, verified by direct test, and got this
   wrong once while checking it). Given how easy that is to get subtly wrong, and that this is a
   maintainability nit rather than a correctness issue, decided to leave the duplication rather than
   risk a fragile abstraction. Accepted, not fixed; name this in the PR body as a named exception.
9. `has_oracle_token`'s `rc>1` branch treats "busybox rejected `--include`" and "a genuine read
   error" the same way, with no diagnostic if `grep` is entirely missing (`rc=127`). **Decided not to
   fix**: `grep` is a pervasive, pre-existing assumption throughout this whole file (dozens of call
   sites), not something specific to the PL/SQL addition; fixing it only here would be inconsistent
   with the rest of the file. Accepted, not fixed; name this in the PR body as a named exception.

All nine findings are now closed: 1 to 7 fixed, 8 and 9 accepted as named exceptions.

The first full suite run after those fixes was **red**, and not on any of them: `validate-skills.sh`
rejected this file for containing four em dashes, written into the section above when it was drafted.
The project forbids them and its own test enforces it on its own documents. Fixed as a mechanical
formatting change, no wording altered, and the suite re-run to `exit 0`, "All test files passed",
619 assertions across 12 files. Recorded because the handoff's "last run was green" was true of a
tree that did not yet contain this section, which is the reason the gate reruns instead of trusting
a remembered result. The `ship`
gate resumes from here (full suite, shellcheck, commit, push, PR), with 8 and 9 named in the PR body
per the `ship` skill's override rule.
