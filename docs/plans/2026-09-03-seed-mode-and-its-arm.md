# Seed mode and its arm Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** build seed, the fourth mode, behind the router that already points at it; give it the
library-gap report that is the reason it exists; hold the cross-cutting assumption that neither new
mode enforces anything; and stop at seed's eval arm.

**Stories:** S-07, S-08, S-09 and S-13. Epic C entire, plus the cross-cutting verify story that
could not run until S-07 existed.

**ADRs:** ADR-0001, whose 700 warning and 900 ceiling bind the body. **This plan does not change the
body**, which stands at 795 words with a passing arm at that length recorded 2026-09-03, so it
inherits the discharge rather than owing a new one. ADR-0002, whose delegation default binds
whoever executes this.

**Architecture.** Five tasks. Task 1 replaces the seed stub with the mode. Task 2 adds the gap
report. Task 3 holds S-13's assumption as checks. Task 4 builds seed's scenario and fixture. Task 5
runs the arm and stops.

**Depends on** `docs/plans/2026-09-02-the-four-mode-router-and-audit.md`, which is complete. Step 0
already routes a fourth cell to `references/seed.md` and that file already exists as a stub, so
nothing here has to touch `SKILL.md`.

## The result this plan is planned against

**Audit's arm passed on eight of eight**, recorded at `tests/evals/results.md:3212` under
`## 2026-09-03, audit mode, the first recorded run`. `docs/stories/coding-standards-audit-and-seed.md:497`
makes that the condition for epic C existing at all: a failing S-06 would have dropped S-07, S-08
and S-09 and reworked audit first. It passed, so epic C is planned, and this is that plan.

What the arm proved is narrower than "the shape works". It proved that **one mode** is followed with
its steps behind a link, on **one run**. It says nothing about seed, which did not exist when it
ran. That is why task 5 exists and why its fail branch is real.

## The one decision taken before writing this, and who took it

**Seed's gap report goes in the reply, not into a file.** `docs/ideas/coding-standards-audit-and-seed-modes.md:141`
lists this as explicitly not decided, and the PRD's FR-09 says only that seed "reports". Put to
Bernard on 2026-09-03 and answered: the reply.

The reason it went that way, recorded so the next reader does not reopen it: decision 1 of the idea
record makes the gap report a feedback loop into keel's own library, addressed to whoever maintains
keel and not to whoever owns the repository. A file written into the project puts keel's to-do list
inside somebody else's tree, addressed to a reader who is not there. It also keeps seed at exactly
one written file, which is the property task 5 verifies with `diff -r` the way task 6 of the
previous plan verified audit's.

**Task 2 records this in the PRD**, on FR-09's row, so the settled placement lives with the
requirement rather than only in this plan.

## Two things this plan carries and does not solve

Both are named here so no task tries to close them in passing.

- **Does a release-gate arm discharge an ADR-0001 length obligation, or only a dedicated length
  arm?** Written up in `docs/ideas/bodies-over-the-target-with-no-arm.md`, stated and deliberately
  unanswered per decision 46. It separates a count of one uncovered body from a count of three. No
  task here answers it, and no task here depends on the answer: `coding-standards` has a dedicated
  arm at its current 795, so this plan is on the settled side of the question either way.
- **`write-plan`'s body is 897 words with no arm at any length**, because no scenario injects it.
  That is the one body over ADR-0001's 700 target with nothing behind it at all. It is not this
  plan's work and is not fixed by anything here. Recorded so that whoever reads this plan next knows
  the gap is known rather than missed.

## The stub, and what task 1 discharges

`references/seed.md` is 47 words that say the steps are not written yet. It exists because the
router links it and the validator fails an unresolved relative link, so the four-mode Step 0 could
not land without it.

The previous plan attached a constraint to that: **the branch must not ship while seed is a stub**,
because a stub reaching an adopter is a mode that routes to nothing. **Task 1 discharges that
constraint** by replacing the stub with the mode. Say so in task 1's hand-over: it is the only thing
in this plan that unblocks a release, and whoever holds the push decision should be told it closed.

## FR-11 says "seed's body", and it means seed's own text

`docs/prd/coding-standards-audit-and-seed.md:225` requires that "Seed's body says explicitly that it
inverts Step 1". Read literally against `tests/validate-skills.sh`'s vocabulary, "body" is the part
of `SKILL.md` after the frontmatter, and satisfying FR-11 there would mean spending body words the
PRD's own budget section says are not available.

**This plan reads it as the mode's own text, which is `references/seed.md`.** That is what
`docs/stories/coding-standards-audit-and-seed.md:290-293` means by "the mode's own text", and it is
the same reading FR-19 forces on every other mode: assess's checks, audit's report shape and audit's
offer all live behind links, and none of them is in the body. Reading FR-11 the other way would make
it the only requirement in the set that contradicts FR-19.

Written down rather than assumed, because the two readings differ by about 40 body words and the
body has 105 to spare.

## One stale citation, found by opening the file

`docs/prd/coding-standards-audit-and-seed.md:60` cites `references/house-defaults.md:27` as the line
gating `frontend.md` on `has_ui` and the framework. **It is line 31.** The index gained rows and the
citation did not move.

Four other copies of `house-defaults.md:27` exist, at `docs/ideas/coding-standards-audit-and-seed-modes.md:22`,
`docs/ideas/standards-that-bind.md:80`, `docs/plans/2026-08-29-dart-flutter-stack-detection.md:2282`
and `docs/plans/2026-08-30-dart-followups.md:394`. **Only the PRD's is corrected**, in task 2, and
the other four are deliberately left: decision 10 says a live claim moves and a dated record does
not, and those four are records of what was true when they were written. The PRD is the live
requirements document and plan 1 already corrected FR-03's path in it on the same principle.

## The six places the reference-word figure is asserted

`tests/test-doc-claims.sh:108-112` computes `coding-standards`'s reference count, reference word
count and body word count from the tree, and the `CLAIMS` heredoc rows at `:443-461` assert them.
Measured today: **17 references, 21,427 reference words, body 795.**

**Tasks 1 and 2 change the reference words and nothing else.** Seed's file already exists, so the
count stays 17, and no task here touches `SKILL.md`, so the body stays 795. Six documents carry the
word figure and each must move with the task that changes it:

- `docs/05-token-and-memory-design.md:61`
- `tests/validate-skills.sh:21`
- `docs/standards.md:60`
- `docs/decisions/ADR-0001-skill-body-word-ceiling.md:31`
- `docs/ideas/leon-van-zyl-skill-collection.md:111`
- `docs/ideas/database-design-and-review.md:110`

`tests/evals/scenarios/assess-a-stale-standard.md` carries the body alone and does not move here.

Recompute after every task rather than copying a number:

```bash
find skills/coding-standards/references -name '*.md' | wc -l              # reference count
cat skills/coding-standards/references/*.md | wc -w                       # reference words
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/coding-standards/SKILL.md | wc -w   # body words
```

## Where a new check goes in `tests/test-doc-claims.sh`

**Not at the end of the file.** It ends with `printf '\n%s passed, %s failed\n'` and
`[ "$fail" -eq 0 ]`, and `bad()` ends in an explicit `return 0`, so a case appended after those runs
after the totals are printed and after the exit status is decided: it would look present and do
nothing. Every snippet in this plan goes **immediately before the
`while IFS='|' read -r file which phrase; do` loop**, which is line 434 today.

**Baselines measured today, before task 1:** `tests/test-doc-claims.sh` is **41 passed, 0 failed**
and `tests/test-eval-harness.sh` is **34 passed, 0 failed**. The tasks add six, three and three
doc-claims cases and one harness case, which is 47, 50, 53 and 35. `tests/run-tests.sh` is green, exit 0.
Every expected count below is arithmetic on those two numbers. **Confirm the baseline before each
task rather than trusting the arithmetic**, per decision 44: if another change has landed, the
expected total moves with it and the number of new cases does not.

**On the decision numbers in this plan.** Decisions 10, 38, 44, 45 and 46 are the coordinating
session's register and there is no file in this repository a fresh reader can open to look one up.
They are cited because the supervisor uses them, and each is stated in full where it is used, so
nothing here depends on the register being reachable. The one that also has a home in the tree is
decision 10, whose rule, that a dated record does not move and a live claim does, is written out at
`tests/test-doc-claims.sh:88-95` and worked through in
`docs/ideas/repo-layout-omits-its-own-executable.md`.

