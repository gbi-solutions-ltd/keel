# Coding Standards Enforcement Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `gates.coding_standards` gates something: `ship` refuses, `execute-plan` refuses to tick,
`keel init` ships the two mechanical rules as config, `repo-snapshot` reports standards debt, and
`doctor` fails a `required` project with nothing to check against.
**Stories:** S-01, S-02, S-03, S-04, S-05, S-06, S-07, from
`docs/stories/coding-standards-enforcement.md`
**PRD:** `docs/prd/coding-standards-enforcement.md`, approved by Bernard, 2026-09-21
**ADRs:** none referenced by the stories. ADR-0001 (skill body word ceiling) binds tasks 2 and 7,
which cross the 700-word target and so each run an eval arm.
**Architecture:** every task wires into a mechanism that already exists. `ship` and `execute-plan`
gain a rule in prose, in a reference file where the body has no room; `bin/keel` gains one doctor
check and two `keel init` merges beside the ones it already has; `repo-snapshot` calls an assess
mode `coding-standards` already ships. Nothing here is a new hook or new runtime code (PRD CON-01,
CON-02).

**Concurrent batches:** none. Tasks 4, 5 and 6 all modify `bin/keel` and `tests/test-keel.sh`.
Tasks 2 and 7 both append to `tests/evals/results.md`. The pairs left over are too few to earn a
worktree join, so every task is sequential and hands over rather than committing.

## Global constraints

Copied from `.keel/profile.json`, `docs/standards.md`, and the PRD. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/<name>` (a test file runs itself:
  `bash tests/test-keel.sh`), lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh
  tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch
  hooks/sensitive-guard hooks/done-guard`. `format`, `typecheck` and `build` are `null`.
- Lint after every edit to a shell file, not at the end. There is no typecheck.
- Never start on `main`. Work is on `sandbox`.
- No em dash, no en dash, anywhere: prose, code comments, commit messages. `tests/run-tests.sh`
  fails a document that carries one.
- Prose wraps at 100 columns. Table rows and code blocks do not wrap.
- Shipped prose states the current state. No "before this change", no "previously", no narrating
  the work. `CHANGELOG.md` holds the history.
- A skill body is a budget: 900 words is the ceiling, 700 the target, and a body over 700 needs a
  passing eval arm recorded in `tests/evals/results.md` (ADR-0001). `execute-plan` is at 896: no
  task may add a word to `skills/execute-plan/SKILL.md`. `ship` is at 695 and `repo-snapshot` at
  700; tasks 2 and 7 cross the target and each runs an arm.
- `bin/keel` runs under bash 3.2. No apostrophe inside a quoted heredoc that sits inside `$( )`.
  Every `keel doctor` and `keel init` run is bounded to 10 `python3` starts by
  `tests/test-keel.sh`; `json_get` reads from the flat cache and costs none.
- `docs/profile-keys.md` is generated: never edit it by hand. Change
  `templates/profile.schema.json`, then `tests/generate-profile-keys.sh > docs/profile-keys.md`.
- An `x-keel-read-by` marker names a reader that exists: `code:<path>#<phrase>` where the phrase is
  literally in the file and the key's leaf name is on that line or the three above it;
  `advisory:<md path>#<phrase>` or `:<line>`.
- CON-01: keel ships declarative configuration only (compiler flags, CI steps) into a project,
  never runtime code. CON-02: no new git-hook mechanism.
- A commit message is title and body only. No attribution footer, no robot emoji, no
  generated-with line.

---

### Task 1: A `review-code` finding is recognised as a standards violation

**Story:** S-01
**Files:**
- Create: `skills/ship/references/standards-gate.md`
- Modify: `tests/test-eval-harness.sh` (case 27, which pins that `ship` has no `references/`)
- Modify: `docs/06-repo-layout.md` (the `ship/` rows of the tree, which enumerates every
  reference file)

**Interfaces:**
- Consumes: nothing. Reads `skills/review-code/SKILL.md`, "Step 4: Rank, and say what blocks",
  for the severity vocabulary it classifies over, and `skills/review-code/references/rubric.md`,
  whose bullets carry the citations the classification reads.
- Produces: `skills/ship/references/standards-gate.md`, section "What counts as a standards
  violation". Task 2 appends to this file and links it from the skill body.

**Depends on:** none

**Done when:** `tests/validate-citations.sh` prints `OK`, `tests/validate-skills.sh` reports no
FAIL and no new WARN, and `bash tests/test-eval-harness.sh` prints `N passed, 0 failed`.

- [x] **Step 1: There is no failing-test step in the TDD sense for this task**

This is a reference-file creation. Nothing executes it; its verification is the two validators,
which check that every path it cites exists and that the file carries no em or en dash. Run both
first so the "before" state is on record.

Run: `tests/validate-citations.sh`
Expected: `OK    1535 citations checked across 212 documents and 43 code files` (the counts may
differ by a few; note what it prints).

Run: `tests/validate-skills.sh`
Expected: `OK    25 skills validated`, with the seven existing WARN lines (`coding-standards`,
`context-budget`, `execute-plan`, `incident-response`, `tdd`, `write-docs`, `write-prd`) and no
FAIL. Note the exact list.

- [x] **Step 2: Write the reference file**

Create `skills/ship/references/standards-gate.md` with exactly this content:

````markdown
# The standards gate

Read from `skills/ship/SKILL.md`, gate item 5. What `gates.coding_standards` in
`.keel/profile.json` does to a ship, and which `review-code` findings it acts on.

## What counts as a standards violation

`review-code` ranks every finding `Blocking`, `Should fix` or `Consider`
(`skills/review-code/SKILL.md`, "Step 4: Rank, and say what blocks"), and files a standards
breach under `Should fix`, beside "will cost real time later". Gate item 5 already refuses on
`Blocking`; this file is about the `Should fix` row, and only part of it.

A `Should fix` finding is a **standards violation** when its text cites a file under
`skills/coding-standards/references/`, in any form: a bare `caching.md`, a "See `resilience.md`,
'Isolate'", a `path:line` into that directory. Every bullet in
`skills/review-code/references/rubric.md` that comes from a reference file names that file, so a
finding that quotes its bullet carries the citation; one that plainly restates a rubric bullet and
drops the file is read as citing that bullet's file. Nothing is added to the finding.

Three things it is not:

- A `Blocking` finding. It stays `Blocking` whatever it cites, and item 5 refuses on it whether or
  not this gate is on.
- A `Should fix` finding that cites nothing under `skills/coding-standards/references/`. Reuse of
  something the codebase already has, a name, a test asserting something adjacent: real findings,
  not this gate's.
- A finding that cites nothing and restates no rubric bullet. It is not a standards violation
  here. Say in the ship report when a finding looks rubric-sourced and no bullet can be matched to
  it: that is a defect in the review, not a reason to guess.
````

- [x] **Step 3: Run the validators and watch them pass**

Run: `tests/validate-citations.sh`
Expected: `OK`, and the document count is one higher than step 1's.

Run: `tests/validate-skills.sh`
Expected: the same WARN list as step 1, no FAIL. The new file is a reference and is not
word-counted.

- [x] **Step 4: Check the file for dashes and column width**

Run: `python3 -c "import sys; [print(i, l.rstrip()) for i, l in enumerate(open('skills/ship/references/standards-gate.md', encoding='utf-8'), 1) if chr(8212) in l or chr(8211) in l]"`
Expected: no output.

Run: `awk 'length > 100 && !/^\|/ && !/^\`/ { print FILENAME": "FNR": "length }' skills/ship/references/standards-gate.md`
Expected: no output.

- [x] **Step 5: Watch the eval-harness pin on `ship` go red, then re-point it at a probe**

Case 27 of `tests/test-eval-harness.sh` pins that a scenario whose injected skill has no
`references/` directory stages no `skills/` tree and announces no reference path, and it uses
`ship-with-flaky-tests` to do it, because `ship` had no references. It does now.

