# Test speed is managed, not only reported Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> Task 1 is test-first under `keel:tdd`. Task 2 changes skill text and docs and carries no failing
> test; each behaviour's example is the wording it must produce, checked by the commands in
> `Done when:` and by a reviewer.

**Goal:** a slow suite is named as a cost, and a project with a runner that can select the tests a
change affects stops paying for the whole suite at every `tdd` unit boundary. `keel doctor` warns
when `verify.test` takes longer than a threshold (60 seconds unless the profile raises it) and says
what that costs; an optional `verify.test_affected` runs at the unit boundary instead of the suite,
which still runs in `review-code`, `ship` and CI.
**Stories:** none. A change to keel's own process, specified by a decided idea record.
**ADRs:** ADR-0009, written by task 1 so the decision precedes the code that cites it, amends
ADR-0006's boundary run: the boundary may run the affected tests, and a red it shows that the start
record does not hold is no longer assumed to be the current unit's. ADR-0006 is otherwise unchanged
and the iron law is untouched. ADR-0001 governs the `tdd` body edit; ADR-0002 holds (the
coordinator writes no code).
**Architecture:** two profile keys. `verify.test_affected` is a command template in which `{base}`
is the commit the unit started from, the commit the `tdd` start record already names (for example
`npx vitest run --changed {base}` or `npx jest --changedSince={base}`). The command must select
from uncommitted and untracked changes too, because under `execute-plan` an implementer stages and
does not commit, so every unit of a task shares one `HEAD`. It is set by hand, so `keel init` writes
it as null. `gates.suite_warn_seconds` is the threshold, following `gates.context_warn_pct`'s
precedent of a number under `gates`; `keel init` writes 60, because `keel profile set` refuses a
path the profile does not hold, and absent still reads as 60 for older profiles. Adding two keys
moves `SCHEMA_VERSION` from 5 to 6, which `tests/validate-skills.sh`'s schema fingerprint requires.
`doctor` already times `verify.test` (`bin/keel#good "verify.$k runs (${el}s): $c"`); the
warning is one comparison after that line.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Decided:** Bernard, 2026-10-16, choosing among options put to him, recorded as "Decided" item 5 by
task 2: warn at 60 seconds, overridable in the profile; `verify.test_affected` replaces the suite at
the `tdd` unit boundary when set, with the full suite still in `review-code`, `ship` and CI, under
a new ADR; set by hand only, with no detection in `keel init`.
**Shape:** behaviours with examples, as gap 1 decided.
**Reviewed:** by a dispatched plan reviewer on 2026-10-16; "What the review changed" records it.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). If `command -v shellcheck` prints nothing,
  say the lint was not run and that CI will run it.
- **`tests/run-tests.sh` takes about 3 minutes.** Run it in the background and read its log to the
  end within one tool call.
- **Precondition: the working tree is clean and nothing is staged.** Each commit stages named paths
  only, checked with `git diff --cached --name-only`. Never `git add -A`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Every commit carries its own documentation, `CHANGELOG.md` included.
- Commits carry no attribution footers; this repository sets `conventions.no_attribution_footers`.
- No vendor model alias under `skills/`.
- **Skill bodies.** `tdd` is at 855 words and stays at or below 900. A body edit to one over 700
  words owes an ADR-0001 eval arm, recorded as owed in `CHANGELOG.md`.
- **Line citations.** Cite by phrase (`file#phrase`), not by line number, in anything this plan
  writes. After each edit, `grep -rn '<file>:[0-9]' docs skills README.md` for each edited file and
  keep cited lines on their text, or repoint them to a phrase. `docs/02-skill-catalog.md` keeps its
  627 lines.
- **Plans are scanned for links.** `tests/validate-skills.sh` checks markdown links in
  `docs/plans/`; write paths in backticks, never as links, in this plan and its examples.