## Global constraints

Copied in full. A task executed by a fresh agent that reads only its own section still obeys these.

- **Verify commands**, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  There is no typecheck and no build.
- **Never start on `main`.** This work belongs on `sandbox`, which is where the branch already is.
- **Pushing `sandbox` is answered and allowed.** This constraint read "do not push, the push
  question is with Bernard and has not been answered" until 2026-09-03, and it was false from
  `a9e398c` onwards: the branch has been pushed since. `.github/workflows/ci.yml` triggers on
  push to `main` and on `pull_request` only, re-read before each push, so a `sandbox` push runs
  no job, opens no pull request and ships nothing. **Never push `main`.**
- **No task's `git add` block lists this plan file, deliberately.** The coordinator stages it with
  each task's commit, because a task's corrections to this plan are part of that task's record. An
  implementer following a `git add` block literally will leave it unstaged and should say so in the
  hand-over rather than adding it.
- **Do not edit any file while `tests/run-tests.sh` is running.** The suite runs test files in
  parallel at `MAX_JOBS=4`, and `test-doc-claims.sh` and `validate-skills.sh` both recompute the
  three figures from the tree at the moment they read it. An edit mid-run makes two jobs read
  different trees, and the failure looks like a wrong number rather than a race. Finish editing,
  then run. The suite takes about 150 seconds.
- **No task may create or delete a file under `tests/evals/scenarios/` while a suite run is in
  progress.** `tests/test-doc-claims.sh` asserts the scenario count against `README.md` and would
  see the window. Task 4 creates one, so it creates the file and all three count updates together,
  with no suite running, and only then runs the suite.
- **No em dashes, no en dashes, no dash longer than a hyphen**, anywhere, including commit messages.
  `tests/validate-skills.sh` fails any file under `docs/` carrying one.
- **Prose wraps at 100 columns; table rows and code blocks do not.**
- **A check is never stricter than correct output.** If a mechanical check disagrees with output you
  believe is correct, the check is wrong until proven otherwise.
- **Evidence about the tooling comes from the tooling.** Use `/usr/bin/grep` rather than bare `grep`
  when the result is evidence, use absolute paths in a background shell, and let a slow command
  finish rather than calling it hung.
- **Commit messages carry no attribution footers**, no `Co-Authored-By`, no generated-with line.
- **Nothing seed writes is enforcement.** `references/assessment-report.md` fixes that nothing in an
  assessment modifies what is being assessed; audit inherits it; seed's version is narrower and
  stricter, because seed writes exactly one file into a tree that had none.
- **Nothing staged for an arm may name `tests/evals`.** `tests/test-eval-harness.sh` case 4 fails
  any staged file that does, over every scenario's staging rather than one.
- **And nothing staged may narrate this repository's own development.** `tests/evals/stage.sh` copies
  **every** reference of an injected skill into the arm's tree, so a sentence about a plan, a branch,
  a release, an unbuilt story or an eval reaches the arm even when it never types the literal
  `tests/evals` that case 4 greps for. **Which arms:** the loop is driven by each scenario's own
  `Inject:` line, so `coding-standards`'s references reach the three scenarios that inject it today,
  `assess-a-stale-standard`, `author-a-standard` and `audit-a-brownfield-tree`, and task 4 adds a
  fourth. Say "the arms that inject it" rather than "every arm". Case 4 catches the string; this half
  is on the writer. It binds `references/seed.md`, which tasks 1 and 2 rewrite.
- **Nothing staged may hand an arm the answer it is scored on.** This is the constraint that shapes
  task 2, and it is why `references/seed.md` names neither `flutter` nor `frontend.md`. See task 2.

## Concurrency

**No concurrent batch is declared.** Tasks 1 and 2 both rewrite `references/seed.md`, tasks 1, 2 and
3 all add cases to `tests/test-doc-claims.sh`, tasks 1 and 2 both restage the same six figure
documents, and tasks 4 and 5 share the scenario. Run them in order.

**The 1 and 2 split costs one duplicated edit and is kept anyway.** The reference word figure is
recomputed twice and the same six documents are restaged twice, which merging the two tasks would
avoid. They stay split because they are different stories, S-07 and S-08, a reviewer could accept
the mode and reject the gap report, and each has its own red-to-green cycle. The duplication is
named here so it reads as a decision rather than as an oversight.

---

### Task 1: Seed's steps replace the stub

**Story:** S-07, satisfying FR-08, FR-10 and FR-11

**Files:**
- Modify: `skills/coding-standards/references/seed.md`
- Modify: `tests/test-doc-claims.sh`
- Modify: `docs/05-token-and-memory-design.md`, `tests/validate-skills.sh`, `docs/standards.md`,
  `docs/decisions/ADR-0001-skill-body-word-ceiling.md`,
  `docs/ideas/leon-van-zyl-skill-collection.md`, `docs/ideas/database-design-and-review.md`

**Interfaces:**
- Consumes: Step 0's seed cell, which already links this file, and `references/house-defaults.md`'s
  index, whose predicates seed evaluates.
- Produces: the mode task 4 stages and task 5 measures.

**Depends on:** none

**Done when:** `tests/test-doc-claims.sh` reports **47 passed, 0 failed** and `tests/run-tests.sh`
is green with exit 0 and zero `FAIL` lines.

- [x] **Step 1: Write the failing checks**

Add to `tests/test-doc-claims.sh`, immediately before the `while IFS='|' read -r file which phrase`
loop:

```bash
# S-07: seed's four load bearing clauses, plus the one that says it writes nothing else. None of
# these is derivable from Step 0's seed cell, which names the mode and links here and says no more.
#
# Flattened, for the reason the audit-offer cases above are flattened: grep is line oriented, this
# is wrapped prose, and a re-wrap that split a phrase across two lines would fail a file whose
# meaning had not changed, which is the too-strict failure docs/standards.md forbids.
#
# Each clause is a separate case rather than one case with five conditions, because the failure
# message has to say which clause went missing. A mode that keeps its provenance sentence and loses
# its Step 1 inversion is a different defect from one that loses both.
sd="skills/coding-standards/references/seed.md"
sd_flat="$(tr '\n' ' ' < "$sd")"

# FR-11, read as the mode's own text and not the skill body. The whole reason seed is defensible is
# that it says out loud it is doing the opposite of Step 1 and why. A seed mode without this
# paragraph is a style guide import with a citation attached, which is the thing Step 1 exists to
# prevent, and a reader who met both without it would be right to distrust one of them.
if printf '%s' "$sd_flat" | grep -q 'inverts Step 1' \
   && printf '%s' "$sd_flat" | grep -q 'assumes a codebase that exists'; then
    ok "seed.md states the Step 1 inversion and why"
else
    bad "seed.md states the Step 1 inversion and why" \
        "FR-11's two halves are not both in seed.md: that seed inverts Step 1, and that Step 1's rule assumes a codebase that exists"
fi

# FR-10. The provenance sentence goes in the document seed writes, not only in this file, so the
# clause asserted here is the instruction to write it. The failure it prevents is an inherited
# default being read six months later as an observed convention, which is the one thing that makes
# seeding worse than writing nothing.
if printf '%s' "$sd_flat" | grep -q 'seeded from the house defaults' \
   && printf '%s' "$sd_flat" | grep -q 'not derived from code'; then
    ok "seed.md requires the document to state its provenance"
else
    bad "seed.md requires the document to state its provenance" \
        "FR-10's sentence, that the document was seeded from the house defaults and not derived from code, is not commissioned in seed.md"
fi

# S-07's fourth scenario. Seed routes on there being no code, and the router decides before anything
# is read, so the mode is where a wrong precondition gets caught. Without this branch an arm that
# finds source files seeds over them anyway and the derivation that should have happened never does.
if printf '%s' "$sd_flat" | grep -q 'offer audit instead'; then
    ok "seed.md names the branch where code turns up after all"
else
    bad "seed.md names the branch where code turns up after all" \
        "seed.md does not tell a run that finds source files to name them and offer audit instead"
fi

# FR-08's second half, and the clause the gap report in task 2 is computed against. Folding in all
# ten references is the failure the index exists to prevent, and it is the likelier failure: reading
# everything is easier than evaluating ten predicates and is indistinguishable in the output unless
# the document says what it left out.
if printf '%s' "$sd_flat" | grep -q 'whose index predicate holds' \
   && printf '%s' "$sd_flat" | grep -q 'which did not and what decided it'; then
    ok "seed.md folds in only the applicable topic references, and names the rest"
else
    bad "seed.md folds in only the applicable topic references, and names the rest" \
        "seed.md does not restrict itself to the references whose index predicate holds, or does not require the excluded ones to be named with what decided them"
fi

# The blocking finding of the 2026-09-03 review, held as a check.
#
# standards-template.md:12 and :14 require a "Derived from" row naming a sample and a commit and an
# "Enforced by" row naming the check-only lint command, and :40-42 requires rule, reason and an
# example from this codebase, "All three". None of the three exists when there is no code, and the
# fixture's profile sets lint to null. seed.md told the arm to follow that template and separately
# forbade it to claim a convention was observed, which is a contradiction the arm resolves by
# guessing: it invents a commit, or it drops the rows, or it takes an example from a house
# reference's own illustration. The scenario's "Ambiguity is a fail" clause then converts a mode
# defect into a seed-drops verdict, which is the arm failing for the wrong reason.
#
# So the override is written down and pinned. Three clauses, one per row, because they fail
# independently: an arm can get the header right and still invent a per-entry example.
if printf '%s' "$sd_flat" | grep -q 'no files sampled' \
   && printf '%s' "$sd_flat" | grep -q 'adding a check-only lint command' \
   && printf '%s' "$sd_flat" | grep -q 'per-entry example is omitted'; then
    ok "seed.md says what the template's three code-dependent fields become with no code"
else
    bad "seed.md says what the template's three code-dependent fields become with no code" \
        "seed.md points at standards-template.md without saying what Derived from, Enforced by and the per-entry example become when there is no commit, no sample, no lint command and no file to cite"
fi

# Seed writes one file. This is the property task 5 verifies with diff -r against the fixture, and
# it is asserted here so the file cannot quietly grow a second output between arms.
if printf '%s' "$sd_flat" | grep -q 'and nothing else' \
   && printf '%s' "$sd_flat" | grep -q 'Make a network request'; then
    ok "seed.md writes one file and makes no network request"
else
    bad "seed.md writes one file and makes no network request" \
        "seed.md does not say it writes standards.md and nothing else, or has lost the no-network clause audit.md carries"
fi
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-doc-claims.sh`
Expected: FAIL, six failures, each naming a clause the 47 word stub does not carry. The stub says
only that the steps are not written yet, so none of the six phrases is present. Note the stub does
say "offer assess or audit", which is not "offer audit instead": that case fails too, and on the
phrase rather than on the file being empty.

