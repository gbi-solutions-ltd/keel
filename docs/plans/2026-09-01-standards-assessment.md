# Standards assessment mode Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `coding-standards` gains a second mode that assesses an existing `standards.md` against the
tree and writes a dated report, without ever editing the document it is checking.

**Requirements:** `docs/prd/standards-assessment.md`, FR-01 to FR-28 and NFR-01 to NFR-08. There is
no story set for this PRD. `write-user-stories` was skipped by instruction, so tasks trace to
requirement IDs rather than story IDs.

**ADRs:** ADR-0001 (`docs/decisions/ADR-0001-skill-body-word-ceiling.md:48-51`) requires a passing
eval arm recorded in `tests/evals/results.md` for any body over 700 words. This plan takes
`coding-standards` from 683 to 876, so task 6 exists and is not optional.

**Architecture:** one new step in `skills/coding-standards/SKILL.md` between the Core principle and
Step 1, branching author against assess. One new reference file holding the report format, because
references are unbounded and the body is not. One router row reworded. Four documentation surfaces
updated. One new eval fixture and scenario, because no existing fixture carries a `standards.md`,
and one recorded arm. No new skill, no new directory in `bin/keel`, no change to the SessionStart
roster.

## Progress

Updated as each task lands. A tick here means its `Done when:` command was run and its output read.

| Task | | Landed |
|---|---|---|
| 1 | The report format reference file | [x] |
| 2 | The mode branch and the description clause | [x] |
| 3 | The router row and the four documentation surfaces | [x] |
| 4 | The eval fixture and its scenario | [x] |
| 5 | ~~The scenario file and the count claim it moves~~ **absorbed into task 4** |
| 6 | Run the ADR-0001 arm and record it | [x] |

**All six tasks landed on 2026-09-01, and the route there was not the one planned.** After task 1,
tasks 4, 5 and 6 were deferred on a content review that found five blocking defects in them. Task 4
was then redesigned, built and executed before it was written down, and resumed; task 5 was absorbed
into it, because `tests/evals/stage.sh` resolves a scenario before it copies a fixture and task 4's
own harness case stages the fixture; task 6 followed once task 4 gave it what it needed.

The deferral notes below are kept rather than deleted, because the review that produced them is what
version 2 of task 4 was built from. Read them as history. "Why the eval work was split out" at the
end of this document is the reasoning; the split it describes was later closed.

**Concurrent batches:** none. Tasks 1 and 4 both say `Depends on: none` and name disjoint files, but
task 4 creates a fixture whose content is chosen to exercise the report format task 1 defines, so
running them together risks two people inventing two vocabularies. Run 1 then 4.

## Global constraints

Copied in full rather than linked. A task executed by a fresh agent that reads only its own section
must still obey these.

