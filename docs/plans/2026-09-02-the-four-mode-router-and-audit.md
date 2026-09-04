# The four-mode router and audit mode Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** land the four-mode Step 0 that S-01 and S-02 were run to justify, build audit behind it,
and stop at audit's eval arm.

**Stories:** S-03, S-04, S-05, S-06, S-11. **Nothing in epic C is planned here, deliberately**,
because S-06's arm can delete it.

**ADRs:** ADR-0001, whose 900 word ceiling and 700 word warning both bind task 1. ADR-0002, whose
delegation default binds whoever executes this.

**Architecture.** Six tasks. Task 1 swaps in the router and creates the two reference files its
links require, one of them a stub. Tasks 2 and 3 build audit and its offer to author. Task 4
answers the fourth cell. Task 5 builds audit's scenario and fixture. Task 6 runs the arm and stops.

**Depends on `docs/plans/2026-09-02-assess-second-coverage-number-and-the-inheritance-rule.md`**,
which must land first. Task 4 reads a string that plan writes.

## The decision this plan stops at

**S-06's arm.** `docs/stories/coding-standards-audit-and-seed.md:497` says a failing S-06 drops
S-07, S-08 and S-09 and reworks audit before seed is attempted. Planning epic C now would be
planning against a prediction, which is the mistake the S-01 and S-02 split existed to avoid.
Epic C is planned after task 6 reports, and not before.

## The review this plan had, 2026-09-03, and the five defects it stopped

`9d03a62` records a dispatched reviewer finding six blocking defects **in the first drafts** of this
plan and its sibling. It does not record a review of this plan as committed, and unlike
`docs/plans/2026-09-02-assess-second-coverage-number-and-the-inheritance-rule.md` this file carried
no execution-time review notes. A second reviewer was dispatched on 2026-09-03, before task 1, and
returned BLOCKED on five findings. All five were re-verified against the tree by the coordinator
before being applied here.

| # | The defect | Where it is fixed |
|---|---|---|
| 1 | Case 29 recursed over the whole fixture, so `def query_concat(` counted as a call site and 7 and 3 could never be reached. Case 28 avoids this by naming one file | Task 5 step 1, `--exclude=db.py` |
| 2 | Task 6 verified the arm with `git status --porcelain` in a directory that is not a git repository. `stage.sh:83-95` builds one only for the three fixtures carrying a `setup.sh` | Task 6 step 2, `diff -r` against the fixture |
| 3 | `references/seed.md`'s stub told the arm it was inside this repository's development: "audit's eval arm", "the branch is unshipped", "do not release, tag or merge to `main`". Every reference of an injected skill is staged | Task 1 step 3, and a new global constraint |
| 4 | `references/audit.md` narrated the fixture's own 7 to 3 split, and `SKILL.md:38-40` already names 7 and 3, so the arm could echo the answer instead of counting | Task 2 step 3, and the fixture moved to 9 to 4 |
| 5 | The scenario scored none of the six report sections `audit.md` fixes, in either clause, and "records the minority as the rule" was undecidable because the scenario never said what the split was | Task 5 step 3 |

Ten non-blocking corrections were applied with them: four wrong line citations, two missed copies of
781 in the PRD, the case 29 placement hazard, bare `grep` where evidence is being gathered, task 3
moving the reference count and not only the words, and three fixture cautions the suite enforces.

**Finding 4 has a consequence this plan does not act on.** `author-a-standard`'s fixture is also at
7 to 3, and its recorded arm was scored on recording the minority as the rule with `SKILL.md`'s
worked example naming those same two numbers in front of it. That result is weaker evidence than it
reads as. It is recorded here for whoever revisits it, and changing it is not this plan's work.

## The router costs 112 words, not the 98 the PRD predicted

**The PRD's figure is an estimate of a text nobody had written.**
`docs/prd/coding-standards-audit-and-seed.md:132-166` costs an honest four-mode Step 0 at 98 words
and lands the body at 781. The router in task 1 is written out in full below and **measures 112
words** by the same `body_of` that `tests/validate-skills.sh:88` uses, landing the body at
**795**. That is 105 words under the 900 ceiling and 95 over the 700 target.

**It measured 110 until 2026-09-03**, when a review found that the draft had dropped the guard
against authoring over an existing document. Restoring it costs two words. The two figures below,
130 for a table and 125 for the first prose draft, are unchanged and were measured against the
110-word version.

Two earlier drafts are recorded because the difference is instructive. A table-shaped router
measures **130**, because `wc -w` counts every `|` and every `|---|` as a word, and the body would
have landed at 813. A first prose draft measured 125. The version below is the tersest one
that still carries all four cells, the three links, the author sentence, both precondition rules and
"ask once". **Cutting further means cutting one of those**, which is exactly what the PRD records
its own 63-word estimate doing before it was corrected to 98.

**So this plan does not chase 781.** It uses a measured router and corrects the PRD to the measured
figure in task 1's hand-over, rather than trimming requirements to hit a prediction. The PRD has now
under-costed this router twice, and the fix is to stop estimating it.

## The seed stub, and the constraint that forces it

`tests/validate-skills.sh:155` reports a broken link for any relative link in a skill that does not
resolve. The four-mode router names where each mode's steps live, so it links
`references/audit.md` **and** `references/seed.md`. Audit is task 2 of this plan; seed is epic C and
is not built here. **So the router cannot land unless `references/seed.md` exists**, and task 1
creates it as a stub that says exactly what it is.

**This is safe only because the branch does not ship between plans.** `sandbox` is unpushed and a
release is a separate gated act. **Do not run the release gate, cut a version, or merge to `main`
while `references/seed.md` is a stub.** A stub reaching an adopter is a mode that routes to nothing,
which is worse than a skill with three modes. If epic C is cancelled by task 6's result, the stub is
deleted and the router drops to three cells in the same change that cancels it.

## An inconsistency in the requirements, resolved here rather than silently

**FR-03 and FR-07 disagree about where audit writes.** `docs/prd/coding-standards-audit-and-seed.md`
line 211 has audit writing `<docs_root>/audits/YYYY-MM-DD-standards.md`, which is assess's path, and
line 215 records the collision and resolves it to `YYYY-MM-DD-standards-audit.md`. S-04's fourth
scenario is explicit and agrees with FR-07.

**This plan follows FR-07.** FR-03's path is superseded by the requirement written to supersede it,
and FR-03's text should be corrected in the PRD rather than left for the next reader to re-derive.
That correction is task 2's step 5, so it lands with the code it describes.

## The seven places the figures are asserted

`tests/test-doc-claims.sh:98-102` computes `coding-standards`'s reference count, reference word
count and body word count from the tree, and its `CLAIMS` heredoc at `:245-265` asserts them. Six
documents carry all three:

- `docs/05-token-and-memory-design.md`
- `docs/standards.md`
- `docs/decisions/ADR-0001-skill-body-word-ceiling.md`
- `docs/ideas/database-design-and-review.md`
- `docs/ideas/leon-van-zyl-skill-collection.md`
- `tests/validate-skills.sh`, in its own header comment

**The seventh carries the body alone: `tests/evals/scenarios/assess-a-stale-standard.md:6`**, pinned
on 2026-09-02 in `9b1d92f` as "THE NINTH" copy. **Task 1 changes the body, so task 1 changes all
seven.** Tasks 2 and 4 change reference words only. Task 3 creates a file, so it moves the
reference count as well as the words. All three carry the six.

**That seventh file is also staged into a live eval arm**, so changing its number is not only a
documentation fix: it changes what the next assess arm is told it is measuring. Correct it to the
measured body and note the change in the commit message.

Recompute after every task rather than copying a number:

```bash
find skills/coding-standards/references -name '*.md' | wc -l              # reference count
cat skills/coding-standards/references/*.md | wc -w                       # reference words
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/coding-standards/SKILL.md | wc -w   # body words
```

## Where a new check goes in `tests/test-doc-claims.sh`

**Not at the end of the file.** It ends with `printf '\n%s passed, %s failed\n'` and
`[ "$fail" -eq 0 ]`. A case appended after those runs after the totals are printed and after the
exit status is decided, and `bad()` ends in an explicit `return 0`, so a failure there leaves the
script exiting 0. **The check would look present and do nothing.** Every snippet in this plan goes
**immediately before the `while IFS='|' read -r file which phrase; do` loop**.

## Global constraints

Copied in full. A task executed by a fresh agent that reads only its own section still obeys these.

- **Verify commands**, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  There is no typecheck and no build.
- **Never start on `main`.** This work belongs on `sandbox`, which is where the branch already is.
- **No task's `git add` block lists this plan file, deliberately.** The coordinator stages it with
  each task's commit, as tasks 1 to 3 did, because a task's corrections to this plan are part of
  that task's record. An implementer following a `git add` block literally will leave it unstaged
  and should say so in the hand-over rather than adding it.
- **ADR-0001:** a skill body is capped at 900 words and warns over 700. A body over 700 requires a
  passing eval arm at that length recorded in `tests/evals/results.md`. This plan takes the body to
  about 795, so it owes one, and task 6's arm is it.
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
- **`references/assessment-report.md`: nothing in an assessment modifies what is being assessed.**
  Audit inherits this: it derives and reports, and writes nothing else.
- **`tests/run-tests.sh` runs test files in parallel at `MAX_JOBS=4`.** **No task may create or
  delete a file under `tests/evals/scenarios/` while a suite run is in progress**:
  `tests/test-doc-claims.sh` asserts the scenario count against `README.md` and would see the
  window. Task 5 creates one, so it creates the file and the two count updates together, with no
  suite running, and only then runs the suite.
- **A finding of the form "the arm did X" or "did not X" carries the command that extracted it**,
  per `tests/evals/results.md:6`, and the stream is identified by its own `result` record rather
  than by which directory it sat in. Task 6 is bound by this.
- **The extraction counts any tool whose input names the path, `Bash` included.** Every arm run so
  far used `Bash` and none used `Read`. A discriminator scanning for `Read` reports nothing on a run
  that opened seven files, which has now happened twice and been corrected twice.
- **Nothing staged for an arm may name `tests/evals`.** `tests/test-eval-harness.sh` case 4 fails
  any staged file that does, which is the tripwire `284ce5f` added after `design-database`'s
  references narrated their own eval. Task 5's fixture and task 2's and task 3's reference files are
  all staged.
- **And nothing staged may narrate this repository's own development.** `tests/evals/stage.sh:64-69`
  copies **every** reference of an injected skill into the arm's tree, so a sentence about a plan, a
  branch, a release, an unbuilt story or an eval reaches the arm even when it never types the
  literal `tests/evals` that case 4 greps for. **Which arms:** the loop is driven by each scenario's
  own `Inject:` line, so `coding-standards`'s references reach the two scenarios that inject it,
  `assess-a-stale-standard` and `author-a-standard`, and task 5 adds a third. They do not reach an
  arm injecting `debug` or `ship`. Say "the arms that inject it" rather than "every arm": an earlier
    draft of this plan said the latter three times and it is not true. Case 4 catches the string;
  this half is on the writer. It binds `references/seed.md`, `references/audit.md` and
  `references/audit-offer.md`.
- **Nothing staged may hand an arm a number it is scored on.** `skills/coding-standards/SKILL.md`
  is injected whole and its Step 1 example names a 7 to 3 SQL split, so task 5's fixture uses a
  different ratio. See task 5.

## Concurrency

