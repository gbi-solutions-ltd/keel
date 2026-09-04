# Assess's second coverage number, and the inheritance rule Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** give assess a second, separately named coverage number, and state in `house-defaults.md`
how an adopter is expected to disagree with a house default.

**Stories:** S-10, S-12. **Not S-11**, and see below.

**ADRs:** ADR-0001 (body ceiling) and ADR-0002 (delegated execution) both apply. Neither binds a
task here, because nothing in this plan touches a skill body.

**Architecture.** Three tasks, all of them edits to reference files with a mechanical check written
first. Nothing here changes `SKILL.md`, so the body stays at 756 and this plan cannot move the
router figure the next plan depends on. **It does move the reference word count**, which six
documents assert, and every task carries them.

## Why this plan carries S-10 and S-12 and not S-11

The stories file groups S-10, S-11 and S-12 as "independent of the reference-move question", which
is true and is about S-02's result. **It is not the same as having no dependencies.**
`docs/stories/coding-standards-audit-and-seed.md:396` gives S-11 `Depends on | S-03, S-10`: the
fourth cell of the mode table is a routing outcome, and the router is S-03. S-11 therefore cannot
run before the router exists and belongs in the router plan, where it is planned.

S-10 depends on S-02, which landed in `4889f7a`. S-12 depends on nothing. Both are buildable today.

## The figure this plan moves, and the six documents that assert it

**Every task here edits a file under `skills/coding-standards/references/`, so every task moves the
reference word count.** `tests/test-doc-claims.sh:99` computes it live as
`cat skills/coding-standards/references/*.md | wc -w` and asserts it in six places:

- `docs/05-token-and-memory-design.md`
- `docs/standards.md`
- `docs/decisions/ADR-0001-skill-body-word-ceiling.md`
- `docs/ideas/database-design-and-review.md`
- `docs/ideas/leon-van-zyl-skill-collection.md`
- `tests/validate-skills.sh`, in its own header comment

**A first draft of this plan reasoned about the body, concluded no figures moved, and named none of
these six in any task.** A reviewer applied task 1 verbatim and the suite printed `21 passed, 6
failed`. The body reasoning was right and irrelevant: the body is `SKILL.md` and the moving figure
is `references/*.md`. The baseline is **20,335** words, measured 2026-09-02 at `0e5ee02`.

Recompute after every task rather than copying a number from here:

```bash
find skills/coding-standards/references -name '*.md' | wc -l   # reference count
cat skills/coding-standards/references/*.md | wc -w            # reference words
```

## Where a new check goes in `tests/test-doc-claims.sh`

**Not at the end of the file.** `tests/test-doc-claims.sh` ends with
`printf '\n%s passed, %s failed\n'` and `[ "$fail" -eq 0 ]`. A case appended after those runs after
the totals are printed and after the exit status is decided, and because `bad()` ends in an explicit
`return 0`, a failure there leaves the script exiting 0. **The check would look present and do
nothing**, which is the exact class of defect this repository has corrected twice in one day.

**Every snippet in this plan goes immediately before the `while IFS='|' read -r file which phrase;
do` loop**, which is after the helpers and the counters and before the summary. Each task's step 1
repeats this instruction rather than referring back to it.

## Global constraints

Copied in full. A task executed by a fresh agent that reads only its own section still obeys these.

- **Verify commands**, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  There is no typecheck and no build.
- **Never start on `main`.** This work belongs on `sandbox`, which is where the branch already is.
- **ADR-0001:** a skill body is capped at 900 words and warns over 700. No task here changes a body;
  if one does, it has gone wrong.
- **Do not edit any file while `tests/run-tests.sh` is running.** The suite runs test files in
  parallel at `MAX_JOBS=4`, and `test-doc-claims.sh` and `validate-skills.sh` both recompute these
  figures from the tree at the moment they read it. An edit mid-run makes two jobs read different
  trees, and the failure looks like a wrong number rather than a race. Finish editing, then run.
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
  and `standards.md` is never edited by one. A new check inherits that rule.
- **No task here creates or deletes a file under `tests/evals/scenarios/`**, and none needs to.
- **A finding of the form "the arm did X" carries the command that extracted it**, per
  `tests/evals/results.md:6`. No task here runs an arm, so no task here should be recording one.