- **Every comment and rule carries its reason**, as `bin/keel`'s comments do.
- **`doctor`'s interpreter budget.** `tests/test-keel.sh` caps full `doctor` at 10 `python3`
  starts ("keel doctor starts python3 at most 10 times") and it is at 9. Read the new keys without
  adding a start, through whatever batched read `doctor` already makes, or say why that is
  impossible before raising the cap.
- **Live citations into `bin/keel`.** An insertion moves every `bin/keel:NNN` citation below it.
  `tests/validate-citations.sh` must pass, and the live ones past the doctor loop
  (`docs/stories/profile-sync.md` and `docs/prd/profile-sync.md` cite `bin/keel:2246`) are checked
  and repointed to a phrase if they moved. Records under `docs/plans/`, `docs/audits/`,
  `docs/ideas/` and `tests/evals/results.md` are history and stay as written.

## What this plan does not build

- **No detection.** `keel init` writes `verify.test_affected` as null for every stack; detecting it
  from a runner is left until a project has used one.
- **No change to where the full suite runs** outside the `tdd` boundary: `review-code`, `ship`,
  `debug`, `refactor`, the parallel-batch join and CI keep `verify.test`. Each `tdd` session's first
  start record still costs one full run, once per task under `execute-plan`.
- **No new `test_one` check.** Gap 2 also asked `doctor` to warn when `verify.test_one` is null; it
  already fails then (`bin/keel#It is required: the commit guard and tdd both need it`), which is
  stronger, so nothing changes.
- **No measurement.** `keel plan report` does not record suite time; `doctor` is where it is seen.
- **No change to `doctor --fast`**, which runs no verify command and so has no time to compare; a
  bad `gates.suite_warn_seconds` is reported by full `doctor` only.
- **No rework threshold.** "Not decided here" keeps the question of how long after delivery a fix
  counts as rework.

---

### Task 1: the decision, the profile keys and `doctor`'s warning

**Story:** none.
**Files:**
- Create: `docs/decisions/ADR-0009-the-unit-boundary-may-run-the-affected-tests.md`
- Modify: `bin/keel`, `templates/profile.schema.json`, `templates/keel-profile.example.json`,
  `docs/profile-keys.md` (regenerated with `tests/generate-profile-keys.sh`, never by hand),
  `.keel/profile.json`, `tests/test-keel.sh`, `tests/test-doc-claims.sh`,
  `tests/validate-skills.sh`, `CHANGELOG.md`, any index listing ADRs (find it with
  `grep -rln 'ADR-0008' docs README.md`), and the files of any citation repointed under the global
  constraint

**Interfaces:**
- Produces: `verify.test_affected` (string or null; `{base}` is substituted with a commit) and
  `gates.suite_warn_seconds` (integer, at least 1; absent means 60), both in the schema with an
  `x-keel-read-by` (doctor's reader; task 2 adds `tdd`'s). Task 2's `tdd` text reads the first and
  carries out ADR-0009.

**Depends on:** none

**Behaviours:**

1. **ADR-0009** (status accepted; deciders Bernard, 2026-10-16) states:
   - the context: ADR-0006 measured 313 seconds for the suite against 2 for one test; keel's suite
     takes about 170 now, and a ten-unit change pays it ten times plus review and `ship`;
   - the decision: the unit boundary runs `verify.test_affected` with `{base}` when the profile sets
     it, else `verify.test`; with no VCS, or when the affected run did not run the unit's own cases,
     it runs `verify.test`; the first start record still costs one full `verify.test`, and its reds
     carry forward, dropping any later seen passing;
   - what it amends in ADR-0006, by phrase: "A boundary red the start record does not hold is one
     this unit caused" no longer holds under an affected run, because a break made by an earlier
     unit outside its own selection can first show at a later unit's; such a red goes to
     `keel:debug` naming every unit since the first start record as a possible cause;
   - consequences: a break outside what the runner selects surfaces at `review-code`; the
     selection's accuracy is the runner's, so a runner that misses a dependency hides a break until
     then; the command must select uncommitted and untracked changes since `{base}`; the iron law is
     untouched. It cites by phrase.