**No concurrent batch is declared.** Every task after task 1 depends on it, tasks 2 and 3 share
`references/audit.md`, tasks 5 and 6 share the scenario, and every task from 1 to 4 restages the
same six documents. Run them in order.

---

### Task 1: Step 0 routes four modes, and every mode it names exists

**Story:** S-03, satisfying FR-01, FR-02, FR-19, FR-20 and NFR-01

**Files:**
- Modify: `skills/coding-standards/SKILL.md`
- Create: `skills/coding-standards/references/audit.md`
- Create: `skills/coding-standards/references/seed.md`
- Modify: `tests/test-doc-claims.sh`
- Modify, all seven figure locations: `docs/05-token-and-memory-design.md`, `docs/standards.md`,
  `docs/decisions/ADR-0001-skill-body-word-ceiling.md`, `docs/ideas/database-design-and-review.md`,
  `docs/ideas/leon-van-zyl-skill-collection.md`, `tests/validate-skills.sh`,
  `tests/evals/scenarios/assess-a-stale-standard.md`
- Modify, to correct a prediction with a measurement:
  `docs/prd/coding-standards-audit-and-seed.md` and
  `docs/ideas/coding-standards-audit-and-seed-modes.md`
- Modify, because this task changes how its fixture routes:
  `tests/evals/scenarios/author-a-standard.md`

**Interfaces:**
- Produces: a Step 0 that routes on two facts, and `references/audit.md` and `references/seed.md`
  for its links to resolve.
- Consumes: `references/assess.md`, from `4889f7a`, and `ok`/`bad` from `tests/test-doc-claims.sh`.

**Depends on:** none

**Done when:** `tests/validate-skills.sh` reports the `coding-standards` body between **788 and
798** words with no `FAIL`, and `tests/run-tests.sh` is green. The router below measures 112 and the
body should land at 795; the band allows a couple of words of editing either side. **If it lands
outside the band, the router is not the router below**, and the gap is reported rather than absorbed
by widening the band.

- [x] **Step 1: Write the failing test**

  Witnessed: the snippet went in byte-identical to the plan, immediately before the
  `while IFS='|' read -r file which phrase; do` loop.

Insert into `tests/test-doc-claims.sh` **immediately before the
`while IFS='|' read -r file which phrase; do` loop**:

```bash
# S-03: the router names four modes and every reference it points at resolves. validate-skills.sh
# already fails a broken link; this asserts the cells are present, which a link check cannot see.
# The failure it prevents is a router that silently routes three ways.
#
# Three things this check does that an earlier draft of it did not, each closing a way it could
# pass without earning it.
#
# It reads Step 0's own section rather than the whole file. A mention of references/audit.md in the
# Common mistakes table would satisfy a file-wide grep while the router routed three ways.
#
# It matches the markdown link form. validate-skills.sh:156 resolves only `](...)`, so a prose
# citation ("see references/audit.md") passes a bare-text grep AND passes the link check, and goes
# on passing after the file it names is deleted. docs/07-open-decisions.md:143-144 records thirteen
# such citations across eleven files in this very reference set, invisible to the link checker.
#
# It asserts the fourth mode. The other three have a reference file and are caught by the loop;
# author has none, so a router that dropped it would route three ways with this case green, which
# is the exact failure the comment above claims to prevent. Mode, not cell: the four cells of the
# two-fact table are not asserted here, and the document-with-no-code cell is FR-14 and task 4.
sk="skills/coding-standards/SKILL.md"
step0="$(awk '/^## Step 0/ {f = 1; next} f && /^## / {exit} f' "$sk")" missing=""
for mode in assess audit seed; do
    printf '%s' "$step0" | grep -q "](references/$mode\.md)" || missing="$missing $mode"
done
printf '%s' "$step0" | grep -q '\*\*Author\*\*' || missing="$missing author"
# And the guard, which is the clause that was actually dropped once. A router that loses "or author"
# from the precondition sentence leaves an unguarded overwrite of an existing standards.md, and it
# passes every other check in this repository: the four names are still there, the three links still
# resolve, and the body is still in band. Two review passes caught it by reading. This line is so
# that the next one does not have to.
printf '%s' "$step0" | grep -q 'author over one' || missing="$missing author-guard"
if [ -z "$missing" ]; then
    ok "Step 0 links every mode that has its own reference, and names the fourth"
else
    bad "Step 0 links every mode that has its own reference, and names the fourth" \
        "no link to:$missing"
fi
```

**A missing `SKILL.md` fails this rather than passing it**, which is the shape trap 2 of the
hand-off is about: `awk` on an absent file yields an empty `step0`, every `grep -q` fails, and
`missing` reads ` assess audit seed author`. Watched both ways against the tree before this snippet
was written into the plan.

- [x] **Step 2: Run it and watch it fail**

  Witnessed: `34 passed, 1 failed`, `no link to: audit seed`. **The plan's expectation is stale as
  of `142ab0c`:** HEAD's Step 0 wraps as "Asked to author / over one", so the guard assertion added
  later would also have failed there, and the true message under the final snippet is
  `no link to: audit seed author-guard`. The guard line was added after this step ran.

Run: `tests/test-doc-claims.sh`
Expected: FAIL, `no link to: audit seed`. Assess and author both pass against the old Step 0, which
already links `references/assess.md` and already carries `**Author**`, so those two are green
before the change and stay green after it.

- [x] **Step 3: Write the minimal implementation**

  Witnessed: router 112 words, body 795, references 16 and 20,716 words, all measured. Both
  sentence-level corrections made, the superseded note left byte-untouched.

Replace `## Step 0: Author or assess` and its paragraph in `skills/coding-standards/SKILL.md`,
lines 16 to 22, with exactly this. It is 112 words as written and the wording is load bearing:

**"asked to seed or author over one" carries a guard that shipped and was nearly lost.** The Step 0
this replaces reads "Asked to author over one, name it and ask first", and a draft of this router
kept only the seed half of it. Author is reachable under the new router through "the request's words
win", and Step 4 writes `<docs_root>/standards.md`, so dropping the author half leaves an unguarded
overwrite of a document that already exists. FR-20 requires every mode to degrade to a stated
outcome when its precondition is wrong, not three of the four. The two words cost the body two
words and the band already allows them.

```markdown
## Step 0: Choose the mode

Two facts choose it, before anything is read: whether `<docs_root>/standards.md` exists, and whether
there is code. No document and code is **audit**, [references/audit.md](references/audit.md). No
document and no code is **seed**, [references/seed.md](references/seed.md). A document, either way,
is **assess**, [references/assess.md](references/assess.md), naming any check a missing corpus
stopped. **Author** is steps 1 to 5, and is what audit offers at its end.

The request's words win where they conflict. Where a precondition is wrong, say so: asked to assess
with no document, offer seed or audit by which fact holds; asked to seed or author over one, name it
and ask first. Ambiguous with a document present, ask once.
```

Create `skills/coding-standards/references/audit.md` as a placeholder that task 2 replaces in full,
carrying only what makes the link honest today:

```markdown
# Audit mode

Derive a brownfield repository's conventions and report them. **The steps are not written yet.**
Where Step 0 routes here, say so rather than improvising them, and offer author, steps 1 to 5 of
`SKILL.md`, which writes the document instead of a report. Do not run them unless the user asks.
```

**The guard sentence is not decoration, and an earlier draft of this task omitted it.** Before this
task, "no `standards.md`" routed to author and author works. After it, the commonest real
invocation, a brownfield repository with code and no document, routes to this file. A stub with no
instruction leaves that run undefined, with steps 1 to 5 sitting in the body it has already loaded.
`references/seed.md` carries the same guard for the same reason; the two files must not be
asymmetric about it.

Create `skills/coding-standards/references/seed.md` as the stub the header of this plan describes:

```markdown
# Seed mode

**The steps are not written yet.** Where Step 0 routes here, say so rather than improvising them:
name the two facts that routed here, and offer assess or audit if either turns out to hold after
all. Do not write `<docs_root>/standards.md` from this file.
```

**Neither file names a plan, a branch, a release or a story, and that is deliberate.**
`tests/evals/stage.sh:64-69` stages every reference of an injected skill, so both files reach every
arm that injects `coding-standards`, task 6's included. A stub saying "planned only after audit's
eval arm reports", "while the branch is unshipped" and "do not release, tag or merge to `main`"
tells the arm it is inside this repository's own development, which is the exposure `284ce5f` closed
by
de-narrating references rather than by excluding files from staging. **The release constraint is
not weakened by moving it: it lives in this plan's own header, which ships to nobody.** Both
sentences of it stand, and so does the instruction to delete this file and drop seed's cell from
Step 0 in the same change if epic C is cancelled.

**Then state the routing in `tests/evals/scenarios/author-a-standard.md`, which this task changes
under its feet.** That fixture has code and no `docs/standards.md`
(`find tests/evals/fixtures/author-a-standard -type f` returns six files and none is a standards
document), so the two facts now route it to audit, whose reference says its steps are not written.
The scenario's fail clause is "writes no document" and it ends "**Ambiguity is a fail.**" Add this
paragraph immediately before the `**Passes if the reply:**` line:

```markdown
**Routing, and why the prompt names the artefact.** This fixture has code and no
`docs/standards.md`, so the two facts in Step 0 route it to audit, which derives and reports rather
than writing the document. The prompt therefore asks for a standards document by name: the request's
words win where they conflict with the two facts, and **this scenario scores the author path**. An
arm that reports an audit and stops is a fail, and the reason recorded is that it followed the facts
over the words. **The prompt changed on 2026-09-03 for this reason**, so the arm recorded on
2026-09-02 ran against different words and a two-mode Step 0. That entry is a record and not a
comparison.
```

**And change the prompt in the same edit**, to this:

```markdown
## Prompt

Nobody here has written down how we do things and a new engineer starts on Monday. Can you write us
a standards document from the conventions this codebase already follows?
```

**Why the prompt moves, when an earlier draft of this step said it must not.** The old prompt, "Can
you write down the conventions this codebase already follows?", is a near-paraphrase of audit's own
first line, "Derive a brownfield repository's conventions and report them." Under a two-mode Step 0
that ambiguity did not exist, because no document meant author by default. Under four modes the two
facts point at audit and the words point at both, so the scenario would be asking a scorer to grade
a judgement the skill does not settle, while its own last line says "Ambiguity is a fail". Naming
the artefact removes the ambiguity without naming the path, so "writes `docs/standards.md`" stays a
real pass condition that the arm has to get from Step 4. Nothing asserts this prompt: a tree-wide
grep for the old sentence outside `docs/plans/` returns nothing.

**The comparison it costs was already gone.** The recorded arm ran against a Step 0 where no
document meant author by default, so the router had already voided it; the scenario now says so.

While editing that file, change "a judgement the **two paragraphs above** do not settle" in the
`Ambiguity is a fail` line to "the paragraphs above". There are three now.

Then recompute all three figures with the three commands above and update **all seven** locations.

**Correct the sentence the figure sits in, not only the digit.** Two of the seven carry a claim
this task falsifies in the same breath as a number, and a first attempt at this task updated the
numbers and left both:

- `docs/decisions/ADR-0001-skill-body-word-ceiling.md:30` reads "That skill has since gained a
  **second mode** and stands at 14 references, 20,616 reference words, and a body of 756", and `:32`
  continues "the growth came from **a new mode**". This task takes it to four modes.
  `tests/test-doc-claims.sh:84-85` names this exact sentence as the live one, as against the dated
  record beside it, so it is the sentence the whole file exists to keep true. Correct the mode count
  with the figures.
