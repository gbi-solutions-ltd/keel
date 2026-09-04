# De-risking the `coding-standards` restructure Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** answer the two questions the rest of the restructure depends on, before writing any mode.

**Stories:** S-01, S-02. **Nothing downstream of S-02 is planned here, deliberately**, because a
single arm result deletes or rewrites most of it.

**ADRs:** ADR-0001, whose 700-word warning and 900-word ceiling both bind task 4.

**Architecture.** Four tasks. Task 1 makes an arm able to read a reference file, which it cannot do
today, by staging references beside the working directory rather than injecting them as text. Task 2
answers S-01. Task 3 captures S-02's baseline under that harness. Task 4 moves assess's checks and
asks the one question that can actually fail: **did the arm go and read the reference.**

## What this plan is a second draft of

A first draft was reviewed against the tree on 2026-09-02 and had four serious defects. They are
recorded because two were design errors rather than slips, and this draft is shaped by avoiding
them.

1. **It injected references as text.** Baseline and after-run would then have carried the same four
   checks in the same prompt, differing only in position, so task 4 was a near-certain pass that
   would have green-lit S-03 and all of epic C on evidence meaning nothing. Requester decision,
   2026-09-02: stage the references instead, so the arm must choose to read them.
2. **Its negative test pinned that `assess-a-stale-standard` emits no reference block**, and task 3
   then made it emit two. The suite would have gone red at task 3. This draft tests against
   `debug-obvious-cause` and `ship-with-flaky-tests`, which no later task touches, and creates no
   file under `tests/evals/scenarios/`.
3. **It claimed the harness limit was newly found.** `tests/evals/results.md:2700` recorded it on
   2026-09-01: "No eval in this repository can currently exercise a skill whose behaviour depends on
   a reference file." A planner who had read that entry would also have found defect 4.
4. **It ignored the only prior run of the scenario it builds on.** `tests/evals/results.md:2644`
   records the 2026-09-01 assess arm **failing** "Names all four checks, in the ranked order". A
   pass condition of "no worse than the baseline" would have passed by failing the same way.
   Task 4's discriminator is now binary and different: whether the reference was read.

Its arithmetic was wrong in two places, both corrected below. The harness has **27** cases, not 26.
Step 0a is **119** words including its heading, so the body lands near **757**, not 761. The PRD's
figure of 115 excluded the heading and was wrong; the idea record's 119 was right.

**A third arithmetic error, found on review of this draft and fixed upstream rather than here.** The
PRD said a four-mode router put the body at 906 and failed by six words. It was mixing conventions:
a heading-exclusive Step 0 of 68 subtracted from a heading-inclusive router of 98. Counted the way
`tests/validate-skills.sh` counts, throughout, it is 876 minus 74 plus 98, which is **900**, and
`validate-skills.sh:123` fails only above 900. So it passes with zero headroom rather than failing.
The PRD now states the convention and makes the argument on the zero spare. **Nothing in this plan
changes**, because task 4 does not swap in the router: it removes Step 0a and rewrites one sentence,
landing near 757.

## Precondition waived, 2026-09-02

`keel:execute-plan` step 1 refuses to start when the PRD is a draft and the stories are provisional,
and `references/preconditions.md` gives that condition no exception: the requirement may change, and
the work with it. `docs/prd/coding-standards-audit-and-seed.md` is `draft, awaiting approval` and
`docs/stories/coding-standards-audit-and-seed.md` says every story it carries is provisional.

**Waived by Bernard on 2026-09-02, for S-01 and S-02 only.** The reasoning, recorded here rather
than left in a chat log, because a waiver nobody can find is indistinguishable from a precondition
nobody checked:

- These two stories exist to test the PRD's central unproven claim, which is section 5.3's argument
  that a mode's steps stay followed from behind a link. **They inform the approval rather than
  follow it.** Approving the PRD first would sign off the argument the arms are built to test.
- The waiver does not extend past S-02. S-03 to S-13 stay unplanned and unstarted, and task 4's
  result decides whether they exist in their current form.