- **Verify commands, from `.keel/profile.json`:** test `tests/run-tests.sh`, one test
  `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  There is no typecheck, format, build or e2e command in this project.
- **`shellcheck` is not installed locally.** `tests/run-tests.sh` prints `SKIP` for the lint step and
  continues. That is expected and is not a failure. CI runs it.
- **Never start on `main`.** This work is on branch `sandbox`.
- **No em dash, no en dash, no dash longer than a hyphen**, in any file this plan touches, including
  fixtures. Enforced by `tests/validate-skills.sh:170-171` for shipped skill content.
- **No project-specific identifier may appear in any file.** `tests/no-internal-leaks.sh` fails the
  suite on one. The worked instance is called `payments-api` and no real client name is ever written.
- **Skill content names the docs root as `<docs_root>`, never a literal `docs/keel/...` path.**
  `tests/validate-skills.sh:161-168` reports `hardcodes a docs/keel path. Use <docs_root>`.
- **Every task ends with `tests/run-tests.sh` green**, meaning `All test files passed`. Warnings from
  `tests/validate-skills.sh` are not failures; the suite prints `OK` with a warning count.
- **Do not commit.** Each task stages its named paths and stops. The coordinator commits after
  review.

### A note on the test cycle in this repository

Most tasks here change documentation and skill content, not code. This repository's tests are
assertions about the tree, so for several tasks there is no test that can be made to go red before
the change without leaving the suite red between tasks, which this plan forbids. Where that is the
case the task says so explicitly in step 1 and names the assertion that would catch the change being
made wrongly. Task 4's step 8 has a genuine red-green cycle and uses it. Do not invent a test to fill the
shape; an honest gap reads as a gap, an invented test reads as coverage.

### Decisions this plan settles, because the PRD leaves them to the implementer

An engineer must not have to choose any of these. They are fixed here.

| Question the PRD leaves open | Settled as |
|---|---|
| FR-02: the exact assess phrasing in the router | `does the code still follow our standards` |
| FR-08: the counting unit for a house rule | One H2 section of a topic reference that states a rule, excluding trailing checklist sections. Settled at `docs/ideas/standards-that-bind.md:81-86` |
| FR-15: how six to eight rules are chosen | The first rule of each judgement section, in document order, up to eight. More than eight sections, take the first eight. Fewer than eight, take every rule until eight or none are left. Six is a target, not a floor a short document can be made to meet. A judgement rule is one `**Rule:**` entry, or the section itself where a section states one rule |
| FR-24: how a prior report is found and its items matched | The prior report is the highest-sorting `<docs_root>/audits/*-standards.md` by filename. Items match on the identifier the assessed `standards.md` itself uses (F-number, D-number, or the reference filename for check 1) |
| NFR-08: what "measurably drifts" means for the fixture | Task 4 specifies the exact files and the exact drift |

**One PRD number is corrected here, by measurement.** `docs/prd/standards-assessment.md:178` costs
the mode at 150 body words landing at 833. That was measured against a draft carrying only the mode
table and the four check names. It does not carry FR-03, FR-04 and FR-05, the three mode-selection
branches, nor NFR-04's one-line link to the reference. With those in, the block measures **173
words** and the body lands at **876**, still 44 under the 900 ceiling. Per-check discipline was
moved into the reference file rather than the body, which is what ADR-0001 advises and what keeps
the number this low. Task 2 verifies 876 by measurement, and task 6 records the arm at that length.

---

### Task 1: The report format reference file

**Requirements:** NFR-04, NFR-05, NFR-06, NFR-07, and the reporting half of FR-07 to FR-25:
FR-07, FR-08, FR-09, FR-10, FR-11, FR-12, FR-13, FR-14, FR-15, FR-16, FR-17, FR-18, FR-19, FR-20,
FR-21, FR-22, FR-24 and FR-25. The template is where each of those becomes an observable line in a
document, which is the only place most of them can be checked.

**Files:**
- Create: `skills/coding-standards/references/assessment-report.md`

**Interfaces:**
- Produces: the file `skills/coding-standards/references/assessment-report.md`. Task 2 links to it
  from `skills/coding-standards/SKILL.md` as a relative markdown link whose text and target are both
  the string `references/assessment-report.md`; the exact link is written out in task 2 step 3.
  `tests/validate-skills.sh:148-153` fails if that path does not resolve, so the filename is fixed
  here and must not be changed later.
- Consumes: nothing.

**Depends on:** none

**Done when:** `tests/run-tests.sh` prints `All test files passed`.

- [x] **Step 1: There is no test that goes red first**

Creating a new reference file breaks nothing, so no assertion can be made to fail beforehand. The
assertions that would catch getting this wrong are three, and step 4 runs them:
`tests/validate-skills.sh:161-168` rejects a hardcoded `docs/keel/` path in any shipped file,
`:170-171` rejects an em dash, and task 2's link check at `:148-153` rejects the file being at a
different path than the body links to.

Record the current state so step 4 has something to compare against:

```bash
ls skills/coding-standards/references/ | wc -l
```

Expected: `12`.

- [x] **Step 2: Write the file**

Create `skills/coding-standards/references/assessment-report.md` with exactly this content:

````markdown
# Assessment report template

The structure of `<docs_root>/audits/YYYY-MM-DD-standards.md`, written by `coding-standards` in
assess mode. Nothing in an assessment modifies what is being assessed, and `standards.md` is never
edited. The mode makes no network request and runs no command that changes the project. **A probe
that needed a change in order to run was not run**: it belongs under "Not covered" by its real name
rather than in the findings. Probe, not check: all four checks run every time, and it is an
individual probe inside one of them that gets dropped. Without that clause the sentence before it is
unenforceable, because a probe can be made to pass and then honestly reported as passing.

Two runs against the same repository must be comparable without re-reading either tree, so the
section order, the counts and the vocabulary below are fixed rather than suggested.

## Header

```markdown
# Standards assessment: <repo or service name>

| | |
|---|---|
| Commit | `<sha>` on branch `<branch>` |
| Document | `<docs_root>/standards.md`, <N> lines, derived at `<sha>` on YYYY-MM-DD |
| Commits since derivation | <N>, <M> files changed |
| Date | YYYY-MM-DD |
| Findings | coverage <n>, backlog <n>, sample <n>, departures <n> |
| Not covered | Named explicitly. See the last section |
```

`Commits since derivation` earns its row because it is the single number that predicts how much of
the document is stale, and it costs one `git rev-list --count` and one `git diff --stat`.

Each of the four `Findings` counts is defined, so that two reports mean the same thing by them.
**Coverage** is rules in the `Omitted` column, plus each reference skipped whole counted once more.
**Backlog** is items not `closed`. **Sample** is rules whose verdict is not `observed`.
**Departures** is rows in `needs an ADR`, `stale reason` or `unclassifiable`, which is what the
`A finding?` column of check 4's category table marks yes.

## Section order, fixed

1. Summary, three sentences and the counts
2. Check 1, house-defaults coverage
3. Check 2, the follow-up backlog
4. Check 3, the judgement sample
5. Check 4, the departures ledger
6. Trend, where a previous assessment exists
7. Not covered, explicit

That is the ranked order, cheapest and highest-yield first. All four checks run every time, so
report every one even where it found nothing. A check that comes back clean is a result, and a
reader who cannot see that it ran cannot tell it from a check that was skipped.

## Check 1, house-defaults coverage

State the counting unit before any number. Without it two runs produce different denominators from
the same corpus and nothing is comparable.

**The unit:** one house rule is one H2 section of a topic reference, excluding any trailing
checklist heading. Three names are in use, `Testing it`, `What review looks for` and `What good
looks like`, and no file carries all three, so exclude by name rather than subtracting a fixed
number. Count every other H2, with no judgement about whether it reads like a rule, because that
judgement is what makes a denominator irreproducible.

```markdown
| Reference | Applies | Decided by | Rules | Folded | Adapted | Departed | Omitted | Skipped whole |
|---|---|---|---|---|---|---|---|---|
| `observability.md` | yes | Always, per the index | 8 | 5 | 1 | 0 | 2 | no |
| `resilience.md` | yes | Calls a partner API over HTTP | 6 | 0 | 0 | 0 | 6 | **yes** |
| `frontend.md` | no | `profile.stack.has_ui` is false | 4 | n/a | n/a | n/a | n/a | n/a |
```

**`Folded` plus `Adapted` plus `Departed` plus `Omitted` must equal `Rules`** on every applicable
row. A row that does not add up is a check that lost track of its own corpus, and the header's
coverage count is derived from the `Omitted` column, so an unbalanced row makes that count
meaningless.

The four dispositions:

| Disposition | Means |
|---|---|
| `Folded` | The rule appears in `standards.md`, substantially as written |
| `Adapted` | It appears, changed to fit this project, and the change is visible |
| `Departed` | It does not apply here and a departure row says so, with a reason |
| `Omitted` | It appears nowhere, and no departure row accounts for it. **This is the coverage failure** |

**One row per reference the index lists, all ten**, including the ones that do not apply. A report
that lists only the applicable ones cannot be compared against a run that judged applicability
differently. `Decided by` is required on every row, applicable or not: nine of the ten index rows
are prose predicates rather than profile fields, so without the deciding fact a second run can reach
a different verdict and nobody can see why.

A reference whose every rule is `Omitted` is also **skipped whole**, and is reported as such. It is
a different finding from a scatter of omissions: an omitted rule may have been considered and
dropped, a skipped reference was never opened.

## Check 2, the follow-up backlog

**What counts as an item.** Any row or bullet in `standards.md` naming work not yet done, whatever
the document calls it: a "Not yet mechanical" list, a follow-up table, or a known inconsistency.
`skills/coding-standards/references/standards-template.md` prescribes no numbering, so where the
document numbers its items use its numbers, and where it does not, identify each by its first clause
and **say so in the report**, because the trend section then has no stable key to match on.

Every item gets exactly one of three states.

| State | Means |
|---|---|
| `closed` | The item's full scope is satisfied in the tree at HEAD |
| `partially covered` | Some of it is. The row names what is not |
| `open` | None of it is |

```markdown
| Item | Document says | Tree at HEAD says | State |
|---|---|---|---|
| F-1 | done | The fix covered `src/*.ts`, 100 files. `test/` and one `.sql` file still carry the pattern, and the lint rule the item also asked for was never added | partially covered |
```

**Establish state from the tree, never from a commit message.** A fix's stated scope and its actual
scope differ often enough that the difference is the finding. Where an item asked for both a fix and
a mechanism, report the two separately: a fix shipped without its mechanism regresses silently, and
a row that says only "done" hides that.

## Check 3, the judgement sample

The only check that *samples* project source, and it reads it only for the rules it sampled. Check 4
may also open source, but only to re-verify a basis one of its rows actually asserts, which is a
narrower allowance than this one.

**The unit.** A judgement rule is one `**Rule:**` entry where the document marks them that way, and
the section itself where a section states a single rule. Say which of the two shapes the document
uses, because they give different denominators. `standards-template.md` permits both.

**Choosing the sample, deterministically, because two runs must pick the same rules.** Where the
document has **eight or more** judgement sections, take the first rule of each of the first eight,
in document order, and take nothing else. Where it has **fewer than eight**, take every rule it
holds, in document order, until you reach eight or run out. The two branches do not overlap, so
there is exactly one reading for any document. **Name the sections you did not
reach**, and where the document holds fewer than six rules in total, sample all of them and say how
many existed: six is a target, not a floor a short document can be made to meet.

| Verdict | Means |
|---|---|
| `observed` | Every site conforms |
| `near-fully observed` | Isolated exceptions, each named |
| `drifting` | A pattern of exceptions, or one on a path that matters |
| `not observed` | The rule describes something the code does not do |

```markdown
**Pre-derivation proportion:** 303 of 388 files (78%) predate the commit the document was derived
from, so this sample substantially measures the corpus the rules were read off rather than
adherence to them.

**Sampled:** the first rule of sections 1 to 8, of 20. **Not reached:** sections 9 to 20.

| Rule | Location of the exception | Verdict | Ratio | Reachable |
|---|---|---|---|---|
| Money quantisation (`standards.md:694`) | `product-repository.service.ts:684,690` | drifting | 8 of 9 conforming | yes, settlement path |
| `sql.raw` allowlist (`standards.md:663`) | `partition.service.ts:356,367` | near-fully observed | 29 of 32 conforming | no, cron-driven only |
```

`Ratio` is always conforming-to-total in the same form, so two runs can be compared. `Location` is
the offending file and line, never the rule's own line, because a finding a reader cannot navigate
to is a finding nobody acts on.

Two rules keep this check honest:

- **A match count is not a finding.** Open every imprecise match before reporting it, and report
  only what you opened. In one assessment all seven apparent leaks were conforming once read, and a
  sweep that reported the count would have filed seven false findings.
- **State reachability, and do not exceed it.** A rule violated only on a path nothing can reach is
  a style deviation, not a vulnerability. Writing it up as one costs the whole report its
  credibility.

## Check 4, the departures ledger

Every departure lands in exactly one category.

| Category | Means | A finding? |
|---|---|---|
| `closed` | No longer a departure | no |
| `tracked` | Temporary, with a tracking reference that exists | no |
| `kept, basis holds` | Permanent, its ADR exists, and its stated basis re-verifies as still true | no |
| `needs an ADR` | Permanent, and the ADR it requires does not exist | yes |
| `stale reason` | Kept, on a reason the tree no longer supports | yes |
| `unclassifiable` | Fits none of the above. Name what it carries instead | yes |

`kept, basis holds` is the row an earlier draft of this template omitted, and omitting it is not
harmless. `standards-template.md` says a departure is "either temporary with a tracking reference,
or permanent with an ADR", so a permanent departure with a live ADR and a basis that still holds is
the healthy end state, not a defect. With no row for it, it falls to `unclassifiable` and is counted
as a finding. In the assessment this template was derived from, four of fifteen departures were in
exactly that state, which would have tripled the reported departure count.

**Identifying a departure.** `standards-template.md`'s departures table carries no identifier
column, so a `D-` number is positional and adding one departure renumbers every row after it. Where
the document numbers its departures, use its numbers. Where it does not, identify each by its
`Default` cell and say so, for the same reason check 2 says it: the trend section has no stable key
otherwise.

The ledger, one row per departure. The example below is an excerpt, so its rows do not total the
counts that follow:

```markdown
| # | Departure | Category | Basis re-verified against the tree |
|---|---|---|---|
| D-2 | Repository services return a result rather than throwing | tracked | Still 17 of 17 services, no competing pattern. Holds |
| D-3 | Structured logging to a collector | needs an ADR | `docs/decisions/` holds no ADR naming this |
```

Then the counts, **with every category present even at zero**, because a per-departure ledger cannot
show an empty category and the empty ones are the result:

```markdown
| Category | Count |
|---|---|
| closed | 3 |
| tracked | 6 |
| kept, basis holds | 4 |
| needs an ADR | 1 |
| **stale reason** | **0** |
| unclassifiable | 1 |
```

**In a real report the counts must total the ledger's rows**, for the same reason check 1's
dispositions must sum to its `Rules`: two tables that can disagree will.

Re-verify the stated factual basis of every departure the document rules as kept, whichever of
`kept, basis holds` or `stale reason` it then lands in, and record the result in the ledger's last
column, including where it still holds. That re-verification is the only thing separating those two
rows. An empty `stale reason` count is the most useful line in this check, and dropping the row
makes a clean result indistinguishable from a check that never ran.

## Trend

Only where a previous report exists. The prior report is the highest-sorting
`<docs_root>/audits/*-standards.md` **other than the one being written**, which matters on a
same-day re-run. Match items on the identifier the assessed `standards.md` itself uses, or on the
first clause where it numbers nothing, as check 2 records. Three lines: what closed since the last
report, what is new, and what has been open longest. This is what makes a second assessment worth
running.

## Not covered

```markdown
## Not covered

- Checks 1 to 4 only. Nothing outside the four was assessed.
- The judgement sample read the first rule of 8 of the document's 20 judgement sections.
  Sections 9 to 20 were not read, and nor were any later rules inside sections 1 to 8.
- No test was run, and nothing was executed against a running instance. The only commands run
  against the repository were the read-only `git` queries this report's own header and check 3
  require.
```

An assessment that implies completeness it does not have is worse than a narrow one, because it
stops the next person looking.
````

**This content is version 4.** Versions 1, 2 and 3 were written, reviewed and rejected on 2026-09-01. The code
quality pass returned three blocking findings against it, all of them defects in the plan rather than
in the transcription: check 1's table had columns for `Folded in` and `Skipped whole` only, so
FR-08's adapted, departed and omitted dispositions had nowhere to go and its own example left 2 of 8
rules unaccounted for; check 3's sample rule covered a document with too few sections and not one
with too many, and this repository's own `docs/standards.md` has 20 against a stated cap of 8; and
check 4 had no output shape at all, so FR-21's "report empty categories" could not be followed,
because a per-departure ledger cannot show a category with no departures. Version 2 adds the four
disposition columns with a sum rule, bounds the sample in both directions, and gives check 4 both a
ledger and a counts table.

**Version 2 was rejected in turn, on two further blocking findings, both in check 3.** Its worked
example still read "Sampled: sections 1 to 6, Not reached: sections 7 to 10", which is the
pre-version-2 behaviour the new upper bound existed to forbid, and a template is copied more often
than it is read. And its "fewer than six, take further rules from the largest section" branch was
undefined (largest by what) and unexecutable on a document that states one rule per section, which
is the shape of this repository's own `docs/standards.md`: 20 H2 sections, 0 H3, so there are no
further rules in any section and six is unreachable. Version 3 gives check 3 its own counting unit,
bounds the sample in both directions without an unreachable floor, and fixes the example to match
the rule. It also takes six should-fix findings: "probe" rather than "check" in the immutability
clause, one table row per indexed reference rather than only the applicable ones, a definition for
each of the four header counts, checklist headings excluded by name rather than by subtracting
three (no topic reference carries all three), a stated tie between check 4's ledger and its counts,
and three prose lines rewrapped under the 100 column rule at `docs/standards.md:83`.

**Version 3 was rejected in turn, on one blocking finding that neither earlier round reached.** Its
five departure categories could not classify a healthy permanent departure: one whose ADR exists and
whose stated basis re-verifies as still true is not closed, not tracked, does not need an ADR, and
its reason is not stale, so it fell to `unclassifiable`, which the header counts as a finding. In
the assessment this template is derived from that is four of fifteen departures, recorded as their
own row at `docs/ideas/standards-that-bind.md:250`, so version 3 would have reported four healthy
departures as findings and tripled the count. Version 4 adds a sixth category, `kept, basis holds`,
and an explicit `A finding?` column so the header count is derived from the table rather than from a
sentence. It also fixes a false statement in the honesty section (the boilerplate claimed no command
was executed against the project, while the header mandates two `git` queries), scopes check 3's
two sampling branches so they cannot overlap, gives check 4 the identifier rule check 2 already had,
and marks the ledger example as an excerpt so it does not contradict the counts rule beneath it.

- [x] **Step 3: There is no implementation beyond step 2**

This task's deliverable is the file itself. Nothing else changes.

- [x] **Step 4: Run the checks and watch them pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, and `tests/validate-skills.sh` reports `OK 25 skills validated`
with its existing 5 warnings and no new one. The file must produce no
`hardcodes a docs/keel path` report and no `contains an em dash` report.

Then confirm the file landed where task 2 will link to it:

```bash
ls skills/coding-standards/references/assessment-report.md
/usr/bin/grep -c 'docs/keel/' skills/coding-standards/references/assessment-report.md
```

Expected: the path prints, and the grep prints `0`.

- [x] **Step 5: Hand over**

```bash
git add skills/coding-standards/references/assessment-report.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(coding-standards): add the assessment report template"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

---

### Task 2: The mode branch and the description clause

**Requirements:** FR-01, FR-03, FR-04, FR-05, FR-06, FR-25, FR-26, FR-27, FR-28, CON-01, CON-02,
CON-03, NFR-01, NFR-02, NFR-04, NFR-07.

**Files:**
- Modify: `skills/coding-standards/SKILL.md`

**Interfaces:**
- Consumes: `skills/coding-standards/references/assessment-report.md`, created in task 1. The body
  links to it relatively.
- Produces: the assess mode, which task 3's router row and documentation surfaces describe, and
  which task 4's scenario dispatches against.

**Depends on:** task 1

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and `tests/validate-skills.sh`
reports `coding-standards: body is 876 words, over the 700 target (ceiling 900). ADR-0001 requires a
passing eval arm at this length.` as a **warning**, not a failure.

- [x] **Step 1: Measure before, and note that no test goes red first**

Adding prose to a skill body cannot be made to fail first without leaving the suite red, which the
global constraints forbid. The assertions that catch getting it wrong are the word ceiling
(`tests/validate-skills.sh:23`, `CEILING_WORDS=900`, a hard failure above it), the description cap
(`:39`, `DESC_MAX_CHARS=216`), and the broken-link check (`:148-153`).

Record the before values:

```bash
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/coding-standards/SKILL.md | wc -w
awk '/^---$/{c++; if(c>=2) exit} c==1' skills/coding-standards/SKILL.md | sed -n 's/^description:[[:space:]]*//p' | tr -d '\n' | wc -c
```

Expected: `683` and `181`.

- [x] **Step 2: Append the description clause**

`skills/coding-standards/SKILL.md:3` currently reads `Use when asked about a project's conventions,
setting up linting...`. Insert ` or assessing code against them` directly after `conventions`, so the
clause sits against the noun `them` refers to rather than four clauses away. The line becomes:

```
description: Use when asked about a project's conventions or assessing code against them, setting up linting or formatting, onboarding onto an unfamiliar codebase, or when review feedback keeps repeating the same style point.
```

The clause is 31 characters including its leading space, and the line lands at 212 of the 216 cap,
one character shorter than appending it at the end would have been.

- [x] **Step 3: Insert the mode branch**

Insert the following after line 14 (the end of the Core principle sentence, `Ink is for judgement
calls only.`) and before the blank line preceding `## Step 1: Derive, do not impose` at line 16.
The inserted block is 193 words, measured with the validator's own extraction.