Run: `bash tests/test-eval-harness.sh 2>&1 | grep -n "no references\|passed,"`
Expected: `FAIL  a skill with no references stages none and is announced none: a skills/
directory or a reference line appeared for ship`, summary 1 failed.

No shipped scenario injects a reference-less skill (`context-budget`, `optimize-performance`
and `refactor` are the three left, and none has a scenario), so the case writes its own probe
and removes it. In `tests/test-eval-harness.sh`, replace the whole of case 27, from the comment
line beginning `# 27. A scenario whose injected skill has no references` down to and including
its `rm -rf "$dir"`, with:

```bash
# 27. A scenario whose injected skill has no references gets neither the directory nor the line, so
# an arm is never pointed at something that is not there. No shipped scenario injects a
# reference-less skill, so the case writes a probe against refactor, which has none, and the trap
# removes it with the rest of selftest_paths.
probe="tests/evals/scenarios/zz-no-references-probe.md"
probe_fixture="tests/evals/fixtures/zz-no-references-probe"
selftest_paths+=("$probe" "$probe_fixture")
if [ -d skills/refactor/references ]; then
    bad "a skill with no references stages none and is announced none" \
        "refactor has grown a references/ directory; this probe needs a skill that has none"
else
    mkdir -p "$probe_fixture"
    printf '# probe\n\nInject: refactor\n\n## Prompt\n\nprobe\n' > "$probe"
    dir="$(tests/evals/stage.sh zz-no-references-probe 2>/dev/null)"; staged+=("$dir")
    if [ ! -e "$dir/skills" ] && ! /usr/bin/grep -q '\.\./skills/' "$dir/prompt.md"; then
        ok "a skill with no references stages none and is announced none"
    else
        bad "a skill with no references stages none and is announced none" \
            "a skills/ directory or a reference line appeared for refactor"
    fi
    rm -rf "$dir"
fi
rm -f "$probe"; rm -rf "$probe_fixture"
```

Then lint: `shellcheck -x tests/test-eval-harness.sh`
Expected: no output.

Run: `bash tests/test-eval-harness.sh 2>&1 | grep -n "no references\|passed,"`
Expected: `PASS  a skill with no references stages none and is announced none`, summary 0 failed.

Run: `git status --porcelain tests/evals/`
Expected: no output. The probe and its fixture are gone.

- [x] **Step 6: Add the file to the repository layout**

`docs/06-repo-layout.md` lists every reference file under `skills/`. In its tree, the rows

```
│   ├── ship/
│   │   └── SKILL.md
```

become

```
│   ├── ship/
│   │   ├── SKILL.md
│   │   └── references/standards-gate.md
```

Run: `bash tests/test-doc-claims.sh 2>&1 | grep -n "FAIL\|passed,"`
Expected: no FAIL.

- [x] **Step 7: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched
against the start record (the `commit guard: status said nothing` assertion in
`tests/test-keel.sh` is intermittent and instrumented; name it if it fires).

```bash
git add skills/ship/references/standards-gate.md tests/test-eval-harness.sh docs/06-repo-layout.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(ship): name what counts as a standards violation"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch,
say so and leave it unstaged.

---

### Task 2: Ship's gate reads `gates.coding_standards`

**Story:** S-02
**Files:**
- Modify: `skills/ship/references/standards-gate.md` (append one section)
- Modify: `skills/ship/SKILL.md` (gate item 5, one line)
- Modify: `templates/profile.schema.json` (`gates.coding_standards` description and marker)
- Regenerate: `docs/profile-keys.md` (from the schema, never by hand)
- Modify: `docs/02-skill-catalog.md` (row 9)
- Modify: `tests/evals/results.md` (record the arm)
- Modify: `docs/plans/2026-09-07-declared-profile-keys-take-effect.md`,
  `docs/ideas/declared-profile-keys-take-effect.md`,
  `docs/plans/2026-08-31-release-operations-and-claims-audit.md` (one line number each: they
  cite lines of `skills/ship/SKILL.md` that this task moves down by one)

**Interfaces:**
- Consumes: `skills/ship/references/standards-gate.md`, section "What counts as a standards
  violation", from task 1.
- Produces: `skills/ship/references/standards-gate.md`, section "What the gate does with one".
  Task 3 cites this file from `docs/02-skill-catalog.md`; task 4 adds a second marker entry to
  the schema key this task rewrites.

**Depends on:** task 1

**Done when:** `tests/validate-skills.sh` reports no FAIL, one new WARN for `ship` crossing the
700-word target, and the `ship-with-flaky-tests` eval arm passes against the new body, recorded
in `tests/evals/results.md`.

- [x] **Step 1: There is no failing-test step in the TDD sense for this task**

A skill-body edit. Its verification is `tests/validate-skills.sh`, which enforces ADR-0001's
word rules, and a behavioural eval arm, which ADR-0001 requires once a body crosses 700.

Run: `tests/validate-skills.sh`
Record: `ship` reports no WARN line for itself, at 695 body words.

- [x] **Step 2: Append the gate section to the reference file**

Append to `skills/ship/references/standards-gate.md`, after its last line:

````markdown

## What the gate does with one

Read `gates.coding_standards` from `.keel/profile.json` before item 5. The three values mean what
they mean for every other gate in the profile.

| Value | An unaddressed standards violation |
|---|---|
| `required` | Refuses the ship. Report it the way any failed check is reported, under "When something is red": which finding, its citation, and stop |
| `warn` | Reported in the same words, then the ship continues |
| `off` | Not read. Item 5 is exactly what it was before this file existed |

A profile with no `gates.coding_standards` key reads as `off`. `keel init` writes `warn` on every
profile it creates.

**Addressed** means one of two things. Fixed: the diff no longer carries what the finding
described. Accepted: the user names the finding under "Overrides" in the skill body, and it goes in
the PR body. "Ship it anyway" names nothing and is not an acceptance.
````

- [x] **Step 3: Edit gate item 5 in the skill body**

In `skills/ship/SKILL.md`, replace the line

```markdown
5. **`review-code` has run** and nothing blocking remains.
```

with

```markdown
5. **`review-code` has run**, nothing blocking remains, and, under `gates.coding_standards`, no
   standards violation remains unaddressed: [references/standards-gate.md](references/standards-gate.md).
```

By the validator's own count (`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/ship/SKILL.md | wc -w`)
that takes the body from 695 to 703: over the 700 target, under the 900 ceiling.

- [x] **Step 4: Run the validator, watch it warn, and repair the line citations the split moved**

Run: `tests/validate-skills.sh`
Expected: a new WARN line for `ship`, in the shape "body is 703 words, over the 700 target
(ceiling 900). ADR-0001 requires a passing eval arm at this length", and one FAIL:

```
templates/profile.schema.json has an x-keel-read-by problem: conventions.commit_style names
advisory:skills/ship/SKILL.md:60 and that line is blank
```

Item 5 is one line longer, so every line of the body after it moved down by one.

Fix the marker with a phrase, which does not move. In `templates/profile.schema.json`, the
`commit_style` property's marker

```json
          "x-keel-read-by": "advisory:skills/ship/SKILL.md:60"
```

becomes

```json
          "x-keel-read-by": "advisory:skills/ship/SKILL.md#profile.conventions.commit_style"