- [x] **Step 3: Replace the stub**

Replace `skills/coding-standards/references/seed.md` entirely with:

```markdown
# Seed mode

Write a starting standards document where there is no code to derive one from, and say in the
document that this is what happened.

**Seed inverts Step 1, and the inversion is stated rather than hidden.** Step 1 says derive and do
not impose, and that rule assumes a codebase that exists. Where there is none there is nothing to
derive from, and the choice is between the house defaults and nothing. Seed is the honest answer to
a question Step 1 does not address rather than an exception to it, and a reader who meets seed and
Step 1 without this paragraph is right to distrust one of them.

## Before anything is written

Confirm the two facts that routed here. **Where the repository has source after all, name the files
and offer audit instead**, which derives from the tree rather than importing defaults: do not seed
over a repository that has something to read. Where `<docs_root>/standards.md` turns out to exist,
name it and ask before writing, per Step 0.

Read `.keel/profile.json` for `stack`, `verify.lint` and `docs_root`. Where the profile was
generated from a tree with no code, the stack fields read `unknown`, `none` and false by fallback
rather than by finding, and a detected nothing is not a decided no. Where the profile declares a
real value, that is a statement about the project and you use it. Several of the index's predicates
ask about a running system that does not exist yet, and the profile cannot settle those at all. Two
deciders are available: a profile value that was declared rather than defaulted, and what the
request actually says the project is, not what it suggests. Where neither settles a predicate,
record it in the document as undecided, naming the predicate, rather than as excluded. An
exclusion that nothing decided is a finding seed invented.

## What seed writes

`<docs_root>/standards.md`, and nothing else. Follow
[standards-template.md](standards-template.md), and take the content from
[house-defaults.md](house-defaults.md) and the topic references its index says apply.

**Only the topic references whose index predicate holds.** The index gives every reference its own
condition, and evaluating each condition against this project is the work. Fold in the ones that
hold, and record in the document which did not and what decided it. Record a reference no decider
settled as undecided instead: this record has three states, and no reference leaves it without one.
Folding in all of them is the failure the index exists to prevent, and it is invisible in the output
unless the document says what it left out.

**The document states its provenance in its own header:** that it was seeded from the house defaults
and not derived from code, and that it becomes a derived standard only once there is code and
somebody runs audit or author against it. Without that sentence an inherited default reads later as
an observed convention, which is worse than having written nothing.

### Where the template asks for something there is no code to give

`standards-template.md` was written for a document derived from a codebase, and three of the things
it requires cannot exist here. **Say what is missing in the document rather than inventing it or
dropping the row silently.** A blank where a reader expects a commit is a question; an invented
commit is a lie the reader has no way to catch.

- **`Derived from`** carries the provenance sentence instead of a sample and a commit: seeded from
  the house defaults, no files sampled, because there were none.
- **`Enforced by`** carries `profile.verify.lint` where the project has one. Where it is `null`,
  say so and say that adding a check-only lint command is the first thing to do here, which is
  Step 3's rule and the highest value work available before any code exists.
- **The per-entry example is omitted**, and each entry says so in one clause: no example, because
  there is no code to take one from. Rule and reason are still required and are both available from
  the house defaults. **Do not write an example from another project, from the house reference's own
  illustration, or from an imagined file in this one.** An invented example is the failure the
  template's own closing line names, and it is worse here than elsewhere, because a reader who finds
  one assumes the rest was observed too.

The departures ledger is written with its heading and no entries. A project that disagrees with a
house default records the departure there, with a reason, and that is the only mechanism there is.

## What seed never does

Write a rule it cannot source from the house defaults, however usual that rule is for the stack.
Claim a convention was observed. Write an example, a sampled file count or a commit into a template
row that has none. Edit any file other than the one it writes. Run anything that changes the
project. Make a network request.
```

**Nothing in that file names a plan, a branch, a story or an eval**, because every reference of an
injected skill is staged into the arms that inject `coding-standards`. The stub it replaces was
rewritten once for exactly this reason.

**The block above is the file as it landed, not as it was first written.** Three dispatched review
rounds amended it during execution and the block was resynced from the tree afterwards, per decision
45. What changed and why, so the next reader does not read the amendments as drift:

- **Blocking, round 2.** The paragraph now at `:19` said the stack "is the only thing that can
  decide it here". It is not. Seven of the ten rows in `house-defaults.md`'s index are properties of
  a running system rather than of a stack, and on a code-free tree the auto-detected profile reads
  `unknown`, `none` and false anyway: `lib/detect-stack.sh:444` returns `unknown unknown none none`
  and `detect_has_ui` at `:810-817` falls through to `false`. That contradicted the ledger clause,
  which requires the document to record what decided each exclusion, and an arm resolves a
  contradiction by guessing. The paragraph now names the two deciders that exist and adds an
  undecided state. `verify.lint` joined the read list in the same edit, because the `Enforced by`
  bullet uses it and the read list did not name it.
- **Should fix, round 3.** That repair stated the fallback rule unconditionally, which is false of a
  hand-authored profile: the fixture task 4 builds declares real values with no source, so an arm
  would have read a rule telling it its own stack fields could not be findings. Scoped to a profile
  generated from a code-free tree. The undecided state was also a third state in a two-state ledger
  sentence, so the ledger is now explicitly three-state, and the requester decider is limited to
  what the request says rather than what it suggests.
- **Should fix, round 4.** "the ledger has three states" collided with the departures ledger, the
  only defined referent of that word in the file and its two dependencies. Renamed to "this record",
  word-count neutral, so no figure moved.

**Carried, not fixed, and named here so they are not rediscovered as new:** the undecided record has
no named home in `standards-template.md`, which is pre-existing for the exclusion list and reopens
the three-fields section to close; `:49`'s "three of the things it requires cannot exist here" is
softened by `:56`'s "where the project has one", since a code-free repo can carry a hand-set lint
command; and `sd_flat` omits the `tr -s ' '` its own comment cites as precedent, which is arguably
correct as it stands, because adding it would let the provenance case pass on a bullet alone.