**The block begins with one blank line and that blank line is part of it.** Without it the `## Step 0`
heading abuts the Core principle sentence and markdown does not parse it as a heading. Line 15's
existing blank line separates the end of the block from `## Step 1`, so do not add a second one
there.

````markdown

## Step 0: Author or assess

**Author** where no `<docs_root>/standards.md` exists, the default, and steps 1 to 5 follow.
**Assess** where one exists and nobody knows whether the code still follows it, and step 0a replaces
them. Choose from the request's words, before reading anything. Asked to assess with no document,
say so and offer to author. Asked to author over one, name it and ask first. Ambiguous with a
document present, ask once.

## Step 0a: Assess

Write `<docs_root>/audits/YYYY-MM-DD-standards.md`, following
[references/assessment-report.md](references/assessment-report.md). Change nothing else, run nothing
that alters the project, never edit `standards.md`. **The report is one numbered section per check,
in this order:**

1. **House-defaults coverage.** `standards.md` against all ten references the index lists,
   applicable or not, each row saying what decided it. Those predicates are prose, not profile
   fields. No code read.
2. **The backlog.** Follow-ups and inconsistencies against HEAD, not the document's own status text.
3. **A judgement sample.** Up to eight rules, all of them where fewer exist, source read for those
   only, every imprecise match opened.
4. **The departures ledger.** Each departure into one of six categories, three of which are
   findings. Re-verify every kept departure's basis.
````

- [x] **Step 4: Run the checks and watch them pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`. `tests/validate-skills.sh` now reports **6** warnings rather than
5, the new one being `coding-standards: body is 876 words, over the 700 target (ceiling 900).
ADR-0001 requires a passing eval arm at this length.` A `report` line rather than a `WARN` line for
`coding-standards` means the body went over 900 and the task has failed. A warning whose text
instead reads `N words, M from the 900 ceiling` means the body crossed 870, which is `CEILING_WORDS`
minus `HEADROOM_WORDS` at `tests/validate-skills.sh:23,27`; that is still a warning and still green,
but it means the block was expanded past 870 and the arm task 6 records would be at the wrong
length. At 876 that branch cannot fire, so seeing it at all is the signal.

Then confirm the measured numbers:

```bash
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/coding-standards/SKILL.md | wc -w
awk '/^---$/{c++; if(c>=2) exit} c==1' skills/coding-standards/SKILL.md | sed -n 's/^description:[[:space:]]*//p' | tr -d '\n' | wc -c
```

Expected: `876` and `212`. If the body is not 876, the inserted block was edited; restore it
verbatim rather than trimming elsewhere, because task 6's arm is recorded against this length.

- [x] **Step 5: Hand over**

```bash
git add skills/coding-standards/SKILL.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(coding-standards): add an assess mode for an existing standards.md"`.
Paste the `git status --porcelain` output into your report.

---

### Task 3: The router row and the four documentation surfaces

**Requirements:** FR-02, and section 15 of the PRD, which lists every surface that must change and
every one that must not.

**Files:**
- Modify: `skills/keel/SKILL.md`
- Modify: `docs/prompting.md`
- Modify: `templates/prompting-cheatsheet.md`
- Modify: `docs/02-skill-catalog.md`
- Modify: `bin/keel`
- Modify: `docs/README.md`
- Modify: `docs/05-token-and-memory-design.md`

**Interfaces:**
- Consumes: the assess mode from task 2. Every edit here describes behaviour task 2 built.
- Produces: nothing another task consumes.