## Concurrency

**No concurrent batch is declared, and the reason is a shared file rather than a shared idea.**
Tasks 1 and 3 have disjoint story dependencies and touch disjoint content files, which is the
condition people usually stop at. All three also edit `tests/test-doc-claims.sh` and restage the
same six documents, and the template's batch rules require no shared file. Run them in order.

---

### Task 1: Check 1b's unit is stated, and its denominator is asserted against the tree

**Story:** S-10, satisfying FR-15, FR-16 and FR-17

**Files:**
- Modify: `tests/test-doc-claims.sh`
- Modify: `skills/coding-standards/references/assessment-report.md`
- Modify: `skills/coding-standards/references/assess.md`
- Modify, because the reference word count moves: `docs/05-token-and-memory-design.md`,
  `docs/standards.md`, `docs/decisions/ADR-0001-skill-body-word-ceiling.md`,
  `docs/ideas/database-design-and-review.md`, `docs/ideas/leon-van-zyl-skill-collection.md`,
  `tests/validate-skills.sh`

**Interfaces:**
- Produces: a stated counting unit for check 1b, and a claimed denominator that
  `tests/test-doc-claims.sh` computes from `house-defaults.md` rather than trusting.
- Consumes: `claim_in`, `ok` and `bad` from `tests/test-doc-claims.sh:20-50`, and
  `references/assess.md`, created by `4889f7a`.

**Depends on:** none

**Done when:** `tests/test-doc-claims.sh` reports **`27 passed, 0 failed`**, which is the baseline
24 plus this task's 3 new cases, and `tests/run-tests.sh` is green. **`0 failed` is the part that
matters**; if the total differs because something else added a case, check that the three new ones
are among the passes rather than adjusting this number.

**The denominator is 12, and it is 12 for a reason a check can re-derive.**
`skills/coding-standards/references/house-defaults.md` carries **14** `##` sections. S-10 excludes
exactly two by name, "The other references, and when each applies" at line 7 and "What is
deliberately not here" at line 242. 14 minus 2 is 12. Measured 2026-09-02. The check below computes
this rather than pinning the literal 12, so a fifteenth section moves the number and the document
that states it goes red instead of going stale.

- [x] **Step 1: Write the failing tests**
  (written by a dispatched implementer, not by me. I verified the placement myself: the block is at
  line 104, the `while IFS='|' read` loop at 138 and the summary at 168, so it is inside the
  counted region)

Insert into `tests/test-doc-claims.sh` **immediately before the line
`while IFS='|' read -r file which phrase; do`**. Not at the end of the file: see "Where a new check
goes" above, and do not skip that section on the grounds that this one looks obvious.

```bash
# ---- check 1b's denominator, computed rather than pinned ---------------------
#
# S-10 defines check 1b's unit as one ## section of house-defaults.md, excluding exactly two by
# name. The number that follows from that definition is asserted here rather than written down
# twice, because the failure mode for this figure is the one this whole file exists for: the
# document keeps its number while the reference grows a section.
hd="skills/coding-standards/references/house-defaults.md"
hd_all="$(grep -c '^## ' "$hd")"
hd_excluded=2
hd_rules=$((hd_all - hd_excluded))

# The two exclusions are asserted by name before the arithmetic that depends on them. A rename
# would leave hd_excluded=2 subtracting two sections that are no longer the two S-10 names, and the
# denominator would stay 12 while meaning something else.
if grep -q '^## The other references, and when each applies$' "$hd" \
   && grep -q '^## What is deliberately not here$' "$hd"; then
    ok "check 1b's two excluded headings exist under the names S-10 names"
else
    bad "check 1b's two excluded headings exist under the names S-10 names" \
        "a heading was renamed, so the exclusion no longer subtracts what it says it does"
fi

# claim_in takes the FIRST match of its phrase in the file. Both phrases below are unique today:
# "denominator is" does not otherwise occur in assessment-report.md, and assess.md spells its only
# other count as the word "ten". A sentence added above either one carrying a digit in the same
# shape would silently make these read the wrong number and still pass.
claim_in skills/coding-standards/references/assessment-report.md \
         "check 1b denominator in assessment-report.md" "$hd_rules" \
         'denominator is [0-9]+'

claim_in skills/coding-standards/references/assess.md \
         "check 1b denominator in assess.md" "$hd_rules" \
         'all [0-9]+ house defaults'
```