Then recompute the three figures and update the reference word count in all six documents listed
above. The count stays 17 and the body stays 795; only the words move.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-doc-claims.sh`
Expected: `47 passed, 0 failed`, which is today's 41 plus six.

Run: `tests/run-tests.sh`
Expected: green, exit 0, zero `FAIL` lines. `tests/validate-skills.sh` resolves
`references/seed.md` as it already did, and the body is untouched at 795.

- [x] **Step 5: Hand over**

```bash
git add skills/coding-standards/references/seed.md tests/test-doc-claims.sh \
        docs/05-token-and-memory-design.md tests/validate-skills.sh docs/standards.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/leon-van-zyl-skill-collection.md docs/ideas/database-design-and-review.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -m "feat(coding-standards): seed mode gets its steps"`.

**Say in the hand-over that the stub constraint is discharged**: the previous plan forbade shipping
the branch while `references/seed.md` was a stub, and after this task it is not one.

---

### Task 2: Seed reports the gaps in keel's own library

**Story:** S-08, satisfying FR-09, NFR-07 and NFR-08

**Files:**
- Modify: `skills/coding-standards/references/seed.md`
- Modify: `tests/test-doc-claims.sh`
- Modify: `docs/prd/coding-standards-audit-and-seed.md`
- Modify: the same six figure documents

**Interfaces:**
- Consumes: task 1's seed mode, and `references/house-defaults.md`'s index, which is the library the
  report is computed against.
- Produces: the report clause 6 and 7 of task 5's rubric score.

**Depends on:** task 1

**Done when:** `tests/test-doc-claims.sh` reports **50 passed, 0 failed** and `tests/run-tests.sh`
is green with exit 0 and zero `FAIL` lines.

**The constraint that shapes this task: the report may not name its own worked example.** The
fixture task 4 builds is the Flutter case, because NFR-07 names it as the known true positive. Every
reference of an injected skill is staged into the arm, so a sentence in `seed.md` saying "a Flutter
application receives no UI-layer defaults" hands the arm the exact finding it is scored on
producing. That is the defect the previous plan's review found as finding 4, where `audit.md`
narrated its own fixture's split, and it is the reason that fixture was reseeded from 7 to 3 to 9 to
4.

**So `seed.md` states the mechanism and never the instance.** It says a predicate excluding the only
reference that covers a layer this project has is a gap in keel's library. It does not say which
predicate, which reference or which framework. The arm has to read the index, evaluate the predicate
against the profile, and notice that nothing else covers the layer. That inference is the whole of
what S-08 measures, and a check below pins the omission so it cannot leak back in later.

- [x] **Step 1: Write the failing checks**

Add to `tests/test-doc-claims.sh`, in the same place, after task 1's cases:

```bash
# NFR-08: the gap report is comparable between two runs the way references/assessment-report.md
# requires of assess. Fixed section order and a counting unit stated before any number. The five
# labels are compared in sequence rather than for presence, because an order that drifts makes two
# runs incomparable while every section is still there, and that is invisible to a presence check.
#
# This is the shape the audit report order case above uses. It is preferred to a file-wide grep
# for the five labels as a precaution, not as a response to a live collision: no label occurs
# twice in seed.md today with the same capitalisation, but these are ordinary words that recur
# in prose, and a file-wide grep would break the first time one of them did.
#
# It reads the gap report's own section, takes numbered lines and bulleted ones, and compares the
# numbers rather than discarding them. Each of those closes a way a sixth section could be added
# invisibly: a bulleted entry is not numbered at all, and renumbering the five to 1 2 3 7 4 leaves
# the labels in order and the check green while the document reads wrong.
want_gap_order='1 The stack
2 Applied
3 Did not apply
4 Not covered by any reference
5 Nothing to report'
got_gap_order="$(awk '/^## The gap report$/ {inside = 1; next}
                      inside && /^## / {exit}
                      inside && /^[0-9]+[.)] /
                      inside && /^[-*+] /' "$sd" \
                 | sed -E 's/^([0-9]+)\. \*\*([^*]+)\*\*.*/\1 \2/; s/[.,]$//')"
if [ "$got_gap_order" = "$want_gap_order" ]; then
    ok "seed.md fixes the gap report's five sections in order"
else
    bad "seed.md fixes the gap report's five sections in order" \
        "seed.md's gap report is not those five entries in that sequence. A missing section reads as an empty list here and fails, which is the intent"
fi

# FR-09 and the placement settled 2026-09-03. Three clauses: the unit is stated, the report goes in
# the reply, and it is addressed to keel rather than to the project. The third is the one that
# decides where it goes, so it is asserted rather than left implied by the second.
if printf '%s' "$sd_flat" | grep -q 'one house reference is one file the index lists' \
   && printf '%s' "$sd_flat" | grep -q 'in the reply' \
   && printf '%s' "$sd_flat" | grep -q "keel's gap rather than the project"; then
    ok "seed.md states the counting unit and puts the gap report in the reply, addressed to keel"
else
    bad "seed.md states the counting unit and puts the gap report in the reply, addressed to keel" \
        "one of FR-09's three clauses is missing: the counting unit before any number, the report going in the reply, or the finding belonging to keel rather than to the project"
fi

# The answer-leak guard, and the reason it is a case rather than a note.
#
# The fixture the arm runs against is the Flutter case, which is the known true positive NFR-07
# names. seed.md is staged into that arm whole. A worked example naming flutter or frontend.md would
# hand the arm the finding it is scored on producing, and the reply would look like a pass on a
# derivation that never happened. That is finding 4 of the previous plan's review, in the mode next
# door: references/audit.md narrated its own fixture's split and the fixture had to be reseeded.
#
# A comment saying "do not name it" is what audit.md had. This is the check.
if ! printf '%s' "$sd_flat" | grep -qi 'flutter' \
   && ! printf '%s' "$sd_flat" | grep -q 'frontend\.md'; then
    ok "seed.md states the gap mechanism without naming its own worked example"
else
    bad "seed.md states the gap mechanism without naming its own worked example" \
        "seed.md names flutter or frontend.md, which is the finding the staged arm is scored on producing"
fi
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-doc-claims.sh`
Expected: FAIL, two failures. The order case reports an empty string and the FR-09 case reports its
three missing clauses. **The leak guard passes already**, because task 1's file names neither term,
and that is correct: it is a guard against a future edit, not a description of work outstanding. Say
so in the step rather than treating a green third case as a defect in the test.

- [x] **Step 3: Add the gap report**

Insert into `skills/coding-standards/references/seed.md`, between "What seed writes" and "What seed
never does":

```markdown
## The gap report

`house-defaults.md`'s index is keel's own library, and a stack it does not reach is **keel's gap
rather than the project's**. Report it **in the reply**, not in the document and not in a file: the
audience is whoever maintains keel, and a note to them left inside somebody else's repository is
addressed to a reader who is not there. Sections 2 and 3 restate what the document's own
record already carries, deliberately and for a different reader: the document serves the project,
so satisfying the reply does not excuse leaving that record out.

**The counting unit, before any number:** one house reference is one file the index lists, and
each one is counted exactly once, as applied, as excluded, or as undecided.

**In this fixed order, every run, including the runs with nothing to report:**

1. **The stack**, as read from the profile: language, framework, and whether it has a user
   interface.
2. **Applied.** The references whose predicate held, by name.
3. **Did not apply.** By name, each marked as excluded or as undecided. An excluded entry
   names the predicate that excluded it and the decider that settled it. An undecided entry
   names the predicate nothing settled and names no decider, because an exclusion nothing
   decided is one seed invented. Every reference the index lists appears in section 2 or in
   this one.
4. **Not covered by any reference.** The finding. A layer this stack has that no listed reference
   reaches, named as a layer rather than as a file that ought to exist. A predicate that excludes
   the only reference covering a layer this project actually has is the shape to look for.
5. **Nothing to report**, in those words, where section 4 is empty. An absent gap report and an
   empty one read identically, and only one of them means the question was asked.