**Depends on:** task 2

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/keel/SKILL.md | wc -w` prints `560`.

- [x] **Step 1: Measure before, and note that no test goes red first**

Three of these five files are not read by any test. `docs/prompting.md` and
`docs/02-skill-catalog.md` have no test reading them at all. The only assertion on
`templates/prompting-cheatsheet.md` is `tests/validate-skills.sh:312-314`, which requires the
router's destination name to appear somewhere in the file, and `coding-standards` already appears,
so that check passes before and after. The edits here are for accuracy, not to turn a test green.

The one measurable constraint is the `keel` body word count. Record it:

```bash
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/keel/SKILL.md | wc -w
```

Expected: `553`.

- [x] **Step 2: The router row**

Replace `skills/keel/SKILL.md:28` in full. It currently reads:

```
| what are our conventions, set up linting | `coding-standards` |
```

Replace with:

```
| what are our conventions, set up linting, does the code still follow our standards | `coding-standards` |
```

That is 7 more words, taking the body to 560, which is 140 under the 700 target.

- [x] **Step 3: The four documentation surfaces**

Replace `docs/prompting.md:34` in full:

```
| "what are our conventions", "set up linting", "enforce style", "does the code still follow our standards" | `coding-standards` | `docs/standards.md` plus lint config, or `docs/audits/<date>-standards.md` |
```

Replace `templates/prompting-cheatsheet.md:33` in full:

```
| "what are our conventions", "set up linting", "enforce style", "does the code still follow our standards" | `coding-standards` | `{{DOCS_ROOT}}/standards.md` plus lint config, or `{{DOCS_ROOT}}/audits/<date>-standards.md` |
```

In `docs/02-skill-catalog.md`, replace the `**Writes:**` line at `:297` and the `**Does:**` line at
`:298` so the entry reads:

```
**Writes:** `<docs_root>/standards.md`, `<docs_root>/audits/YYYY-MM-DD-standards.md`, and lint/format/hook config when missing.
**Does:** three distinct jobs.
```

Then, after the existing numbered item 2 that ends `What remains in `standards.md` is only the
judgement calls.` at `:305`, insert a third numbered item:

```
3. **Assess.** Given a `standards.md` that already exists, check it against the tree and write a
   dated report to `<docs_root>/audits/YYYY-MM-DD-standards.md`. Four checks, always all four, in
   one order: house-defaults coverage, the follow-up backlog, a judgement sample, the departures
   ledger. It never edits the document it is checking.
```

Replace `bin/keel:499` in full. It currently reads:

```
| \`audits/\` | \`security-audit\` |
```

Replace with:

```
| \`audits/\` | \`security-audit\`, \`coding-standards\` |
```

Keep the backslash escaping exactly as shown; this line is inside a `cat > ... <<D` heredoc that
expands variables, and an unescaped backtick would run a command substitution.

**Two skills, not three.** An earlier draft of this task added `incident-response` on the authority
of `docs/02-skill-catalog.md`, which says it writes an incident record under `<docs_root>/audits/`.
That catalog line is stale and the skill is the authority: `skills/incident-response/SKILL.md:42`
and `skills/incident-response/references/incident-record.md:5` both write
`<docs_root>/incidents/YYYY-MM-DD-<slug>.md`. Adding it would have pointed every scaffolded project
at the wrong directory. Correct the catalog line in the same edit, below.

Then state the audits naming convention once, per the PRD's section 14 decision 2. The PRD says it
belongs on "the `audits/` row of the scaffolded documentation table". That table is this heredoc in
`bin/keel`, not `docs/02-skill-catalog.md`, which has no such table. Insert **a blank line and then**
this line after the table, before the existing `See \`prompting.md\`...` line at `bin/keel:501`:

```

A dated report here is named \`YYYY-MM-DD-<kind>.md\`, where \`<kind>\` is the noun of the skill
that wrote it: \`security\`, \`standards\`.
```

`<kind>` is the **noun**, not the skill name. The files are `YYYY-MM-DD-security.md` and
`YYYY-MM-DD-standards.md`, so a sentence saying `<kind>` names the skill would send a reader looking
for `YYYY-MM-DD-security-audit.md`.

The blank line is load bearing. Without it the sentence sits directly under the last table row and
GFM parses it as another row of the table, which is what the scaffolded README would then render.
The heredoc already has a blank line before its `See \`prompting.md\`` line; reuse that one rather
than adding a second.

**Four more documents this change makes wrong, corrected in the same task**, per `CLAUDE.md`'s rule
that a change lands with the documents it makes wrong:

- `docs/README.md`, this repository's hand-maintained twin of the heredoc above. Same table row and
  the same naming sentence.
- `docs/02-skill-catalog.md`, the `incident-response` **Writes:** line, corrected to
  `<docs_root>/incidents/YYYY-MM-DD-<slug>.md`.
- `docs/02-skill-catalog.md`, the `coding-standards` **Trigger:** line, which listed only authoring
  triggers while the entry beneath it now claims three jobs.
- `docs/05-token-and-memory-design.md`, whose tree comment called `audits/` "security audit history".

Naming the kind rather than enumerating the three skills keeps the sentence true when a fourth
starts writing here.

- [x] **Step 4: Run the checks and watch them pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, with the same 6 warnings task 2 left and no new failure. In
particular `tests/test-keel.sh` must still pass, because `bin/keel` changed.

Then confirm the word count and the heredoc:

```bash
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/keel/SKILL.md | wc -w
bash -n bin/keel && echo "bin/keel parses"
```

Expected: `560`, and `bin/keel parses`.

- [x] **Step 5: Hand over**

```bash
git add skills/keel/SKILL.md docs/prompting.md templates/prompting-cheatsheet.md \
        docs/02-skill-catalog.md bin/keel docs/README.md docs/05-token-and-memory-design.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs: route and document the coding-standards assess mode"`. Paste the
`git status --porcelain` output into your report.

---

### Task 4: The eval fixture and its scenario

**Requirements:** NFR-08, which is the stated prerequisite for NFR-03.

**This is version 2 of this task.** Version 1 was reviewed before dispatch and rejected on four
blocking findings, all of them defects in the content specified rather than in any implementation.
Two were the same mistake made twice, prose written for a reader of the plan ending up inside an
artifact meant for an agent under test: a comment reading `# Drift: the fee is computed in floating
point, which section 1 forbids.` and a three line note explaining `${BASH_SOURCE[0]}` and citing
another fixture. `tests/evals/fixtures/README.md:14-18` forbids exactly this: "Nothing in a fixture
may describe the exercise." The other two were the fixture's design being asserted rather than
derived: the plan said four house references applied in one step and five in the next, and D-2's
stated basis did not survive the re-verification FR-22 requires, so the `stale reason` category was
not empty as predicted.

Version 2 was built and run before it was written down. Every file below was executed, `setup.sh`
was run through a simulated stage, and every predicted finding was checked against the resulting
tree. The numbers in step 6 are measurements, not expectations.

**Files:**
- Create: `tests/evals/fixtures/assess-a-stale-standard/.keel/profile.json`
- Create: `tests/evals/fixtures/assess-a-stale-standard/docs/standards.md`
- Create: `tests/evals/fixtures/assess-a-stale-standard/docs/decisions/ADR-0001-error-codes-not-exceptions.md`
- Create: `tests/evals/fixtures/assess-a-stale-standard/src/money.sh`
- Create: `tests/evals/fixtures/assess-a-stale-standard/src/payouts.sh`
- Create: `tests/evals/fixtures/assess-a-stale-standard/tests/run-tests.sh`
- Create: `tests/evals/fixtures/assess-a-stale-standard/tests/test-payouts.sh`
- Create: `tests/evals/fixtures/assess-a-stale-standard/setup.sh`
- Create: `tests/evals/scenarios/assess-a-stale-standard.md`
- Modify: `README.md`
- Modify: `tests/evals/fixtures/README.md`
- Modify: `tests/evals/stage.sh`
- Modify: `tests/test-eval-harness.sh`

**Interfaces:**
- Produces: the fixture directory and the scenario that resolves it, both named
  `assess-a-stale-standard`. The two names must match exactly: `tests/evals/stage.sh:26` resolves
  the scenario and `:40` the fixture, from the same argument.
- **Why the scenario is here rather than in task 5, where it was originally planned.**
  `tests/evals/stage.sh:38` runs `tests/evals/run.sh "$name"` before it copies anything, and
  `run.sh:11` resolves a scenario file. So `stage.sh` fails outright without one, and step 7's case
  17 stages the fixture. A fixture task that ends with a failing harness case is not a task that can
  land, so the scenario comes with it. This was found by dispatching task 4 without it and watching
  case 17 fail on arrival.
- Consumes: nothing.

**Depends on:** none

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and the fixture's own
`tests/run-tests.sh`, run from inside the fixture directory, prints six `PASS` lines followed by
`All tests passed` and exits 0.

**No file in this fixture may explain itself.** The arm reads every staged file. `setup.sh` is the
one exception and may carry comments, because `tests/evals/stage.sh:59` removes it from the staged
copy before it runs. Do not add a comment to any file under `src/`, `tests/`, `docs/` or `.keel/`,
however helpful it would be to the next engineer.

- [x] **Step 1: There is no test that goes red first, and one that must stay green**

A fixture directory with no scenario breaks nothing: `tests/test-eval-harness.sh:97-106` requires
every scenario to have a fixture, not the reverse, so an orphan fixture is green. The assertion that
catches this being done wrongly is `tests/test-eval-harness.sh:248-261`, which fails if any fixture
file is gitignored.

```bash
find tests/evals/fixtures -name 'standards.md' | wc -l
find tests/evals/scenarios -name '*.md' | wc -l
```

Expected: `0` and `8`.

- [x] **Step 2: Write the profile**

`tests/evals/fixtures/assess-a-stale-standard/.keel/profile.json`:

```json
{
  "project": { "name": "payouts", "kind": "cli", "description": "Settles agent payouts from a ledger file" },
  "stack": { "language": "bash", "runtime": "bash", "package_manager": "none", "has_ui": false },
  "verify": { "test": "tests/run-tests.sh", "lint": null, "build": null },
  "gates": { "coding_standards": "required" },
  "docs_root": "docs",
  "artifacts": { "prd": null, "stories": null, "architecture": null }
}
```