- [x] **Step 2: Run it and watch it fail**
  (the implementer watched `25 passed, 2 failed`: both `claim_in` cases failed as predicted. The
  heading guard passed on arrival and it declined to claim it as a watched failure. A reviewer
  re-derived the red from HEAD independently, where both phrases return 0 matches)

Run: `tests/test-doc-claims.sh`
Expected: FAIL, twice, with `no claim in skills/coding-standards/references/assessment-report.md
matched /denominator is [0-9]+/` and the same for `all [0-9]+ house defaults`. The heading case
passes on its first run, which is correct: it asserts existing structure and is a regression guard
rather than new behaviour. Record that it passed immediately rather than ticking it as a watched
failure.

- [x] **Step 3: Write the minimal implementation**
  (done by the implementer, with one deviation it declared: the bullet below wrapped between
  "house" and "defaults", which step 1's line oriented regex cannot match, so it reflowed the line
  and changed no words. The plan text is corrected above. A quality review then found three more
  sites, corrected by a second dispatch: a fifth "four checks" claim inside the copied block at
  `assessment-report.md:260`, a live one at `docs/02-skill-catalog.md:309`, and `1b.` not being a
  valid CommonMark marker, now a sub-item)

In `skills/coding-standards/references/assessment-report.md`, add a section immediately after
`## Check 1, house-defaults coverage` and before `## Check 2, the follow-up backlog`:

```markdown
## Check 1b, house-defaults coverage as its own number

**The counting unit.** One house rule is one `##` section of
[house-defaults.md](house-defaults.md), excluding exactly two by name: "The other references, and
when each applies", which is an index, and "What is deliberately not here", which is a statement of
scope. Nothing else is excluded from the count. No fixed number is subtracted, and no judgement is
made about whether a heading reads like a rule. The denominator is 12, measured 2026-09-02.

**What it reports.** For each of those sections, whether `standards.md` folds it in, adapts it,
departs from it with a reason, or omits it, on the same four dispositions check 1 uses. Report it
immediately after check 1 and before check 2.
```

In `skills/coding-standards/references/assess.md`, extend the numbered list. **The phrase "check
1b" must appear literally**, because task 4 of
`docs/plans/2026-09-02-the-four-mode-router-and-audit.md` greps this file for it as a precondition:

```markdown
1. **House-defaults coverage.** `standards.md` against all ten references the index lists,
   applicable or not, each row saying what decided it. Those predicates are prose, not profile
   fields. No code read.
1b. **The house defaults themselves, reported as check 1b.** `standards.md` against
   all 12 house defaults, which is every `##` section of `house-defaults.md` bar its
   index and its scope statement. Reported immediately after check 1, as its own number.
```

**The line break above is load bearing, and this text is the corrected form.** `claim_in` matches
with `grep -oE`, which is line oriented, so the phrase `all 12 house defaults` has to sit on one
line or step 1's assertion cannot match it and reports "no claim matched" rather than a wrong
number. A first version of this step wrapped between "house" and "defaults" and gave
`26 passed, 1 failed` when applied verbatim; the implementer reflowed it, changed no words, and
declared it. Corrected here on 2026-09-02 so the next reader does not reintroduce the break.

**The assertion stays wrap fragile and that is accepted.** Widening the regex to span lines means
abandoning line oriented matching inside `claim_in`, which every other case in the file relies on.
The cost of the fragility is a confusing failure message, not a wrong number, and a wrong number is
what this file exists to prevent.

**Correct the four places that say there are four checks**, because after this task there are five.
This is not tidying: `CLAUDE.md` makes a change land with the documents it makes wrong, and nothing
mechanical catches these.

- `references/assess.md:3`, "The four checks assess mode runs" becomes "The checks assess mode runs"
- `references/assess.md:10`, the `## The four checks` heading becomes `## The checks`
- `references/assessment-report.md:7`, "all four checks run every time" becomes "every check runs
  every time"
- `references/assessment-report.md:50`, the same phrase, the same replacement