2. **The keys exist and init writes both.** `SCHEMA_VERSION` is 6. `keel init` on a fresh fixture
   writes `"test_affected": null` inside `verify` (it joins `VERIFY_KEYS`) and
   `"suite_warn_seconds": 60` inside `gates`; re-running init keeps a value a person set.
   `schema_fingerprint_for` in `tests/validate-skills.sh` gains a `6)` line with the new hash and
   its `5)` line is untouched. The pins move to 6, each comment naming this plan: "SCHEMA_VERSION is
   where" in `tests/test-doc-claims.sh` and "init writes schema version 5" in `tests/test-keel.sh`.
   keel's own `.keel/profile.json` is at schema 6 with both keys, so keel's doctor does not call it
   stale.
3. **A slow suite warns, and says what it costs.** After a passing `verify.test` run that took more
   than the threshold, with `verify.test_affected` null, full `doctor` keeps its
   `verify.test runs (Ns)` line and adds a warning:
   `verify.test took 170s, over gates.suite_warn_seconds (60s): tdd runs it at every unit boundary,
   so ten units spend about 28 minutes in it. Set verify.test_affected, or raise
   gates.suite_warn_seconds if 170s is this suite's honest cost.` The minutes are
   `(seconds * 10 + 30) / 60` in whole numbers, and "under a minute" when that is 0. A run that
   fails or times out gets its existing line and no warning. Tested with `gates.suite_warn_seconds:
   1` and a suite of `sleep 2`, matching `verify.test took [0-9]+s, over
   gates.suite_warn_seconds \(1s\)`, because `$SECONDS` gives 2 or 3.
4. **At or under the threshold, nothing new is said.** Tested with a suite of `true` under the
   default 60. The threshold is exclusive (a run equal to it does not warn), checked by a reviewer
   reading the comparison, since no real run lands on it reliably.
5. **A suite managed by `test_affected` is not warned about.** With `verify.test_affected` set and
   the suite over the threshold, the line is `ok`, not a warning, and says why:
   `verify.test takes 170s, over 60s; tdd runs verify.test_affected at unit boundaries instead, so
   the suite runs once at the start of each task, in review-code, ship and CI`. If
   `verify.test_affected` is the same string as `verify.test`, it saves nothing, so the behaviour 3
   warning fires and says so.
6. **A bad threshold is named, not obeyed.** A `gates.suite_warn_seconds` that is not a whole
   number of at least 1 (`0`, `"fast"`) gives a warning naming the key and its value and saying 60
   was used. A string of digits (`"90"`) reads as that number.
7. **`verify.test_affected` is reported, never run, by `doctor`.** Null is `ok`:
   `verify.test_affected is null: tdd runs verify.test at each unit boundary`. Set, it is `ok` and
   shown, under full `doctor` and `--fast` alike, as `verify.e2e`'s line is. `doctor` does not
   execute it, because it needs a commit only a `tdd` unit has: tested with
   `touch affected-ran-sentinel {base}` leaving no file. A value without `{base}` is accepted (a
   runner may track changes itself).
8. **Templated keys stay out of the places that run bare commands.** The CI writer and the pre-push
   loosening check skip `test_affected` as they skip `test_one`, each with its reason in the
   comment: it is a template, and dropping it makes the boundary run wider, not narrower. Tested:
   with `test_affected` set, the generated CI workflow has no line containing `{base}`; a push
   changing `test_affected` from a command to null is not refused by the hook body. The commit
   guard's fast subset is unchanged.
9. **`CHANGELOG.md`:** an Unreleased entry saying the schema moved to 6 (re-run `keel init`, which
   merges), what the two keys do, and ADR-0009.

**Done when:** all of these:
- The new cases in `tests/test-keel.sh` were watched to fail before the code, and pass now.
- `tests/validate-skills.sh` prints `OK` (the fingerprint and the profile-keys page match).
- `bash tests/test-doc-claims.sh` and `tests/validate-citations.sh` pass.
- `grep -c 'test_affected' templates/profile.schema.json` and
  `grep -c 'suite_warn_seconds' templates/profile.schema.json` each print at least 1.