`runtime` is `bash`, not `posix-sh`: the sources use `local` and `BASH_SOURCE`, and a profile that
claimed POSIX would be a defect the assessment could legitimately report, which is not the exercise.

- [x] **Step 3: Write the source tree**

`tests/evals/fixtures/assess-a-stale-standard/src/money.sh`:

```bash
#!/usr/bin/env bash

to_minor() {
    printf '%s\n' "$1" | awk -F. '{ printf "%d\n", ($1 * 100) + ($2 == "" ? 0 : $2) }'
}

from_minor() {
    printf '%d.%02d\n' "$(( $1 / 100 ))" "$(( $1 % 100 ))"
}

add_minor() {
    printf '%d\n' "$(( $1 + $2 ))"
}

valid_minor() {
    case "$1" in
        ''|*[!0-9-]*) return 3 ;;
        *) return 0 ;;
    esac
}
```

`tests/evals/fixtures/assess-a-stale-standard/src/payouts.sh`. Note it ships **without**
`settle_payout` and `receipt_line`; step 5's `setup.sh` adds both as a later commit so the breaches
they carry genuinely postdate the derivation point:

```bash
#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/money.sh"

log() {
    printf '{"level":"%s","msg":"%s"}\n' "$1" "$2" >&2
}

submit_payout() {
    local amount_minor="$1" payee="$2"
    if [ -z "$payee" ]; then
        log error "payee missing"
        return 2
    fi
    if ! valid_minor "$amount_minor"; then
        log error "amount not minor units"
        return 3
    fi
    log info "submitted"
    printf '%d %s\n' "$amount_minor" "$payee"
}

payout_status() {
    case "$1" in
        submitted|settled|failed) printf '%s\n' "$1"; return 0 ;;
        *) log error "unknown status"; return 4 ;;
    esac
}

record_time() {
    date -u '+%s'
}

append_ledger() {
    local payee="$1" amount_minor="$2"
    if [ ! -w "$(dirname "$LEDGER_FILE")" ]; then
        log error "ledger not writable"
        return 5
    fi
    printf '%s\t%s\t%s\n' "$(record_time)" "$payee" "$amount_minor" >> "$LEDGER_FILE"
    return 0
}
```

- [x] **Step 4: Write the test suite**

`tests/evals/fixtures/assess-a-stale-standard/tests/test-payouts.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
. src/payouts.sh
fails=0
check() {
    if [ "$2" = "$3" ]; then printf 'PASS  %s\n' "$1"
    else printf 'FAIL  %s: expected %s, got %s\n' "$1" "$3" "$2"; fails=$((fails+1)); fi
}
check "to_minor" "$(to_minor 12.34)" "1234"
check "from_minor" "$(from_minor 1234)" "12.34"
check "add_minor" "$(add_minor 100 250)" "350"
check "submit_payout" "$(submit_payout 500 alice 2>/dev/null)" "500 alice"
check "payout_status" "$(payout_status settled)" "settled"
submit_payout 500 "" 2>/dev/null; check "missing payee returns 2" "$?" "2"
exit "$fails"
```

`tests/evals/fixtures/assess-a-stale-standard/tests/run-tests.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
if bash tests/test-payouts.sh; then echo "All tests passed"; exit 0; fi
echo "Tests failed"; exit 1
```

Make both executable:

```bash
chmod +x tests/evals/fixtures/assess-a-stale-standard/tests/run-tests.sh \
         tests/evals/fixtures/assess-a-stale-standard/tests/test-payouts.sh
```

- [x] **Step 5: Write the document and the history**

`tests/evals/fixtures/assess-a-stale-standard/docs/standards.md`. The literal `DERIVED_SHA` is a
placeholder that `setup.sh` rewrites with the real commit:

````markdown
# Coding standards

| | |
|---|---|
| Derived from | 2 files under `src/`, at commit `DERIVED_SHA` |
| Date | 2026-03-01 |
| Enforced by | nothing. There is no lint command |
| Departures from the house defaults | see the last section |

## 1. Money is integer minor units

**Rule:** amounts are integer minor units everywhere. Never floating point, never a decimal string
in arithmetic.
**Why:** a half unit that survives a division becomes a reconciliation break a month later.
**Example, from this codebase:** `to_minor` and `add_minor` in `src/money.sh` take and return
integers.

## 2. One log function

**Rule:** one `log` function, structured, to stderr. No bare `echo` or `printf` to stderr from a
code path.
**Why:** a line assembled by hand cannot be queried, and a field you cannot query is a field you do
not have.
**Example, from this codebase:** `log` in `src/payouts.sh` emits one JSON object per line.

## 3. Failure paths return a named code

**Rule:** a failure path returns a distinct non-zero code. Never `exit` from a library function.
**Why:** a caller that cannot tell bad input from an unavailable dependency retries the wrong one.
**Example, from this codebase:** `submit_payout` returns 2 for a missing payee and 3 for a bad
amount.

## 4. Timestamps are epoch seconds in UTC

**Rule:** a timestamp is epoch seconds in UTC. Never a formatted local string, and never a
locale-dependent format.
**Why:** a receipt written in one timezone and read in another is off by hours, and `%d/%m` against
`%m/%d` is off by months.
**Example, from this codebase:** `record_time` in `src/payouts.sh` emits `date -u '+%s'`.

## 5. Inputs arrive as arguments

**Rule:** every function takes its inputs as positional arguments. No function reads a global.
**Why:** a function that reads a global cannot be tested without building the world around it.
**Example, from this codebase:** every function in `src/money.sh` takes what it needs.

## 6. Amounts are validated before use

**Rule:** a function that takes an amount from a caller outside `src/` validates it before use.
The helpers in `src/money.sh` are internal and are not entry points.
**Why:** an unvalidated amount reaches the ledger as a silent zero.
**Example, from this codebase:** `submit_payout` calls `valid_minor` and returns 3 on failure.

## Known inconsistencies

**Two status vocabularies.** `payout_status` accepts `submitted`, `settled` and `failed`, while the
upstream ledger file uses `pending` and `complete`. Do not fix piecemeal: the mapping belongs in one
place and nobody has decided where.

## Not yet mechanical

| # | Item | Owner skill |
|---|---|---|
| F-1 | Add a lint command and wire `verify.lint`, then ban floating point arithmetic in `src/` | `coding-standards` |
| F-2 | Give the two status vocabularies one mapping function | `refactor` |

## Departures from the house defaults

| # | Default | This project | Ruling |
|---|---|---|---|
| D-1 | A check-only lint command exists | none | **Close.** F-1 |
| D-2 | Errors propagate as exceptions | functions return distinct codes | **Keep.** Bash has no exceptions. Recorded in `docs/decisions/ADR-0001-error-codes-not-exceptions.md`. Verified: no function in `src/` calls `exit` |
| D-3 | Logs reach a collector | stderr only | **Keep, permanently.** This runs as a foreground command whose stderr the caller already captures. Needs an ADR recording that |
| D-4 | Runtime version pinned where developers see it | `.keel/profile.json` names `bash` | **Closed 2026-03-01.** No departure remains |
````

`tests/evals/fixtures/assess-a-stale-standard/docs/decisions/ADR-0001-error-codes-not-exceptions.md`.
This file is why D-2 lands in `kept, basis holds` rather than `needs an ADR`: that category requires
the ADR to exist, so a fixture without one cannot exercise it. `setup.sh` commits it in commit 1.

````markdown
# ADR-0001: Failure paths return distinct codes

| | |
|---|---|
| Status | accepted |
| Date | 2026-02-14 |
| Deciders | the payouts team |

## Context

Bash has no exception mechanism. A function that fails can signal it by returning a non-zero code,
by writing to stderr and returning 1, or by calling `exit` and taking the caller down with it.

## Decision

Every failure path in `src/` returns a distinct non-zero code. No function in `src/` calls `exit`.

## Consequences

A caller can tell a missing payee from an unusable amount without parsing a message. The cost is
that a caller who ignores `$?` sees nothing, which the test suite guards against by asserting the
code rather than the output.
````

`tests/evals/fixtures/assess-a-stale-standard/setup.sh`. This file may carry comments, because it is
removed from the staged copy before it runs:

```bash
#!/usr/bin/env bash
# Makes the staged copy a real git repository whose history has a before and an after.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and removed from
# project/ before it runs, so the arm never sees this file or these comments.
#
# Commit 1 is the point the document was derived from: the money and payout modules as they stood.
# Commit 2 adds the document, pinned to commit 1's sha, and two functions written after it. Both new
# functions breach a rule the document states, which is what gives the assessment something true to
# find, and both land after the derivation commit, which is what makes the pre-derivation proportion
# a real number rather than a formality.
#
# The commit messages describe the code and not the exercise, per fixtures/README.md: the arm reads
# this history, and a message naming the breach hands over the finding.
#
# Identity and signing are set locally so the commit does not depend on whoever ran the stage.

set -euo pipefail

git init -q -b main
git config user.name "Payouts CI"
git config user.email "ci@payouts.invalid"
git config commit.gpgsign false

git add src tests .keel docs/decisions
git commit -q -m "feat: submit a payout and read its status"
derived=$(git rev-parse --short HEAD)

cat >> src/payouts.sh <<'FN'

settle_payout() {
    local amount_minor="$1" fee_rate="$2"
    log info "settling"
    awk -v a="$amount_minor" -v r="$fee_rate" 'BEGIN { printf "%.4f\n", (a * r) / 100 }'
    return 0
}

receipt_line() {
    local amount_minor="$1"
    printf '%s settled %s\n' "$(date '+%d/%m/%Y %H:%M')" "$(from_minor "$amount_minor")"
}
FN

sed -i.bak "s/DERIVED_SHA/$derived/" docs/standards.md
rm -f docs/standards.md.bak

git add docs src/payouts.sh
git commit -q -m "feat: settle a payout at a fee rate and print a receipt line"
```