```

(`profile.conventions.commit_style` is the literal text on the line "Commit style comes from
`profile.conventions.commit_style`." in the skill body.)

Run: `tests/validate-citations.sh`
Expected: three FAIL lines, each a record citing a line of `skills/ship/SKILL.md` that moved:
`docs/plans/2026-09-07-declared-profile-keys-take-effect.md`, `docs/ideas/declared-profile-keys-take-effect.md`
(both cite `:60`) and `docs/plans/2026-08-31-release-operations-and-claims-audit.md` (cites
`:34-35`). Records keep line numbers rather than phrases (`tests/validate-citations.sh`, the
"Records" case), so in each, add one to every cited `skills/ship/SKILL.md` line number: `:60`
becomes `:61`, `:34-35` becomes `:35-36`. Change the number and nothing else in those lines.

Run: `tests/validate-citations.sh`
Expected: `OK`.

Run: `tests/validate-skills.sh`
Expected: the single new WARN, no FAIL.

- [x] **Step 5: Rewrite the schema entry and regenerate the reference page**

In `templates/profile.schema.json`, the `coding_standards` property under `gates` (it begins at the
line `"coding_standards": {`) currently reads:

```json
        "coding_standards": {
          "enum": [
            "required",
            "warn",
            "off"
          ],
          "description": "Whether a change must follow the conventions in the project's standards document. No skill, hook or CLI path is written to read it, so nothing in keel enforces it, and an agent reading the profile acts on it anyway: an eval arm was measured doing exactly that, which is what the observed: marker cites. Declared so the intent has somewhere to live until something enforces it, and docs/ideas/standards-that-bind.md already ranks that wiring.",
          "x-keel-read-by": "observed:tests/evals/results.md#read by nothing and acted on anyway"
        },
```

Replace it with:

```json
        "coding_standards": {
          "enum": [
            "required",
            "warn",
            "off"
          ],
          "description": "Whether a change must follow the conventions in the project's standards document. Read by ship at its gate item 5, through skills/ship/references/standards-gate.md, advisorily: required refuses the ship while a review-code finding that cites a coding-standards reference file is unaddressed, warn reports it and continues, off adds no check. A profile with no key reads as off. An eval arm was also measured acting on this key unprompted, which is what the observed: marker cites.",
          "x-keel-read-by": [
            "advisory:skills/ship/references/standards-gate.md#gates.coding_standards",
            "observed:tests/evals/results.md#read by nothing and acted on anyway"
          ]
        },
```

Then regenerate the page:

Run: `tests/generate-profile-keys.sh > docs/profile-keys.md`
Expected: exits 0. `git diff --stat docs/profile-keys.md` shows one changed row, the
`gates.coding_standards` one, and nothing else.

Run: `tests/validate-skills.sh`
Expected: no FAIL. The marker resolves: the phrase `gates.coding_standards` is in the reference
file, and the `observed:` entry still renders, which `tests/test-profile-keys.sh` asserts.

- [x] **Step 6: Correct the catalog row**

In `docs/02-skill-catalog.md`, row 9 of the capability table reads:

```markdown
| 9 | Coding standards derived and documented, the mechanical ones moved into the linter. Enforced by nothing at coding time | `coding-standards`, checked against a diff by `review-code` |
```

Replace it with:

```markdown
| 9 | Coding standards derived and documented, the mechanical ones moved into the linter. Enforced at ship under `gates.coding_standards` | `coding-standards`, checked against a diff by `review-code`, refused at `ship` gate item 5 per `skills/ship/references/standards-gate.md` |
```

- [x] **Step 7: Discharge the eval-arm requirement**

`ship-with-flaky-tests` (`tests/evals/scenarios/ship-with-flaky-tests.md`) injects `ship` and
passed at 695 words on the 0.20.0 gate. Per ADR-0001's 2026-09-04 clarification, an arm that
passes against the modified body discharges the requirement at the new length, so this existing
scenario is re-run; no new scenario is needed.

Run:
```bash
dir=$(tests/evals/stage.sh ship-with-flaky-tests)
cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json"
```

Read `$dir/result.json` and score it against the scenario's own "Passes if" and "Fails if"
paragraphs, not from memory: it refuses to open the PR while the suite is red, says which check
failed, and neither accepts "flaky" as sufficient nor repairs the tests as part of shipping.

Record the result in `tests/evals/results.md`: a new `## 2026-09-21, ship gate reads
gates.coding_standards` heading at the end of the file, the cost and method line the existing
entries carry, and one row in the `| Scenario | Skill | Verdict | Note |` table shape, noting the
body length the arm ran at and that gate item 5 now names the standards gate.

- [x] **Step 8: Run the suite at the unit boundary, then hand over**

Run: `tests/validate-skills.sh`
Expected: the same single new WARN as step 4, no FAIL.

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched
against the start record.

```bash
git add skills/ship/references/standards-gate.md skills/ship/SKILL.md \
        templates/profile.schema.json docs/profile-keys.md docs/02-skill-catalog.md \
        tests/evals/results.md \
        docs/plans/2026-09-07-declared-profile-keys-take-effect.md \
        docs/ideas/declared-profile-keys-take-effect.md \
        docs/plans/2026-08-31-release-operations-and-claims-audit.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(ship): gates.coding_standards refuses a ship over an unaddressed standards violation"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did
not touch, say so and leave it unstaged.

**Deviation, recorded by the coordinator.** The quality review found gate item 5's second line at
105 columns; the rewrap needed to fit it split the link onto a third line, which shifted every
later line of `skills/ship/SKILL.md` by one more than step 4 accounted for. That shift broke three
citations step 4 had already fixed
(`docs/plans/2026-08-31-release-operations-and-claims-audit.md:388`,
`docs/plans/2026-09-07-declared-profile-keys-take-effect.md:813`,
`docs/ideas/declared-profile-keys-take-effect.md:91`, each re-bumped by one more) and revealed five
pre-existing shorthand citations (`ship/SKILL.md:N`,
a form `tests/validate-citations.sh` does not scan, by its own documented design) in
`docs/ideas/write-ci-does-not-match-ship.md`, `docs/ideas/standards-that-bind.md` (two), and
`docs/ideas/leon-van-zyl-skill-collection.md` (two of seven checked; the other five either needed
no change or, for two at `leon-van-zyl-skill-collection.md:139` and `:193`, turned out to already be
imprecise before this task and were left alone as unrelated pre-existing drift). All were repaired
and independently re-verified; `tests/validate-citations.sh` and `tests/validate-skills.sh` are
both clean. The quality review's second should-fix, a "before this file existed" sentence in
`skills/ship/references/standards-gate.md` violating "shipped prose states the current state," was
reworded. Its first should-fix, that the gate's definition of "standards violation" does not cover
a `review-code` finding citing `<docs_root>/standards.md` (rubric section 4) rather than
`skills/coding-standards/references/`, was checked against the PRD and left as specified: FR-04
confirms this exact scoping as Bernard's deliberate choice, 2026-09-21 (Q2), and Bernard reconfirmed
it when asked during this run. No change made.

---

### Task 3: A `Blocking` quality finding gates the tick, the same as `DEVIATES`

**Story:** S-03
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md` ("Running the loop")
- Modify: `docs/02-skill-catalog.md` (row 9, extending task 2's wording)

**Interfaces:**
- Consumes: nothing from earlier tasks. Reads the same file's "3. Code quality review" prompt,
  which already ranks findings `blocking`, `should fix`, `consider`.
- Produces: nothing shared.

**Depends on:** task 2 (the catalog row this task extends is the one task 2 wrote)

**Done when:** `tests/validate-skills.sh` reports no FAIL and no new WARN, and
`tests/validate-citations.sh` prints `OK`.

- [x] **Step 1: There is no failing-test step in the TDD sense for this task**

A reference-file edit. `skills/execute-plan/SKILL.md` is at 896 of 900 words and is not touched;
`references/` files are not word-counted (`tests/validate-skills.sh`, the reference-file rule).

Run: `tests/validate-skills.sh`
Record: the WARN list, for comparison. `execute-plan`'s own line says 896 words, 4 from the
ceiling.

- [x] **Step 2: Make the loop's tick conditional on the quality verdict too**

In `skills/execute-plan/references/subagent-prompts.md`, under "## Running the loop", the sentence

```markdown
After both passes: tick the checkboxes in the plan file, **then commit**, with the paths and the
message the task's hand-over step names, then dispatch the next.
```

becomes

```markdown
After both passes, with pass one at COMPLIES and pass two carrying nothing `blocking`: tick the
checkboxes in the plan file, **then commit**, with the paths and the message the task's hand-over
step names, then dispatch the next.
```

Then, immediately after the paragraph that begins `**Never re-dispatch on top of the rejected
attempt.**` and before the heading `## Which model each prompt goes to`, insert:

```markdown

**A `blocking` finding from the quality review is handled exactly as a DEVIATES verdict is**, and
for the same reason: the tick is the gate, and a finding acted on only after the commit is a
comment on history. Do not tick, do not commit. Discard the attempt and re-dispatch the task to a
fresh subagent with the finding attached, as above. `should fix` and `consider` findings do not
stop the tick; they go in the Step 6 report beside the task they came from. The one way past a
`blocking` finding without a fix is the user accepting it by name, and that acceptance is written
into the plan file beside the task before its box is ticked.
```

- [x] **Step 3: Extend the catalog row**

In `docs/02-skill-catalog.md`, row 9 now reads (from task 2):

```markdown
| 9 | Coding standards derived and documented, the mechanical ones moved into the linter. Enforced at ship under `gates.coding_standards` | `coding-standards`, checked against a diff by `review-code`, refused at `ship` gate item 5 per `skills/ship/references/standards-gate.md` |
```

Replace it with:

```markdown
| 9 | Coding standards derived and documented, the mechanical ones moved into the linter. Enforced at ship under `gates.coding_standards`, and per task in a delegated `execute-plan` run | `coding-standards`, checked against a diff by `review-code`, refused at `ship` gate item 5 per `skills/ship/references/standards-gate.md`, and a `blocking` quality finding stops the tick per `skills/execute-plan/references/subagent-prompts.md` |
```

- [x] **Step 4: Run the validators and watch them pass**

Run: `tests/validate-skills.sh`
Expected: the same WARN list as step 1, no FAIL, `execute-plan` still at 896.

Run: `tests/validate-citations.sh`
Expected: `OK`.

Run: `python3 -c "import sys; [print(i, l.rstrip()) for i, l in enumerate(open('skills/execute-plan/references/subagent-prompts.md', encoding='utf-8'), 1) if chr(8212) in l or chr(8211) in l]"`
Expected: no output.

- [x] **Step 5: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched
against the start record.

```bash
git add skills/execute-plan/references/subagent-prompts.md docs/02-skill-catalog.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(execute-plan): a blocking quality finding stops the tick, as DEVIATES does"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did
not touch, say so and leave it unstaged.

**Deviation, recorded by the coordinator.** The "After both passes" edit shifted the DEVIATES
paragraphs below it by one line, which broke a pre-existing citation in
`docs/stories/coding-standards-enforcement.md:15`, into
`skills/execute-plan/references/subagent-prompts.md`, formerly the range starting at line 145,
now starting at line 146. Fixed per this project's fix-citation-drift-per-task convention and
staged alongside this task's two named paths; both reviews independently confirmed the range
still spans the same content and nothing else on that line changed.

---

### Task 4: `keel doctor` fails a `required` project with no standards document

**Story:** S-07
**Files:**
- Modify: `bin/keel` (`cmd_doctor_text`, one check)
- Modify: `tests/test-keel.sh` (one new block)
- Modify: `templates/profile.schema.json` (add the `code:` marker entry)
- Regenerate: `docs/profile-keys.md`

**Interfaces:**
- Consumes: `json_get .keel/profile.json gates.coding_standards` (a string, or empty when the key
  is absent), and `$root` from `docs_root`, both already in scope in `cmd_doctor_text`.
- Produces: the doctor line `cs="$(json_get .keel/profile.json gates.coding_standards`, which the
  schema marker in step 6 cites by phrase.

**Depends on:** task 3 (sequential: task 5 and 6 also modify `bin/keel` and `tests/test-keel.sh`,
and this task's schema edit builds on task 2's)

**Done when:** `bash tests/test-keel.sh` prints `N passed, 0 failed` for its new assertions and
exits 0 (or 1 only for the pre-existing intermittent `commit guard: status said nothing`
assertion, named).

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, insert this block immediately before the comment line that begins
`# --- write_ci reaches every verify.* command`:

```bash
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
  *) ok "a warn or off gate does not fail on a missing standards document" ;;
esac
rm -rf "$cs"

```

Then lint: `shellcheck -x tests/test-keel.sh`
Expected: no output.

- [x] **Step 2: Run it and watch it fail**

Run: `bash tests/test-keel.sh 2>&1 | grep -n "coding_standards\|passed,"`
Expected: `FAIL  coding_standards: no FAIL naming the missing standards document` and
`FAIL  coding_standards: no ok line for the present document`; the third assertion passes
because doctor currently says nothing either way. The summary line shows 2 failed.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, inside `cmd_doctor_text`, find the block that ends

```bash
            warn "artifacts.$akey is null but '$apath' exists, so the profile does not know about it. Record it with: keel profile sync"
        done
    fi
```

and insert immediately after that `fi`:

```bash

    # gates.coding_standards is a promise about a document. required with no <docs_root>/standards.md
    # is indistinguishable from off, and it is the one state in which the key reads as configured
    # while enforcing nothing, so it fails rather than warns. json_get answers from the cache: no
    # interpreter start. FR-10, docs/prd/coding-standards-enforcement.md.
    local cs; cs="$(json_get .keel/profile.json gates.coding_standards 2>/dev/null || true)"
    if [ "$cs" = required ]; then
        [ -f "$root/standards.md" ] && good "gates.coding_standards is required and $root/standards.md exists" \
          || fail "gates.coding_standards is required and $root/standards.md does not exist. Write it with coding-standards, or set the gate to warn or off"
    fi
```

Then lint: `shellcheck -x bin/keel`
Expected: no output.

- [x] **Step 4: Run it and watch it pass**

Run: `bash tests/test-keel.sh 2>&1 | grep -n "coding_standards\|standards document\|python3 at most\|passed,"`
Expected: the three new assertions PASS, `keel doctor starts python3 at most 10 times` still
PASSES (this check adds no interpreter start), and the summary shows 0 failed.

- [x] **Step 5: Add the `code:` marker and regenerate the page**

In `templates/profile.schema.json`, the `coding_standards` entry from task 2 has the marker

```json
          "x-keel-read-by": [
            "advisory:skills/ship/references/standards-gate.md#gates.coding_standards",
            "observed:tests/evals/results.md#read by nothing and acted on anyway"
          ]
```

Make it

```json
          "x-keel-read-by": [
            "advisory:skills/ship/references/standards-gate.md#gates.coding_standards",
            "code:bin/keel#cs=\"$(json_get .keel/profile.json gates.coding_standards",
            "observed:tests/evals/results.md#read by nothing and acted on anyway"
          ]
```

and append this sentence to the end of the same entry's `description` string, inside the JSON
quotes, backticks included (an unbackticked `<docs_root>` renders as an HTML tag in the generated
table): `` Read by keel doctor, which fails a required project with no `<docs_root>/standards.md`
to check against.``

Run: `tests/generate-profile-keys.sh > docs/profile-keys.md`
Expected: exits 0; `git diff --stat docs/profile-keys.md` shows the one row.

Run: `tests/validate-skills.sh`
Expected: no FAIL. The `code:` phrase is literally in `bin/keel` and `coding_standards` is on
that line, which is what the marker rule checks.

- [x] **Step 6: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched
against the start record.

```bash
git add bin/keel tests/test-keel.sh templates/profile.schema.json docs/profile-keys.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(doctor): fail a required coding_standards gate that has no document to check"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did
not touch, say so and leave it unstaged.

**Deviation, recorded by the coordinator.** The quality review found the test's third assertion
claimed to cover both `warn` and `off`, per S-07's "warn or off" scenario, while only setting the
gate to `warn`. Fixed by adding a fourth assertion that sets the gate to `off` and checks doctor
separately, and narrowing the `warn` assertion's message to name only `warn`. Both states are now
independently exercised; re-verified clean.

---

### Task 5: `keel init` merges TypeScript strict-mode into `tsconfig.json`

**Story:** S-04
**Files:**
- Modify: `bin/keel` (new function `merge_ts_strict`, one call in `cmd_init`)
- Modify: `tests/test-keel.sh` (one new block)
- Modify: whichever records under `docs/` cite a `bin/keel` line this insertion moves (step 5
  names them; a line number only, nothing else)

**Interfaces:**
- Consumes: `json_get .keel/profile.json stack.language` (already cached in `cmd_init` after
  `json_load`), `have_python`, `err`.
- Produces: `merge_ts_strict`, a function with no arguments that returns 0 always. Called from
  `cmd_init` only.

**Depends on:** task 4 (same files)

**Done when:** `bash tests/test-keel.sh` prints `N passed, 0 failed` for its new assertions and
exits 0 (or 1 only for the named intermittent assertion).

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, insert this block immediately after the block task 4 added (that is,
still before the `# --- write_ci reaches every verify.* command` line):

```bash
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

```

Then lint: `shellcheck -x tests/test-keel.sh`
Expected: no output.

- [x] **Step 2: Run it and watch it fail**

Run: `bash tests/test-keel.sh 2>&1 | grep -n "tsconfig\|passed,"`
Expected: `FAIL  tsconfig: compilerOptions.strict is 'None' after init, want True` and
`FAIL  tsconfig: no message about the unparsed tsconfig`. The other four assertions pass on the
current code (nothing touches `tsconfig.json` today, which is exactly what they assert survives).
Summary shows 2 failed.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, immediately before the line `write_ci() {`, add:

```bash
# Strict type checking on (skills/coding-standards/references/house-defaults.md, "Types and
# tooling") is the one house rule the compiler holds for a TypeScript project, so init sets it
# where tsconfig.json has not decided. A strict the project set, to either value, is its decision
# and stays. A file this cannot parse (a comment, a trailing comma) is left byte identical and said
# so: the posture merge_permissions_into_settings takes toward .claude/settings.json. One
# interpreter start, only on a typescript project with a tsconfig.json.
merge_ts_strict() {
    [ "$(json_get .keel/profile.json stack.language || true)" = typescript ] || return 0
    [ -f tsconfig.json ] || return 0
    have_python || { err "python3 absent: could not set compilerOptions.strict in tsconfig.json. Set it by hand."; return 0; }
    python3 - <<'PY' || true
import json
p = "tsconfig.json"
try:
    d = json.load(open(p))
except Exception as e:
    raise SystemExit("keel: %s could not be parsed (%s), so compilerOptions.strict was not set. Set it by hand." % (p, e))
opts = d.setdefault("compilerOptions", {})
if "strict" in opts:
    raise SystemExit(0)
opts["strict"] = True
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
print("  set compilerOptions.strict to true in tsconfig.json (house rule: strict type checking on)")
PY
}
```

`raise SystemExit("...")` with a string prints it to stderr and exits 1, which `|| true` absorbs;
`cmd_init` runs without `set -e`, and the message is what the test asserts on.

Then in `cmd_init`, the line

```bash
    ignore_local_state
```

becomes

```bash
    ignore_local_state
    merge_ts_strict
```

Then lint: `shellcheck -x bin/keel`
Expected: no output.

- [x] **Step 4: Run it and watch it pass**

Run: `bash tests/test-keel.sh 2>&1 | grep -n "tsconfig\|python3 at most\|passed,"`
Expected: all six new assertions PASS; `keel init starts python3 at most 10 times` still PASSES
(a node fixture goes from 3 starts to 4); summary shows 0 failed.

- [x] **Step 5: Repair the `bin/keel` line citations this insertion moved**

`bin/keel` is cited by line from records under `docs/`, and this task inserted lines above most of
those citations. `tests/validate-citations.sh` names each one that now lands on a blank line.

Run: `tests/validate-citations.sh`
Expected: one or more `FAIL` lines, each of the shape "`<citing file>:<n>` cites `bin/keel:<N>`, and
line `<N>` of bin/keel is blank". Record the count.

For each, find what the citation pointed at and where it is now:

```bash
git show HEAD:bin/keel | sed -n '<N>p'              # the line the citation meant
grep -n -F '<that line, verbatim>' bin/keel        # where it is now
```

Then, in the citing file, change only the number. A citing file under `docs/plans/`,
`docs/prd/`, `docs/stories/`, `docs/architecture/`, `docs/decisions/`, `docs/audits/`,
`docs/ideas/`, `docs/07-open-decisions.md`, `docs/harness-support.md`, `tests/evals/` or
`CHANGELOG.md` is a record and keeps a line number. Any other citing file gets a phrase instead, the path,
a `#`, and text quoted from the line, because a line number into `bin/keel` from a document that
states current truth is stale within a task (`tests/validate-citations.sh`, "A file that changes
often, cited by line").

Run: `tests/validate-citations.sh`
Expected: `OK`.

Stage every file you changed here with the hand-over below; list them in your report.

- [x] **Step 6: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched
against the start record.

```bash
git add bin/keel tests/test-keel.sh
git add <each record file step 5 changed, by name, one path per argument>
git status --porcelain
```

Stage exactly those paths and stop. The second `git add` lists the files step 5 named, by path; it
is never `-A`, `.` or a glob. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(init): set compilerOptions.strict where a TypeScript project has not decided"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did
not touch, say so and leave it unstaged.

**Deviation, recorded by the coordinator.** The quality review found `merge_ts_strict` crashed with
an uncaught Python traceback, rather than its intended friendly message, on a `tsconfig.json` that
parses but is not a JSON object (for example `null`). Fixed with an `isinstance` guard, scoped to
this function only. That fix added four lines inside `merge_ts_strict`, which shifted every later
`bin/keel` line by four more, breaking further citations: some `tests/validate-citations.sh` caught
directly, others landed on unrelated but non-blank content, which the checker's blank-line-only rule
cannot see by design (its own header explains a content-matching rule was tried, measured at a 70%
false-positive rate, and deliberately dropped). Both classes were traced by hand against
`git show HEAD:bin/keel` and repaired across two more passes, ending with
`tests/validate-citations.sh` clean at `OK` and a total of 20 files staged (`bin/keel`,
`tests/test-keel.sh`, and 18 citation-repair documents; six of the eighteen were not in this task's
originally declared file list, added because the second shift touched them too).

During that tracing, several citations were found to have already been wrong before this task, or
before this whole plan, touched `bin/keel` at all: task 5's mechanical shift correctly preserved
their line-relative offset, it just moved an already-wrong pointer to a new number. These are
pre-existing drift, not introduced by this task, and are left untouched, matching the scope this
project's own citation checker already accepts (see above) and the same call already made earlier in
this plan for other pre-existing citations:
the `docs/audits/2026-08-19-efficiency.md` line 9 citation,
the `docs/audits/2026-09-02-standards.md` line 39 citation (second occurrence),
the `docs/audits/2026-09-20-security.md` line 81 citation (first occurrence), `docs/ideas/fleet-view-for-doctor.md:19`
and `:20`, `docs/ideas/leon-van-zyl-skill-collection.md:177`,
`docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:490,921,993`,
`docs/ideas/profile-loosening-goes-unnoticed.md:30`, `docs/ideas/context-window-at-init.md:100,129`,
`docs/ideas/snapshot-records-its-own-path.md:36,86`, `docs/ideas/snapshot-citation-accuracy.md:46`,
`docs/stories/context-window-at-init.md:339`'s `bin/keel:1602` citation,
the `docs/audits/2026-09-20-security.md` line 81 citation (second occurrence, now `bin/keel:2070`),
the `docs/audits/2026-08-19-delegation-rules-baselines.md` lines 318 and 322 citations, and
`docs/plans/2026-09-07-declared-profile-keys-take-effect.md`'s `artifacts.*` and `project.kind`
citations. One genuine task-5-caused miss was found and fixed:
`docs/stories/coding-standards-enforcement.md:324` still cited the pre-should-fix value for
`write_ci`; its sibling `docs/prd/coding-standards-enforcement.md` had the correct one, which is how
the miss was caught. A full semantic audit of every citation into `bin/keel` is a separate, larger,
already-recognized problem (`docs/plans/2026-09-09-citations-the-checker-cannot-see.md`) that no
single task in this plan is scoped to solve.

---

### Task 6: `keel init`'s generated CI audits dependencies, keyed on the package manager

**Story:** S-05
**Files:**
- Modify: `bin/keel` (`write_ci`, one step; `cmd_init`, one note)
- Modify: `tests/test-keel.sh` (one new block)
- Modify: whichever records under `docs/` cite a `bin/keel` line this insertion moves (step 5
  names them; a line number only, nothing else)

**Interfaces:**
- Consumes: `json_get .keel/profile.json stack.package_manager` (`npm`, `pnpm`, `yarn`, `bun`,
  `pip`, `poetry`, `uv`, `pdm`, `pipenv`, `none`, or empty when two lockfiles left it undeclared),
  `$VERIFY_KEYS`, and the existing `write_ci` structure.
- Produces: `CI_AUDIT_SKIPPED`, a global `write_ci` sets to the package manager it found no audit
  command for, empty otherwise; `cmd_init` reads it once for a note.

**Depends on:** task 5 (same files)

**Done when:** `bash tests/test-keel.sh` prints `N passed, 0 failed` for its new assertions and
exits 0 (or 1 only for the named intermittent assertion).

- [x] **Step 1: Write the failing test**

In `tests/test-keel.sh`, insert this block immediately after the existing block that ends
`rm -rf "$w4"` (the "two CI markers make the platform ambiguous" case):

```bash

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
```

Then lint: `shellcheck -x tests/test-keel.sh`
Expected: no output.

- [x] **Step 2: Run it and watch it fail**

Run: `bash tests/test-keel.sh 2>&1 | grep -n "audit\|write_ci\|passed,"`
Expected: FAIL for the npm, pnpm, yarn, both pip cases, and "init did not say the audit step was
skipped"; PASS for "never runs npm audit", "no audit mapping gets no step", the go silence and
the byte-identical case, which hold on the current code. Summary shows 6 failed.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, inside `write_ci`, after the two `local` lines

```bash
    local lang; lang="$(json_get .keel/profile.json stack.language || true)"
    local test_cmd; test_cmd="$(json_get .keel/profile.json verify.test || true)"
```

add, still before the `{` that opens the redirected block:

```bash
    # house-defaults.md, "Dependencies": an advisory scan runs in CI and fails the build on a high
    # severity finding. Keyed on the package manager, because `npm audit` in a pnpm project fails for
    # the wrong reason. Computed here rather than inside the block below, because a `say` in there
    # would land in the workflow file. FR-06, docs/prd/coding-standards-enforcement.md.
    local pm audit; pm="$(json_get .keel/profile.json stack.package_manager || true)"
    case "$pm" in
      npm)  audit='npm audit --audit-level=high' ;;
      pnpm) audit='pnpm audit --audit-level high' ;;
      yarn) audit='yarn npm audit --severity high' ;;
      pip)  if [ -f requirements.txt ]; then audit='pip install pip-audit && pip-audit -r requirements.txt'
            else audit='pip install pip-audit && pip-audit'; fi ;;
      *)    audit="" ;;
    esac
    CI_AUDIT_SKIPPED=""
    [ -n "$audit" ] || CI_AUDIT_SKIPPED="${pm:-none declared}"
```

(`CI_AUDIT_SKIPPED` is deliberately not `local`: `cmd_init` reads it after `write_ci` returns.)

Then, inside the block, after the `done` that closes the `for k in $VERIFY_KEYS` loop and before
the line `printf '\n      - name: Refuse committed key material\n        run: |\n'`, add:

```bash
      [ -n "$audit" ] && printf '\n      - name: Audit dependencies\n        run: %s\n' "$audit"
```

Then in `cmd_init`, the line

```bash
    { [ -n "$(json_get .keel/profile.json deploy.ci || true)" ] || ci_marker_present; } || write_ci
```

becomes

```bash
    { [ -n "$(json_get .keel/profile.json deploy.ci || true)" ] || ci_marker_present; } || write_ci
    # Only where the mapping could have applied: a go or rust project is not missing an audit step
    # this table was ever going to write, and a note on every init is one people stop reading.
    case "$(json_get .keel/profile.json stack.language || true)" in
      javascript|typescript|python)
        [ -n "${CI_AUDIT_SKIPPED:-}" ] && say "  note: no dependency audit step in the CI workflow: no audit command is known for package manager '$CI_AUDIT_SKIPPED'. Add one by hand." ;;
    esac
```

No top-level declaration: `cmd_init` reads `${CI_AUDIT_SKIPPED:-}`, which is safe under `set -u`
whether or not `write_ci` ran, and a line added near the top of `bin/keel` would move every
citation below it for nothing.

Then lint: `shellcheck -x bin/keel`
Expected: no output. If SC2034 reports `CI_AUDIT_SKIPPED` appears unused, it is read in
`cmd_init`; check the spelling matches in both places rather than adding a directive.

- [x] **Step 4: Run it and watch it pass**

Run: `bash tests/test-keel.sh 2>&1 | grep -n "audit\|write_ci\|passed,"`
Expected: all ten new assertions PASS, the existing `write_ci` assertions still PASS, summary
shows 0 failed.

- [x] **Step 5: Repair the `bin/keel` line citations this insertion moved** (done where
  possible, unresolved otherwise; see the deviation note after Step 6)

`bin/keel` is cited by line from records under `docs/`, and this task inserted lines above most of
those citations. `tests/validate-citations.sh` names each one that now lands on a blank line.

Run: `tests/validate-citations.sh`
Expected: one or more `FAIL` lines, each of the shape "`<citing file>:<n>` cites `bin/keel:<N>`, and
line `<N>` of bin/keel is blank". Record the count.

For each, find what the citation pointed at and where it is now:

```bash
git show HEAD:bin/keel | sed -n '<N>p'              # the line the citation meant
grep -n -F '<that line, verbatim>' bin/keel        # where it is now
```

Then, in the citing file, change only the number. A citing file under `docs/plans/`,
`docs/prd/`, `docs/stories/`, `docs/architecture/`, `docs/decisions/`, `docs/audits/`,
`docs/ideas/`, `docs/07-open-decisions.md`, `docs/harness-support.md`, `tests/evals/` or
`CHANGELOG.md` is a record and keeps a line number. Any other citing file gets a phrase instead, the path,
a `#`, and text quoted from the line, because a line number into `bin/keel` from a document that
states current truth is stale within a task (`tests/validate-citations.sh`, "A file that changes
often, cited by line").

Run: `tests/validate-citations.sh`
Expected: `OK`.

Stage every file you changed here with the hand-over below; list them in your report.

- [x] **Step 6: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched
against the start record.

```bash
git add bin/keel tests/test-keel.sh
git add <each record file step 5 changed, by name, one path per argument>
git status --porcelain
```

Stage exactly those paths and stop. The second `git add` lists the files step 5 named, by path; it
is never `-A`, `.` or a glob. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(init): the generated CI audits dependencies, keyed on the package manager"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did
not touch, say so and leave it unstaged.

**Deviation, recorded by the coordinator.** Step 5's own citation-repair investigation found all 12
citations `tests/validate-citations.sh` flags were already pointing at the wrong `bin/keel` content
at `HEAD`, before this task, or this plan, ever touched the file: this task's insertion moved an
already-wrong pointer from a non-blank (silently wrong) line onto a blank one, which is what
surfaced it. Per the lesson task 5 left behind, a mechanical shift onto a plausible-looking but
unverified line is worse than a visible `FAIL`, so none of the 12 were force-fixed. Both review
passes independently sampled several of the 12 against `git show HEAD:bin/keel` and confirmed the
mismatch predates this task. `tests/validate-citations.sh` is left red (`12 stale citation(s)
found`), the one exception to `tests/run-tests.sh`'s otherwise-clean run, matching its own "or reds
this task did not cause" clause: the underlying content wrongness is pre-existing, only its
visibility changed. No `docs/` file was touched by this task.

---

### Task 7: `repo-snapshot` runs the standards assessment, or names its absence

**Story:** S-06
**Files:**
- Modify: `skills/repo-snapshot/SKILL.md` (Step 2, one paragraph)
- Modify: `skills/repo-snapshot/references/section-templates.md` (section 8, one paragraph)
- Create: `tests/evals/scenarios/snapshot-against-a-standard.md`
- Create: `tests/evals/fixtures/snapshot-against-a-standard/` (a copy of
  `tests/evals/fixtures/assess-a-stale-standard/`, every file including `setup.sh`)
- Modify: `tests/evals/fixtures/README.md` (one entry, one count)
- Modify: `README.md`, `docs/06-repo-layout.md`, `tests/evals/README.md` (the scenario count,
  which `tests/test-doc-claims.sh` asserts against the tree)
- Modify: `tests/evals/results.md` (record the arm)

**Interfaces:**
- Consumes: `skills/coding-standards/SKILL.md` Step 0 (assess mode is chosen by the presence of
  `<docs_root>/standards.md`) and `skills/coding-standards/references/assess.md` (writes
  `<docs_root>/audits/YYYY-MM-DD-standards.md`). Nothing from earlier tasks.
- Produces: nothing shared.

**Depends on:** task 6 (sequential by choice: task 2 also appends to `tests/evals/results.md`,
and no batch is declared)

**Done when:** `tests/validate-skills.sh` reports no FAIL and one new WARN for `repo-snapshot`
crossing the 700-word target; `tests/test-eval-harness.sh` and `tests/test-doc-claims.sh` pass;
and the `snapshot-against-a-standard` arm passes against the new body, recorded in
`tests/evals/results.md`.

- [x] **Step 1: There is no failing-test step in the TDD sense for this task**

A skill-body edit plus a new eval scenario. `repo-snapshot` is at exactly 700 words, no existing
scenario injects it, and ADR-0001 requires a passing arm at the new length, so this task writes
the scenario the arm needs. Run the validators first so the "before" state is on record.

Run: `tests/validate-skills.sh`
Record: `repo-snapshot` reports no WARN line for itself, at 700 body words.

Run: `bash tests/test-doc-claims.sh 2>&1 | grep -n "scenario count"`
Record: `eval scenario count (13)` and the `06-repo-layout.md` twin, both PASS.

- [x] **Step 2: Edit the skill body**

In `skills/repo-snapshot/SKILL.md`, immediately after the quoted brief that ends
`> it from naming. Flag anything that contradicts the README.` and before the heading
`## Step 3: Verify what will drive action`, insert:

```markdown

Where `<docs_root>/standards.md` exists, **REQUIRED SUB-SKILL:** `keel:coding-standards` in
assess mode once the agents return, whoever wrote the document; its report's findings go to
section 8 and its remedies to section 10. Where it does not exist, section 8 says so as a gap and
section 10 names `coding-standards`.
```

By the validator's own count (`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/repo-snapshot/SKILL.md | wc -w`)
that takes the body from 700 to 747: over the 700 target, under the 900 ceiling.

- [x] **Step 3: Give the findings a home in the section template**

In `skills/repo-snapshot/references/section-templates.md`, under `## 8. Technical debt`,
immediately after the paragraph that begins `Dependency health belongs here:` and before the
heading `## 9. Health metrics`, insert:

```markdown

**Standards adherence belongs here too.** Where `<docs_root>/standards.md` exists, the assess
report at `<docs_root>/audits/YYYY-MM-DD-standards.md` supplies this part: its coverage figure and
each departure it found, cited to that report rather than restated from your own reading. Where no
document exists, one line: `No standards document; nothing to assess against`, and section 10
names `coding-standards` as the fix.
```

- [x] **Step 4: Run the validator and watch it warn**

Run: `tests/validate-skills.sh`
Expected: a new WARN line for `repo-snapshot`, in the shape "body is 747 words, over the 700
target (ceiling 900). ADR-0001 requires a passing eval arm at this length." No FAIL. Record the
count it prints.

Run: `tests/validate-citations.sh`
Expected: `OK`.

- [x] **Step 5: Write the scenario and its fixture**

Copy the fixture. Every file, `setup.sh` included, because that script is what builds the git
history the arm reads and seeds the two breaches the arm has to find:

```bash
cp -R tests/evals/fixtures/assess-a-stale-standard tests/evals/fixtures/snapshot-against-a-standard
```

Create `tests/evals/scenarios/snapshot-against-a-standard.md` with exactly this content:

````markdown
# snapshot a repository that carries a standards document

Inject: repo-snapshot coding-standards

**Tests:** whether a snapshot of a repository holding `docs/standards.md` assesses the code
against that document and reports what it found as debt, and whether the `repo-snapshot` body,
over the 700-word target, is still followed at its length, which is what ADR-0001 asks of it.
`coding-standards` is injected beside it because the arm has no other way to reach the assess
mode the snapshot is meant to invoke: `tests/evals/run.sh` pastes only the injected bodies, and
a skill the arm cannot see is a step it can only skip.

**Baseline, no skill:** not recorded. This is a treatment-only length measurement, not a
skill-versus-baseline comparison.

**The fixture** is `assess-a-stale-standard`'s, copied whole: a bash payout CLI with a
`docs/standards.md` derived at an earlier commit, and two functions landed after it that each
breach a rule the document states. `settle_payout` computes money in floating point, and
`receipt_line` prints a formatted local timestamp. `.keel/profile.json` sets
`gates.coding_standards` to `required` and `docs_root` to `docs`. Seven tracked files, so the
skill's own rule collapses the reading to three agents.

**Passes if the reply:** dispatches the reading agents; because `docs/standards.md` exists, runs
`coding-standards` in assess mode (a `docs/audits/<date>-standards.md` is written or drafted, and
`docs/standards.md` is left byte identical); writes `docs/snapshot.md`; and section 8 of that
snapshot carries the assessment's findings, the two seeded breaches among them, cited to the audit
report rather than to the arm's own reading of `src/payouts.sh`.

**Fails if the reply:** writes a snapshot whose section 8 does not mention the standards document
or the assessment; edits `docs/standards.md`; reports the breaches as its own unverified reading
with no audit report behind them; skips the assessment with a reason; or writes the assessment's
findings into section 10 only, with nothing in section 8.

## Prompt

Give me a snapshot of this repository. I am picking it up from someone who has left.
````

Then add the fixture to `tests/evals/fixtures/README.md`. After the `## assess-a-stale-standard`
entry's table and before `## seed-a-greenfield-mobile-app`, insert:

```markdown

## `snapshot-against-a-standard`

`assess-a-stale-standard`'s fixture, copied whole, `setup.sh` included. The scenario injects
`repo-snapshot` rather than `coding-standards`, and what it measures is whether the snapshot reaches
for the assessment at all when a `docs/standards.md` is there to assess against. The seeded rows
above are the ones the snapshot's section 8 has to carry.
```

And in the same file, the sentence that begins `All eight other fixtures that ship a profile
set` is already wrong: count the fixtures whose profile sets `docs` with
`grep -l '"docs_root": *"docs"' tests/evals/fixtures/*/.keel/profile.json | wc -l`, subtract one
for the fixture the paragraph describes, and write that number in words in place of `eight`
(twelve profiles set it once the new fixture is in, so `eleven`). The rest of the sentence,
including its backticked `docs`, stays as it is.

- [x] **Step 6: Correct every document that counts scenarios**

`tests/test-doc-claims.sh` asserts two of these against the tree; the third is prose made wrong
by the same change.

In `README.md`, the line `13 scenarios exist. Six are dispatched at a release gate and score a
reply.` becomes `14 scenarios exist. Six are dispatched at a release gate and score a reply.`
(The "Six" is a pre-existing discrepancy with `tests/evals/gate-scenarios`, which lists seven; it
is not this task's to settle, and is named in the plan's hand-off.)

In `docs/06-repo-layout.md`, `# 13 scenarios, 13 fixtures, results.md` becomes
`# 14 scenarios, 14 fixtures, results.md`.

In `tests/evals/README.md`, `Thirteen scenarios exist; 7 scenarios are dispatched at the release
gate` becomes `Fourteen scenarios exist; 7 scenarios are dispatched at the release gate`.

Run: `bash tests/test-doc-claims.sh 2>&1 | grep -n "scenario count"`
Expected: both PASS at 14.

Run: `bash tests/test-eval-harness.sh 2>&1 | grep -n "fixture\|criteria\|eval harness\|passed,"`
Expected: `every scenario has a fixture` PASS, `no scenario stages its own pass criteria` PASS,
`nothing staged names the eval harness` PASS, summary 0 failed.

- [x] **Step 7: Run the arm and score it against the scenario file**

Run:
```bash
dir=$(tests/evals/stage.sh snapshot-against-a-standard)
cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json"
```

Read `$dir/result.json`, then read `$dir/project/docs/snapshot.md` and `ls $dir/project/docs/audits/`
yourself: the scenario is scored on the artifacts, not the reply. Score against the "Passes if"
and "Fails if" paragraphs in `tests/evals/scenarios/snapshot-against-a-standard.md`. Confirm
`git -C $dir/project diff --quiet -- docs/standards.md` exits 0.

Record the result in `tests/evals/results.md`: a new `## 2026-09-21, repo-snapshot assesses
against a standards document` heading at the end of the file, the cost and method line the
existing entries carry, and one row in the `| Scenario | Skill | Verdict | Note |` table shape,
noting the body length the arm ran at and which section of the snapshot carried the findings. A
failing arm is recorded the same way, with the reason verbatim, and the task stops there for the
user rather than editing the body until the arm passes.

- [x] **Step 8: Run the suite at the unit boundary, then hand over**

Run: `tests/validate-skills.sh`
Expected: the same single new WARN as step 4, no FAIL.

Run: `tests/run-tests.sh`
Expected: `All test files passed`, or reds this task did not cause, each named and matched
against the start record. `tests/supply-chain-scan.sh` and `tests/no-internal-leaks.sh` both walk
the new fixture; it is a copy of one they already pass.

```bash
git add skills/repo-snapshot/SKILL.md skills/repo-snapshot/references/section-templates.md \
        tests/evals/scenarios/snapshot-against-a-standard.md \
        tests/evals/fixtures/snapshot-against-a-standard \
        tests/evals/fixtures/README.md README.md docs/06-repo-layout.md tests/evals/README.md \
        tests/evals/results.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(repo-snapshot): assess against the standards document, or name its absence"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did
not touch, say so and leave it unstaged.

**Deviation, recorded by the coordinator.** The quality review found the pre-existing section 10
rule that lists `coding-standards` as a required first-look recommendation did not account for
Step 2's new behaviour: on a repository that already has `<docs_root>/standards.md`, Step 2 now
runs that assessment itself, so repeating it as a generic section-10 recommendation duplicated
work already reported in section 8. Fixed by qualifying the bullet on whether the document already
exists. That two-line insertion shifted a citation into the same file from
`docs/plans/2026-09-07-declared-profile-keys-take-effect.md:65`, repaired in place (a line-number
only change, matching this project's citation-drift convention for record files).

Separately, before committing, the coordinator found that six of this task's intended files
(`README.md`, `docs/06-repo-layout.md`, `skills/repo-snapshot/SKILL.md`,
`tests/evals/README.md`, `tests/evals/fixtures/README.md`, `tests/evals/results.md`) had never
actually been staged: the implementer and both review passes each read `git status --porcelain`'s
leading space as meaning staged, when it means the opposite. All six were staged before commit;
their content was independently re-verified against the working tree and the project's own
validators (`tests/validate-citations.sh`, `tests/validate-skills.sh`,
`tests/test-doc-claims.sh`) rather than trusted from the earlier misreading.

---

## Open questions

None that block a task. Two things the plan could not settle and does not pretend to:

1. `README.md:185` says six scenarios are dispatched at the release gate; `tests/evals/gate-scenarios`
   lists seven, and `tests/test-eval-harness.sh` asserts the seven against `tests/evals/README.md`
   and the runbook, not against `README.md`. Task 7 leaves the word "Six" alone and changes only
   the count it is responsible for. Worth a one-line fix in its own change.
2. `CHANGELOG.md` has no `## Unreleased` section today. The entries for this plan, and for the four
   fixes made in the working tree earlier on 2026-09-21 (`bin/keel-fleet`, the pre-push first-push
   case, the `doctor plugins` test isolation, `incident-response` item 6), belong there when `ship`
   opens the pull request; `docs/runbooks/cutting-a-release.md` section 0 is the rule.
3. **The working tree is not clean, and `execute-plan` refuses a dirty tree before its first
   dispatch** (`skills/execute-plan/references/subagent-prompts.md`, "Running the loop"). The four
   fixes above, this plan, its PRD and its stories are all uncommitted. They are committed, or
   stashed, before task 1 is dispatched; which is the user's call, and the hand-off says so.

## Plan review, 2026-09-21

Dispatched per `skills/write-plan/references/plan-review.md`, model `inherit`, against the code.
Three findings blocked and are folded in above: case 27 of `tests/test-eval-harness.sh` pinned
`ship` as reference-less (task 1 step 5 re-points it at a probe); the item-5 split and the two
`bin/keel` insertions move line citations that `tests/validate-citations.sh` and
`tests/validate-skills.sh` then fail (task 2 step 4, task 5 step 5, task 6 step 5 repair them);
and an arm injecting `repo-snapshot` alone could not reach `coding-standards` (task 7's scenario
injects both). Should-fix findings taken: the working tree is dirty (open question 3); the
reference file's claim that every finding carries a citation is now a claim about the rubric's
bullets; word counts are the validator's (703, 747) and the scenario states none;
`docs/06-repo-layout.md` gains the reference row (task 1 step 6); the fixtures README count is
recounted rather than incremented. Not taken, with the reason: `yarn npm audit --severity high`
is Yarn Berry syntax and a `yarn.lock` alone cannot tell Berry from v1; the mapping is what PRD
FR-06 fixed after Q6, so it stands, and a v1 project's failing step is the visible outcome that
would earn the follow-up. The missing-audit note firing on every non-JavaScript, non-Python init
was taken: it fires only for those two ecosystems now.

## Self-review

1. Every story maps to a task: S-01 to task 1, S-02 to task 2, S-03 to task 3, S-07 to task 4,
   S-04 to task 5, S-05 to task 6, S-06 to task 7.
2. No placeholder phrases: every edit is quoted in full, every test is written out, every command
   names its expected output.
3. Names match across tasks: `merge_ts_strict` is defined in task 5 and called there;
   `CI_AUDIT_SKIPPED` is set in task 6's `write_ci` and read in task 6's `cmd_init`; the `code:`
   marker task 4 adds cites the exact `cs="$(json_get ...` line task 4 writes; task 3's catalog
   row starts from the text task 2 wrote.
4. Every verifying command is from `profile.verify` or is one of the repository's own validators
   that `tests/run-tests.sh` runs (`tests/validate-skills.sh`, `tests/validate-citations.sh`,
   `tests/test-doc-claims.sh`, `tests/test-eval-harness.sh`, `tests/generate-profile-keys.sh`).
   The `claude -p` dispatch and the dash and column checks are investigative, not verifying.
5. Every task ends with a hand-over that stages named paths and names the coordinator's commit.
   No task commits; no concurrent batch is declared. Tasks 5 and 6 stage, by name, whichever
   records their citation-repair step changed; the step says how to find them and the hand-over
   says never a glob.
6. No task depends on a file no task creates: `skills/ship/references/standards-gate.md` is created
   in task 1 before task 2 appends to it; the new fixture is copied in task 7 before task 7 stages
   it.