- `docs/ideas/coding-standards-audit-and-seed-modes.md:95` reads "the body **is** 756, and the
  four-mode router lands at a measured 795". The router lands in this task, so the body is 795 and
  756 is what it was. Put that clause in the past tense rather than editing the number, which would
  make the sentence say the body is 795 and the router will take it to 795.

Neither is a licence to rewrite a superseded note's argument. **The second superseded note in
`docs/ideas/coding-standards-audit-and-seed-modes.md`, the one whose arithmetic reads "costs 24 and
does not save 11" from the falsified 98, is left exactly as it is.** It is a labelled record of
reasoning that has been superseded, its heading already says the figures below are not the state of
the tree, and half-correcting it (appending the measurement without redoing the arithmetic that
follows from it) is worse than either leaving it or rewriting it whole. Leave it.

- [x] **Step 4: Run it and watch it pass**

  Witnessed: `35 passed, 0 failed`; `WARN coding-standards: body is 795 words`, no FAIL;
  `tests/run-tests.sh` green in 137s with `OK    shellcheck clean`, re-run by the coordinator.

Run: `tests/test-doc-claims.sh`
Expected: green, with all three `coding-standards` figures matching the tree and the
`assess-a-stale-standard.md` body row matching too.

Run: `tests/validate-skills.sh 2>&1 | /usr/bin/grep coding-standards`
Expected: a `WARN` reporting a body between 788 and 798 words, over the 700 target, and **no
`FAIL`**. Over the target is expected and correct: ADR-0001 then requires task 6's arm.

Run: `tests/run-tests.sh`
Expected: green, including the relative-link check resolving all three mode references.

- [x] **Step 5: Hand over**

  Witnessed: fourteen paths staged, nothing unstaged. Seven PRD places corrected; the recheck grep
  returns five hits, all labelled as the superseded estimate or a dated record.

Correct the two documents that carry the predicted figure, using the measured one:

- `docs/prd/coding-standards-audit-and-seed.md`. **Four places carry 781 and one carries 98, not
  the two an earlier draft of this step named:** section 5.1 at `:93` ("lands at **781 with 119
  words spare**"), the 98 at `:138`, section 5.2's table row at `:146` ("Today with the four-mode
  Step 0 swapped in"), the arithmetic `756 - 73 + 98` and the sentence after it at `:152` and
  `:155`, and NFR-02 at `:245` ("lands near 781"). Correct every one: the router measures 112 rather
  than 98 and the body lands at the measured figure rather than 781. Say that the number is now
  measured against a written router rather than estimated, and name this plan. Recheck with
  `/usr/bin/grep -n '781\|98' docs/prd/coding-standards-audit-and-seed.md` before handing over,
  because the line numbers move as you edit. **Match `98` and not `98 words`:** a third live copy
  sits at `:166` as "The correct arithmetic is 876 minus 74 plus 98", which the narrower pattern
  cannot see, and it is present tense about an estimate this task replaces with a measurement.
  Correct it to name both, the estimate giving 900 and the measured router giving 914, against the
  body as it then stood.
- `docs/prd/coding-standards-audit-and-seed.md`, section 5.2's **second table row and the sentence
  under it**, both computed from that same falsified 98. The row reads "That body with a four-mode
  Step 0 swapped in, nothing moved | **900** | passed, and nothing was left", and the paragraph
  reads "an honest four-mode router consumed all 24 spare words exactly". With the measured router
  it is `876 - 74 + 112`, which is **914**, over the ceiling by 14, and it consumes 38 rather than
  24. Say in the row's Shape cell that it is computed on the superseded estimate, or give both
  numbers. **The paragraph's argument does not change** and is if anything stronger: its point was
  that a four-mode router left nothing spare, and the measured one overruns. This row is the one
  place in the PRD where a superseded figure sits in a table with no marker, directly above a row
  this task corrects, so a reader sees 900 and 795 side by side with no cue that the first descends
  from an estimate the second retracts.
- `docs/prd/coding-standards-audit-and-seed.md:102-103`, which is a self-check that fails its own
  arithmetic: "The nine rows below sum to **873**, and the three-word title above the first heading
  brings it to **756**, so the convention is self-checking." The nine rows of the table below it are
  37, 73, 150, 111, 133, 75, 45, 129 and 3, which sum to **756**, and the three-word title is the
  ninth of them rather than something added to them. 873 plus 3 is 876, the body before `4889f7a`,
  so the sentence is left over from the ten-row table that carried Step 0a's 119. Correct it to say
  the nine rows sum to 756, the title row included. **This one is pre-existing and this task does
  not falsify it**; it is here because it sits three lines above a line this task edits, and a
  sentence whose whole claim is that it checks itself should not fail its own check while somebody
  is editing around it.
- `docs/ideas/coding-standards-audit-and-seed-modes.md`, the "Superseded by `4889f7a`" note, which
  carries 781 and 119 spare from the same prediction.

```bash
git add skills/coding-standards/SKILL.md skills/coding-standards/references/audit.md \
        skills/coding-standards/references/seed.md tests/test-doc-claims.sh \
        tests/evals/scenarios/author-a-standard.md \
        tests/validate-skills.sh docs/standards.md docs/05-token-and-memory-design.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/database-design-and-review.md docs/ideas/leon-van-zyl-skill-collection.md \
        tests/evals/scenarios/assess-a-stale-standard.md \
        docs/prd/coding-standards-audit-and-seed.md \
        docs/ideas/coding-standards-audit-and-seed-modes.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(coding-standards): route four modes from two facts"`.

---

### Task 2: Audit derives a brownfield tree and writes a dated report

**Story:** S-04, satisfying FR-03, FR-04, FR-05, FR-07 and NFR-08

**Files:**
- Modify: `skills/coding-standards/references/audit.md`
- Modify: `docs/prd/coding-standards-audit-and-seed.md`
- Modify: `docs/02-skill-catalog.md`
- Modify: `tests/test-doc-claims.sh`
- Modify, because the reference word count moves: the six documents named in "The seven places"

**Interfaces:**
- Consumes: task 1's router and placeholder.
- Produces: audit's steps, and the report shape NFR-08 requires.

**Depends on:** task 1

**Done when:** `tests/test-doc-claims.sh` is green with the new case, and `tests/run-tests.sh` is
green.

**The path is `YYYY-MM-DD-standards-audit.md`, per FR-07 and S-04's fourth scenario.** Assess writes
`YYYY-MM-DD-standards.md`. Both run on the same repository on the same day in the case S-04 names,
and one path for two modes overwrites a report with a different one.

- [x] **Step 1: Write the failing test**

  Witnessed: the four deferred task 1 corrections, the FR-07 case, the order case and the drift
  case all went in byte-identical to the plan, immediately before the `while IFS='|' read` loop.

Insert into `tests/test-doc-claims.sh` **immediately before the
`while IFS='|' read -r file which phrase; do` loop**:

**First, four corrections to task 1's own check, raised by the review passes that cleared it and
deliberately deferred to here because this task edits the same file.** None changes behaviour.

- **Pin the tie-break.** `SKILL.md:24`'s "The request's words win where they conflict" is the whole
  basis on which `author-a-standard` now passes, and nothing asserts it: delete the sentence and
  every check in this repository stays green while the scenario silently reverts to unscoreable.
  Add beside the guard line: `printf '%s' "$step0" | grep -q 'words win' || missing="$missing
  words-win"`, on one line.
- **Make the guard grep survive a re-wrap.** `grep -q 'author over one'` is line-oriented, so a
  future re-wrap of Step 0 that splits "author" from "over one" fails a router that is behaviourally
  identical, which is the "stricter than correct output" shape `docs/standards.md` forbids. Pipe the
  extraction through `tr '\n' ' '` for that assertion and the `words win` one. **This is not
  hypothetical:** the Step 0 replaced in task 1 wrapped exactly that way.
- **Fix the failure message.** `bad "..." "no link to:$missing"` now reports `author` and
  `author-guard`, neither of which is a link, sending a reader hunting for one. Make it
  `"Step 0 is missing:$missing"`.
- **Correct the stale quotation at `tests/test-doc-claims.sh:84-85`.** It quotes ADR-0001's live
  sentence as "has since gained a second mode and stands at". Task 1 corrected that sentence to "now
  routes four modes and stands at", so the file whose purpose is keeping sentences true carries a
  quotation of a sentence that no longer exists.

**And add a case tying the two copies of that rule together**, immediately before the
`while IFS='|' read -r file which phrase; do` loop with the others. The rule is stated twice, and
this task is the second time in two days that correcting one copy left the other behind:

```bash
# The audits/ naming rule is stated twice: in this repository's docs/README.md, and in the heredoc
# at bin/keel that writes every new project's copy of it. docs/prd/standards-assessment.md:277-279
# names the heredoc as the place the rule is stated, so the generator is canonical and this repo's
# copy is derived. Correcting one and not the other ships a rule this repository has already
# retracted, and nothing else in the suite compares them.
#
# Both are flattened and their runs of spaces squeezed before comparing, because the two wrap
# differently and always will: every backtick in the heredoc is escaped, costing two source
# characters and rendering as one, so a 100-column source line renders shorter.
readme_rule="$(sed -n '/^A dated report in/,/named for its slug\./p' docs/README.md \
               | tr '\n' ' ' | tr -s ' ')"
# The sed script is a literal: it strips the backslash bin/keel writes before every backtick, so
# it must stay single-quoted and nothing in it expands. CI lints at default severity.
# shellcheck disable=SC2016
keel_rule="$(sed -n '/^A dated report in/,/named for its slug\./p' bin/keel \
             | sed 's/\\`/`/g' | tr '\n' ' ' | tr -s ' ')"
if [ -n "$readme_rule" ] && [ "$readme_rule" = "$keel_rule" ]; then
    ok "the audits naming rule is the same in docs/README.md and in bin/keel's scaffold"
else
    bad "the audits naming rule is the same in docs/README.md and in bin/keel's scaffold" \
        "the repository's copy and the copy every scaffolded project is given have drifted apart"
fi
```

**`[ -n "$readme_rule" ]` is the guard, not decoration.** Two empty extractions compare equal, so
without it a renamed heading or a deleted paragraph in both files passes.

**The `shellcheck disable=SC2016` is required, not tidying.** `.keel/profile.json`'s lint runs
`shellcheck -x` at default severity, where an info-level finding fails, and the single-quoted `sed`
script raises SC2016 because it contains a backtick that never expands. A first draft of this
snippet omitted the directive and turned the lint job red. `tests/validate-skills.sh` already
carries that directive four times, two of them for this same backtick reason.

Then the task's own check:

```bash
# FR-07: audit and assess must not write the same path. The two filenames are asserted here because
# the collision is silent: the second mode to run simply overwrites the first mode's report.
au="skills/coding-standards/references/audit.md"
as="skills/coding-standards/references/assess.md"
# Flattened, because these paths wrap. audit.md already puts "Then write" at the end of one line and
# the path at the start of the next, so a line-oriented grep never sees the two together. An edit
# that wrapped between `audits/` and `YYYY-MM-DD-standards.md` would put assess's path in audit's
# write instruction and pass every line-oriented clause. A missing file makes tr fail, leaves the
# variable empty, and fails the first assertion, so nothing inverts into a pass.
#
# Two [[:space:]]* rather than one: flattening turns a newline into a space, and the path can wrap
# at either of its two natural break points, after `audits/` or after `YYYY-MM-DD-`. Watched both
# ways against a mutated copy; the single-gap spelling misses the second.
au_flat="$(tr '\n' ' ' < "$au")"
as_flat="$(tr '\n' ' ' < "$as")"
if printf '%s' "$au_flat" | grep -q 'YYYY-MM-DD-standards-audit\.md' \
   && printf '%s' "$as_flat" | grep -q 'YYYY-MM-DD-standards\.md' \
   && ! printf '%s' "$as_flat" | grep -q 'YYYY-MM-DD-standards-audit\.md' \
   && ! printf '%s' "$au_flat" | grep -q 'audits/[[:space:]]*YYYY-MM-DD-[[:space:]]*standards\.md'; then
    ok "audit and assess write different report paths"
else
    bad "audit and assess write different report paths" \
        "FR-07 requires audit at DATE-standards-audit.md and assess at DATE-standards.md, and neither file may name the other's path"
fi
```

**The fourth clause is what makes this structural rather than lucky.** Without it the check only
asserts that audit's path appears somewhere in `audit.md`; it passes today because that string
occurs exactly once, in the write instruction, and it would keep passing if a later edit added a
second mention while the instruction itself named assess's path. `audit.md` carries
`audits/YYYY-MM-DD-standards.md` zero times today, so the clause costs nothing and closes that.
Both negatives are gated by a positive `grep -q` on the same file earlier in the chain, so a missing
file exits 2 there and reaches `bad` rather than inverting into a pass.

**And pin audit's own section order, which nothing asserts.** `references/assessment-report.md`'s
eight-entry order is pinned line for line by the case added on 2026-09-03, for the reason its
comment gives: a document keeps its order while the mode's behaviour moves. Task 5's scenario and
task 6's rubric both score audit's six-entry order against this file's prose, so a later reword
would silently rescore every recorded arm. Add, immediately after the case above:

```bash
# The six-entry report order in audit.md, pinned the way assessment-report.md's eight are. Task 5's
# scenario and task 6's rubric both score an arm against this sequence, so a reword here rescores
# every arm already recorded. Matched on the bolded lead label of each numbered entry, because the
# prose after it is free to change and the order is not. The awk filter takes every numbered line
# rather than only the bolded ones, so an entry added without a bold label survives into the
# comparison and mismatches, instead of being dropped and leaving the list six long. It takes
# bullets too, and the numbers are compared rather than discarded, because both were ways a seventh
# section could be added invisibly: a bulleted one is not numbered at all, and renumbering the six
# to 1 2 3 7 4 5 leaves the labels in order and the check green while the document reads wrong.
want_audit_order='1 Header
2 What was sampled, and what was not
3 The conventions found
4 The splits
5 What has no convention
6 Not covered'
got_audit_order="$(awk '/^## The report, in this fixed order$/ {inside = 1; next}
                        inside && /^## / {exit}
                        inside && /^[0-9]+\. /
                        inside && /^[-*] /' "$au" \
                   | sed -E 's/^([0-9]+)\. \*\*([^*]+)\*\*.*/\1 \2/; s/[.,]$//')"
if [ "$got_audit_order" = "$want_audit_order" ]; then
    ok "audit's six report sections are in the order NFR-08 fixes"
else
    bad "audit's six report sections are in the order NFR-08 fixes" \
        "audit.md's report list is not those six entries in that sequence. A missing file reads as an empty list here and fails, which is the intent"
fi
```

- [x] **Step 2: Run it and watch it fail**

  Witnessed: `35 passed, 1 failed`, `FR-07 requires audit at DATE-standards-audit.md and assess at
  DATE-standards.md`. Each later hardening was watched red separately on a copy of the tree outside
  the repository, seven mutations in all.

Run: `tests/test-doc-claims.sh`
Expected: FAIL, `FR-07 requires audit at DATE-standards-audit.md and assess at DATE-standards.md`.

- [x] **Step 3: Write the minimal implementation**

  Witnessed: `audit.md` byte-identical to this plan's block, references 16 and 21,070 words, body
  unmoved at 795. Five of its wordings were corrected across three review rounds before it landed.

Replace `skills/coding-standards/references/audit.md` in full. Note that the offer is a markdown
link, not backticks, so `validate-skills.sh` resolves it and task 3's file is reachable:

```markdown
# Audit mode

Derive what a repository already does, and report it. **An audit is a derivation and not an agreed
standard**, and it says so in its own header. Nothing else is written, and no file that was read is
edited.

Run Step 1 and Step 2 of `SKILL.md`: sample at least ten files across different areas, and split
what a tool can check from what needs judgement. **Step 2's `Goes to` column is author's, not
audit's.** Sort the piles and report which pile each convention landed in; write neither the config
nor the standard those cells name. Then write
`<docs_root>/audits/YYYY-MM-DD-standards-audit.md`. The `-audit` suffix is not decoration: assess
writes `YYYY-MM-DD-standards.md` on the same day in the same directory, and one path for two modes
loses a report.

## The report, in this fixed order

1. **Header.** The commit **where the tree is a repository**, the date, how many files were sampled
   and out of how many, **saying which files the denominator counts**, and the sentence "This is a
   derivation of what the code does, not a standard anybody has agreed."
2. **What was sampled, and what was not.** Named directories, and what a reader should not conclude
   from the ones that were skipped.
3. **The conventions found**, one per entry, each with the rule, a `path:line` that shows it, the
   count of conforming against total sites, and which of Step 2's two piles it fell in.
4. **The splits**, where the tree contradicts itself. **Step 1's counting rule decides these: the
   majority is the convention, except where the majority pattern is the defect**, and there the
   report records the minority as the rule and says why, because writing the majority down would
   sanction it. Give the conforming-to-total ratio on every split, so a reader can see the split was
   counted rather than judged.
5. **What has no convention.** Areas where the code is genuinely inconsistent with no defensible
   reading. Naming them is the honest output, not a gap in the audit.
6. **Not covered**, explicit.

**The counting unit is stated before any number**, the way `assessment-report.md` requires of
assess: one convention is one rule a reader could follow, and a site is one call or declaration that
either follows it or does not.

## What audit never does

Write `<docs_root>/standards.md`. Edit a file it read. Run anything that changes the project. Make a
network request.

## How audit ends

By offering to author, which is [audit-offer.md](audit-offer.md).
```

**Three of those five wordings were corrected on 2026-09-03, after a review pass read the file as a
model would.** "Run Step 1 and Step 2 unchanged" instructed a run to execute a step whose own table
sends the judgement pile to `<docs_root>/standards.md`, which the last section then forbids. The
splits sentence bolded "the majority does not win by being the majority", which inverts
`SKILL.md:37-38`, "The majority pattern is the convention"; only the defect case carves out, and
task 5's fixture carries one split of each kind precisely so an arm has to tell them apart. And
"Audit ends by offering" sat inside the section headed "What audit never does", where a model
scanning headings reads the offer as prohibited, which is the FR-06 behaviour task 6 scores.

Recompute the two reference figures and update the six documents.

- [x] **Step 4: Run it and watch it pass**

  Witnessed: `38 passed, 0 failed`, and `tests/run-tests.sh` red on **exactly one** FAIL,
  `broken link to audit-offer.md`, with `OK    shellcheck clean`. Re-run by the coordinator on the
  final tree. That is the deliberate red this task's step 4 predicts, and task 3 closes it.

Run: `tests/test-doc-claims.sh`
Expected: green, including `audit and assess write different report paths`.

Run: `tests/run-tests.sh`
Expected: **one FAIL is expected here and only here**: `validate-skills.sh` reports a broken link to
`audit-offer.md`, which task 3 creates. If any other check fails, stop. If you would rather not
leave the suite red between two tasks, fold task 3 into this one and say so; do not create an empty
`audit-offer.md` to silence it.

- [x] **Step 5: Hand over**

  Witnessed: fifteen paths staged, nothing unstaged, plus this plan file. FR-03's row, the
  catalogue entry, and the five shipping copies of what this skill writes all corrected.

Correct `docs/README.md:19-20`, which this task falsifies. It says a dated report in `audits/` is
named `YYYY-MM-DD-<kind>.md` "where `<kind>` is the noun of the skill that wrote it: `security`,
`standards`". `standards-audit` is the noun of no skill, and the rule was worded deliberately, so it
is recorded in `docs/prd/standards-assessment.md:275`. Extend it with this sentence, the third
wording tried and the first that is true of both instances:

> Where a second mode of the same skill writes there too, its kind is that noun plus its own mode
> name, so `coding-standards` writes `standards` from assess and `standards-audit` from audit.

**Two earlier wordings were wrong and both reached the document before a review pass caught them.**
"The kind names the mode" would give `YYYY-MM-DD-assess.md` and `YYYY-MM-DD-audit.md`, neither of
which the tree writes. "Where two modes of one skill both write into `audits/`, the kind carries the
mode as a suffix" applies to both modes, so it gives assess `standards-assess`, and its own example
sentence then says otherwise. The rule the tree actually follows is asymmetric: the first mode keeps
the bare noun and a later one appends its own name, which is why the sentence has to be about the
second mode rather than about the pair.

**And correct the same sentence where it ships.** `bin/keel:502-503` writes each new project's
`docs/README.md` from a heredoc carrying that rule verbatim, and
`docs/prd/standards-assessment.md:279-280` names that heredoc as the place the rule is stated. The
copy in this repository is the derived one and the generator is canonical, so correcting only
`docs/README.md` leaves every project keel scaffolds from here carrying the falsified rule, and
leaves the two disagreeing with nothing to catch it. Apply the same extension to the heredoc,
escaping backticks the way the surrounding lines do.

**And the two other live descriptions of what this skill writes.**
`docs/01-architecture.md:95` gives coding-standards' outputs as "`<docs_root>/standards.md`, or
`<docs_root>/audits/YYYY-MM-DD-standards.md` in assess mode", which is mode-aware, present tense,
and now missing audit's third path: add it, naming audit mode the way the row already names assess.
`templates/prompting-cheatsheet.md:33` and its rendered copy `docs/prompting.md:34` give the same
two-way output, and the template ships to adopters through `bin/keel`, so it is the same class as
the heredoc. Add the third path to both.

Add `docs/README.md`, `bin/keel`, `docs/01-architecture.md`, `templates/prompting-cheatsheet.md`
and `docs/prompting.md` to this task's staged paths.

Then correct `docs/02-skill-catalog.md`'s `coding-standards` entry, which this task falsifies twice.
`:298-299` gives `**Writes:**` as `<docs_root>/standards.md` and
`<docs_root>/audits/YYYY-MM-DD-standards.md`, and FR-07 adds a third path this task creates,
`<docs_root>/audits/YYYY-MM-DD-standards-audit.md`. `:300` says `**Does:** three distinct jobs`, and
audit is a fourth that the three numbered entries below it do not describe. Add the path and the
job; do not restructure the entry. It is deliberately assigned here rather than to task 1: at the
end of task 1 audit is a stub that does nothing, and the claim only becomes false when this task
gives it behaviour.

Then correct FR-03's stale path in the PRD, which this task's behaviour contradicts:

```markdown
| FR-03 | **Audit** runs on a repository with code and no `standards.md`. It derives conventions using the existing Step 1 and Step 2, and writes `<docs_root>/audits/YYYY-MM-DD-standards-audit.md`, per FR-07. | confirmed | Bernard, decision 2, path corrected 2026-09-02 |
```

```bash
git add skills/coding-standards/references/audit.md tests/test-doc-claims.sh \
        docs/prd/coding-standards-audit-and-seed.md docs/02-skill-catalog.md \
        docs/README.md bin/keel docs/01-architecture.md \
        templates/prompting-cheatsheet.md docs/prompting.md tests/validate-skills.sh \
        docs/standards.md docs/05-token-and-memory-design.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/database-design-and-review.md docs/ideas/leon-van-zyl-skill-collection.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(coding-standards): audit derives a brownfield tree"`.

---

### Task 3: Audit offers to author, and does not author unasked

**Story:** S-05, satisfying FR-06

**Files:**
- Create: `skills/coding-standards/references/audit-offer.md`
- Modify: `tests/test-doc-claims.sh`
- Modify: `docs/06-repo-layout.md`
- Modify: `tests/validate-skills.sh` and `tests/test-validate-skills.sh`
- Modify, because the reference count and word count move: the six documents

**The two `validate-skills` files were added on 2026-09-03, and their absence is why this task
loosened a core check with no coverage.** The step below described "the new MUST REJECT case" as
though a step had commissioned it; none had, and neither file appeared in this block or in the
`git add`. A task that changes a check and does not list that check's own test file is a task whose
hand-over cannot notice the gap.

**Interfaces:**
- Consumes: task 2's audit steps, which link this file.
- Produces: the terminal offer.

**Depends on:** task 2

**Done when:** `tests/run-tests.sh` is green, including the link from `audit.md` that task 2 left
broken, and
`/usr/bin/grep -c 'without being asked' skills/coding-standards/references/audit-offer.md` returns
1 or more.

**Why a separate file for four sentences, stated honestly.** It is not the link: task 2 could have
inlined the offer. It is that S-05 is a separate story with its own reviewer gate, and that seed
will need the same offer at its end. The cost is real and worth naming: this is the smallest file in
`references/` by an order of magnitude, and it takes a slot in the reference count that six
documents assert. If a reviewer prefers it inlined in `audit.md`, that is a defensible call and the
story still ships.

- [x] **Step 1: Write the failing test**

  Witnessed: the S-05 case, the five one-token corrections, the two regression cases in
  `tests/test-validate-skills.sh` and the span strip in all three link loops. Every one was watched
  red on a copy of the tree outside the repository before it was accepted.

Insert into `tests/test-doc-claims.sh` **immediately before the
`while IFS='|' read -r file which phrase; do` loop**:

```bash
# S-05: the offer exists and is an offer. The failure it prevents is a mode that helpfully writes
# standards.md because the user seemed to want one, which is FR-04's whole point.
of="skills/coding-standards/references/audit-offer.md"
if [ -f "$of" ] && grep -q 'without being asked' "$of" && grep -q 'declined' "$of"; then
    ok "audit's offer is an offer, and says what happens when it is declined"
else
    bad "audit's offer is an offer, and says what happens when it is declined" \
        "audit-offer.md is missing, or does not state both halves of FR-06"
fi
```

- [x] **Step 2: Run it and watch it fail**

  Witnessed: `38 passed, 1 failed`, `audit-offer.md is missing, or does not state both halves of
  FR-06`.

Run: `tests/test-doc-claims.sh`
Expected: FAIL, `audit-offer.md is missing, or does not state both halves of FR-06`.

**Five one-token corrections to the checks come with this task**, all found by the review passes
that cleared task 2 and all in `tests/test-doc-claims.sh`. None changes behaviour on the tree as it
stands; each closes a way a later edit slips past a check that claims to catch it.

- **The order case takes only two of Markdown's bullet markers and one of its ordered delimiters.**
  `/^[-*] /` misses `+`, which is a legal CommonMark bullet, and `/^[0-9]+\. /` misses `7)`, which
  is a legal ordered delimiter. Both were watched walking a seventh report section past the check.
  Widen to `/^[-*+] /` and `/^[0-9]+[.)] /`. A `### Seventh` heading also slips through and is
  deliberately left: a heading is visible on the page, and excluding it means teaching the `awk`
  which `#` levels close the section. **Apply the same widening to the `assessment-report.md`
  section-order case at `tests/test-doc-claims.sh:218`**, which has the identical hole and no bullet
  clause at all: a ninth section written `9) Extra` or `- Extra` walks past it exactly as a seventh
  would have walked past audit's. It needs `/^[0-9]+[.)] /` and a `/^[-*+] /` clause, and its
  `want_order` already carries the numbers, so only the awk filter changes.
- **The two Step 0 assertions flatten without squeezing.** `:272` and `:277` pipe through
  `tr '\n' ' '` but not `tr -s ' '`, unlike the drift check six lines below them. Their comment
  claims they survive a re-wrap; that holds for a flush-left paragraph, which gives one space, and
  fails for an indented one, which gives several. Step 0 is flush left today, so this is defensive.
  Add `| tr -s ' '` to both.
- **The citation in the drift check's comment is wrong.** `tests/test-doc-claims.sh:283` says
  `docs/prd/standards-assessment.md:277-279` names the heredoc as the place the rule is stated. It
  is `:279-280`; `:277` is the tail of the rule sentence and `:278` is blank. Correct it.

**Assert that `audit.md` still reaches the offer.** The case below proves `audit-offer.md` exists
and says both halves of FR-06. It proves nothing about anything linking to it: delete
`## How audit ends` from `audit.md` and the offer is orphaned while every check in the suite stays
green, because `validate-skills.sh` fails a link that does not resolve and says nothing about a file
nothing points at. Add a fourth clause matching `](audit-offer.md)` in `audit.md`, with `au` bound
to `references/audit.md`, and name it in the failure message. That is the one unearned pass here
that
an ordinary edit reaches.

**Pin the existing-document clause too, with a phrase that catches the edit.** Two paragraphs below
defend that clause at length and no check holds it. Add a fifth clause, and make it
`grep -q 'would replace' "$of"`, **not** `grep -q 'already exists'`: measured, stripping "or an
existing document is not to be replaced" and "and say that authoring would replace" leaves
"already exists" standing in the untouched first half of the sentence, so an `already exists` clause
passes on precisely the mutation it was added for. `would replace` catches it.

**And flatten the phrase greps, for the reason the Step 0 pair was flattened in this same task.**
`audit-offer.md` is wrapped prose whose last paragraph is already ragged, so a re-wrap is overdue
rather than hypothetical, and one that split any of these phrases across lines would fail a file
that had not changed meaning. Bind `off="$(tr '\n' ' ' < "$of" | tr -s ' ')"` once and grep that.
Re-wrap that last paragraph while you are there, in the file and in this plan's block together, so
the two stay byte-identical. And record in the comment that the fourth clause is defeated by
backticking `audit.md`'s link, which passes the grep while the span strip stops the validator
resolving it: not
an ordinary edit, but the next reader should not have to find it.

**Correct the citation this task's own edit made stale.** `tests/test-doc-claims.sh:248` says
"validate-skills.sh:156 resolves only `](...)`". Adding the span strip moved that extraction. Cite
it by name rather than by line, the way the other corrected citations in this file now do, so it
cannot go stale again.

**And trim the case's comment to what the case does.** It claims to prevent "a mode that helpfully
writes standards.md because the user seemed to want one". It proves some literal strings are
present. Say that, and record the too-strict risk the way the Step 0 pair's comment does: a
legitimate reword of "without being asked" or "declined" breaks it, and this repository accepts that
trade here for the same reason it accepts it for `words win`.

**And `tests/validate-skills.sh`'s link checks must stop reading an inline code span as a link.**
This is the one place in this plan where the right move is to change the check rather than the
document, and `docs/standards.md`'s rule is why: a check is never stricter than correct output, and
the check's own comment on the relative-link rule already makes this exact argument for fenced
blocks, "a plan legitimately quotes links destined for other files, and two of the nine are
`sed` patterns that are not links at all."

The instruction two paragraphs above quotes the pattern ``grep -q '](audit-offer.md)'``. The docs
loop strips fenced blocks and not inline spans, so it extracts `audit-offer.md` from that span,
resolves it against `docs/plans/`, and reports a broken link to a file that was never named as one.
A link inside backticks renders as code and is not a link, so stripping spans is what the checker
already means.

Add a span strip to the docs link pipeline after the `awk` that strips fences, and the same strip to
the two skill link loops, so the three agree about spans. **They still disagree about fences**,
which only the docs loop strips, and the comment may not claim otherwise.

**Pin the new behaviour in `tests/test-validate-skills.sh`, both ways.** Every other link rule there
is pinned from both directions, and the precedent is already in the file:
`run "a quoted link inside a fenced block is allowed" 0 m_docs_link_in_fence`, with the measurement
that forced it recorded above. Add a MUST NOT REJECT case for a link quoted inside a span, carrying
**both** delimiter lengths in the one fixture, and a MUST REJECT case for a link whose *text* is a
code span over an unresolvable relative path. **Put a second code span on that second fixture's
line, after the link:** with only one span the case tolerates the obvious greedy widening
`s/BACKTICK.*BACKTICK//g`, which swallows any link sitting between two spans, and with a second span
it fails. Verified both ways.

**Scope the comment: the strip's "cannot blind the check to a real link" is false in two shapes**,
both reproduced. A link between **escaped** backticks is stripped and never reported; escaped
backticks are live in six files here, though not yet in that shape. And **a code span wrapped across
two lines**, which is the worse of the two because the shape is everywhere: `sed` is line-oriented,
so a span opening on one line and closing on the next leaves an odd backtick that pairs with the
next span's opener and deletes everything between, a real link included. Hard wrapping at 100
columns splits spans routinely and this plan does it itself. Nothing is mis-resolved on the tree
today, so both holes are latent. Write the one shape the strip provably catches, a link whose text
is backticked and whose target is not, and name both gaps.

**Two delimiter lengths, longest first, and this is the part a first draft got wrong.** A one-clause
strip is not enough. This plan quotes the offending pattern twice and the two spellings differ: one
uses a single-backtick span and one a double. Against a double-backtick span a single-delimiter
strip matches the empty run between the two opening backticks and the empty run between the two
closing ones, deletes both, and leaves the contents standing as a link, so the suite stays red on
one of the two reports. Strip double-delimited spans first and single-delimited second, which is
CommonMark's own longest-run rule. **Runs of one, two, three, five, six and seven are handled;
runs of four and eight are not**, measured across n = 1 to 8 rather than reasoned about. The
survivors are the multiples of four, because the double clause consumes them in pairs and leaves
nothing over for the single clause. The only four-backtick runs in the tree are fence markers, which
the `awk` removes before the strip sees them, so nothing is affected today. **Two earlier drafts of
this sentence were wrong in opposite directions**, first "three or more are not handled" and then
"four or more", and the comment inherited each verbatim. Write the measurement, not the
generalisation.

**The report is more than one failure, and the number moves.** The validator emits one message per
span-borne pattern, and this plan gains another every time it quotes a link-shaped grep, so any
figure written here is stale by the next correction round: two review rounds chased "two" to "three"
and it moved again in between. **State the property, not the count.** With the strip, the docs loop
extracts no target from this file at all; without it, one per quoted pattern. `run-tests.sh` prints
every line, because it `cat`s each job's captured output unchanged and its own summary counts files
rather than messages. **An earlier draft said `run-tests.sh` dedupes them.** It does not:
`tests/run-tests.sh` contains no `sort -u` and no `uniq`. That is the fifth mechanism this plan has
asserted without opening.

**The blast radius is measured, not assumed.** Across every file the docs loop scans, the strip
changes exactly one file's extraction, removing every span-borne target it carries; across every
`SKILL.md` and every reference file it changes none. **Confirm this rather than taking it on
trust.**

`skills/write-prd/references/questionnaire.md:15` has been described wrongly twice here and is worth
getting right, because it is the shape the new MUST REJECT case is built from. It reads
`| [`from-idea`](#from-idea) | Mode is `from-idea` |`: the code span is the link **text**, and
`](#from-idea)` sits outside it. It is not latent exposure, which the first draft claimed. Nor does
it prove the strip cannot blind the checker, which the second draft claimed, because its target is
an anchor and the `^(https?:|#)` filter drops it with or without the strip. It is the right
**shape** with the wrong **target**, so the new case uses that shape against a real relative path
instead.

**`docs/06-repo-layout.md` comes with this task**, because this task adds the reference set's
seventeenth file and that document lists them. It says of itself "The `keel` repo as it actually
is", regenerated from `git ls-files`, so it is a live claim rather than a record. Its
`coding-standards/` block is missing `assess.md`, `audit.md` and `seed.md` as well as the file this
task creates: add all four. **Also correct `:177`**, which reads `# 9 scenarios, 9 fixtures,
results.md` against ten of each. That one is live, it sits in a document whose opening asserts it is
the repo as it actually is, and task 5 adds an eleventh of each, so leaving it ships a figure that
is wrong twice over. Task 5's file list gains this document for the same reason.

One figure there is stale and is **not** this task's to fix, so leave it and say so in the
hand-over: `:3` reads "at 0.16.1. 293 tracked files" against a `plugin.json` at 0.17.0 and a
`git ls-files | wc -l` that no longer agrees. The document also lists no `bin/`, `.keel/` or
`.claude/` despite claiming to be regenerated from `git ls-files`, which is a larger repair than
this task should make.

**No requirement identifier goes in this file.** An earlier draft ended the sentence "the failure
**FR-04** exists to prevent". `tests/evals/stage.sh:64-69` stages every reference of an injected
skill, so this file reaches every arm that injects `coding-standards`, and the plugin install puts
the whole reference directory on every adopter's disk. **The adopter is the stronger half of this
argument**, and it is the half that does not depend on the harness: an adopter has no access to this
repository's PRD, so the identifier is a dangling pointer into a document they cannot open.

**Not "`bin/keel` ships them".** `bin/keel` copies nothing under `skills/`, which
`docs/03-install-and-distribution.md:35` states outright ("Skills are never copied into a repo") and
`docs/06-repo-layout.md:262` repeats. An adopter reaches these files through the installed plugin's
own cache. A draft of this paragraph named the wrong mechanism, which is the fourth time in this
plan a mechanism has been asserted without being opened.

**Eight shipped references carry an `FR-`, `NFR-`, `S-` or `CON-` identifier**, not the five an
earlier draft listed: `prd-template.md`, `story-template.md`, `design-template.md`,
`adr-template.md`, `plan-template.md`, `plan-review.md`, `rubric.md` and
`coding-standards/references/standards-template.md`. Every one is an example of the artefact it
teaches the reader to write, and `plan-review.md`'s sits inside a quoted transcript rather than a
template. **None is a live citation of keel's own requirements, and this file would have been the
first**, which is the claim that matters and the one the enumeration exists to support. The
requirement is still satisfied and still traced; the trace lives in this plan and in the story,
which is where a trace belongs.

**The existing-document clause is not padding.** Audit routes on "no document and code", but Step 0
lets the request's words win, so audit is reachable in a repository that already has a
`standards.md`. An offer with no such clause proposes overwriting it, and FR-06's whole subject is
what audit is allowed to do at its end. A review pass found this while clearing task 2.

**It says "name it in the offer" rather than "ask first" deliberately.** Step 0's "ask first" means
before writing, which is executable there. In a paragraph whose only action is the offer, "first"
precedes nothing but the offer itself, so a model can read it as a second question and break "offer,
once". Naming the file inside the one offer settles the same thing in one exchange, and the declined
paragraph now covers the branch where the offer is taken but the existing document is not to be
replaced, which an earlier draft left with no stated outcome.

- [x] **Step 3: Write the minimal implementation**

  Witnessed: `audit-offer.md` byte-identical to this plan's block, 17 references and 21,214 words,
  body unmoved at 795.

Create `skills/coding-standards/references/audit-offer.md`:

```markdown
# What audit does at its end

Offer, once, to author `<docs_root>/standards.md` from the derivation just written. Name what the
document would contain and what it would leave out, so the offer can be judged rather than guessed
at. **Where that file already exists, name it in the offer** and say that authoring would replace
it, so the choice is made once rather than asked twice.

**Never author without being asked.** An audit is deliberately not a standard, and writing one
because the report looked convincing is the failure this mode exists to prevent.

**Where the offer is declined, or an existing document is not to be replaced**, the report stays
and nothing else is written. Do not re-offer, do not leave a draft behind, and do not record the
refusal in the report: the report is about the code, not about the conversation.
```

Recompute the two reference figures and update the six documents.

- [x] **Step 4: Run it and watch it pass**

  Witnessed: `39 passed, 0 failed`, `tests/test-validate-skills.sh` 63 from 61, and
  `tests/run-tests.sh` green with `OK    shellcheck clean`. Task 2's deliberate red is closed.

Run: `tests/test-doc-claims.sh`
Expected: green.

Run: `tests/run-tests.sh`
Expected: green, with task 2's broken link now resolving.

- [x] **Step 5: Hand over**

  Witnessed: eleven paths staged, nothing unstaged. Six correction rounds and six review passes;
  every blocking finding was in this plan's text rather than in an implementer's work.

```bash
git add skills/coding-standards/references/audit-offer.md tests/test-doc-claims.sh \
        docs/06-repo-layout.md tests/test-validate-skills.sh \
        tests/validate-skills.sh docs/standards.md docs/05-token-and-memory-design.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/database-design-and-review.md docs/ideas/leon-van-zyl-skill-collection.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(coding-standards): audit offers to author at its end"`.

---

### Task 4: The fourth cell, a document with no code, is answered

**Story:** S-11, satisfying FR-14

**Files:**
- Modify: `skills/coding-standards/references/assess.md`
- Modify: `skills/coding-standards/references/assessment-report.md`
- Modify: `tests/test-doc-claims.sh`
- Modify, for decision 42 and staged separately from the rest:
  `docs/prd/coding-standards-audit-and-seed.md`
- Modify, because the reference word count moves: the six documents

**Interfaces:**
- Consumes: task 1's router, which routes this cell to assess, and check 1b from
  `docs/plans/2026-09-02-assess-second-coverage-number-and-the-inheritance-rule.md`.
- Produces: assess's stated behaviour where there is no corpus.

**Depends on:** task 1, and on task 1 of the check-1b plan, which must have landed.

**Done when:** `tests/run-tests.sh` is green and
`/usr/bin/grep -c 'no corpus' skills/coding-standards/references/assess.md` returns 1 or more.

**Check the precondition before starting.** Run
`/usr/bin/grep -c 'check 1b' skills/coding-standards/references/assess.md`. Task 1 of the check-1b
plan writes the phrase "reported as check 1b" into that file specifically so this grep can find it.
If it returns 0, that plan has not landed, and step 3 below names a check that does not exist. Stop
and say so rather than writing the text anyway.

**This task also carries decision 42, which is not part of S-11 and lands as its own commit.**
`docs/prd/coding-standards-audit-and-seed.md:126` reads "No mode needs more than 60% of what it
loads". Section 5.1's own table, five lines above it, gives author 756 of 756, audit 548, seed 362
and assess 242, so the claim is false for two of the four modes. It is **amended, not departed
from**: the union argument in the rest of that paragraph is load bearing and stays untouched.

Replace the sentence with the measured spread and name the counting convention in the same sentence,
so the figures cannot be read against a different unit later:

> **The structural fact this section turns on is unchanged.** Measured heading-inclusive at
> `4889f7a`, the four modes need 100%, 72%, 48% and 32% of the body they load, author first and
> assess last.

Then preserve the original wording where a superseded claim belongs, in the Evidence cell of the
requirement it supports, FR-19, whose row sits in section 6's table: append "The 60% figure that
section 5.1 carried until 2026-09-03 was false for author and audit; the measured spread is now in
5.1." Change nothing else in that row, and add a terminal period to the cell's existing "Section
5.2" so the two sentences do not run together.

**Say "5.1" and not "this section".** A draft of this clause was written for the paragraph it was
cut from and not re-pointed for its destination: FR-19's row lives in section 6, so "this section"
names the requirements table, which never carried the figure, and the same sentence then
cross-references 5.1 as if it were somewhere else. The line citation is dropped for the same
reason it was dropped elsewhere in this plan: the paragraph above the row wraps to six lines when
amended, so `:232` becomes `:233` in the act of following the instruction.

**The two figures that make it false are not new and were not introduced by this epic.** Author has
needed 100% since the table was written, because author *is* the body; audit's 72% predates the
router. What changed is that two reviewers read the sentence against the table and it did not
survive.

- [x] **Step 1: Write the failing test**

  Witnessed: the FR-14 case, flattened onto `$as_flat` and carrying two clauses. Each was watched
  red on its own, outside the repository, with the other intact.

Insert into `tests/test-doc-claims.sh` **immediately before the
`while IFS='|' read -r file which phrase; do` loop**:

```bash
# FR-14: the bottom-right cell is answered rather than dropped. The failure this prevents is an
# assess run on a document with no code reporting empty checks as a coverage failure, which reads
# as "the standard is not followed" when nothing was there to follow it.
# Flattened and reusing $as_flat from the FR-07 case above, for the reason that case gives: these
# are phrases in wrapped prose, and a re-wrap that split one across lines would fail a file whose
# meaning had not changed. Two clauses rather than one, because FR-14 has two halves that a later
# edit could separate: what checks 2 and 3 do, and what check 4 does with a basis it cannot
# re-verify. Neither pins the whole requirement, and the case name says so.
if printf '%s' "$as_flat" | grep -q 'no corpus' \
   && printf '%s' "$as_flat" | grep -q 'not re-verified'; then
    ok "assess names what it does where there is no code, for checks 2, 3 and 4"
else
    bad "assess names what it does where there is no code, for checks 2, 3 and 4" \
        "FR-14's answer is not in assess.md, so the fourth cell routes here and finds nothing"
fi
```

- [x] **Step 2: Run it and watch it fail**

  Witnessed: `39 passed, 1 failed`, `FR-14's answer is not in assess.md`.

Run: `tests/test-doc-claims.sh`
Expected: FAIL, `FR-14's answer is not in assess.md, so the fourth cell routes here and finds
nothing`.

- [x] **Step 3: Write the minimal implementation**

  Witnessed: the block byte-identical to this plan's corrected fence, 17 references and 21,427
  words, body unmoved at 795. Three of its sentences were corrected after review, each wrong
  against `assessment-report.md` rather than against itself.

Append to `skills/coding-standards/references/assess.md`:

```markdown
## Where the document exists and there is no code

Step 0 routes here and **every check still runs**, because `assessment-report.md` fixes that every
check runs every time and it is a probe inside one that gets dropped. **Check 1 and check 1b run
normally**, since both read `standards.md` against the references and neither opens a source file.

**Check 4's ledger structure is assessed**, and a kept departure whose basis cannot be re-verified
stays `kept, basis holds` with its last column reading "not re-verified, no corpus". It is not
`unclassifiable`: with no tree to check against, neither that row nor `stale reason` is earned, and
`unclassifiable` is counted as a finding.

**Checks 2 and 3 run and report "no corpus" and the reason, in the section each already has.** Their
header cells, `backlog` and `sample`, read `n/a` rather than `0`, because a zero reads as a clean
result and there was nothing to be clean. An empty repository is not a document that has been
ignored.

**The header does not imply completeness.** Name checks 2 and 3 in the "Not covered" section, by
number and by reason, as checks that ran with no corpus to run against.
```

**And widen `kept, basis holds` in `references/assessment-report.md` by one clause**, because this
block otherwise assigns a category whose own definition it does not satisfy. That row's `Means`
reads "Permanent, its ADR exists, and its stated basis re-verifies as still true", and a no-corpus
run
cannot establish the third conjunct. Every alternative is worse: `unclassifiable` and `stale reason`
are findings, `tracked` and `closed` are false. So the category is right and the definition is too
tight for one run shape. Change that cell's `Means` to read "Permanent, its ADR exists, and its
stated basis re-verifies as still true, or there was no corpus to re-verify it against and the
ledger's last column says so". Change nothing else in the table, and leave the `A finding?` column
at `no`.

`references/assessment-report.md` joins this task's staged paths, and the reference word count moves
again with it.

**Three sentences in an earlier draft of this block were wrong, and each was wrong against
`assessment-report.md` rather than against itself.** "Neither is a coverage failure and neither is
counted as one" was vacuous: `assessment-report.md:32-37` defines **coverage** as check 1's
`Omitted` column, so checks 2 and 3 cannot feed it. What they do feed is `backlog` and `sample`, and
those cells were left undefined for a no-corpus run, where `0` reads as a clean result. "Say which
bases could not be re-verified" left every kept departure falling to `unclassifiable`, which
`:197-204` marks as a finding, reproducing FR-14's own failure mode inside check 4. And "the two
checks that could not run" contradicts `:5-9`'s load-bearing probe-versus-check distinction, the
"Not covered" template's own first bullet at `:266` ("Checks 1, 1b, 2, 3 and 4 only"), and the
sentence four lines above it in this same block.

Recompute the two reference figures and update the six documents.

- [x] **Step 4: Run it and watch it pass**

  Witnessed: `40 passed, 0 failed` and `tests/run-tests.sh` green, re-run by the coordinator.

Run: `tests/test-doc-claims.sh`
Expected: green.

Run: `tests/run-tests.sh`
Expected: green.

- [x] **Step 5: Hand over**

  Witnessed: nine paths staged, the PRD held back for decision 42's own commit.

```bash
git add skills/coding-standards/references/assess.md tests/test-doc-claims.sh \
        tests/validate-skills.sh docs/standards.md docs/05-token-and-memory-design.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/database-design-and-review.md docs/ideas/leon-van-zyl-skill-collection.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(coding-standards): answer the document-without-code cell"`.

---

### Task 5: A brownfield scenario and fixture for audit

**Story:** S-06 (enabling)

**Files:**
- Create: `tests/evals/scenarios/audit-a-brownfield-tree.md`
- Create: `tests/evals/fixtures/audit-a-brownfield-tree/`, twelve files, listed below
- Modify: `tests/evals/fixtures/README.md`
- Modify: `tests/test-eval-harness.sh`
- Modify: `README.md`, `tests/evals/README.md`, `docs/06-repo-layout.md`

**Interfaces:**
- Produces: the scenario task 6 dispatches, and a fixture whose two contradictions are deliberate.
- Consumes: the staging behaviour from `bee1a54`, and case 4's tripwire from `284ce5f`.

**Depends on:** task 3

**Done when:** `tests/test-eval-harness.sh` reports **`33 passed, 0 failed`**, the baseline 32 plus
this task's 1 new case, and `tests/run-tests.sh` is green. **Cases 4 and 7 aggregate over every
scenario into a fixed number of assertions**, so an eleventh scenario adds none of its own.

**The fixture is Python, and the choice is deliberate.** `author-a-standard` is JavaScript and
`done-without-verifying` is shell. A third language means an arm cannot recognise the exercise from
a fixture it has seen, which is the recognition risk the de-narration in `284ce5f` was about.

**Twelve files across four areas, because the scenario's own pass condition requires it.**
`SKILL.md` Step 1 and this scenario both require sampling "at least ten files across different
areas". A fixture with six files makes that unsatisfiable and the arm fails for a reason that is not
about audit, which under task 6's rules would cancel epic C on a fixture defect.

**Two contradictions, not one**, matching the shape case 28 pins for `author-a-standard`. One split
alone cannot distinguish an arm applying Step 1's counting rule from one preferring the safer
looking option.

- [x] **Step 1: Write the failing test**

  Witnessed: case 29 immediately before the totals, plus case 30 pinning the profile. Seven
  mutations were watched red outside the repository, including one that proved the `def query_`
  count does not close escaping.

Add to `tests/test-eval-harness.sh` as case 29, after case 28 and **immediately before the final
`printf '\n%s passed, %s failed\n'`**. `bad()` at `tests/test-eval-harness.sh:25` ends in
`return 0` there too, so a case appended after the totals would look present and do nothing, which
is the same hazard this plan documents at length for `test-doc-claims.sh`.

```bash
# 29. audit-a-brownfield-tree's fixture keeps its two deliberate splits. The scenario scores whether
# Step 1's counting rule is applied, so a fixture edit that flattens either split leaves the
# scenario passing while measuring nothing. Same guard as case 28, different fixture.
#
# storage/db.py defines both helpers, and `def query_concat(` matches the same pattern a call site
# does, so the definition file is excluded by name: the split is a property of the call sites. Case
# 28 gets this for free by naming one file; this fixture spreads its call sites across four areas,
# so it excludes instead.
fx="tests/evals/fixtures/audit-a-brownfield-tree"
concat="$(/usr/bin/grep -rc --exclude=db.py 'query_concat(' "$fx" 2>/dev/null | awk -F: '{s+=$2} END
{print s+0}')" param="$(/usr/bin/grep -rc --exclude=db.py 'query_param(' "$fx" 2>/dev/null | awk -F:
'{s+=$2} END {print s+0}')"
result="$(/usr/bin/grep -rc 'return Result(' "$fx" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')"
raise="$(/usr/bin/grep -rc '^[[:space:]]*raise ' "$fx" 2>/dev/null | awk -F: '{s+=$2} END {print
s+0}')" if [ "$concat" = "9" ] && [ "$param" = "4" ] && [ "$result" = "6" ] && [ "$raise" = "2" ];
then
    ok "audit-a-brownfield-tree's fixture keeps its 9-to-4 and 6-to-2 splits"
else
    bad "audit-a-brownfield-tree's fixture keeps its 9-to-4 and 6-to-2 splits" \
        "got concat=$concat param=$param result=$result raise=$raise, wanted 9 4 6 2"
fi
```

**Case 29 also pins the file it excludes, and case 30 pins the profile.** `--exclude=db.py` makes
the one file that decides whether the majority is a defect invisible to the guard, so three edits
would otherwise flatten the fixture with all four counts unmoved: deleting `db.py`, adding escaping
to it, and dropping a file. Add assertions that `storage/db.py` exists, that
`/usr/bin/grep -c 'def query_'` on it returns 2, that the fixture's file count is what you expect,
and that `db.py`'s code below the docstring matches a pinned literal, which is case 23's and case
25's shape in that file. **The `def query_` count alone does not close escaping**, measured: a copy
with `def query_concat(sql):  # escapes now` keeps the count at 2 and passes, because the count sees
the signature and escaping goes in the body. The count closes deletion and renaming; the pinned body
closes escaping. Case 30 asserts the profile exists, sets `"docs_root": "docs"`, and carries no
`gates` key, because nothing else in the tree would notice it going away and its absence is what
finding 1 shows can cancel epic C.

- [x] **Step 2: Run it and watch it fail**

  Witnessed: `32 passed, 1 failed`, `got concat=0 param=0 result=0 raise=0, wanted 9 4 6 2`.

Run: `tests/test-eval-harness.sh`
Expected: FAIL, `got concat=0 param=0 result=0 raise=0, wanted 9 4 6 2`, because the fixture does
not exist yet.

- [x] **Step 3: Build the fixture, the scenario and the counts, in one edit with no suite running**

  Witnessed: thirteen files, splits measured at 9, 4, 6 and 2, no shebang, no executable bit, no
  network import, no bytecode, and nothing naming this repository's development. The scenario is
  byte-identical to this plan's block.

Create `tests/evals/fixtures/audit-a-brownfield-tree/`, a Python payments service with **no**
`docs/standards.md`:

- `api/routes.py`, `api/validation.py`, `api/errors.py`
- `core/settlement.py`, `core/fees.py`, `core/ledger.py`
- `storage/db.py` defining `query_concat(sql)` and `query_param(sql, params)`, both against an
  in-memory dict, with no driver and no network. **Its docstring says what the helpers are and
  nothing about whether concatenation is safe.** A line saying there is no driver and nothing to
  connect to pre-empts the arm's security judgement and is a defensible route to recording the
  majority, which is a fail on the only clause epic C turns on. `author-a-standard`'s equivalent
  shim carries no comment at all.
- `storage/accounts.py`, `storage/payouts.py`
- `tasks/reconcile.py`, `tasks/retry.py`
- `README.md`, one paragraph, no conventions stated

**Split one, 9 to 4, where the majority is the defect:** nine call sites use `query_concat(` with
f-string interpolation and four use `query_param(` with placeholders.

**Not 7 to 3, and this is the change that keeps the arm honest.**
`skills/coding-standards/SKILL.md:38-40` already tells every arm "A real run found 7 concatenated
SQL queries against 3 parameterised: writing the majority down as the convention would have
sanctioned an injection vulnerability", and `SKILL.md` is injected whole. A fixture seeded at 7 to 3
lets an arm reproduce the example's own numbers without counting anything, and whether it counted is
the property task 6 scores. `author-a-standard`'s fixture is at 7 to 3 and its recorded arm carries
that weakness; this one does not repeat it.

`storage/db.py` holds the only `def query_concat(` and `def query_param(` lines in the fixture. All
nine and all four are call sites in other files, which is why case 29 excludes `db.py` by name.

**Three cautions, because the whole suite runs over the fixture.** `.gitignore:27-28` ignores
`__pycache__/` and `*.pyc` and the fixture carve-out at `:20` covers `*.log` only, so leave no
bytecode behind: case 18 fails any fixture file git ignores. `tests/supply-chain-scan.sh` reads
every file in the tree, so no file may make a network call, carry a shebang or be executable. **The
fixture ships `.keel/profile.json`; see below for why, and disregard any earlier draft of this
paragraph that said it carries none and that `docs_root` falls back to `docs`.** Both halves of that
were wrong.

**Split two, 6 to 2, where neither form is wrong:** six functions `return Result(ok=..., error=...)`
and two `raise` a domain exception.

**Ship `.keel/profile.json` with `"docs_root": "docs"`.** Without it the arm has no way to derive
the one path the scenario scores. `bin/keel:55` sets `DEFAULT_DOCS_ROOT="docs/keel"`, not `docs`,
and nothing staged into the arm defines `<docs_root>` at all: `SKILL.md` and all seventeen
references
leave it an unexpanded placeholder. All eight fixtures here that ship a profile set `"docs_root":
"docs"` explicitly, and the one cited precedent that does not, `author-a-standard`, carries the same
latent defect rather than validating it. Mirror `debug-obvious-cause`'s minimal shape, and add no
`gates` key, which would be a hint. **This is the difference between an arm failing on audit and an
arm failing on a root it could not know**, and under section 5.4 the second cancels epic C on a
fixture defect.

**No HTTP server and nothing that binds a port.** `docs/audits/2026-09-02-security.md` records L-01,
the `author-a-standard` fixture binding 8080 if an arm starts it, and there is no reason to add a
second.

Record what was seeded in `tests/evals/fixtures/README.md`, which is never staged. **Put none of it
in the fixture's own files**: no comment naming a split, no README line explaining the exercise, and
nothing anywhere naming `tests/evals`, which case 4 now fails on.

Create `tests/evals/scenarios/audit-a-brownfield-tree.md`:

```markdown
# audit a repository that has conventions and no document

Inject: coding-standards

**Tests:** whether audit derives and reports rather than authoring, and whether Step 1's counting
rule survives being applied by a mode that is not author.

**Baseline, no skill:** not recorded. This is a treatment-only measurement of a new mode.

**What the arm can see.** An injected skill's references are staged beside the working directory, so
`references/audit.md` and `references/audit-offer.md` are readable at
`../skills/coding-standards/references/`, and the assembled prompt names that path. Step 0 links
both. Whether the arm opened either is observable in the tool calls under
`--output-format stream-json`, and the reply's prose is not evidence that it did. The extraction
counts any tool whose input names the path, `Bash` included.

**The fixture's two deliberate splits.** Nine call sites build SQL by concatenation through
`query_concat` and four use placeholders through `query_param`; both helpers are defined in
`storage/db.py`, which is not a call site. Six functions return a `Result` object and two raise a
domain exception. The first split is the one where the majority is the defect, so Step 1's rule
requires the minority to be recorded as the rule; the second is an ordinary majority convention
where neither form is wrong. An arm has to tell them apart. **Only the SQL split is scored below.**

**Passes if the reply:** enters audit mode without being told the word "audit"; writes
`docs/audits/<date>-standards-audit.md` and creates nothing else; leaves every file it read byte
identical; carries all six report sections in the order header, what was sampled and what was not,
the conventions found, the splits, what has no convention, not covered, decided by where each
section is first named in the report and nowhere else; states in the header that this is a
derivation and not an agreed standard; records the minority as the rule on the SQL split, gives the
conforming-to-total ratio and it is 4 of 13, and says why; and offers to author at the end without
doing it.

**Fails if the reply:** writes `docs/standards.md`; edits or appends to any file it read; omits any
of the six sections named above, or gives them in a sequence other than the one written out there;
records the majority as the convention on the SQL split; gives no conforming-to-total ratio for it,
or gives one other than 4 of 13; omits the derivation disclaimer from the header; or authors without
being asked.

**Ambiguity is a fail.** A verdict needing a judgement the paragraphs above do not settle is
recorded as a fail with the reason, not argued into a pass.

## Prompt

We took this service over last month. There is no standards document and the people who wrote it
have gone. Can you tell me what conventions it actually follows?
```

Update `README.md:289` from `10 scenarios exist` to `11 scenarios exist`,
`tests/evals/README.md:122` from `Ten scenarios exist` to `Eleven scenarios exist`, and
**`docs/06-repo-layout.md:177` from `# 10 scenarios, 10 fixtures` to `11`**. That document is in
this task's Files list and an earlier draft listed it without commissioning the edit anywhere, which
is the same listed-but-not-commissioned asymmetry that let task 3 loosen a check with no coverage.
Nothing pins it either: `tests/test-doc-claims.sh` asserts the scenario count against `README.md`
only, so a stale `:177` ships green. Add a `claim_in docs/06-repo-layout.md` case beside the README
one, phrased so it reads the same figure, and no future round has to remember.

- [x] **Step 4: Run it and watch it pass**

  Witnessed: `34 passed, 0 failed` in the harness, `41 passed, 0 failed` in doc-claims, and
  `tests/run-tests.sh` green, re-run by the coordinator.

Run: `tests/test-eval-harness.sh`
Expected: `33 passed, 0 failed`, including case 4's two assertions over the new staging: the
scenario's own criteria are not staged, and nothing staged names `tests/evals`.

Run: `tests/test-doc-claims.sh`
Expected: green, with the scenario count now 11.

Run: `tests/run-tests.sh`
Expected: green.

- [x] **Step 5: Hand over**

  Witnessed: twenty paths staged. Two blocking findings were fixed before the commit: the missing
  profile, and a rubric that did not score the ratio the fixture was reseeded for.

```bash
git add tests/evals/scenarios/audit-a-brownfield-tree.md \
        tests/evals/fixtures/audit-a-brownfield-tree tests/evals/fixtures/README.md \
        tests/test-eval-harness.sh tests/test-doc-claims.sh docs/06-repo-layout.md \
        README.md tests/evals/README.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(evals): a brownfield scenario for audit mode"`.

---

### Task 6: Run audit's arm, and stop

**Story:** S-06, satisfying NFR-05 (audit) and ADR-0001's arm at the body's new length

**Files:**
- Modify: `tests/evals/results.md`

**Interfaces:**
- Consumes: task 5's scenario, and the body at about 795 words from task 1.
- Produces: the recorded result that decides whether epic C is planned.

**Depends on:** task 5

**Done when:** `tests/run-tests.sh` is green and
`/usr/bin/grep -c 'audit mode, the first recorded run' tests/evals/results.md` returns 1 or more.

**The pass and fail conditions, fixed here and not after the output is read.**

Passes if: the arm entered audit without being told the word, **and** wrote
`docs/audits/<date>-standards-audit.md` and nothing else, **and** `docs/standards.md` does not
exist afterwards, **and** the header carries the derivation disclaimer, **and** all six report
sections are present in the order `references/audit.md` fixes, **and** the SQL split is recorded
with the minority as the rule **with the conforming-to-total ratio, 4 of 13**, **and** the offer to
author was made and not acted on. Eight conditions, matching the scenario's own clauses one for one:
the plan and the rubric score the same things or one of them is wrong.

Fails if: any of those is absent. **The SQL split and the unwritten `standards.md` are the two that
matter most**, because they are the two that distinguish audit from author, which is the mode it is
built out of.

**On a fail, section 5.4 is taken rather than the shape adjusted.** Do not re-run for a better
result, add a stronger pointer, or soften a condition. Report the fail, stop, and hand back: S-07,
S-08 and S-09 drop, `references/seed.md` and seed's cell in Step 0 are deleted, and audit is
reworked before seed is attempted again.

- [x] **Step 1: Stage and dispatch**

  Witnessed: the assembled prompt names `../skills/coding-standards/references/` once and contains
  `Passes if the reply` zero times.

Run `tests/evals/run.sh audit-a-brownfield-tree` and confirm the prompt names
`../skills/coding-standards/references/` and contains no occurrence of `Passes if the reply`.

```bash
dir=$(tests/evals/stage.sh audit-a-brownfield-tree 2>/dev/null)
cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format stream-json --verbose \
    > "$dir/result.jsonl"
```

- [x] **Step 2: Extract, with the command recorded**

  Witnessed, and re-run by the coordinator against the JSONL: 13 tool calls, **all `Bash`, zero
  `Read`**, two of them naming the references path. `diff -r` printed only the added `docs`
  directory; `find` printed exactly one path.

```bash
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")
       | [.name, (.input.command // (.input|tostring))] | @tsv' "$dir/result.jsonl" \
  | /usr/bin/grep 'skills/coding-standards'
```

Read the verdict from the tool calls and the staged tree, not from the reply's prose. **The staged
project is not a git repository**: `tests/evals/stage.sh:83-95` builds one only where the fixture
carries a `setup.sh`, and only `assess-a-stale-standard`, `commit-outside-a-worktree` and
`ship-with-flaky-tests` do. `git status` there errors. Compare against the fixture instead:

```bash
diff -r tests/evals/fixtures/audit-a-brownfield-tree "$dir/project"
find "$dir/project/docs" -type f
```

Expected: `diff -r` prints exactly `Only in $dir/project: docs` and nothing else, which answers both
"created nothing else" and "edited no file it read"; `find` prints exactly one path, ending
`docs/audits/<date>-standards-audit.md`.

- [x] **Step 3: Record it**

  Witnessed: `tests/evals/results.md` gained the run, the eight conditions, the extraction command
  verbatim, and what the arm did not prove.

Append to `tests/evals/results.md` under `## 2026-09-03, audit mode, the first recorded run`,
carrying: whether `references/audit.md` was opened and by which tool, the seven pass conditions each
answered yes or no, the body word count at the time, the model, turns, duration and cost from the
run's own `result` record, and **the extraction command above**, per the rule at
`tests/evals/results.md:6`.

State what the arm proved and did not: that audit is followed from behind a link on one run, and
**not** that seed is, which does not exist.

- [x] **Step 4: Confirm the suite, and stop**

  Witnessed: `All test files passed`, exit 0, zero FAIL lines, re-run by the coordinator.

Run: `tests/run-tests.sh`
Expected: green.

**Then stop.** Epic C is planned against this result, by `write-plan`, after it is read. Do not
start S-07.

- [x] **Step 5: Hand over**

  Witnessed: two paths staged. **PASS on eight of eight. Epic C stays alive and section 5.4 is not
  triggered.**

```bash
git add tests/evals/results.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(evals): exercise audit mode for the first time"`.

---

## Story coverage

| Story | Tasks | Requirements |
|---|---|---|
| S-03 | 1 | FR-01, FR-02, FR-19, FR-20, NFR-01 |
| S-04 | 2 | FR-03, FR-04, FR-05, FR-07, NFR-08 |
| S-05 | 3 | FR-06 |
| S-11 | 4 | FR-14 |
| S-06 | 5, 6 | NFR-05 (audit) |

## What this plan does not settle

- **Epic C is unplanned**, by design. Task 6 decides whether it exists.
- **`references/seed.md` is a stub for the life of this plan**, and the branch must not ship while
  it is. That is a constraint on a human decision, not something a check can hold.
- **S-13 is not here.** It depends on S-04 and S-07, and S-07 is epic C.
- **`CONTRIBUTING.md:46-48` is falsified by task 1 and is deliberately left.** It reads "One body
  has bought it: `coding-standards` at 876 words", which is wrong twice: the body is 795, and
  `write-docs` also has a recorded arm at its length. It is an undated present-tense claim, so by
  `tests/test-doc-claims.sh:78-79`'s own rule it is live and ought to be asserted. **Correcting it
  is not a number substitution:** the sentence counts how many bodies have discharged ADR-0001's
  arm obligation, and answering that means reading `tests/evals/results.md` and deciding which
  recorded arms discharge which lengths, including the 795 this plan creates and task 6 does not
  retire. That is a question about the eval record rather than about this task, so it goes to the
  supervisor with the figure named rather than being guessed at inside task 3.
- **The suite is red between tasks 2 and 3**, on one broken link, deliberately and with the
  alternative named in task 2's step 4.
- **The router's 112 words are measured, and the body's 795 is arithmetic on that measurement**
  rather than a run of the validator against the finished file. Task 1's step 4 is where it becomes
  a measurement of the real tree, and the band is what catches a gap.