Make it executable:

```bash
chmod +x tests/evals/fixtures/assess-a-stale-standard/setup.sh
```

- [x] **Step 6: What each check will find, derived rather than asserted**

These were checked against the staged tree, not predicted. Task 6 scores the arm against them, so a
wrong number here produces an arm that measures the wrong thing.

**Two of them were nonetheless wrong, and the arm found both.** Rule 5 is predicted "near-fully
observed" below; `append_ledger` reads its global in commit 1, the derivation commit itself, so the
document was false about rule 5 the day it was written. And D-4 is predicted `closed`; it claims the
runtime is pinned, and `bash` with no version is not a pin, so it is not closed. The corrected
record is `tests/evals/fixtures/README.md` and the finding is in `tests/evals/results.md`. The rows
below are left as written, because a prediction table that quietly agrees with the result afterwards
is not a prediction.

**Check 1, house-defaults coverage. Three of the ten references apply.** Derived row by row against
`skills/coding-standards/references/house-defaults.md:18-27`:

| Reference | Applies | Because |
|---|---|---|
| `observability.md` | yes | "Always" |
| `time-and-dates.md` | yes | "Always" |
| `data-protection.md` | yes | `append_ledger` writes the payee to a file, so personal data is stored |
| `async-work.md` | no | No queue, worker or scheduled job. Zero matches for `cron`, `queue`, `worker` |
| `authorisation.md` | no | One kind of caller. Zero matches for `role`, `permission`, `tenant` |
| `rate-limiting.md` | no | Exposes no API. It consumes one |
| `api-contracts.md` | no | Its trigger is a consumer **you** cannot deploy. This project provides no API; consuming a partner's is not the same row |
| `caching.md` | no | Nothing is cached. Zero matches for `cache` |
| `resilience.md` | no | Nothing is called over a network. Zero matches for `curl`, `wget`, `nc` |
| `frontend.md` | no | `profile.stack.has_ui` is false |

By the counting unit, those three hold 8, 6 and 7 rules, twenty one in total. The document folds in one
(`observability.md`'s single-log-function rule, as its rule 2) and adapts one (`time-and-dates.md`'s
store-UTC rule, as its rule 4). **`data-protection.md` is skipped whole**: all 7 of its rules, with no
departure row recording the choice, and the document contains zero occurrences of `retention`,
`encrypt`, `erasure`, `subject right`, `personal data` or `anonymi`. That is the FR-09 finding, and
it is the only skipped-whole reference.

**Check 2, the backlog.** F-1 open, because `verify.lint` is still `null` and no lint command exists.
F-2 open, because no mapping function exists. The known-inconsistency entry is still true.

**Check 3, the judgement sample.** The document holds exactly six judgement rules, so the sample is
all six and the "fewer than eight" branch fires. Verified verdicts:

| # | Rule | Verdict | Evidence in the staged tree |
|---|---|---|---|
| 1 | Money is integer minor units | drifting | `settle_payout` computes a fee with `awk` `%.4f` |
| 2 | One log function | observed | Zero bare `echo` writes to stderr in `src/` |
| 3 | Failure paths return a named code | observed | Zero `exit` calls in `src/` |
| 4 | Timestamps are epoch seconds UTC | drifting | `receipt_line` formats local `%d/%m/%Y %H:%M` |
| 5 | Inputs arrive as arguments | near-fully observed | 1 of 11 functions reads a global, `append_ledger` reads `$LEDGER_FILE` |
| 6 | Amounts are validated before use | near-fully observed | `submit_payout` calls `valid_minor`, `settle_payout` does not |

Two observed, two drifting, two near-fully observed. The pre-derivation proportion is real: the
document pins commit 1, and rules 1 and 4's breaches both arrive in commit 2.

**Check 4, the departures ledger.** Four departures, and every category's count is determined:

| # | Category | Why |
|---|---|---|
| D-1 | `tracked` | Open, and F-1 exists as its tracking reference |
| D-2 | `kept, basis holds` | It names an ADR that exists, and its stated basis, "no function in `src/` calls `exit`", is true of zero |
| D-3 | `needs an ADR` | Ruled keep permanently, and no ADR names it. The fixture does ship one ADR, which D-2 names; that is what makes `kept, basis holds` reachable and leaves D-3 the only row needing one |
| D-4 | `closed` | No departure remains |

So `closed` 1, `tracked` 1, `kept, basis holds` 1, `needs an ADR` 1, **`stale reason` 0**,
`unclassifiable` 0. The two zero rows are the FR-21 test: a report that omits them rather than
printing them as zero has failed that requirement.

- [x] **Step 7: Record the fixture where this repository records fixtures**

`tests/evals/fixtures/README.md` states its own rule, that what a fixture seeds is recorded there,
and `tests/test-eval-harness.sh` cases 12 to 16 each pin one load bearing property of one fixture.

Insert this **before** the `## What none of them contain` heading at
`tests/evals/fixtures/README.md:153`, so it sits with the other per-fixture sections rather than
after the closing material:

````markdown
## `assess-a-stale-standard`

A payout CLI in bash with a `docs/standards.md` written against an earlier commit. Seeded so each of
the four assessment checks has something definite and derivable to find.

| Seeded | Value |
|---|---|
| Document | 6 judgement rules, 1 known inconsistency, 2 follow-up items, 4 departures |
| Applicable house references | 3 of 10: `observability.md`, `time-and-dates.md`, `data-protection.md` |
| Coverage gap | `data-protection.md` skipped whole, all 7 rules, no departure row. `append_ledger` stores a payee with no retention or access rule |
| Backlog | F-1 and F-2 both open. `verify.lint` is still null |
| Sample | 2 rules observed, 2 drifting, 2 near-fully observed, of 6 |
| Departures | 1 each of tracked, kept-basis-holds, needs-an-ADR, closed. Both `stale reason` and `unclassifiable` are zero |
| History | `setup.sh` builds it. Commit 1 is the derivation point, commit 2 adds the document and both breaches |
````

Two counts elsewhere become wrong when this fixture lands, and this task fixes them rather than
leaving them. `tests/evals/fixtures/README.md:11-12` reads "Two fixtures have one,
`commit-outside-a-worktree` and `ship-with-flaky-tests`"; make it three and name this one.
`tests/evals/stage.sh:46` reads "One scenario needs it"; make it three, since this fixture's
scenario lands in the same task.

Then add a case to `tests/test-eval-harness.sh`, after case 16 and before case 18, using the
`staged+=` idiom its neighbours use rather than cleaning up by hand:

```bash
# 17. assess-a-stale-standard: the document forbids floating point money and a formatted local
# timestamp, and the tree does both anyway, in a commit later than the one the document pins. A
# fixture whose document and code agreed would give the arm nothing to find, and the arm would pass
# by saying so.
d="$(tests/evals/stage.sh assess-a-stale-standard 2>/dev/null)"; staged+=("$d")
money="$(grep -c '%\.4f' "$d/project/src/payouts.sh" 2>/dev/null || true)"
clock="$(grep -c "date '+%d/%m" "$d/project/src/payouts.sh" 2>/dev/null || true)"
pinned="$(grep -c 'DERIVED_SHA' "$d/project/docs/standards.md" 2>/dev/null || true)"
commits="$(git -C "$d/project" rev-list --count HEAD 2>/dev/null || echo 0)"
if [ "$money" -eq 1 ] && [ "$clock" -eq 1 ] && [ "$pinned" -eq 0 ] && [ "$commits" -eq 2 ]; then
    ok "assess-a-stale-standard seeds both breaches, pins a real derivation commit, and has a history"
else
    bad "assess-a-stale-standard seeds both breaches, pins a real derivation commit, and has a history" \
        "money=$money clock=$clock pinned=$pinned commits=$commits"
fi
```

- [x] **Step 8: Write the scenario, and watch the count claim go red**

This step has a genuine red-green cycle. Create
`tests/evals/scenarios/assess-a-stale-standard.md`:

````markdown
# assess a standards document that has gone stale

Inject: coding-standards

**Tests:** whether an existing `standards.md` is assessed rather than rewritten, and whether the
876 word body is still followed at that length, which is what ADR-0001 asks of it.

**Baseline, no skill:** not recorded. This is a treatment-only length measurement, not a
skill-versus-baseline comparison.

**What the arm can and cannot see.** `tests/evals/run.sh:26-29` injects `skills/<name>/SKILL.md`
and nothing else, and the staged working directory is outside this repository, so
`references/house-defaults.md` and `references/assessment-report.md` are both unreachable. Score
only what the body itself asks for. An arm that names check 1 as not covered, because the
house-defaults
index is unavailable, has followed the body correctly.

**Passes if the reply:** enters assess mode without being told the word "assess"; writes or
drafts `docs/audits/<date>-standards.md` and creates nothing else; leaves `docs/standards.md`
byte identical; names all four checks and presents them in the order house-defaults coverage,
backlog,
judgement sample, departures ledger; and opens its pattern matches rather than reporting a bare
count. Reporting check 1 as not covered for want of the reference is a pass.

**Fails if the reply:** edits or rewrites `docs/standards.md`; starts authoring a new document;
names fewer than four checks; presents them in a different order; reports a match count as a finding
without opening it; or drops check 1 silently rather than saying it could not be run.

**Not measured here.** The pre-derivation proportion and the empty-category rows live in
`references/assessment-report.md`, which this arm cannot reach. Their absence is not a fail.

## Prompt