- `bin/keel doctor` in this repository prints the behaviour 3 warning for its own suite; the
  warning is true, so this plan does not silence it.
- A reviewer finds behaviours 1 to 9, and the exclusive comparison of behaviour 4.

- [x] **Step 1.1: Write ADR-0009** for behaviour 1, and add it to any ADR index.
- [x] **Step 1.2: Write the failing cases** for behaviours 2 to 8 in `tests/test-keel.sh` and the
  pins, and watch them fail for the missing change.
- [x] **Step 1.3: Make them pass** in `bin/keel`, the schema, the fingerprint, the example profile
  and keel's own profile; regenerate `docs/profile-keys.md`; repoint any moved live citation.
- [x] **Step 1.4: Check and stage.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: full; attempt 1 discarded on spec DEVIATES (a 123-column line) with quality findings attached, attempt 2 spec COMPLIES and quality nothing blocking; two should-fix left for review-code (python3-starts case never reaches the threshold read, an unexplained deleted blank line); full run-tests.sh passed in the reviewer's run (163s)
  Stage every file named under **Files:** that changed, by path, show `git status --porcelain`, and
  stop. The coordinator ticks and commits, with this plan:
  `feat(doctor): a slow suite is named as a cost, and verify.test_affected is declared`.

---

### Task 2: the unit boundary runs the affected tests when the profile names them

**Story:** none.
**Files:**
- Create (if the body cannot hold the detail): `skills/tdd/references/affected-tests.md`
- Modify: `skills/tdd/SKILL.md`, `skills/write-plan/references/plan-template.md`,
  `skills/review-code/SKILL.md`, `templates/profile.schema.json` (one `x-keel-read-by`),
  `docs/profile-keys.md` (regenerated), `docs/02-skill-catalog.md`,
  `docs/ideas/delivery-flow-gaps.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: `verify.test_affected` and its `{base}` from task 1, and ADR-0009's decision.

**Depends on:** task 1

**Behaviours:**

1. **`tdd` names the key.** "Commands come from the profile" adds `verify.test_affected`, the tests
   a change since `{base}` affects.
2. **`tdd`'s boundary runs it.** "Unit boundary: run the suite" reads, in substance: the unit ends
   with one `verify.test_affected` run when the profile sets it, `{base}` filled with the start
   record's commit, else one `verify.test`; because it runs what the unit could have broken, and the
   full suite still runs in `review-code` and `ship`. With no VCS, or when the run's output does not
   show the unit's own cases ran (a runner that did not select a new test file), the boundary runs
   `verify.test`. The heading may change to fit.
3. **The start record still sees every red.** The first unit's start record still costs one full
   `verify.test`; its reds carry forward to later units' start records, and a test seen passing at a
   later boundary drops out. Example: a test red before the work started and in the affected set at
   unit 3 is matched, not handed to `keel:debug`; a pre-existing red that unit 2 fixed and unit 4
   breaks again is unmatched.
4. **An unmatched red names its possible causes.** Under an affected run, an unmatched red goes to
   `keel:debug` naming every unit since the first start record as a possible cause, because a unit
   can break a test outside its own selection that shows only later. Example: unit 2 breaks a test
   its run did not select, and unit 4's run shows it; `debug` is told units 2 to 4, not unit 4
   alone.
5. **The body stays within its ceiling.** `tdd` stays at or below 900 words as
   `tests/validate-skills.sh` counts it (855 now); the iron law and every other section are
   unchanged. Detail that does not fit goes in `skills/tdd/references/affected-tests.md`, linked
   from the boundary section.
6. **Planned work uses it.** The template's "Step 3.5: Run the suite at the unit boundary" runs
   `verify.test_affected` with `{base}` when the profile sets it, else `verify.test`, because the
   task text overrides the skill and would otherwise schedule the full suite every task.
   `review-code` step 3's "`keel:tdd` runs it once at a unit boundary" says that `tdd` may have run
   only the affected tests there, so review is where the suite result is established.
   `write-plan/SKILL.md` is not touched (899 words, and its wording stays true).
7. **The schema cites its advisory reader.** `verify.test_affected`'s `x-keel-read-by` adds
   `advisory:skills/tdd/SKILL.md#<phrase>` beside doctor's, and `docs/profile-keys.md` is
   regenerated.