- The risk the precondition guards against is accepted knowingly: if the PRD is not approved, the
  work in tasks 2 to 4 is three eval arms and a harness improvement, and the harness improvement
  stands on its own regardless.

## Global constraints

Copied in full. A task executed by a fresh agent that reads only its own section still obeys these.

- **Verify commands**, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  There is no typecheck and no build.
- **Never start on `main`.** This work belongs on `sandbox`, which is where the branch already is.
- **ADR-0001:** a skill body is capped at 900 words and warns over 700. A body over 700 requires a
  passing eval arm at that length recorded in `tests/evals/results.md`.
- **`docs/standards.md`: no em dashes, no en dashes, no dash longer than a hyphen**, anywhere,
  including commit messages. `tests/validate-skills.sh` fails any file under `docs/` carrying one.
- **`docs/standards.md`: prose wraps at 100 columns; table rows and code blocks do not.**
- **`docs/standards.md`: a check is never stricter than correct output.** If a mechanical check
  disagrees with output you believe is correct, the check is wrong until proven otherwise.
- **`docs/standards.md`: evidence about the tooling comes from the tooling.** Use `/usr/bin/grep`
  rather than bare `grep` when the result is evidence, use absolute paths in a background shell, and
  let a slow command finish rather than calling it hung. The suite takes about 150 seconds.
- **Commit messages carry no attribution footers**, no `Co-Authored-By`, no generated-with line.
- **`references/assessment-report.md`: nothing in an assessment modifies what is being assessed**,
  and `standards.md` is never edited by one. Task 3 and task 4 both assert this.
- **`tests/run-tests.sh` runs test files in parallel at `MAX_JOBS=4`.** No task may create or delete
  a file under `tests/evals/scenarios/` during a run: `tests/test-doc-claims.sh` asserts the
  scenario count against `README.md` and would see the window.

---

### Task 1: An arm can read a skill's reference files

**Story:** S-02 (enabling), NFR-05 (enabling for all modes)

**Files:**
- Modify: `tests/evals/stage.sh`
- Modify: `tests/evals/run.sh`
- Modify: `tests/test-eval-harness.sh`
- Modify: `tests/evals/README.md`

**Interfaces:**
- Produces: for every skill a scenario injects, `skills/<skill>/references/` staged at
  `<staged dir>/skills/<skill>/references/`, which is `../skills/<skill>/references/` from the arm's
  working directory. `run.sh` emits one line naming that path per skill that has one.
- Consumes: the existing `Inject:` line. No new scenario syntax.

**Depends on:** none

**Done when:** `tests/test-eval-harness.sh` reports `30 passed, 0 failed`, up from 27, and
`tests/run-tests.sh` is green with `shellcheck` clean.

**Corrected during execution, 2026-09-02: 30 and not 29.** The plan said 29 by counting its own new
blocks rather than its own new assertions. Case 26 carries two, staging and the announced path, and
case 27 carries one, so three are added and not two. The tests are unchanged; the arithmetic in this
line was wrong. Task 2's expectation moves from 30 to 31 for the same reason.

**Why staged rather than injected.** Injected text tests whether a reference's content is obeyed
when the model already has it, which is not a question anyone is asking. Staged, the arm has to
decide to open the file, which is the risk a reference actually carries and the thing S-02 exists to
measure. It is also the only design under which task 4 can fail.

- [x] **Step 1: Write the failing tests**
  (written in an earlier session, product on disk and committed in `bee1a54`, not observed by me)

Append to `tests/test-eval-harness.sh`. The last section label in that file is `# 25.`, so these are
26 and 27. Both use scenarios that already exist, so no file is created under
`tests/evals/scenarios/` and neither case 7's fixture check nor the parallel scenario-count race is
touched.