We inherited this service. There is a standards document in `docs/` that somebody wrote back in
March and nobody has looked at since. I do not know how much of it is still true. Can you tell me
where the code and that document have come apart?
````

Then run the suite and watch it fail:

Run: `tests/run-tests.sh`
Expected: **FAIL** in `tests/test-doc-claims.sh`, with
`README says '8 scenarios', the tree says 9`. That is the claim at `README.md:289` going red because
a ninth scenario now exists. Watching it fail is what proves the claim is enforced.

Confirm it is that failure and not another:

```bash
bash tests/test-doc-claims.sh; echo "exit $?"
find tests/evals/scenarios -name '*.md' | wc -l
```

Expected: the `eval scenario count` claim reports `bad`, exit non-zero, and the count is `9`. The
`every scenario has a fixture` check at `tests/test-eval-harness.sh:97-106` must **not** be among
the failures.

Then update `README.md:289`. It currently reads:

```
8 scenarios exist. Six are dispatched at a release gate and score a reply.
```

Replace with:

```
9 scenarios exist. Six are dispatched at a release gate and score a reply.
```

The gate stays at six. This scenario does not join it, following the precedent at
`tests/evals/results.md:2497-2499`, where an ADR-0001 length arm was recorded without changing the
gate.

- [x] **Step 9: Run the checks and watch them pass**

The fixture's own suite first, from inside the fixture, before `setup.sh` has run:

```bash
cd tests/evals/fixtures/assess-a-stale-standard && ./tests/run-tests.sh; echo "EXIT=$?"; cd -
```

Expected, verified by running this exact code before this plan was written:

```
PASS  to_minor
PASS  from_minor
PASS  add_minor
PASS  submit_payout
PASS  payout_status
PASS  missing payee returns 2
All tests passed
EXIT=0
```

Then the repository suite:

Run: `tests/run-tests.sh`
Expected: `All test files passed`, including the new case 17 and
`no fixture file is gitignored, so a clone stages what this tree stages`.

Then confirm no file in the staged fixture explains itself:

```bash
d=$(tests/evals/stage.sh assess-a-stale-standard) && grep -rn '#' "$d/project/src" | grep -v '^.*:.*#!/usr/bin/env' ; rm -rf "$d"
```

Expected: no output. Any comment in `src/` breaches
`tests/evals/fixtures/README.md:14-18` and must be removed.

- [x] **Step 10: Hand over**

```bash
git add tests/evals/fixtures/assess-a-stale-standard tests/evals/fixtures/README.md \
        tests/evals/stage.sh tests/test-eval-harness.sh \
        tests/evals/scenarios/assess-a-stale-standard.md README.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(evals): add the assess-a-stale-standard fixture and scenario"`. Paste the
`git status --porcelain` output into your report.


### Task 5: absorbed into task 4

The scenario file and the `README.md` count claim moved into task 4, step 8. `tests/evals/stage.sh`
resolves a scenario before it copies a fixture, so a fixture task whose own harness case stages the
fixture cannot land without the scenario. Task 4 carries both, and its step 8 keeps the genuine
red-green cycle this task was written around.

Its one blocking finding is fixed there rather than here: the pass criteria no longer score the arm
on the pre-derivation proportion or on empty-category rows, because both live in
`references/assessment-report.md` and `tests/evals/run.sh:26-29` injects only `SKILL.md`. The
scenario now says so in its own text and lists them under "Not measured here".

---

### Task 6: Run the ADR-0001 arm and record it

**Requirements:** NFR-03, and success metric 4 in section 9 of the PRD.

**This task must run in the main session. It cannot be delegated.** It dispatches a subagent arm and
scores the reply, and a subagent cannot dispatch and then score its own arm without the scoring being
an echo rather than a measurement. `tests/evals/README.md` records the same rule for every other arm.

**Files:**
- Modify: `tests/evals/results.md`

**Interfaces:**
- Consumes: the scenario and fixture from tasks 4 and 5, and the 876 word body from task 2.
- Produces: the recorded arm ADR-0001 requires. Nothing consumes it.

**Depends on:** task 4

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and `tests/evals/results.md`
contains a new dated section recording the arm and its verdict.

- [x] **Step 1: There is no test for this**

This task is a measurement, not a code change. It cannot be automated: it dispatches an agent
against a staged fixture and a human or the coordinating session reads the reply against the
scenario's own pass criteria. Inventing an assertion here would produce a test that passes without
measuring anything, which is worse than an honest gap.

- [x] **Step 2: Stage the scenario and assemble the prompt**

```bash
d=$(tests/evals/stage.sh assess-a-stale-standard) && echo "$d"
head -20 "$d/prompt.md"
```

Confirm before dispatching that the assembled prompt carries the **edited** body, not the old one,
because an arm run against the pre-edit skill measures the wrong length:

```bash
/usr/bin/grep -c 'Step 0: Author or assess' "$d/prompt.md"
```

Expected: `1`. If it prints `0`, task 2 has not landed and this task must stop. The file is
`prompt.md`, not `prompt.txt`: `tests/evals/stage.sh:38` writes
`tests/evals/run.sh "$name" > "$dir/prompt.md"`.

- [x] **Step 3: Dispatch one treatment arm**

Dispatch a single subagent with the assembled prompt, working directory `$d/project`. One arm, not
two: this is a length measurement under ADR-0001, not a skill-versus-baseline comparison, and the
`write-prd` length arm at `tests/evals/results.md:2495-2539` is the precedent for recording one.

**Model and settings, because "the same flags as every other arm" is not knowledge a fresh agent
has.** Dispatch on `claude-opus-5[1m]`, the model the `write-prd` length arm recorded at
`tests/evals/results.md:2511-2512`, with a subagent turn budget of at least 10. Record the model,
the turn count, the wall clock and the cost in the results entry, as that arm did. Do not use a
smaller model: this measures whether a 876 word body is followed, and a different model measures a
different question.

- [x] **Step 4: Score the reply against the scenario's criteria and record it**

Score against the `Passes if` and `Fails if` lines in
`tests/evals/scenarios/assess-a-stale-standard.md`, not on impression. The five things the arm must
demonstrate, from the PRD at `docs/prd/standards-assessment.md:187-196`:

1. Assess mode entered from the request's words, no authoring started (FR-01).
2. All four checks run and appear in the report in the ranked order (FR-25).
3. `docs/standards.md` unmodified, and no file created but the report (FR-23, NFR-06). Task 4's
   `setup.sh` makes the staged project a real repository, so this is one command:
   `git -C "$d/project" status --porcelain`. Expected: one untracked entry, `docs/audits/`, and
   nothing else. Any modified line for `docs/standards.md` is a fail.
4. The pre-derivation proportion stated (FR-17).
5. No unopened match count reported as a finding (FR-16).

Append a new section to `tests/evals/results.md` following the shape of the entry at `:2495-2539`:
a dated heading, why the body grew and by how much, the method including model and cost, a
`### Verdict` subsection scoring each criterion, and a statement of what the run does not establish.
Record a failure as a failure: an arm that fails is the signal ADR-0001 wants, and the response is to
shorten the body, not to re-run until it passes.

Then clean up the staging directory:

```bash
rm -rf "$d"
```

- [x] **Step 5: Hand over**

```bash
git add tests/evals/results.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "test(evals): record the coding-standards length arm at 876 words"`.
Paste the `git status --porcelain` output into your report.

---

## Delegation

| Task | Where it runs | Why |
|---|---|---|
| 1 | Delegated subagent | Creating one file whose content is given verbatim |
| 2 | Delegated subagent | Two edits to one file, both given verbatim, with measured before and after counts |
| 3 | Delegated subagent | Five edits, all given verbatim |
| 4 | Delegated subagent | Six files, all given verbatim |
| 5 | Delegated subagent | Two edits, both given verbatim, with a real red-green cycle |
| 6 | **Main session only** | Dispatches an arm and scores the reply. A subagent scoring its own arm is an echo, not a measurement |

**For every delegated task**, the implementer brief at
`skills/execute-plan/references/subagent-prompts.md:20-61` now carries a
`=== PROJECT STANDARDS ===` block at `:29-30`, whose placeholder reads
`<paste the rules from <docs_root>/standards.md this task could breach>`. **It must be filled in, not
left as the placeholder.** For every task in this plan the rules that could be breached are the same
three, and they are in this repository's own `docs/standards.md`: no em dash or en dash anywhere; no
project-specific identifier in any shipped file; and skill content names the docs root as
`<docs_root>` rather than a literal path. Paste those three into the block. A subagent sees only what
it is sent, so a placeholder left in place means the rules were not sent at all.

## Out of scope

- **Problem B, making standards bind during coding.** Shipped in `13d90d9` and verified in the tree.
  No task here touches `skills/execute-plan/references/subagent-prompts.md`,
  `skills/write-plan/references/plan-template.md`, or the two corrected claims in
  `docs/02-skill-catalog.md:69` and `:382`.
- **Open question 3, why a loaded rule does not bind.** Untouched. No task depends on its answer,
  because the mode is a procedure that returns findings rather than a rule told to a model.
- **Open question 5, whether the ranked check order holds on a second instance.** Stays open. The
  PRD's decision 1 does not depend on it: all four checks run together whatever the answer, so no
  task here waits on it. It closes when a second repository is assessed, which is not this plan.
- **The SessionStart roster.** No task changes `hooks/session-start`. The roster names skills and
  `coding-standards` is already in it at `:30`. Measured with the validator's own probe
  (`tests/validate-skills.sh:340-356`), the worst case across all four `response_style` and
  `explain_level` combinations is 1,266 characters and 351 tokens against the 356 token rule at
  `:364-366`, leaving 19 characters. A mode needs none of them.
- **The skill count claim** at `README.md:6`, enforced by `tests/test-doc-claims.sh:45-47`. A mode is
  not a skill, so 25 stays 25.