8. **Catalog:** the `tdd` entry in `docs/02-skill-catalog.md` says the boundary runs
   `verify.test_affected` when the profile sets it, and the file keeps 627 lines.
9. **Records:** `docs/ideas/delivery-flow-gaps.md`:
   - Status names gap 2 built by this plan, with task 1's commit and task 2's commit title;
   - Next names gap 6, "queue, not overlap";
   - the gap 2 section gets "**Built 2026-10-16**, see Status. What follows is the state before it
     was built.";
   - "Decided" gains item 5 with Bernard's three answers;
   - "Not decided here" keeps only the rework half of its thresholds bullet;
   - "What stays" says the boundary run and the start record stay, and that the boundary may now run
     the affected tests with the start record's reds carried forward (gap 2, ADR-0009).
   `CHANGELOG.md`: an entry, and the owed eval arm for the `tdd` body edit with its word counts.

**Done when:** all of these:
- `tests/validate-skills.sh` prints `OK`, with `tdd` at or below 900 words.
- `bash tests/test-doc-claims.sh`, `tests/validate-citations.sh` and
  `bash tests/test-harness-claims.sh` pass.
- `grep -c 'test_affected' skills/tdd/SKILL.md`, and the same in
  `skills/write-plan/references/plan-template.md`, each print at least 1.
- `wc -l < docs/02-skill-catalog.md` prints 627.
- A reviewer finds behaviours 1 to 9, with the outcomes of the examples in behaviours 3 and 4.

- [x] **Step 2.1: The `tdd` body and its reference** for behaviours 1 to 5. Note: tdd body 855 to 897 words; detail in skills/tdd/references/affected-tests.md; the plan's behaviour 4 example said units 2 to 4, which contradicts its own rule, and the reference says units 1 to 4
- [x] **Step 2.2: The template, `review-code`, the schema, the catalog and the records** for
  behaviours 6 to 9.
- [x] **Step 2.3: Check and stage.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: light; spec DEVIATES on the behaviour 4 example, one fix pass, second spec pass COMPLIES; full run-tests.sh witnessed by me, all passed; the final review-code widened behaviour 4: once any boundary in the session ran the affected tests, an unmatched red names every unit since the first start record, even after a full run (2fdeaf9)
  Stage every file named under **Files:** that changed, by path, show `git status --porcelain`, and
  stop. The coordinator ticks and commits, with this plan:
  `feat(skills): the tdd unit boundary runs the affected tests when the profile names them`.

---

## What the review changed

A plan reviewer read the first draft on 2026-10-16. Applied: the schema fingerprint file and the
second schema pin are named; the warning's minutes have a formula and its test a pattern; `init`
writes the threshold, because `keel profile set` refuses a path the profile does not hold; ADR-0009
moved into task 1 and amends ADR-0006's attribution sentence, because a break outside one unit's
selection can first show at a later unit's; `{base}` is defined for no VCS, for units that share a
`HEAD`, and for a run that did not select the unit's own cases; the start record drops tests seen
passing; the plan template and `review-code` carry the change, so planned work uses it; the
hand-over steps stage and stop, leaving the commit to the coordinator; `doctor`'s interpreter budget
and the live `bin/keel` citations are constraints; behaviours 4, 7 and 8 have concrete checks; a
`test_affected` equal to `verify.test` still warns; and the existing `test_one` failure is named as
why that half of gap 2 needs no change.