```bash
# 26. A staged scenario carries the references of every skill it injects, beside the working
# directory rather than inside it.
#
# Before this, an arm could not read a reference at all: stage.sh copied only the fixture, so the
# staged tree had no skills/ directory. tests/evals/results.md:2700 recorded that on 2026-09-01 as
# the most useful thing that run surfaced about the eval setup. A body pointing at a reference was
# pointing at something no arm could follow.
#
# Beside project/ and not inside it, for the reason prompt.md and setup.sh are kept out: these are
# not files the arm should find lying around in the project it is working on.
dir="$(tests/evals/stage.sh debug-obvious-cause)"
if [ -f "$dir/skills/debug/references/root-cause-tracing.md" ] \
   && [ ! -e "$dir/project/skills" ]; then
    ok "an injected skill's references are staged beside the working directory"
else
    bad "an injected skill's references are staged beside the working directory" \
        "missing under $dir/skills/debug/references/, or leaked into project/"
fi

# And the prompt says where they are. The arm's working directory is project/, and the relative
# links inside the injected SKILL.md resolve nowhere from there, so without this line the files are
# staged and unreachable in practice, which is the same failure with an extra step.
if /usr/bin/grep -q '\.\./skills/debug/references/' "$dir/prompt.md"; then
    ok "the prompt names the staged reference path"
else
    bad "the prompt names the staged reference path" "no ../skills/debug/references/ in prompt.md"
fi
rm -rf "$dir"

# 27. A scenario whose injected skill has no references gets neither the directory nor the line, so
# an arm is never pointed at something that is not there. ship has no references/ directory.
dir="$(tests/evals/stage.sh ship-with-flaky-tests)"
if [ ! -e "$dir/skills" ] && ! /usr/bin/grep -q '\.\./skills/' "$dir/prompt.md"; then
    ok "a skill with no references stages none and is announced none"
else
    bad "a skill with no references stages none and is announced none" \
        "a skills/ directory or a reference line appeared for ship"
fi
rm -rf "$dir"
```

- [ ] **Step 2: Run it and watch it fail** (an event, never observed by me, no product on disk)

Run: `tests/test-eval-harness.sh`
Expected: FAIL on case 26, both assertions, because nothing stages references and nothing writes the
path into the prompt. Case 27 passes already, and must keep passing: it is the guard that stops the
feature firing where it should not.

- [x] **Step 3: Write the minimal implementation**
  (written in an earlier session, product on disk and committed in `bee1a54`, not observed by me)

In `tests/evals/stage.sh`, after the fixture copy block and before the `setup.sh` block, add:

```bash
# The references of every skill this scenario injects, staged beside project/ rather than inside it.
#
# An arm's working directory is project/, and until 2026-09-02 the staged tree held nothing else, so
# a skill body pointing at references/ pointed at nothing an arm could open. Staged rather than
# injected into the prompt on purpose: injected text measures whether a reference is obeyed when the
# model already has it, and the question worth asking is whether it goes and reads it.
#
# Beside project/ for the same reason prompt.md and setup.sh are kept out of it. A skills/ directory
# inside the project is a file the arm would find lying around in the repository it is working on.
for s in $(sed -n 's/^Inject: *//p' "$f"); do
    [ -d "skills/$s/references" ] || continue
    mkdir -p "$dir/skills/$s" || { rm -rf "$dir"; exit 1; }
    cp -R "skills/$s/references" "$dir/skills/$s/" || { rm -rf "$dir"; exit 1; }
done
```

In `tests/evals/run.sh`, inside the existing `if [ -n "$skills" ]` block, after the skills loop and
before `printf '=== TASK ===\n\n'`, add:

```bash
    # Where the staged references are, from the arm's working directory. stage.sh puts them at
    # <staged>/skills/<skill>/references/ and the arm runs in <staged>/project, so this path is a
    # promise this script makes and stage.sh keeps. Case 26 of tests/test-eval-harness.sh pins both
    # halves, because a path named here and not staged is worse than no path at all.
    #
    # Only for skills that have one. Pointing an arm at a directory that does not exist teaches it
    # the instruction is unreliable, and the SKILL.md links are relative to the skill directory, so
    # they resolve nowhere from project/ without this.
    for s in $skills; do
        [ -d "skills/$s/references" ] || continue
        printf 'The reference files %s links are on disk at `../skills/%s/references/`. Read one when the skill tells you to.\n\n' "$s" "$s"
    done
```