- **`skills/repo-snapshot/references/section-templates.md`.** The mode creates a third state,
  present but unassessed, which that template has no row for. Raised as Q5 in the PRD and not
  reopened here.
- **Stale prose in `tests/evals/README.md`.** Lines 68 and 103 say "seven-arm gate" and "Seven
  scenarios" against a tree that already had eight before this plan. That drift predates this work,
  is not test-enforced, and fixing it here would be scope creep. It is worth its own small change.

## Changes that landed outside the task that made them

Recorded because the plan is the contract and these were not in it. All four are correct and none is
reverted; the defect is that the plan did not say so, which is exactly what makes a diff hard to
review against its own plan.

| Change | Task that carried it | Why it is not in that task's steps |
|---|---|---|
| `tests/test-eval-harness.sh`, the `first` and `points` variables and a fifth condition asserting the pin resolves to commit 1 | 4 | Added after review found case 17 asserted only that the placeholder was gone, so a `setup.sh` pinning HEAD would have passed. The plan's case 17 block was never updated to match |
| `README.md`, a paragraph explaining why `assess-a-stale-standard` sits outside the release gate | 4 | Step 8 specifies replacing `8 scenarios` with `9 scenarios` and nothing more. Without the paragraph the gate arithmetic does not close: nine scenarios, six at the gate, two explained |
| `tests/evals/fixtures/README.md`, the corrected sample and departure rows | 6 | Task 6 says "Stage exactly that path and stop" for `results.md` alone. The arm falsified two rows of the fixture's own record, and leaving a known-false durable record to keep a task's surface clean is the wrong trade |
| `docs/02-skill-catalog.md`, the `incident-response` **Writes:** line | 3 | **Scope creep, and it stays.** That line was already wrong before this branch: the feature does not make it false. It was corrected because it had just been consulted as authority and found stale. It wants its own commit and did not get one, because extracting it would mean rewriting six commits of otherwise sound history to relocate a single line. The follow-up it implied, that nothing scaffolded or documented `incidents/`, is fixed separately in its own commit |

## Reviewer findings, and what was done with each

A reviewer read this plan against the repository before hand-off, per
`skills/write-plan/references/plan-review.md`. It returned four blocking findings, all four real and
all four fixed. Recorded here rather than dropped, because the next reader will want to know the plan
was wrong once.

| Finding | Action |
|---|---|
| The plan document itself made the suite red: a markdown link in task 1's prose resolved against `docs/plans/` | Fixed. The Interfaces line no longer contains link syntax. Found and fixed independently before the review landed |
| Task 4's `src/payouts.sh` sourced `money.sh` via `$0`, which in a sourced file is the caller's, so every money function was undefined and the fixture suite was red | Fixed with `${BASH_SOURCE[0]}`, the idiom four existing fixtures already use. The corrected code was run before this plan was rewritten and produces exactly the PASS lines the step claims |
| The mode block measured 191 words, not 150, landing the body at 874 rather than 833 | Fixed by moving per-check discipline into the reference file. Measured at 173 and 876. See the note under the decisions table |
| Task 6 read `$d/prompt.txt`; `tests/evals/stage.sh:38` writes `prompt.md` | Fixed |
| The staged arm cannot read `references/house-defaults.md`, so check 1 cannot produce a real coverage table | Accepted and scoped. Task 5's criteria now measure whether the body is followed, which is what ADR-0001 asks, and an arm that reports check 1 as not covered passes |
| The fixture had no git history, so FR-17 and the report header were unmeetable | Fixed. Task 4 step 4 adds a `setup.sh` building two commits, with the derivation commit genuinely preceding the drift |
| Task 4's predicted check-1 findings did not follow from the index | Fixed, then superseded. The first re-derivation gave five applicable and four skipped whole; the version 2 fixture changed the stack, and the shipped answer is three applicable with `data-protection.md` the only one skipped whole. `tests/evals/fixtures/README.md` is the durable record |
| No `tests/test-eval-harness.sh` case and no `tests/evals/fixtures/README.md` entry for the new fixture | Fixed. Both are now task 4 step 5 |
| The audits naming convention had no home: the PRD names a table in `docs/02-skill-catalog.md` that does not exist | Fixed. It goes in the `bin/keel` scaffolded README heredoc, which is the table the PRD meant |
| FR-23's "no other file" clause and NFR-06 were in no output text | Fixed. The mode block now says "Change nothing else, run nothing that alters the project" |
| Task 6 named no model for the dispatch | Fixed. `claude-opus-5[1m]`, with the reason |
| The description reads awkwardly at 213 characters | **Fixed during task 2's review.** Moving the clause to sit directly after `conventions` puts the pronoun beside its antecedent and measures 212, one character shorter than appending it. The original note here was wrong to call it unfixable: it assumed the clause had to go at the end |
| Task 3 dropped the trigger phrase "enforce style" from `docs/prompting.md:34` and `templates/prompting-cheatsheet.md:33`. PRD section 15 says add the assess phrasing, not replace one, and the phrase exists nowhere else in the repository | Fixed by the supervising session, 2026-09-01. Both replacement rows now carry all four phrasings |
| Task 4 contradicted itself on the coverage gap | Superseded. Both numbers in that row describe the version 1 fixture, which was replaced. The shipped fixture has three applicable references and one skipped whole, recorded in `tests/evals/fixtures/README.md` and confirmed by the 2026-09-01 arm |
| Citations to `tests/validate-skills.sh` start on the explanatory comment, one to six lines above the check | **Not fixed.** Deliberate. This repository's comments carry the reasoning, and a reader sent to the comment learns why the check exists |

## What this plan could not settle

Nothing blocks execution. Three things are recorded because a later reader will want them.

1. **FR-24's trend section has no natural key in a document that carries no identifiers.** This plan
   settles it by matching on whatever identifier the assessed `standards.md` itself uses, which works
   for the task 4 fixture because that document numbers its items F-1, F-2, D-1 to D-4. A document
   with unnumbered items would fall back to matching on the item's first clause, which is fragile.
   The durable fix is the rule-identifier work deferred as Q2 in the PRD.
2. **A2, that two runs agree on which house-defaults references apply**, is untested by this plan.
   Task 6 runs one arm. The assumption is falsified only by two runs disagreeing on an unchanged
   tree, and a second run is the first success metric in section 9 of the PRD rather than a task
   here.
3. **A staged eval arm cannot read a skill's references at all.** `tests/evals/run.sh:26-29` injects
   `SKILL.md` and nothing else, and the working directory is outside this repository. That is fine
   for a length arm, which is all ADR-0001 asks for, but it means no eval in this repository can
   ever exercise a skill whose behaviour depends on a reference file. Several skills now have that
   shape. Widening `run.sh` or `stage.sh` to stage the references is a change to the harness and
   belongs in its own piece of work, not here.

## Why the eval work was split out

Task 1 was implemented four times. Every rejection was a defect in the content this plan specified,
never in the transcription, which came back byte-identical each time. That is a signal about where
the risk sits in a plan of this shape: not in the building, in the specifying.

So before dispatching task 2, the same review was run against the content tasks 2 to 5 specify,
ahead of any implementer rather than after one. Tasks 2 and 3 came back clean, with every quoted
line number matching the tree and both budget numbers confirmed by measurement on a scratch copy.
Tasks 4 and 5 came back with five blocking findings, and the shape of them is what decided the
split:

1. **The fixture ships a comment naming its own seeded defect**, `# Drift: the fee is computed in
   floating point, which section 1 forbids.` `tests/evals/fixtures/README.md:14-18` forbids exactly
   this: "Nothing in a fixture may describe the exercise". It hands the arm check 3's finding.
2. **A note written for the engineer landed inside the artifact.** The three lines explaining
   `${BASH_SOURCE[0]}` and citing another fixture sit inside the shipped source, telling the arm it
   is running inside a keel eval fixture.
3. **The plan contradicts itself on how many house-defaults references apply**, four in task 4's
   step 2 and five in its step 3, and that number is pinned into a permanent record in
   `tests/evals/fixtures/README.md`.
4. **D-2's stated basis does not survive re-verification**, so the `stale reason` category is not
   empty as predicted. The fixture's whole design rests on each check finding one definite thing.
5. **Task 5's scenario scores the arm on two criteria the injected body never asks for**, having
   argued in its own prose that only the body is visible. That is the same defect that got task 1
   rejected three times: a rule and its worked criteria disagreeing inside one block.

Findings 1 and 2 are one mistake made twice: prose meant for a reader of the plan ending up inside
an artifact meant for an agent under test. Findings 3, 4 and 5 are all the fixture's design being
asserted rather than derived.

None of that is patchable in place. A fixture whose predicted findings are wrong produces an arm
that scores the wrong thing, and an arm that scores the wrong thing is worse than no arm, because
ADR-0001 will then have a passing record against a body nobody actually measured. The next plan
starts from the pre-review's own re-derivation of what applies and what each check would find, which
is a better specification than the one written here.

**What the split left open, since closed.** At the time of the split `coding-standards` landed at
876 words with no eval arm recorded, and this paragraph recorded that debt. The arm was run on
2026-09-01, failed, the body was corrected, and the re-run passes. Both are in
`tests/evals/results.md` and NFR-03 is met. The original wording follows.

`coding-standards` lands at 876 words with no eval arm recorded.
`tests/validate-skills.sh` warns on every run,
`coding-standards: body is 876 words, over the 700 target (ceiling 900). ADR-0001 requires a passing
eval arm at this length.` That warning is the obligation, and it stays on screen until the arm is
recorded. NFR-03 and NFR-08 of `docs/prd/standards-assessment.md` are not met by this plan and are
not marked as met.