Then recompute the reference count and reference word figures with the two commands in "The figure
this plan moves" and update all six documents that assert them.

- [x] **Step 4: Run it and watch it pass**
  (`27 passed, 0 failed` and a green suite, run by the implementer, by both reviewers and by me)

Run: `tests/test-doc-claims.sh`
Expected: `27 passed, 0 failed`.

Run: `tests/run-tests.sh`
Expected: green, and `validate-skills.sh` still reports `coding-standards: body is 756 words`. **If
the body has moved, this task has edited `SKILL.md` and has gone wrong.**

- [x] **Step 5: Hand over**
  (staged by the implementer and the correction dispatch, committed by me. Two paths beyond the
  nine listed: `docs/02-skill-catalog.md`, from the quality review, and this plan file)

```bash
git add tests/test-doc-claims.sh skills/coding-standards/references/assessment-report.md \
        skills/coding-standards/references/assess.md tests/validate-skills.sh \
        docs/standards.md docs/05-token-and-memory-design.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/database-design-and-review.md docs/ideas/leon-van-zyl-skill-collection.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(coding-standards): count the house defaults as check 1b"`.

---

### Task 2: The two coverage numbers are named separately and never summed

**Story:** S-10, satisfying FR-18

**Files:**
- Modify: `skills/coding-standards/references/assessment-report.md`
- Modify: `tests/test-doc-claims.sh`
- Modify, because the reference word count moves: the same six documents task 1 names

**Interfaces:**
- Consumes: task 1's check 1b section.
- Produces: a header row carrying two named coverage figures, and a fixed section order of eight
  rather than seven.

**Depends on:** task 1

**Done when:** `tests/test-doc-claims.sh` reports **`28 passed, 0 failed`**, task 1's 27 plus this
task's 1 new case, and `tests/run-tests.sh` is green.

**Why this is its own task rather than part of task 1.** Task 1 defines a unit and a denominator; a
reviewer can accept that and still reject how the number is presented. The failure this task
prevents is different too: a single combined coverage figure is what hides which of the two checks
failed, which is the whole point of S-10.

- [x] **Step 1: Write the failing test**
  (written by a dispatched implementer, on the second attempt. The first attempt was reviewed,
  returned DEVIATES, and was discarded in full before this one started from a clean tree)

Insert into `tests/test-doc-claims.sh` **immediately before the
`while IFS='|' read -r file which phrase; do` loop**, after task 1's block:

```bash
# The header must carry both coverage figures under distinct names. A single "coverage <n>" is the
# shape S-10 exists to remove, so the check fails on its absence rather than on its presence.
arp="skills/coding-standards/references/assessment-report.md"
if grep -q 'coverage <n>, house defaults <n>, backlog <n>, sample <n>, departures <n>' "$arp"; then
    ok "the report header names both coverage figures separately"
else
    bad "the report header names both coverage figures separately" \
        "the Findings row does not carry check 1 and check 1b as two named numbers"
fi
```

- [x] **Step 2: Run it and watch it fail**
  (`27 passed, 1 failed` with exactly the predicted message, watched by the implementer. A
  reviewer re-derived the red independently against `ebf9e37`)

Run: `tests/test-doc-claims.sh`
Expected: FAIL, `the Findings row does not carry check 1 and check 1b as two named numbers`.

- [x] **Step 3: Write the minimal implementation**
  (all four parts. The implementer put the House defaults definition beside Coverage rather than
  last, so the definitions run in the Findings row's own order, which nothing asked for and is
  right. Two corrections followed by separate dispatch: the definition's wording, and two stale
  line range citations this insert broke)

In `assessment-report.md`'s `## Header` block, replace the `Findings` row at line 25:

```markdown
| Findings | coverage <n>, house defaults <n>, backlog <n>, sample <n>, departures <n> |
```

In `## Section order, fixed`, insert check 1b and renumber:

```markdown
1. Summary, three sentences and the counts
2. Check 1, house-defaults coverage
3. Check 1b, house-defaults coverage as its own number
4. Check 2, the follow-up backlog
5. Check 3, the judgement sample
6. Check 4, the departures ledger
7. Trend, where a previous assessment exists
8. Not covered, explicit
```

Then add one sentence under the section order:

```markdown
**Check 1 and check 1b are never added together.** They have different denominators and different
sources, and a reader who sees one combined coverage figure cannot tell which of the two failed.
Report both, name both, and let the reader do any arithmetic they want.
```

**Then define the count you have just added, at `assessment-report.md:32`.** That paragraph opens
"Each of the four `Findings` counts is defined, so that two reports mean the same thing by them",
and then defines coverage, backlog, sample and departures. Adding a fifth count to the row seven
lines above makes the sentence false twice: the number is wrong, and the new count is undefined in
the one paragraph whose stated purpose is that none of them is. Change `four` to `five`, and add a
definition beside the other four:

```markdown
**House defaults** is the `house-defaults.md` sections `standards.md` omits, out of the sections
check 1b counts.
```

**The definition carries no number, and that is deliberate.** A first version of this step said "out
of the 12 that check 1b counts", which would have been a third written copy of the denominator. Two
copies are pinned to `house-defaults.md`'s live count; a third, pinned to nothing, goes stale in the
worst possible way: the suite would go red on exactly the two pinned lines, whoever fixes them reads
the red output to find them, and this line is not in it. Silent by construction. The authoritative
figure is stated once, 75 lines below, where a check holds it.

**This step was added on 2026-09-02, after a review returned DEVIATES on the first attempt.** The
implementer left the sentence alone and said why: step 3 did not name that line. It was right about
the instruction and the instruction was wrong. Recorded rather than quietly widened, because the
defect was in this plan and the next reader should be able to see that it was.

Recompute the two reference figures and update the six documents. **The definition sentence changes
the count too**, so recompute after writing it rather than before.

- [x] **Step 4: Run it and watch it pass**
  (`28 passed, 0 failed`, green suite, comparability grep 1. Run by the implementer, both
  reviewers, the correction dispatches and me)

Run: `tests/test-doc-claims.sh`
Expected: `28 passed, 0 failed`.

Run: `tests/run-tests.sh`
Expected: green.

**Confirm the existing report stays comparable.** Run:
`/usr/bin/grep -c 'Check 1, house-defaults coverage' docs/audits/2026-09-02-standards.md`
Expected: `1`. S-10's third scenario requires that report to remain comparable against a new one.
Checks 2, 3 and 4 keep their numbers and meanings, so it is, and nothing in that file is edited.
**This is an assertion about structure and not a proof of comparability**: proving it means running
assess again and diffing two reports, which is an eval arm and is not in this plan.

- [x] **Step 5: Hand over**
  (committed by me. Two paths beyond the eight listed, both documents this insert made wrong:
  `docs/prd/coding-standards-audit-and-seed.md` and `docs/ideas/standards-that-bind.md`, each
  citing a line range that no longer held what it claimed)

```bash
git add skills/coding-standards/references/assessment-report.md tests/test-doc-claims.sh \
        tests/validate-skills.sh docs/standards.md docs/05-token-and-memory-design.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/database-design-and-review.md docs/ideas/leon-van-zyl-skill-collection.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with
`git commit -m "feat(coding-standards): report the two coverage numbers separately"`.

---

### Task 3: `house-defaults.md` states that adopters inherit it unchanged

**Story:** S-12, satisfying FR-12 and FR-13

**Files:**
- Modify: `skills/coding-standards/references/house-defaults.md`
- Modify: `tests/test-doc-claims.sh`
- Modify, because the reference word count moves: the same six documents task 1 names

**Interfaces:**
- Produces: a stated inheritance rule in the opening of `house-defaults.md`, and a check that no
  overlay mechanism appeared alongside it.
- Consumes: `SCHEMA_VERSION` from `bin/keel`, read so the failure message can name the value it
  found, and compared against a `2` pinned here deliberately, because that pin is the tripwire.

**Depends on:** none. Ordered after tasks 1 and 2 only because all three edit
`tests/test-doc-claims.sh` and restage the same six documents.

**Done when:** `tests/test-doc-claims.sh` reports **`32 passed, 0 failed`**, task 2's 28 plus this
task's 4 new cases, and `tests/run-tests.sh` is green. *(Corrected from 31 and 3 during execution:
a review round added a fourth case asserting the schema file exists. See the correction note under
step 3.)*

**The negative half is the load-bearing half.** S-12's second scenario is that no mechanism is
added: no overlay file, no schema key, and `SCHEMA_VERSION` does not move. A sentence saying
adopters inherit the defaults is cheap to write and cheap to contradict later by adding the overlay
somebody asks for. The checks below fail if the mechanism appears, which is the part that still
holds in six months.

- [x] **Step 1: Write the failing tests**

Insert into `tests/test-doc-claims.sh` **immediately before the
`while IFS='|' read -r file which phrase; do` loop**:

```bash
# S-12: the inheritance rule is stated, and no mechanism is added to soften it. The current
# SCHEMA_VERSION is read from bin/keel so the failure message can name the value it found; the 2 it
# is compared against is pinned here deliberately, because that pin is the tripwire.
hd_s12="skills/coding-standards/references/house-defaults.md"
if grep -q 'inherit it unchanged' "$hd_s12" && grep -q 'departures ledger' "$hd_s12"; then
    ok "house-defaults states the inheritance rule and where disagreement goes"