The `=== TASK ===` printf does not move, and nothing outside the `if [ -n "$skills" ]` block
changes, so `commit-outside-a-worktree`, the one scenario that injects nothing, is untouched.

In `tests/evals/README.md`, under "Running one", document that an injected skill's references are
staged at `../skills/<skill>/references/` and that the prompt says so, and record that this is what
makes a reference-dependent skill measurable at all.

- [ ] **Step 4: Run it and watch it pass**
  (that run never observed by me. The suite is green at this working tree, run twice on
  2026-09-02, which is a different run)

Run: `tests/test-eval-harness.sh`
Expected: `30 passed, 0 failed`.

Run: `tests/run-tests.sh`
Expected: green. `shellcheck` must be clean: both `tests/evals/stage.sh` and `tests/evals/run.sh`
are in the lint set at `.keel/profile.json`.

- [x] **Step 5: Hand over**
  (written in an earlier session, product on disk and committed in `bee1a54`, not observed by me)

```bash
git add tests/evals/stage.sh tests/evals/run.sh tests/test-eval-harness.sh tests/evals/README.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(evals): stage a skill's references so an arm can read them"`.
Paste the `git status --porcelain` output into your report.

---

### Task 2: Author mode is exercised, or its absence is recorded

**Story:** S-01, satisfying NFR-06

**Files:**
- Create: `tests/evals/scenarios/author-a-standard.md`
- Create: `tests/evals/fixtures/author-a-standard/` and its contents
- Modify: `tests/evals/fixtures/README.md`, which records what each fixture was seeded with
- Modify: `tests/test-eval-harness.sh`, which carries one load-bearing case per fixture
- Modify: `tests/evals/results.md`
- Modify: `README.md` and `tests/evals/README.md`, both of which state a scenario count
- Modify: `docs/standards.md`, **on the no-arm branch only**

**Interfaces:**
- Consumes: task 1's staging, which gives the arm `house-defaults.md`. Author mode's Step 4 requires
  it and no arm has ever been able to reach it.

**Depends on:** task 1

**Done when:** `tests/run-tests.sh` is green, `tests/test-eval-harness.sh` reports `31 passed`, and
**either** `/usr/bin/grep -c 'author-a-standard' tests/evals/results.md` returns 1 or more, **or**
the no-arm branch's `Done when` below is met. Not both.

**The pass and fail conditions, fixed here and not after the output is read.**

Passes if the reply: cites at least three conventions by `path:line` from the fixture; resolves the
7-to-3 SQL split by recording the minority as the rule, per Step 1's rule that counting decides
style and never correctness; writes `docs/standards.md`; and gives it a departures section.

Fails if the reply: writes any rule with no basis in the fixture, which is the "imports a generic
style guide" failure Step 1's Common mistakes table forbids; records the 7-to-3 majority as the
convention, which would sanction an injection; writes no document; or omits the departures section.

**Ambiguity is a fail.** An arm whose verdict needs a judgement the two paragraphs above do not
settle is recorded as a fail with the reason, not argued into a pass.

- [x] **Step 1: Build the fixture and its scenario**
  (written in an earlier session, product on disk and committed in `ca89c77`, not observed by me)

Create `tests/evals/fixtures/author-a-standard/`: a small service carrying two deliberate splits.

- **Seven call sites building SQL by string concatenation, three using parameters.** This is the
  split where the majority is a defect, and resolving it correctly is the pass condition. Step 1's
  rule is that counting decides style and never correctness.
- **Six functions returning a typed error object, two throwing.** An ordinary majority convention,
  so the arm has to tell the two cases apart rather than applying one rule to both.

Create `tests/evals/scenarios/author-a-standard.md`:

```markdown
# author a standards document for a repository that has none

Inject: coding-standards

**Tests:** whether author mode derives from the code rather than importing a style guide, and
whether it applies Step 1's rule that counting decides style and never correctness. Author mode had
never been exercised in a recorded run before 2026-09-02, and two proposed modes depend on it.

**Baseline, no skill:** not recorded. Treatment only.

**Passes if the reply:** cites at least three conventions by `path:line`; records the minority as
the rule on the 7-to-3 SQL split; writes `docs/standards.md`; gives it a departures section.

**Fails if the reply:** writes a rule with no basis in the fixture; records the SQL majority as the
convention; writes no document; or omits the departures section.

## Prompt

Nobody here has written down how we do things and a new engineer starts on Monday. Can you write
down the conventions this codebase already follows?
```

Add the fixture's entry to `tests/evals/fixtures/README.md`, which that file requires: what was
seeded and why, naming both splits.

Add a case to `tests/test-eval-harness.sh` as case 28, following cases 12 to 17, which carry one
load-bearing property per fixture so none can rot into a fixture that looks right and measures
nothing:

```bash
# 28. author-a-standard's fixture keeps its two deliberate splits. The scenario scores whether the
# arm records the minority as the rule on the SQL split, so a later edit that flattens it makes the
# scenario measure nothing while still passing.
sql_concat=$(/usr/bin/grep -rc "queryConcat" tests/evals/fixtures/author-a-standard/src | \
             awk -F: '{n+=$2} END{print n+0}')
sql_param=$(/usr/bin/grep -rc "queryParam" tests/evals/fixtures/author-a-standard/src | \
            awk -F: '{n+=$2} END{print n+0}')
if [ "$sql_concat" -eq 7 ] && [ "$sql_param" -eq 3 ]; then
    ok "author-a-standard's fixture keeps its 7-to-3 SQL split"
else
    bad "author-a-standard's fixture keeps its 7-to-3 SQL split" \
        "found $sql_concat concatenated and $sql_param parameterised, expected 7 and 3"
fi
```

Name the fixture's two query helpers `queryConcat` and `queryParam` so those greps are exact. The
counts are the assertion; the helper names exist to make them countable.

Update the scenario count in **both** places: `README.md:289` says "9 scenarios exist", which
`tests/test-doc-claims.sh` asserts against the tree, and `tests/evals/README.md` says "Nine
scenarios exist" spelled as a word, which no check can catch.

- [ ] **Step 2: Run the mechanical checks and watch them pass** (that run never observed by me)

Run: `tests/test-eval-harness.sh`
Expected: `31 passed, 0 failed`, including case 7's "every scenario has a fixture" and the new
case 28.

Run: `tests/test-doc-claims.sh`
Expected: `24 passed, 0 failed`, with the scenario count now 10.