Do not invent a rule to fill a gap. The report is the output; a house default written to cover a
layer keel has no reference for is exactly the imposition seed's opening paragraph disclaims.
```

Then correct `docs/prd/coding-standards-audit-and-seed.md`, two edits:

- FR-09's row at `:223`, so the settled placement lives with the requirement. Replace the
  requirement cell with: "Seed reports which house references were missing for the stack it
  detected, **in its reply and not in a file**. The finding is addressed to keel's maintainers, not
  to the project, and a report written into the project's tree is addressed to the wrong reader."
  Append `, placement settled 2026-09-03` to that row's Source cell, which is the shape FR-03's row
  already uses for a correction.
- Line 60's citation, `references/house-defaults.md:27` to `references/house-defaults.md:31`. The
  four other copies are dated records and are deliberately left; the top of this plan says why.

Recompute the three figures and update the word count in the six documents again. The count is still
17 and the body still 795.

**The block above is the section as it landed, not as it was first written**, resynced from the tree
per decision 45. A dispatched review found one blocking defect in the plan's own text and it was
repaired inside this task:

- **Blocking.** The gap report was two-state, `Applied` and `Did not apply`, while task 1's repair
  had established three: applied, excluded with the thing that decided it, and undecided. That is
  not an edge case. Against the ten-row index for a project with a declared stack and no source, two
  rows are `Always` and apply, one is decidable from the profile, and **seven** ask about a running
  system a profile cannot settle, so an arm reaches the report holding seven references with nowhere
  to put them and only two exits, both forbidden: naming a predicate that excluded them is the
  invented finding `seed.md` forbids, and dropping them silently fails to account for seven of ten,
  which is the non-comparability NFR-08 exists to prevent. Section 3 now covers both, each entry
  marked, and the counting unit no longer asserts a binary. **The five section labels, their
  numbering and their order are unchanged**, so the order check and task 4's scenario text are
  untouched by the repair.
- **Should fix, applied with it.** Nothing said the reply's sections 2 and 3 deliberately overlap
  the record the document carries, and `standards-template.md` has no slot for that record at all,
  so an arm satisfying the reply and dropping the document's copy would have been behaving
  reasonably. One sentence now says the overlap is deliberate and for a different reader.

**Carried, not fixed.** The order check cannot see a sixth section added as a `###` sub-heading,
as a bold-lead paragraph, or as an indented sub-bullet. The comment claims only that each
mechanism it names closes one way, so it does not overclaim, but the bold-lead form is the one
this section already uses twice and is the likeliest way a later edit slips past.

**And named for tasks 4 and 5, which do not run in this batch.** The scenario's pass line, its fail
line and task 5's condition 5 are all written two-state, "the excluded ones are named with what
decided them". The mode and its report are now three-state. All three need the same treatment before
the arm runs, or a correct run is scored against a rubric that cannot describe it. **Done, in the
standalone commit that precedes task 4**, which corrected the three and settled where the record
sits in the document; this note records that they were two-state, not that they still are.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-doc-claims.sh`
Expected: `50 passed, 0 failed`.

Run: `tests/run-tests.sh`
Expected: green, exit 0, zero `FAIL` lines.

- [x] **Step 5: Hand over**

```bash
git add skills/coding-standards/references/seed.md tests/test-doc-claims.sh \
        docs/prd/coding-standards-audit-and-seed.md \
        docs/05-token-and-memory-design.md tests/validate-skills.sh docs/standards.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/leon-van-zyl-skill-collection.md docs/ideas/database-design-and-review.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -m "feat(coding-standards): seed reports the gaps in keel's library"`.

---

### Task 3: Neither new mode enforces anything, held as a check

**Story:** S-13, satisfying FR-21, NFR-03 and NFR-04

**Files:**
- Modify: `tests/test-doc-claims.sh`

**Interfaces:**
- Consumes: `references/audit.md` and `references/seed.md` as they stand after task 2, plus
  `hooks/hooks.json` and `.keel/profile.json`.
- Produces: nothing. This is a verify story, so the deliverable is a check on behaviour believed
  correct, and it becomes implementation work only if the check goes red.

**Depends on:** task 2

**Done when:** `tests/test-doc-claims.sh` reports **53 passed, 0 failed** and `tests/run-tests.sh`
is green with exit 0 and zero `FAIL` lines.

**This is a `verify` story and is planned as one.** The assumption in the PRD's section 12 is that
the new modes stay outside the open question at `docs/ideas/standards-that-bind.md:624`, "why does a
loaded rule not bind". They stay outside it by not enforcing anything at the point of work. That is
believed true today. Step 2 is where it is measured, and **a red result here is a finding about the
modes, not a broken test**: it would mean one of them acquired a hook, a gate or a read enforced
elsewhere while nobody was watching.

**Why none of these cases counts anything.** An assertion on the number of gate keys, hook entries
or profile properties goes red on every legitimate addition anywhere in the project, and the fix
each time is to retype a number nobody reads. The property S-13 protects is that **these two modes**
added nothing, and that is what is asserted. The same reasoning is written up at
`docs/ideas/repo-layout-omits-its-own-executable.md`, on the file count that went stale three times.

- [x] **Step 1: Write the checks**

Add to `tests/test-doc-claims.sh`, after task 2's cases:

```bash
# S-13, first scenario: no enforcement is added. Three places a mode could acquire it, and none of
# them counts anything, for the reason the plan gives: a count goes red on every unrelated addition.
# $au is already set to references/audit.md at the FR-07 case above, and $sd to references/seed.md
# by task 1's cases. Reused rather than redefined, which is what the FR-14 case above does with
# $as_flat: a second assignment of the same path is one more place for the two to drift apart.
#
# Both files are asserted to exist before the negated grep, and that is not defensive noise. `!
# grep -q` inverts grep's exit 2 on a missing file into a pass, so deleting references/seed.md would
# turn this case green while proving nothing. tests/test-doc-claims.sh:186-193 already guards the
# same shape for schema_s12 and says so; this is that guard.
if [ -f "$au" ] && [ -f "$sd" ] && ! /usr/bin/grep -qiE 'hook|gate' "$au" "$sd"; then
    ok "neither audit nor seed names a hook or a gate"
else
    bad "neither audit nor seed names a hook or a gate" \
        "$(/usr/bin/grep -niE 'hook|gate' "$au" "$sd" | head -3 | tr '\n' ' ')"
fi

# The registration side of the same question. A mode that names no hook but is wired into one is
# enforced anyway, and hooks/hooks.json is where wiring that ships to an installer lives, which is
# the property this story protects. It is not the only hooks block in the tree:
# .claude/settings.json:39-46 wires SessionStart to ./.claude/keel-nudge. That file is this
# repository's own development-time configuration, and this case deliberately does not read it.
if [ -f hooks/hooks.json ] && [ -f .keel/profile.json ] \
   && ! /usr/bin/grep -qE 'coding-standards|audit|seed' hooks/hooks.json \
   && ! /usr/bin/grep -qE '"(audit|seed)"[[:space:]]*:' .keel/profile.json; then
    ok "no hook is registered for the modes and no gate key names one"
else
    bad "no hook is registered for the modes and no gate key names one" \
        "hooks/hooks.json names one of the modes, or .keel/profile.json has grown a gate key for one"
fi

# S-13, third scenario: both modes run offline. Asserted as the clause each file carries rather than
# by scanning for a URL. No other check backs that up: the one rule in tests/supply-chain-scan.sh
# that matches a plain network command is net-in-script at line 66, whose scope is exec, and
# in_scope at lines 128-134 limits exec to bin, hooks, lib, tests and .github/workflows, or a file
# carrying the executable bit. Both mode files sit under skills/ and are not executable, so that
# scanner never reads them for a network command. What this case does is check that the promise is
# written down where a reader of the mode meets it.
# Flattened, and not optionally: audit.md wraps this very phrase across lines 39 and 40, as
# "Make a" then "network request.", so the line-oriented spelling of this case fails on a correct
# file. Measured against the tree while the plan was written, which is the only way it was going to
# be found. Both flattened copies are already in scope, $au_flat from the FR-07 case above and
# $sd_flat from task 1's cases, and are reused rather than re-flattened.
if printf '%s' "$au_flat" | grep -q 'Make a network request' \
   && printf '%s' "$sd_flat" | grep -q 'Make a network request'; then
    ok "audit and seed both state that they make no network request"
else
    bad "audit and seed both state that they make no network request" \
        "one of the two mode files has lost its no-network clause"