else
    bad "house-defaults states the inheritance rule and where disagreement goes" \
        "the opening does not say adopters inherit unchanged and disagree through their own ledger"
fi

# S-12's "no overlay file exists" scenario. Checked as an absence at the paths an overlay would
# plausibly take, because a grep of house-defaults.md would not see a file created beside it.
overlay=""
for p in skills/coding-standards/references/house-defaults-overlay.md \
         skills/coding-standards/references/overrides.md \
         templates/house-defaults.md .keel/house-defaults.json; do
    [ -e "$p" ] && overlay="$overlay $p"
done

# The overlay case reads this file with grep. A missing file exits 2, which `!` would invert into a
# pass, so its existence is asserted before the case that depends on it.
schema_s12="templates/profile.schema.json"
if [ -f "$schema_s12" ]; then
    ok "the profile schema the overlay case reads exists"
else
    bad "the profile schema the overlay case reads exists" \
        "$schema_s12 is gone, so the overlay case below passes on grep's exit 2 rather than on an absent key"
fi

if [ -z "$overlay" ] && [ -f "$schema_s12" ] \
   && ! grep -q '"house[_-]defaults"' "$schema_s12"; then
    ok "no overlay file and no profile key for house defaults"
else
    bad "no overlay file and no profile key for house defaults" \
        "S-12 forbids an overlay mechanism; found:$overlay and any schema key named above"
fi

sv="$(grep -oE '^SCHEMA_VERSION=[0-9]+' bin/keel | head -1 | cut -d= -f2)"
if [ "$sv" = "2" ]; then
    ok "SCHEMA_VERSION has not moved for S-12 ($sv)"
else
    bad "SCHEMA_VERSION has not moved for S-12" \
        "bin/keel is at $sv, expected 2. S-12 adds no schema change, so a bump is either a different change riding along or the overlay S-12 forbids"
fi
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-doc-claims.sh`
Expected: FAIL, once, `the opening does not say adopters inherit unchanged and disagree through
their own ledger`. The other three cases pass on their first run, which is correct and is what they
are for. Record that rather than ticking them as watched failures.

- [x] **Step 3: Write the minimal implementation**

In `skills/coding-standards/references/house-defaults.md`, replace the opening paragraph:

```markdown
# House defaults

Conventions that apply across this organisation's repositories unless a project records a
deliberate departure.