- [x] **Step 3: Run the arm**
  (the arm's run not observed by me. Its record is on disk at `tests/evals/results.md`, `##
  2026-09-02, author mode, the first recorded run`, committed in `ca89c77`)

Run: `tests/evals/run.sh author-a-standard` and confirm the prompt names
`../skills/coding-standards/references/`. If it does not, task 1 did not land and this task stops.

```bash
dir=$(tests/evals/stage.sh author-a-standard)
cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json"
```

Append an entry to `tests/evals/results.md` under `## 2026-09-02, author mode, the first recorded
run`, carrying the model, turns, duration and cost from `result.json`, the verdict against the two
paragraphs above, and the rules the arm derived in full.

- [ ] **Step 4: The no-arm branch, if the arm is not run**
  (not taken. Step 3's arm was run and recorded)

Taken only if a decision is made not to run it. It is the cheapest branch and therefore the one most
likely to be taken quietly, so its deliverable is a file change and not a judgement.

Add a row to the departures table in `docs/standards.md`, next to the existing "A bug fix ships with
a test that reproduced it" row, which already says a skill's equivalent is a behavioural eval:

```markdown
| A skill's behaviour is verified by an eval arm | `coding-standards`'s author mode ships unexercised | No arm has ever run it, which is the row above narrowed to one mode. `audit` and `seed`, both proposed in `docs/prd/coding-standards-audit-and-seed.md`, depend on it: audit ends by offering to author, and seed is author's Step 4 with the house defaults as its source. Recorded 2026-09-02 rather than closed |
```

**Done when, for this branch:** `/usr/bin/grep -c 'author mode ships unexercised' docs/standards.md`
returns 1 or more, and that row names both `audit` and `seed`. The record naming the two dependent
modes is the deliverable. A note saying the gap was considered does not satisfy this task.

- [x] **Step 5: Hand over**
  (written in an earlier session, product on disk and committed in `ca89c77`, not observed by me)

```bash
git add tests/evals/scenarios/author-a-standard.md tests/evals/fixtures/author-a-standard \
        tests/evals/fixtures/README.md tests/test-eval-harness.sh tests/evals/results.md \
        README.md tests/evals/README.md
git status --porcelain
```

On the no-arm branch, stage `docs/standards.md` and drop `tests/evals/results.md`. Stage exactly
those paths and stop. **Do not commit.** The coordinator commits after both review passes, with
`git commit -m "test(evals): exercise author mode for the first time"` or, on the no-arm branch,
`git commit -m "docs(standards): record author mode as shipping unexercised"`.

---

### Task 3: Capture the assess baseline, before the checks move

**Story:** S-02

**Files:**
- Modify: `tests/evals/scenarios/assess-a-stale-standard.md`
- Modify: `tests/evals/results.md`

**Interfaces:**
- Consumes: task 1's staging.
- Produces: the recorded baseline task 4 compares against. Nothing else consumes it.

**Depends on:** task 1

**Done when:** `tests/run-tests.sh` is green and
`/usr/bin/grep -c 'the assess baseline before the reference move' tests/evals/results.md` returns 1
or more.

**This baseline is a new condition, and saying otherwise would be false.** Task 1 makes
`assessment-report.md` and `house-defaults.md` readable by an arm for the first time, so check 1
becomes runnable and the two honesty requirements `tests/evals/results.md:2698-2701` records as "not
reachable and not scored" become reachable. The baseline is therefore comparable with task 4 and
with nothing else, **including the 2026-09-01 run of the same scenario**, whose body was 865 words
and which had no references at all.

- [x] **Step 1: Correct the scenario's three stale claims**
  (written in an earlier session, product on disk and committed in `e6eef6c`, not observed by me)

`tests/evals/scenarios/assess-a-stale-standard.md` asserts unreachability in three places, and all
three are false after task 1. Fixing one and leaving two is worse than fixing none, because the
survivors read as current.

1. The "What the arm can and cannot see" paragraph, which says both files are unreachable.
2. The Passes-if clause "Reporting check 1 as not covered for want of the reference is a pass."
   With `house-defaults.md` staged, check 1 is reachable and skipping it is now a fail.
3. The "Not measured here." paragraph, which exempts the pre-derivation proportion and the
   empty-category rows from scoring because `assessment-report.md` "cannot be reached". Those are
   exactly the two honesty requirements task 1 makes reachable, so the exemption goes.

- [x] **Step 2: Run the baseline**
  (the baseline arm's run not observed by me. Its record is on disk, committed in `e6eef6c`)

Run: `tests/evals/run.sh assess-a-stale-standard` and confirm the prompt names
`../skills/coding-standards/references/`. Then stage and dispatch as task 2 step 3 does, with
`assess-a-stale-standard` as the name, and with `--output-format stream-json` rather than `json`, so
the tool calls are recorded. Task 4 needs to see whether a reference was opened, and
`docs/standards.md` requires evidence about the tooling to come from the tooling.

- [x] **Step 3: Record the baseline as a comparable set of facts**
  (written in an earlier session, product on disk and committed in `e6eef6c`, not observed by me)

Append to `tests/evals/results.md` under `## 2026-09-02, the assess baseline before the reference
move`. Record as a list, because task 4 compares item by item:

1. **whether any file under `../skills/coding-standards/references/` was opened**, and which, taken
   from the `stream-json` tool calls rather than inferred from the prose
2. which of the four checks fired, by name
3. the order they were presented in
4. the path written, and whether `docs/standards.md` was modified
5. the body word count at the time, which is 876
6. model, turns, duration, cost

Then record, in the same entry, that the 2026-09-01 run of this scenario **failed** the "names all
four checks, in the ranked order" criterion at `tests/evals/results.md:2644`, and whether this run
reproduces that. It is the only prior run of this scenario, and task 4's reading of item 3 depends
on knowing it.

- [ ] **Step 4: Confirm the suite is unaffected** (that run never observed by me)

Run: `tests/run-tests.sh`
Expected: green. This task changes one scenario file and appends to `results.md`.

- [x] **Step 5: Hand over**
  (written in an earlier session, product on disk and committed in `e6eef6c`, not observed by me)

```bash
git add tests/evals/scenarios/assess-a-stale-standard.md tests/evals/results.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(evals): record the assess baseline before the reference move"`.

---

### Task 4: Move assess's four checks to a reference, and ask whether it is read

**Story:** S-02, satisfying FR-19 and NFR-02. **Not NFR-05**, and see below.

**Files:**
- Create: `skills/coding-standards/references/assess.md`
- Modify: `skills/coding-standards/SKILL.md`
- Modify: `tests/evals/results.md`

**Interfaces:**
- Consumes: task 3's recorded baseline.
- Produces: `references/assess.md`, linked from Step 0. `tests/validate-skills.sh` requires every
  relative link in a skill to resolve.

**Depends on:** task 3

**Done when:** `tests/run-tests.sh` is green, `tests/validate-skills.sh` reports the
`coding-standards` body between 750 and 770 words with no `FAIL`, and
`/usr/bin/grep -c 'the assess arm after the reference move' tests/evals/results.md` returns 1 or
more.

**The pass and fail conditions, fixed here and not after the output is read.**

**The discriminator is item 1 of the baseline: was `references/assess.md` opened.** It is binary, it
is read from the `stream-json` tool calls rather than inferred, and it is the question S-02 asks.

Passes if: the arm opened `../skills/coding-standards/references/assess.md`, **and** the four checks
fired by name, **and** the report went to the same path as the baseline, **and**
`docs/standards.md` is unmodified.

Fails if: the arm did not open it; or opened it and fewer of the four checks fired than in the
baseline; or `docs/standards.md` was modified; or no report was produced.

**Item 3, the presentation order, is not a discriminator here, and the reason is on the record.**
The 2026-09-01 run failed that criterion with the checks inline in the body
(`tests/evals/results.md:2644`), so it was already failing before anything moved. Record whether it
changed and do not let it decide the verdict in either direction. A pass condition that can be met
by failing the same way as the baseline is not a test, which is the defect that sank the first
draft.

**Why this task does not claim NFR-05.** NFR-05 says each mode has a passing arm "with its steps
behind a link". This task measures whether one mode's steps are read from behind a link, on one
mode. It does not discharge NFR-05 for audit or seed, and the PRD should be corrected rather than
this task's header stretched.

**On a fail, section 5.4 of the PRD is taken rather than the shape adjusted.** Do not re-run for a
better result, add a stronger pointer to the reference, or soften the condition. Report the fail,
stop, and hand back: S-03 and epic C drop, and S-04 and S-05 are rewritten as a terminal branch of
author.

- [ ] **Step 1: Confirm the starting measurement**
  (never observed by me. The move was already applied when I arrived, so the 876 word reading
  could no longer be taken)

Run: `tests/validate-skills.sh 2>&1 | /usr/bin/grep coding-standards`
Expected, before any edit, a line beginning: `WARN  coding-standards: body is 876 words, 24 from
the 900 ceiling and over the 700 target.` Note the two spaces after `WARN`, and that the message
continues past this prefix.

- [x] **Step 2: Move the content**
  (the move was on disk uncommitted when I arrived, not written by me. I made one edit of my own:
  rewrapping the new Step 0 sentence, which the move had left at 145 columns, to the 100 column
  rule. No word changed)

Create `skills/coding-standards/references/assess.md` containing Step 0a's four numbered checks
verbatim, with a header naming what it is and pointing at `references/assessment-report.md` for the
report's shape. Deleting Step 0a removes `SKILL.md`'s only link to `assessment-report.md`, so
`assess.md` must carry that pointer forward or the report template becomes unreferenced.

In `skills/coding-standards/SKILL.md`, delete Step 0a, lines 24 to 39 inclusive of its heading, and
rewrite Step 0's sentence "step 0a replaces them" at line 19 to point at the new file. Step 0 keeps
its mode-choosing rules unchanged.

- [x] **Step 3: Run the mechanical checks and watch them pass**
  (run and read by me: 756 words, no `FAIL`, `tests/run-tests.sh` green)

Run: `tests/validate-skills.sh 2>&1 | /usr/bin/grep coding-standards`
Expected: a `WARN` line reporting a body between 750 and 770 words, over the 700 target. The
arithmetic is 876 minus 119, which is 757, plus whatever Step 0's rewritten sentence costs. Over the
target is expected and correct: ADR-0001 then requires the arm this task runs.

Run: `tests/run-tests.sh`
Expected: green, including the relative-link check now resolving `references/assess.md`.

- [x] **Step 4: Run the arm and compare** (staged, dispatched and scored by me)

Stage and dispatch as task 3 step 2 did, with `--output-format stream-json`. Append to
`tests/evals/results.md` under `## 2026-09-02, the assess arm after the reference move`, recording
the same six items task 3 recorded, an item-by-item comparison against the baseline, and the verdict
against the conditions above.

State in that entry what the arm proved and did not: that this mode's steps are read from a staged
reference, on one run, and **not** that the same holds for audit or seed, neither of which exists.

- [x] **Step 5: Hand over**
  (staged by me, with six files added to the list. See the deviation note below)

```bash
git add skills/coding-standards/references/assess.md skills/coding-standards/SKILL.md \
        tests/evals/results.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "refactor(coding-standards): move assess's checks to a reference"`.

**Deviation, 2026-09-02: six more files are staged than this step lists, and the plan was wrong to
list three.** `tests/test-doc-claims.sh:100-118` asserts `coding-standards`'s reference count,
reference word count and body word count against the tree in five documents and in
`tests/validate-skills.sh`'s own comment. Adding `references/assess.md` moves all three numbers,
from 13 / 20,146 / 876 to 14 / 20,335 / 756, so those six files change with this task or the commit
lands with its own suite red. They were already updated in the working tree when this session
arrived, and the suite is green with them. The staged set is therefore:

```bash
git add skills/coding-standards/references/assess.md skills/coding-standards/SKILL.md \
        tests/evals/results.md tests/validate-skills.sh docs/standards.md \
        docs/05-token-and-memory-design.md docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/leon-van-zyl-skill-collection.md docs/ideas/database-design-and-review.md
```

**Left unstaged deliberately:** `docs/audits/2026-09-02-standards.md`, untracked, an assessment of
this repository that predates this session and belongs to no task here.

---

## Story coverage

| Story | Tasks | Complete? |
|---|---|---|
| S-01 | 2 | yes, by either branch |
| S-02 | 1, 3, 4 | yes |

**S-03 to S-13 are not planned here**, by requester decision of 2026-09-02. Task 4's result decides
whether they exist in their current form.

## What this plan could not settle, and what it changes upstream

**The PRD's Step 0a figure of 115 words is wrong**, and its 761 with it. Step 0a is 119 words
including its heading, so the body lands near 757. `docs/prd/coding-standards-audit-and-seed.md`
section 5.1 and story S-02's first acceptance scenario both carry the wrong number and should be
corrected when the PRD is next opened. Not corrected here, because this plan does not have approval
to edit the PRD it was written from.

**NFR-05 is broader than any one task can discharge.** Task 4 measures one mode on one run. The
requirement says each of four modes has a passing arm, and two of those modes do not exist yet.

**Whether one run is enough.** Task 4's discriminator is binary but its sample is one arm. A model
that reads a reference once may not read it every time, and nothing here measures variance. That is
the limit every arm in `tests/evals/results.md` carries rather than one this plan introduces, but it
bears on how strongly a pass licenses S-03.