fi
```

- [x] **Step 2: Run it, and read the result as a finding either way**

Run: `tests/test-doc-claims.sh`
Expected: `53 passed, 0 failed`. **All three are expected to pass on the first run**, because this
is a verify story asserting behaviour believed correct, and that is the outcome that closes S-13.

**If any goes red, stop and report it.** Do not adjust the check to fit. A red first case means a
mode named a hook or a gate; a red second means one was wired in; a red third means a no-network
clause was dropped. Each is a real change to what the modes do and is a finding for the supervisor,
not a test to soften. Record which one, with the `grep` output that produced it.

- [x] **Step 3: Confirm the suite**

Run: `tests/run-tests.sh`
Expected: green, exit 0, zero `FAIL` lines. S-13's second scenario is this run: the delegation check
in `tests/validate-skills.sh`, `tests/test-doc-claims.sh` and shellcheck all still pass.

- [x] **Step 4: Hand over**

```bash
git add tests/test-doc-claims.sh
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after the review pass,
with `git commit -m "test(coding-standards): hold the no-enforcement assumption as a check"`.

**All three passed on the first run**, which is the outcome that closes S-13: no hook, no gate, no
registration, and both no-network clauses present. The block above is as it landed, resynced from
the tree per decision 45. A dispatched review mutated each side of each case against a scratch copy
of the repository, nine mutations in all, and every one went red, so none of the three passes
vacuously. Deleting either mode file, `hooks/hooks.json` or `.keel/profile.json` also fails rather
than inverting into a pass, which is what the `[ -f ]` guards are for.

Two claims in the plan's own comments were wrong about this repository and were corrected inside
this task, both of them the "asserted a mechanism nobody opened" shape:

- The third case said `tests/supply-chain-scan.sh` "already reads every file in the tree for network
  patterns", offered as the reason this case need not scan for a URL. The scanner does read every
  file, but its only rule matching a plain network command is `net-in-script` at `:66`, whose scope
  is `exec`, and `in_scope` at `:128-134` limits `exec` to `bin`, `hooks`, `lib`, `tests` and
  `.github/workflows`, or a file carrying the executable bit. Both mode files sit under `skills/`
  and are not executable, so nothing backs this case up and the comment now says so.
- The second case said "hooks.json is the only place that wiring can live". `.claude/settings.json`
  is tracked and carries a hooks block at `:39-46` wiring `SessionStart` to `./.claude/keel-nudge`.
  The comment now says `hooks/hooks.json` is where wiring that ships to an installer lives, which is
  the property S-13 protects, and that this case deliberately does not read the other one.

**Carried, not fixed**, because each would change what a check does rather than correct a falsehood:

- `hook|gate` carries no word boundaries, so `navigate`, `delegates` and `mitigate` all match, and
  appending "navigate the report" to `audit.md` turns the first case red on correct output. A
  bounded spelling would stop catching `hooked` and `gating`, one of which was a mutation that
  legitimately went red, so the trade is a design call.
- The third case proves the phrase is present, not that the promise binds. Moving the clause out
  from under "What audit never does" into a fabricated fetch-the-style-guide heading in both files
  left all 53 cases green. It catches accidental deletion during a re-wrap, which is the realistic
  failure, and nothing about a rewrite that keeps the words and reverses the sense.
- The second case's failure message misdiagnoses its own guard failures: delete `hooks/hooks.json`
  and it reports that the file names one of the modes. The first case avoids this by embedding live
  `grep` output, and the `schema_s12` precedent at `:186-193` avoids it with a separate existence
  case.
- `audit` and `seed` are broad substrings to grep `hooks/hooks.json` for, so a future unrelated
  `audit-log` hook would trip the case.

---

### Task 4: Seed's scenario and its fixture

**Story:** S-09, first half

**Files:**
- Create: `tests/evals/scenarios/seed-a-greenfield-mobile-app.md`
- Create: `tests/evals/fixtures/seed-a-greenfield-mobile-app/README.md`,
  `tests/evals/fixtures/seed-a-greenfield-mobile-app/.keel/profile.json`
- Modify: `tests/evals/fixtures/README.md`, `tests/test-eval-harness.sh`, `README.md`,
  `tests/evals/README.md`, `docs/06-repo-layout.md`,
  `docs/ideas/bodies-over-the-target-with-no-arm.md`

**Interfaces:**
- Consumes: seed as it stands after task 3.
- Produces: the staging task 5 dispatches.

**Depends on:** task 3

**Done when:** `tests/test-eval-harness.sh` reports **35 passed, 0 failed**,
`tests/test-doc-claims.sh` reports **53 passed, 0 failed** with the scenario count now 12, and
`tests/run-tests.sh` is green with exit 0.

**The fixture is two files, and the smallness is the point.** S-09 asks for an empty repository with
a profile and no source. A greenfield tree is what routes to seed at all, so a fixture with source in
it would route to audit and measure the wrong mode. Two files also make the verdict cheap: `diff -r`
against the fixture answers "created nothing else" and "edited nothing" in one command.

**The profile is the only thing that says what the stack is**, which is the whole of what seed has to
work from. It pins `docs_root` to `docs`, because `bin/keel:55` sets `DEFAULT_DOCS_ROOT="docs/keel"`
and every reference staged into an arm leaves `<docs_root>` an unexpanded placeholder: without it a
correct arm fails on a root it had no way to derive, which is a fixture defect rather than a result.
It carries no `gates` key, which would be a hint. That is case 30's lesson from the previous plan,
applied before it costs a dispatch rather than after. `project.kind` is `frontend`, because
`templates/profile.schema.json` requires the key and admits only `service`, `library`, `cli`,
`frontend`, `plugin` and `docs`: `app` is not one of them, and `docs` says outright that it means no
stack, which this profile contradicts. It leaks nothing the profile does not already say, `has_ui`
being true beside it, and the word is saturated in the staged references anyway.

- [x] **Step 1: Write the failing fixture guard**

Add to `tests/test-eval-harness.sh`, immediately before the final `printf` of the totals:

```bash
# 31. seed-a-greenfield-mobile-app's fixture is a stack with no code, and its profile is the only
# thing that says which stack.
#
# Three properties, each of which silently invalidates the scenario if it goes:
#
# A source file appearing anywhere in the fixture routes Step 0 to audit instead of seed, and the
# arm would be measured on the wrong mode while every other check stayed green.
#
# The framework and has_ui pair is what makes this the known true positive NFR-07 names. Without
# both, the gap report has nothing to find and the scenario measures only that seed writes a file.
#
# docs_root and the absent gates key are case 30's lesson: the arm has to derive docs/standards.md
# from the profile, and a gates key would be a hint at enforcement the modes deliberately lack.
# `src_files` and not `src`: cases 23 and 25 above already read a loop variable called src, and a
# name reused for two things in one script is how the next edit to either goes wrong.
# The directory is tested before find runs, so the pre-fixture failure says "the fixture does not
# exist" rather than printing a find error to stderr and reporting zero source files.
# The README is tested by name because the source count excludes it by basename: without this line
# deleting the README leaves the case green, and the arm then has nothing routing it to a greenfield
# app while every other check still passes.
fx2="tests/evals/fixtures/seed-a-greenfield-mobile-app"
prof2="$fx2/.keel/profile.json"
src_files=""
[ -d "$fx2" ] && src_files="$(find "$fx2" -type f ! -name 'README.md' ! -name 'profile.json' | wc -l | tr -d ' ')"
if [ -d "$fx2" ] && [ -f "$prof2" ] && [ -f "$fx2/README.md" ] \
   && /usr/bin/grep -q '"docs_root": "docs"' "$prof2" \
   && /usr/bin/grep -q '"framework": "flutter"' "$prof2" \
   && /usr/bin/grep -q '"has_ui": true' "$prof2" \
   && ! /usr/bin/grep -q 'gates' "$prof2" \
   && [ "$src_files" = "0" ]; then
    ok "seed-a-greenfield-mobile-app ships a stack and no code"
else
    bad "seed-a-greenfield-mobile-app ships a stack and no code" \
        "fixture, profile or README missing, profile not pinning docs_root to docs, not naming flutter with has_ui true, carrying a gates key, or the fixture has grown a file named neither README.md nor profile.json (found '$src_files', wanted 0)"
fi
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-eval-harness.sh`
Expected: FAIL, `fixture or profile missing, ...`, because the fixture does not exist yet. The
directory test runs before `find`, so the failure names the missing fixture rather than reporting
zero source files in a tree that is not there.

- [x] **Step 3: Build the fixture, the scenario and the three counts, in one edit with no suite running**