**Adopters inherit it unchanged.** There is no overlay, no per-project defaults file and no
profile key that switches a default off. A project that disagrees with a default says so in its own
`standards.md`, in the departures ledger, with a reason. That is the only mechanism, and it is
deliberate: a departure a reader can see beats a default that was quietly never adopted.
```

Recompute the two reference figures and update the six documents.

**The prose above says "inherit it unchanged" and step 1 greps for exactly that.** A first version
of this step wrote "inherit this file unchanged", which the assertion cannot match, so step 3
applied verbatim left step 2's failure standing. Corrected on the document side rather than in the
check, because S-12's own acceptance criterion and this task's title both say "inherit it
unchanged": the grep tracks the story and the prose was the copy that drifted.

**The rule asks for a reason and not a date, and that was a correction too.** A first version said
"with a reason and a date". The departures ledger's canonical shape is
`references/standards-template.md:79`, three columns, `| Default | This project | Why |`, with no
date column, and check 4 re-verifies a departure's basis rather than its age. Asking an adopter to
record a field the template cannot hold and the assessor never reads is a rule that cannot be
followed, which is worse than one that is merely unenforced.

**Two of step 1's checks were corrected after review, and both were checks that could pass or fail
for the wrong reason.** First, the overlay case reads `templates/profile.schema.json` with
`! grep -q`; a missing file makes `grep` exit 2, which `!` inverts into a pass, so the case would
have gone green precisely when the schema it guards had been deleted. A fourth case now asserts the
file exists, and the overlay case carries `[ -f ]` itself. That is why this task adds four cases and
not three. Second, the pattern was `'house_defaults\|house-defaults'`, which matches a `$comment` or
a description that merely mentions house defaults in prose. `standards.md` forbids a check stricter
than correct output, so it was narrowed to `'"house[_-]defaults"'`: a JSON key, in quotes, which is
the mechanism S-12 forbids. Both directions were watched afterwards in a scratch copy of the tree,
in a run recorded under step 4.

**This is the third time in this plan that a step 1 assertion and a step 3 text disagreed**, after
task 1's line break and task 2's undefined count. All three were caught by an implementer writing
what it was given and reporting the mismatch rather than improvising. Whoever writes the next plan
in this repository should assume a snippet and the prose it asserts against will drift unless they
are written together and checked against each other.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-doc-claims.sh`
Expected: `32 passed, 0 failed`.

Run: `tests/run-tests.sh`
Expected: green, including `no-internal-leaks.sh`, which reads every file under `skills/`.

**Witnessed.** `tests/test-doc-claims.sh` printed `32 passed, 0 failed`, and `tests/run-tests.sh`
was green in 2m28s with `OK    shellcheck clean` rather than the skip it printed before 2026-08-29.
The four corrected cases were then exercised in both directions against a copy of the tree outside
the repository, a baseline plus four mutations:

| What was done to the copy | Result |
|---|---|
| Nothing, baseline | `32 passed, 0 failed` |
| `templates/profile.schema.json` removed | `30 passed, 2 failed`, the new existence case and the overlay case |
| A `$comment` added to the schema saying "house defaults" in prose | `32 passed, 0 failed`, so a mention cannot fail correct output |
| A real `"house_defaults"` key added to the schema | `31 passed, 1 failed`, the overlay case |
| An `overrides.md` created beside the reference | the overlay case failed, and the six figure assertions failed with it, since the file moved the reference count to 15 |

The live figures after this task: 14 reference files, **20,616** reference words, body 756, and 14
`##` sections in `house-defaults.md` giving check 1b's denominator of 12.

- [x] **Step 5: Hand over**

```bash
git add skills/coding-standards/references/house-defaults.md tests/test-doc-claims.sh \
        tests/validate-skills.sh docs/standards.md docs/05-token-and-memory-design.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/database-design-and-review.md docs/ideas/leon-van-zyl-skill-collection.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with
`git commit -m "docs(coding-standards): state that adopters inherit the house defaults unchanged"`.

---

## Story coverage

| Story | Tasks | Requirements |
|---|---|---|
| S-10 | 1, 2 | FR-15, FR-16, FR-17, FR-18 |
| S-12 | 3 | FR-12, FR-13 |
| S-11 | **none here.** Depends on S-03, so it is planned with the router | FR-14 |

## What this plan does not settle

- **S-10's third scenario is asserted, not proved.** "The section order stays comparable" is checked
  by confirming `docs/audits/2026-09-02-standards.md` still parses against the new order, not by
  re-running assess and diffing two reports. Re-running is an eval arm and belongs with the arms.
- **No eval arm runs here.** Check 1b changes what assess reports, and the only recorded assess run
  is the 2026-09-02 one against the four-check shape. Whether a five-check assess is still followed
  is a question for the next arm, and NFR-05 already owes one per mode.
- **The pass totals here are whole-file counts.** They are correct against the 24-case baseline at
  `0e5ee02` and will be wrong if anything else adds a case to `tests/test-doc-claims.sh` first. The
  durable half of each `Done when` is `0 failed` plus the named new cases passing.