Create `tests/evals/fixtures/seed-a-greenfield-mobile-app/.keel/profile.json`:

```json
{
  "project": { "name": "kirabo", "kind": "frontend" },
  "stack": { "language": "dart", "runtime": "dart", "framework": "flutter", "package_manager": "pub", "datastores": [], "has_ui": true },
  "verify": { "test": null, "lint": null, "build": null },
  "docs_root": "docs"
}
```

Create `tests/evals/fixtures/seed-a-greenfield-mobile-app/README.md`, one paragraph naming what the
app will be, with **no conventions stated, no mention of standards, and nothing about which
references keel does or does not have**. A README that names the gap hands the arm the finding, the
same way task 2's leak guard exists to stop the reference doing it.

**No `pubspec.yaml` and no `lib/`.** A manifest is arguable as code and the routing fact has to be
unambiguous: the two files above are the fixture.

**No `setup.sh`**, so the staged project is deliberately not a git repository, and task 5 verifies
with `diff -r` rather than `git status`.

**Three cautions, because the whole suite runs over the fixture.** `tests/supply-chain-scan.sh`
reads every file in the tree, so no file may make a network call, carry a shebang or be executable.
`.gitignore:27-28` ignores `__pycache__/` and `*.pyc` and the fixture carve-out at `:20` covers
`*.log` only, so leave no build output behind. Nothing binds a port, so L-01 of
`docs/audits/2026-09-02-security.md` gains no second instance.

Create `tests/evals/scenarios/seed-a-greenfield-mobile-app.md`:

```markdown
# seed a standards document for a project with no code yet

Inject: coding-standards

**Tests:** whether seed writes a starting document that says where it came from, and whether the
library-gap report is produced against a stack the house references do not fully reach.

**Baseline, no skill:** not recorded. This is a treatment-only measurement of a new mode.

**What the arm can see.** An injected skill's references are staged beside the working directory, so
`references/seed.md`, `references/house-defaults.md` and `references/standards-template.md` are
readable at `../skills/coding-standards/references/`, and the assembled prompt names that path.
Step 0 links the mode. Whether the arm opened any of them is observable in the tool calls under
`--output-format stream-json`, and the reply's prose is not evidence that it did. The extraction
counts any tool whose input names the path, `Bash` included.

**The fixture is two files.** A profile and a README, no source of any kind. The profile is the only
statement of what the stack is: a Dart and Flutter application with a user interface. Nothing in the
fixture names a house reference, a gap, or anything about standards.

**What the arm has to work out for itself.** The index in `house-defaults.md` gives each topic
reference a predicate. One of those predicates excludes the only reference covering the user
interface layer for exactly this framework, and no other reference covers that layer. `seed.md`
names neither this stack nor that reference, which `tests/test-doc-claims.sh` pins, so the mode text
hands over nothing. The index names both, because the predicate is what the arm has to apply and
applying it is the measurement.

**Passes if the reply:** enters seed without being told the word "seed", and does not attempt to
derive conventions from a codebase that does not exist; writes `docs/standards.md` and creates
nothing else; leaves both fixture files byte identical; states in that document's header that it was
seeded from the house defaults and not derived from code; folds in only the topic references whose
index predicate holds, and lands every topic reference in exactly one of three states, applied, or
excluded naming the predicate and the decider that settled it, or undecided naming the predicate and
saying no decider settled it, at least one of those exclusions naming as its decider a value the
profile states outright, and leaving undecided no predicate such a value settles; gives the gap
report in the reply, in the five sections in the order the stack, applied, did not apply, not
covered by any reference, nothing to report, with the counting unit stated before any number; names
the user interface layer as covered by no house reference for this stack, as a gap in keel's library
rather than a fault in the project; and keeps the gap report out of `docs/standards.md`.

**Fails if the reply:** writes no document, or writes it anywhere other than `docs/standards.md`;
creates or edits any other file; omits the provenance sentence; folds in every topic reference
without evaluating the predicates, or names no excluded reference, or names no exclusion whose
decider is a value the profile states outright, or leaves undecided a predicate such a value
settles, or leaves a topic reference in none of the three states, or marks one excluded or undecided
without naming its predicate, or marks one excluded without naming the decider that settled it, or
marks one undecided while naming a decider, an exclusion nothing decided being a finding seed
invented; omits the gap report, or gives its sections in another order, or gives a number before
stating the unit; reports no uncovered layer for this stack; puts the gap report into the project's
standards document; or invents a house rule to fill the gap instead of reporting it.

**Declared means stated outright**, for both lines above. `seed.md` names `unknown`, `none` and
false as fallbacks, and its governing sentence is that a detected nothing is not a decided no, which
covers an empty list too: so a reference left undecided on `datastores` alone is not scored against
either clause.

**Ambiguity is a fail.** A verdict needing a judgement the paragraphs above do not settle is
recorded as a fail with the reason, not argued into a pass.

## Prompt

We are starting a new mobile app and nobody has written any code yet, there is just the repo and a
readme. Can you put together the coding standards we should be working to before anyone starts?
```

Record what the fixture seeds in `tests/evals/fixtures/README.md`, in the shape the
`audit-a-brownfield-tree` entry uses, **including a "Deliberately not said" row** naming the two
things the fixture withholds: any mention of standards, and anything about which references keel has.
That file is never staged.

Then the three scenario counts, all in this same edit:

- `README.md:289`, `11 scenarios exist` to `12 scenarios exist`.
- `tests/evals/README.md:122`, `Eleven scenarios exist` to `Twelve scenarios exist`.
- `docs/06-repo-layout.md:177`, `# 11 scenarios, 11 fixtures` to `# 12 scenarios, 12 fixtures`.

The first and third are asserted by `tests/test-doc-claims.sh` and recompute from the tree. The
second carries no digit and is asserted by nothing, which is why it is named here.

**And a fourth, found by the review rather than planned.** `docs/ideas/bodies-over-the-target-with-no-arm.md`
counts the scenarios that inject a skill: "Ten of the eleven scenarios carry an `Inject:` line, and
between them they name `coding-standards` (three times)". This task makes that eleven of twelve and
four times. Nothing asserts it, which is why nothing caught it. Its load-bearing claim is untouched,
`write-plan` still being injected by no scenario, so this corrects two figures and settles no
carried question. It is here because a change lands with the documents it makes wrong.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-eval-harness.sh`
Expected: `35 passed, 0 failed`, including case 4's two assertions over the new staging: the
scenario's own criteria are not staged, and nothing staged names `tests/evals`.

Run: `tests/test-doc-claims.sh`
Expected: `53 passed, 0 failed`, with the scenario count now 12.

Run: `tests/run-tests.sh`
Expected: green, exit 0, zero `FAIL` lines.

- [x] **Step 5: Hand over**

```bash
git add tests/evals/scenarios/seed-a-greenfield-mobile-app.md \
        tests/evals/fixtures/seed-a-greenfield-mobile-app tests/evals/fixtures/README.md \
        tests/test-eval-harness.sh README.md tests/evals/README.md docs/06-repo-layout.md \
        docs/ideas/bodies-over-the-target-with-no-arm.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -m "test(evals): a greenfield scenario for seed mode"`.

---

### Task 5: Run seed's arm, and stop

**Story:** S-09, second half, satisfying NFR-05 for seed

**Files:**
- Modify: `tests/evals/results.md`

**Interfaces:**
- Consumes: task 4's scenario, and seed as tasks 1 to 3 left it.
- Produces: the recorded result that says whether seed ships.

**Depends on:** task 4

**Done when:** `tests/run-tests.sh` is green with exit 0 and
`/usr/bin/grep -c 'seed mode, the first recorded run' tests/evals/results.md` returns 1 or more.

**The pass and fail conditions, fixed here and not after the output is read.**

Eight conditions, matching the scenario's own clauses one for one. The plan and the rubric score the
same things or one of them is wrong, and the previous round's review found that mismatch by reading
them side by side.

Passes if, and only if, all eight hold:

1. The arm entered seed without being told the word, and did not try to derive conventions from a
   codebase that does not exist.
2. It wrote `docs/standards.md` and created nothing else.
3. Both fixture files are byte identical afterwards.
4. That document's header states it was seeded from the house defaults and not derived from code.
5. Only the topic references whose index predicate holds are folded in, and every topic reference
   lands in exactly one of three states: applied, or excluded naming the predicate and the decider
   that settled it, or undecided naming the predicate and saying no decider settled it. At least one
   reference is excluded with a value declared in `.keel/profile.json` named as its decider.
   Exclusions the request settled are correct and expected, seed.md naming both deciders, but they
   do not satisfy that clause on their own: a run naming no profile-decided exclusion, or leaving
   undecided a predicate a declared value settles, evaluated no predicate against the profile and is
   not a pass. Declared means stated outright: `seed.md` names `unknown`, `none` and false as
   fallbacks, and its governing sentence that a detected nothing is not a decided no covers an
   empty list too, so a reference left undecided on `datastores` alone is not scored against this
   clause. An exclusion
   nothing decided is a finding seed invented, and the run fails this condition rather than
   satisfying it.
6. The gap report is in the reply, in the five sections in the fixed order, with the counting unit
   stated before any number.
7. The gap report names the user interface layer as covered by no house reference for this stack,
   and attributes the gap to keel's library rather than to the project.
8. The gap report is not in `docs/standards.md`.

**Where in the document the three-state record condition 5 requires sits is not scored:**
`standards-template.md` has no section for it, so a heading the arm invents to carry it is not a
fail under any of the eight, and Step 2's grep hitting that heading is one of the hits it tells you
to judge and record rather than a condition 8 failure.

**Conditions 5 and 7 are the two that matter most**, because they are the two that cannot be
satisfied by writing a plausible document. Everything else is a shape an arm can produce from Step 0
and the template; those two require it to have read the index and evaluated a predicate against a
profile.

**Fails if any of the eight is absent.**

**A fail is a legitimate outcome of this task and is not a problem to route around.**
`docs/stories/coding-standards-audit-and-seed.md:498` names what follows: S-09 and seed drop, audit
is unaffected and ships alone, which is section 5.4's named fallback. Concretely, on a fail: do not
re-run for a better result, do not add a stronger pointer to `seed.md`, do not soften a condition,
and do not reword the scenario. Record the fail with its evidence, report it, and stop. Deleting
seed and dropping Step 0's fourth cell is a separate decision for the supervisor, not part of this
task.

- [x] **Step 1: Stage and dispatch**

First confirm the prompt, before anything is spent:

```bash
tests/evals/run.sh seed-a-greenfield-mobile-app | /usr/bin/grep -c '\.\./skills/coding-standards/references/'
tests/evals/run.sh seed-a-greenfield-mobile-app | /usr/bin/grep -c 'Passes if the reply'
```

Expected: `1` and `0`. The arm can reach the references and cannot read the criteria it is scored on.

```bash
dir=$(tests/evals/stage.sh seed-a-greenfield-mobile-app 2>/dev/null)
cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format stream-json --verbose \
    > "$dir/result.jsonl"
```

Every flag there is load bearing and `tests/evals/README.md:40-59` says why. `--output-format
stream-json --verbose` rather than `json`, because conditions 1 and 5 turn on which files were
opened and a reply cannot settle that.

- [x] **Step 2: Extract, with the command recorded**

Which references were opened, and by which tool:

```bash
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")
       | [.name, (.input.command // (.input|tostring))] | @tsv' "$dir/result.jsonl" \
  | /usr/bin/grep 'skills/coding-standards'
```

**Count any tool whose input names the path, `Bash` included.** Every arm run so far used `Bash` and
none used `Read`; a discriminator scanning for `Read` reports nothing on a run that opened seven
files, which has happened twice and been corrected twice.

The tree, verified against the fixture rather than by `git status`, because **the staged project is
not a git repository**: `tests/evals/stage.sh` builds one only where the fixture carries a
`setup.sh`, and this one deliberately does not.

```bash
diff -r tests/evals/fixtures/seed-a-greenfield-mobile-app "$dir/project"
find "$dir/project/docs" -type f
```

Expected: `diff -r` prints exactly `Only in $dir/project: docs` and nothing else, which answers both
conditions 2 and 3; `find` prints exactly one path, the absolute staged one ending
`/project/docs/standards.md`. Record the output as it came, absolute path and all: the results entry
carries these commands and what they printed, and rewriting the path to a tidy relative one makes
the record something nobody can reproduce.

The reply, for conditions 6, 7 and 8:

```bash
jq -r 'select(.type=="result") | .result' "$dir/result.jsonl"
```

Condition 8 is checked against the written document, not the reply. **One literal is not enough
here**, and the rubric says so: `seed.md` requires the document itself to name the excluded
references and what decided them, so a document can carry the whole gap report under different
wording and score zero on a single-phrase grep. Match the report's own five labels, which is what
the scenario clause actually forbids appearing there:

```bash
/usr/bin/grep -ciE 'not covered by any reference|nothing to report|did not apply' \
    "$dir/project/docs/standards.md"
```

Expected: `0`. **A non-zero result is not automatically a fail**: read the lines it returns. The
document is required to say which references did not apply and what decided them, and the phrase
"did not apply" is a natural way to write that. Condition 8 is about the gap report as a report,
addressed to keel, appearing in the project's document. Judge the hits, and record which and why,
rather than reading the count alone.

- [x] **Step 3: Record it**

Append to `tests/evals/results.md` under `## 2026-09-03, seed mode, the first recorded run`,
carrying: which references were opened and by which tool, the eight conditions each answered yes or
no, the body word count at the time, the model, turns, duration and cost from the run's own `result`
record, and **every extraction command above, verbatim**, per the rule at `tests/evals/results.md:6`.
Identify the stream by its own `result` record rather than by which directory it sat in.

State what the arm proved and what it did not, in the same paragraph and with the same weight.

It proves seed is followed from behind a link on one run, against one stack. It does not prove the
empty case: this fixture is the known true positive, so section 5 of the gap report, "nothing to
report", is never exercised by it.

**And it proves less about conditions 5 and 7 than a clean pass reads as.** Section 4 of the gap
report tells the arm that a predicate excluding the only reference covering a layer the project has
is the shape to look for. Exactly one row of the index names a framework and exactly one reference
is layer-shaped, so once the arm reads that table the pointer leaves a single candidate. The
derivation is real, and it is shorter than "worked it out from the profile and the index" suggests.
Record it, rather than leaving the next reader to find the pointer and discount the whole result.

- [x] **Step 4: Confirm the suite, and stop**

Run: `tests/run-tests.sh`
Expected: green, exit 0, zero `FAIL` lines.

**Then stop.** Epic C is complete or it is dropped, and either way what follows is a decision rather
than a task. Do not start epic D or E.

- [x] **Step 5: Hand over**

```bash
git add tests/evals/results.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after the review pass,
with `git commit -m "test(evals): exercise seed mode for the first time"`.

Report the verdict as eight of eight, or as the count that held with the failing conditions named
and their evidence.

---

## Story coverage

| Story | Tasks | Requirements |
|---|---|---|
| S-07 | 1 | FR-08, FR-10, FR-11 |
| S-08 | 2 | FR-09, NFR-07, NFR-08 |
| S-13 | 3 | FR-21, NFR-03, NFR-04 |
| S-09 | 4, 5 | NFR-05 (seed) |

Four stories, four covered. **Epic C is S-07, S-08 and S-09 and all three are here.** S-13 could not
be planned earlier because it depends on S-04 and S-07, and S-07 is epic C.

**Not in scope, and not orphaned:** S-10, S-11 and S-12 are epics D and E, they are independent of
everything here, and `docs/stories/coding-standards-audit-and-seed.md:500-502` says they proceed
whatever the arms say.

## What this plan does not settle

- **Whether a release-gate arm discharges an ADR-0001 length obligation.** Carried, not solved. See
  the top of this plan and `docs/ideas/bodies-over-the-target-with-no-arm.md`.
- **`write-plan` at 897 words with no arm at any length.** Carried, not solved. No scenario injects
  it, so covering it means writing one, which is not this plan's work.
- **The gap report's empty branch is never measured.** The fixture is the known true positive NFR-07
  requires, so section 5 of the report, "nothing to report", is asserted by a doc-claims case and by
  no arm. Measuring it would need a second fixture and a second dispatch, and S-08's second scenario
  is the place that decision belongs.
- **Whether seed ships at all.** Task 5 decides it. A fail drops seed and audit ships alone, and
  that is a legitimate outcome rather than a problem to design around.
- **The push question.** The branch is unpushed and that decision is with Bernard. Task 1 removes
  the stub that made shipping unsafe, which changes the answer's constraints and not the answer.
