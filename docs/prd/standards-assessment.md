# PRD: standards assessment mode

| | |
|---|---|
| Status | approved. All FRs and NFRs delivered 2026-09-01. NFR-03 met on the second arm, at 876 words, after the body was corrected; the first arm failed FR-25 and both are recorded in `tests/evals/results.md` |
| Mode | from-idea |
| Author | Claude, in session with Bernard |
| Date | 2026-09-01 |
| Derived from | `docs/ideas/standards-that-bind.md`, and this conversation, at commit `13d90d9` |
| Approved by | Bernard, 2026-09-01 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

Of the 25 functional requirements below, **15 were stated by Bernard** in the brief for this PRD or
settled in `docs/ideas/standards-that-bind.md`, 4 are inferred from keel's own files, and **6 are
author-added**: FR-05, FR-07, FR-08, FR-09, FR-21 and FR-24. Nobody asked for those six and nothing
in the record implies them. Four of them (FR-07, FR-08, FR-09, FR-21) exist because the record's
headline number turns out not to be reproducible, which is set out under FR-08. Their rows say so,
because a requirement that was invented stays cheaper to delete than one that was requested.

Of the 7 non-functional requirements, 6 are confirmed and NFR-06 is inferred. The 5 constraints are
all inherited rather than chosen here.

## 1. Executive summary

`coding-standards` writes a project's `standards.md` and never reads one back
(`skills/coding-standards/SKILL.md:16-79`, five authoring steps with no branch that reads an existing
document, confirmed by a directory-wide search finding no mention of assessing, auditing or
re-checking one). A repository whose standards document is a year old has no way to find out which
parts of it are still true.

This adds a second mode to that skill. Given an existing `standards.md`, it runs four checks in a
fixed order and writes a dated report to `<docs_root>/audits/YYYY-MM-DD-standards.md`. It never
edits the document it is checking.

It is for whoever inherits or maintains a repository that already has a standards document: the
person who has the document, has read it, and still cannot say which of its sections has decayed.
It matters now because the instance recorded in `docs/ideas/standards-that-bind.md:47-280` found
that four checks against one document returned four different verdicts, that one check
found far more than the other three, and that the authoring pass itself had left violations of its own rules unreported
in the very files it derived them from (`docs/ideas/standards-that-bind.md:214-218`).

## 2. Problem statement

A standards document is written once and read by one skill, over a diff. `review-code` is that skill
and its scope is defined over changed lines (`skills/review-code/SKILL.md:21`,
`skills/review-code/references/rubric.md:61-63`). Nothing reads the document as a whole against the
tree as a whole, so a document decays silently and the decay is only discovered by whoever next
trips over it.

**Evidence**, from the instance measured on 2026-09-01 and written up at
`docs/ideas/standards-that-bind.md:47-280`. A 1,271 line document, 169 commits and 325 changed files
past the commit it was derived from (`:53-60`):

- **House-defaults coverage**: four applicable topic references skipped wholesale with no departure
  recorded, which is 28 of the 65 rules the applicable references hold (`:115-124`). No code needs
  reading to find this.
- **The follow-up backlog**: 10 of 15 follow-up items still open, nothing on the "not yet
  mechanical" list became mechanical, and one hand fix covered a narrower scope than its own item
  asked for, invisibly, because the mechanism that would have caught the remainder was the half of
  the item never built (`:141-180`).
- **A judgement sample**: an unquantised write into a money column that four security audits, two
  code reviews and the document itself had all missed (`:200-212`).
- **The departures ledger**: came back clean apart from one missing ADR (`:239-268`).

**What this costs is an information gap, not a quality gap** (`:270-279`). Five of six sampled
judgement rules were fully or near-fully observed. The cost is that four checks give four answers
and nobody can tell in advance which one to run.

## 3. Goals and non-goals

**Goals**

- Someone holding an existing `standards.md` can find out which of its parts the tree still supports, in one request.
- The answer lands as a dated artifact that a later run can be compared against, so drift is visible over time rather than only at the moment somebody asks.
- The four checks run in the order the instance measured, because that order is the finding (`docs/ideas/standards-that-bind.md:652-653`).
- `coding-standards` stays inside its budgets: 900 body words (`tests/validate-skills.sh:23`) and a 216 character description.

**Non-goals**

- Making standards bind during coding. That is problem B, and it shipped in `13d90d9`. See section 11.
- Fixing anything the assessment finds. The mode reports; it does not remediate.
- Replacing `review-code`. A diff-scoped review and a whole-document assessment answer different questions.

## 4. Users and personas

- **The inheriting maintainer.** Has a repository with a `standards.md` written by somebody else, possibly months ago. Knows the document exists, does not know which parts survived. This is the instance's own case (`docs/ideas/standards-that-bind.md:54-56`).
- **The document's own author, later.** Wrote the standards, has since merged 169 commits, and wants to know what the document no longer describes.
- **A coding agent running the skill.** The immediate consumer of the skill body. It has the 900 word ceiling's attention budget and nothing else, which is why the report format lives in a reference file rather than in the body (NFR-04).

## 5. Functional requirements

### 5.1 Mode selection and trigger

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | The skill must select between author mode and assess mode from the words of the request, before reading `standards.md` or any source file. | confirmed | Brief item 1, this conversation, 2026-09-01. The router admits one skill per request (`skills/keel/SKILL.md:42`), so the distinction cannot be deferred to a second routing pass |
| FR-02 | The router row that reaches `coding-standards` must carry at least one assess phrasing alongside its existing author phrasings. Today it reads `\| what are our conventions, set up linting \| coding-standards \|`. | confirmed | `skills/keel/SKILL.md:28`; brief item 1 |
| FR-03 | Asked to assess when no `<docs_root>/standards.md` exists, the skill must say that no document exists and offer to author one. It must not silently author one. | confirmed | Brief item 1, which asks explicitly what happens in this case |
| FR-04 | Asked to author when a `<docs_root>/standards.md` already exists, the skill must name the existing document and ask before overwriting it. | inferred | `docs/ideas/standards-that-bind.md:336` records that the skill's step 4 writes the document with no branch for an existing file, checked by reading rather than by running |
| FR-05 | Where the request's words fit both modes and a `standards.md` exists, the skill must ask which is wanted, as one question. | author-added, see note | Follows from FR-01 and FR-04. Nobody asked for it; delete it and the skill guesses |

Note on FR-05: it is cheap to delete. If it goes, FR-04's ask absorbs the ambiguous case at the cost of a wrong first guess.

### 5.2 Check 1, house-defaults coverage

Ranked first on yield: the largest finding in the instance (`docs/ideas/standards-that-bind.md:438-440`),
and the largest again on the second, 51 of 76. Not cheapest to run, which is what the first instance
claimed: section 16 measured it the most expensive of the four.

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-06 | Check 1 must read exactly three inputs: the project's `standards.md`, `skills/coding-standards/references/house-defaults.md` and the topic references it indexes, and `.keel/profile.json`. It must not read project source code. | confirmed | `docs/ideas/standards-that-bind.md:438`, "No code is read at all" |
| FR-07 | For each of the ten indexed topic references, the report must record an applies or does-not-apply verdict and the fact that decided it. | author-added, see note | The index gives ten prose predicates at `skills/coding-standards/references/house-defaults.md:18-27`. Only one, `frontend.md` at `:27`, names profile fields (`profile.stack.has_ui`, `profile.stack.framework`). The other nine are judgements a second run can make differently |
| FR-08 | The report must state the counting unit it used for "rules" and the per-file denominator that unit produces, both for applicable references and for the rules it reports as folded in, adapted, departed from, or omitted. | author-added, see note | See the reproducibility note below |
| FR-09 | Where a whole applicable reference has no rule-level content in `standards.md` and no departure row recording the choice, the report must name it as a skipped reference distinctly from an individually omitted rule. | author-added | `docs/ideas/standards-that-bind.md:115-124` treats these as the headline finding, and they are the only part of it that survived the tally's withdrawal, because they rest on zero-hit greps rather than on a count |
| FR-10 | Check 1 must be assessable against `skills/coding-standards/SKILL.md:69-71`, which requires the house defaults to be included "noting any this project deliberately departs from". A rule neither folded in nor recorded as a departure is a coverage failure. | confirmed | `skills/coding-standards/SKILL.md:69-71`; `docs/ideas/standards-that-bind.md:136-138` |

**Why FR-08 exists.** The record's first version of this finding reported "76 house rules assessed:
9 folded in, 9 adapted, 1 departed, 58 silently omitted", with per-reference ratios. That tally has
since been withdrawn (`docs/ideas/standards-that-bind.md:102-113`) on three grounds: its parts summed
to 77 rather than 76; its denominators matched no counting unit that can be applied consistently
across the files; and its numerators cannot be re-derived, because that needs the assessed project's
own `standards.md`.

The record now settles the unit (`docs/ideas/standards-that-bind.md:81-86`): one house rule is one
H2 section of a topic reference that states a rule, excluding each file's trailing checklist
sections. On that unit the nine references applicable to that project hold **65 rules** and all ten
hold 69 (`:87-99`), and the four skipped wholesale account for 28 of the 65 (`:115-124`).

FR-08 exists so the mode never reproduces the original mistake. Without a stated unit and a stated
denominator, two runs produce different numbers from the same corpus and the comparability NFR-05
requires is lost. FR-08 does not fix the deeper problem, which is that no rule in the ten references
carries an identifier, so an omitted rule can be counted but not named. That was put to Bernard on
2026-09-01 and deferred: see Q2.

### 5.3 Check 2, the follow-up backlog

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-11 | Check 2 must re-derive each follow-up item and each known inconsistency in `standards.md` against the tree at HEAD, rather than trusting the document's own status text. | confirmed | `docs/ideas/standards-that-bind.md:442` |
| FR-12 | For any item the document records as done, the report must state what the fix actually covered, established from the tree, and must not rely on the fix's commit message. | confirmed | Brief item 2; `docs/ideas/standards-that-bind.md:446-447`, "Check what a fix actually covered, not what its commit message claims" |
| FR-13 | Each item must be reported in one of exactly three states: closed, partially covered, or open. A partially covered item must name what is not covered. | inferred | The instance's tally is "4 closed, 1 partial, 10 open" (`docs/ideas/standards-that-bind.md:157`), which is this vocabulary |
| FR-14 | Where an item asked for both a fix and a mechanism, the report must state the two separately. | confirmed | `docs/ideas/standards-that-bind.md:162-180`, where the fix shipped, the mechanism did not, and the gap is invisible in consequence |
| FR-26 | Check 2 must read exactly three inputs: the document's follow-up and known-inconsistency sections, the tree at HEAD, and git history. It must not treat the document's own status text or a fix's commit message as evidence of state; both are the claim under test, not a source. | confirmed | Symmetry with FR-06, requested 2026-09-01. The failure this bounds is `docs/ideas/standards-that-bind.md:162-180`, where a fix's stated scope and its actual scope differ |

### 5.4 Check 3, the judgement sample

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-15 | Check 3 must measure up to eight rules drawn from the document's judgement sections across the tree, taking all of them where fewer exist, and report a conforming-to-total ratio for each. **Amended 2026-09-01, from "six to eight".** Six read as a floor, which pushes an agent assessing a short document to pad the sample; the fixture holds exactly six and a shorter document could not meet it. | confirmed | `docs/ideas/standards-that-bind.md:449` |
| FR-16 | Every imprecise pattern match must be opened and hand-verified before it is reported. A raw match count is not a finding. | confirmed | Brief item 2; `docs/ideas/standards-that-bind.md:452-454`. In the instance all seven apparent leaks were conforming once opened |
| FR-17 | The report must state what proportion of the tree predates the commit the document was derived from. | confirmed | Brief item 2; `docs/ideas/standards-that-bind.md:452-454`. 78 percent in the instance (`:62-63`) |
| FR-18 | A finding must state whether it is reachable in production, and must not be presented at a severity its reachability does not support. | inferred | `docs/ideas/standards-that-bind.md:220-231`: the instance's unguarded interpolation sites are unreachable and the record requires they "must not be written up as an injection bug". Cross-check `skills/coding-standards/SKILL.md:29-32` |
| FR-27 | Check 3 is the only check that reads project source code, and it must read it only in service of the rules it sampled. It must not report a finding outside those rules, and must not use git history for anything except the pre-derivation proportion FR-17 requires. | confirmed | Symmetry with FR-06, requested 2026-09-01. Without the bound the check becomes an unscoped code review, which `review-code` already owns over a diff (`skills/review-code/references/rubric.md:104-106`) |

### 5.5 Check 4, the departures ledger

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-19 | Check 4 must classify every departure into exactly one of six categories: closed; tracked; kept with its basis re-verified and holding; requires an ADR that does not exist; kept on a reason the tree no longer supports; unclassifiable. **Amended 2026-09-01, from four.** Four had no row for the healthy end state, a permanent departure whose ADR exists and whose basis still holds, so it fell to `unclassifiable` and was counted as a finding. In the founding instance that is four of fifteen departures. | confirmed | `docs/ideas/standards-that-bind.md:456-457`, per `skills/coding-standards/references/standards-template.md:85-87` |
| FR-20 | A departure that fits none of the four must be reported as unclassifiable, naming what it carries instead. | inferred | The instance produced exactly one such row, a departure naming a skill rather than a tracking item (`docs/ideas/standards-that-bind.md:251`) |
| FR-21 | Where a category is empty, the report must say so explicitly rather than omitting the row. | author-added | `docs/ideas/standards-that-bind.md:459-460`, "A check that comes back clean is a result". The instance's empty category is reported as a row rather than dropped (`:219`). The record states the principle; making it a report requirement is this PRD's addition |
| FR-22 | For each departure ruled "keep", the report must re-verify the stated factual basis against the tree and record the result. | confirmed | `docs/ideas/standards-that-bind.md:253-258`, where all four keep rulings were re-verified and the counts behind one had grown |
| FR-28 | Check 4 must read the departures section and the tracking artifacts its rows name, such as the ADR directory. It may read project source only to re-verify a factual basis a row actually asserts, per FR-22, and must not extend to facts the row does not claim. | confirmed | Symmetry with FR-06, requested 2026-09-01. In the instance the re-verification touched exactly the facts the rows stated, four of them (`docs/ideas/standards-that-bind.md:253-258`) |

### 5.6 The report

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-23 | The mode must write `<docs_root>/audits/YYYY-MM-DD-standards.md` and must not create or modify any other file. In particular it must never edit `standards.md`. | confirmed | `docs/ideas/standards-that-bind.md:462-463`; the existing form of this rule is `skills/security-audit/references/report-template.md:105`, "Nothing in an audit modifies what is being audited" |
| FR-24 | Where a report for the same repository already exists under `<docs_root>/audits/`, the new report must carry a trend section stating what closed, what is new, and what has been open longest. | author-added | The shape already exists at `skills/security-audit/references/report-template.md:85`, section 6. Applying it here is this PRD's addition, and it is what makes NFR-05 observable rather than aspirational |
| FR-25 | All four checks must run on every assessment, and the report must present them in the CON-02 order with each check's finding count stated separately. | confirmed | Decision 1 in section 14; `docs/ideas/standards-that-bind.md:433-460` |

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | The `coding-standards` body must stay at or under the 900 word ceiling. Measured: the body is 876 words as shipped, from 683, with 193 words of mode text. The 150 and 833 this row first carried were measured against a draft that lacked three of the requirements. | confirmed | `CEILING_WORDS=900` at `tests/validate-skills.sh:23`; `body_of()` at `:85`. Measured by `awk 'f;/^---$/{c++; if(c==2) f=1}' skills/coding-standards/SKILL.md \| wc -w` giving 683, and 833 for the body concatenated with the 150 word draft |
| NFR-02 | The `coding-standards` description must stay at or under 216 characters. Measured: 181 today, 213 with a 32 character assess clause appended. | confirmed | `DESC_MAX_CHARS=216` at `tests/validate-skills.sh:39`, enforced per skill at `:110-111`. Description at `skills/coding-standards/SKILL.md:3`; measured with `printf '%s' "<description>" \| wc -c` |
| NFR-03 | Because 876 crosses the 700 warning, a passing eval arm at that length must be recorded in `tests/evals/results.md` before the change is considered done. | confirmed | ADR-0001, quoted at `docs/decisions/ADR-0001-skill-body-word-ceiling.md:48-51`: "A skill body over 700 words requires a passing eval arm at that length, recorded in `tests/evals/results.md`, so the room is taken against observed behaviour rather than against an assertion" |
| NFR-04 | The report format must live in `skills/coding-standards/references/`, not in the skill body, and the body must reference it in one line. | confirmed | References are unbounded (`tests/validate-skills.sh:161-162`, `docs/05-token-and-memory-design.md:49`). The precedent is `skills/security-audit/SKILL.md:63` pointing at `references/report-template.md` |
| NFR-05 | Two assessments of the same repository at different dates must be comparable without re-reading either tree: same section order, same per-check counts, same vocabulary. | confirmed | Brief item 3 |
| NFR-06 | The mode must make no network request and must not run any command that modifies the repository being assessed. | inferred | `skills/security-audit/references/report-template.md:105-112` states this rule for audits, including that a check needing a change in order to pass belongs in "Not covered" rather than in the findings |
| NFR-07 | The mode's text must name the output path as `<docs_root>/audits/...`, never a literal `docs/keel/...` path, and the body's link to the new reference file must resolve. | confirmed | The hardcoded-path check at `tests/validate-skills.sh:161-168` reports "hardcodes a docs/keel path. Use `<docs_root>`"; the broken-link check is at `:148-153`. Both apply to references as well as bodies (`:161-162`) |
| NFR-08 | **Prerequisite for NFR-03.** An eval fixture carrying a `<docs_root>/standards.md` and a tree that measurably drifts from it must exist before the ADR-0001 arm can run, together with the scenario file that resolves it. No fixture has one today. | confirmed | `find tests/evals/fixtures -name standards.md` returns nothing. Both `tests/evals/stage.sh:26` and `tests/evals/run.sh:11` resolve an arm through `tests/evals/scenarios/<name>.md`, so an arm cannot run without one. Unlike the `write-prd` length arm (`tests/evals/results.md:2509-2513`) this one can reuse nothing |

**What the NFR-03 arm must demonstrate.** ADR-0001's purpose for the arm is stated at
`docs/decisions/ADR-0001-skill-body-word-ceiling.md:123-125`: "A skill that crossed 700 and whose arm
later fails is the direct signal that its body outgrew what the model will follow." So the arm must
show the body is still followed at 876 words, specifically that: assess mode is entered from the
request's words rather than authoring being started (FR-01); all four checks run and appear in the
report in the ranked order (FR-25); `standards.md` is not modified (FR-23); and the two
honesty requirements are observed, meaning the report states the pre-derivation proportion (FR-17)
and no unopened match count is reported as a finding (FR-16). The precedent for recording an
ADR-0001 length arm without adding it to the release gate is
`tests/evals/results.md:2495-2539`.

## 7. Constraints

| ID | Constraint | Imposed by | Evidence |
|---|---|---|---|
| CON-01 | The mode goes inside `coding-standards`. Not a new skill, not a widened `review-code`. | The idea record, already decided | `docs/ideas/standards-that-bind.md:379-383`. A widened `review-code` contradicts its own skill's principle at `skills/review-code/SKILL.md:16-22` and voids its changed-lines scope; a new skill loses on the router's one-skill rule (`skills/keel/SKILL.md:42`) and on the roster |
| CON-02 | The four checks run in the order given: house-defaults coverage, backlog, judgement sample, departures ledger. | The idea record | `docs/ideas/standards-that-bind.md:433-460`, and `:617-618`: "a mode that lists the checks without ranking them throws away the only thing this instance taught" |
| CON-03 | Output is a dated report under `<docs_root>/audits/`, never an edit to `standards.md`. | The idea record, answering its own open question 4 | `docs/ideas/standards-that-bind.md:462-463, 589-593` |
| CON-04 | Any repository used as an example in keel's own documents or fixtures carries a generic name. Naming a real client repository fails the suite. | keel | `tests/no-internal-leaks.sh`, which fails on project-specific identifiers. The instance is `payments-api` throughout |
| CON-05 | No em dash, no en dash, no dash longer than a hyphen, anywhere. | keel's writing rules | Applied throughout this document |

## 8. Observed but not required

Not applicable, because this is `from-idea` mode. The section exists to stop an accident in an
existing codebase being promoted to a requirement, and there is no existing implementation of this
mode to observe.

## 9. Success metrics

| Metric | Target | Source |
|---|---|---|
| A second repository is assessed and its report's per-check finding counts are recorded | 1 assessment, no target date set | Answers Q1 below, which is the record's own open question 5 (`docs/ideas/standards-that-bind.md:625-632`) |
| The ranked order survives that second assessment, or is replaced by "run all four unranked" | Decided rather than left open | `docs/ideas/standards-that-bind.md:625-632` |
| `tests/validate-skills.sh` reports `coding-standards` at or under 900 words after the change | 876 words, 0 failures | `tests/validate-skills.sh:23,85` |
| The NFR-03 eval arm passes and is recorded | 1 recorded arm | `docs/decisions/ADR-0001-skill-body-word-ceiling.md:48-51` |

No metric is offered for whether assessments change behaviour. `Unknown, needs a decision`, and it
is Q3.

## 10. Milestones

`Unknown, needs a decision.` None were given.

## 11. Out of scope

- **Problem B, making standards bind during coding.** Already shipped in `13d90d9`, verified in the tree: the `=== PROJECT STANDARDS ===` block is now in the implementer prompt at `skills/execute-plan/references/subagent-prompts.md:29` as well as the review prompt at `:114`; the plan template names the standards document at `skills/write-plan/references/plan-template.md:28` with an example at `:34`; `docs/02-skill-catalog.md:69` now reads "Enforced by nothing at coding time"; and `:382` now reads "Not `<docs_root>/standards.md`, which this line claimed".
- **Open question 3, why a loaded rule does not bind.** Untouched by this work and still open (`docs/ideas/standards-that-bind.md:615-618`). No requirement here depends on its answer, because the mode is a procedure that returns findings rather than a rule told to a model.
- **Answering Q1, whether the ranked order generalises.** Still open, and deliberately not blocking. Section 14's decision 1 runs all four checks together whatever the answer, so nothing in this PRD waits on it. It closes when a second repository is assessed and its per-check finding counts are recorded, which is the first row of section 9. It carries in the idea record as its open question 5 (`docs/ideas/standards-that-bind.md:625-632`).
- **Remediating anything an assessment finds.** The mode reports. Fixes route to the skill the finding names.
- **`keel doctor` warning when `gates.coding_standards` is `required` and no `standards.md` exists.** Left undecided by the record (`docs/ideas/standards-that-bind.md:684-685`) and not reopened here.
- **Whether `refactor` and `debug` should read the standards document.** Left undecided by the record (`:680-682`).

## 12. Assumptions

| # | Assumption | Falsified if |
|---|---|---|
| A1 | The instance's ranked order generalises beyond one repository. | A second assessment finds the ranking inverted, in which case CON-02 becomes "run all four, unranked". This is Q1 |
| A2 | An agent can determine applicability from the nine prose predicates in the house-defaults index consistently enough for two runs to agree. | Two assessments of the same unchanged repository disagree on which references apply. FR-07 is what makes this observable |
| A3 | ~~150 body words is enough to carry four checks and their order.~~ **Falsified 2026-09-01, in exactly the way this row predicted.** The first arm followed the mode and not the ranking. 150 was never shipped; 182 was, the arm failed, and 193 passes | The falsification test is spent. What is now assumed is that 193 is enough, on one arm |
| A4 | An assessment that reports without remediating is useful. | Reports accumulate and nothing closes. The FR-24 trend section is what would show it |

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | ~~Does the ranked order hold on a second instance, or does it collapse to "run all four"?~~ | A second assessment | **Answered 2026-09-01: the order is wrong on cost and right on yield.** See section 16 |
| Q2 | Should the ten topic references gain stable rule identifiers, so an omitted rule can be named rather than counted? | Bernard | **Answered 2026-09-01: not now.** FR-08 stands as written, so the mode states its counting unit and per-file denominator and the number becomes reproducible without identifiers. Identifiers stay deferred: ten files of edits, no skill-word cost, larger than the mode itself, and wanting their own PRD |
| Q3 | Is there a success metric for whether an assessment changes anything, or is the artifact the deliverable? | Bernard | Section 9 |
| Q4 | Does the NFR-03 arm get a fixture of its own, given that no existing fixture has a `standards.md`? | Bernard | **Answered 2026-09-01: yes, and it is now NFR-08**, an explicit prerequisite rather than a question, so a plan cannot miss it. The residue, whether the new scenario joins the release gate, was also settled: it does not. The gate stays at six, following the `write-prd` precedent (`tests/evals/results.md:2497-2499`). Nothing in Q4 is open |
| Q5 | Should `repo-snapshot`'s section template gain a "present but unassessed" state, now that one is detectable? | Bernard | Nothing in this PRD. Raised because the mode creates the state (`skills/repo-snapshot/references/section-templates.md:147,227`) |

## 14. The two decisions this PRD closes

**Decision 1: the four checks always run together, in the ranked order. They are not independently
selectable.** Three reasons, and the third is the one that decides it.

1. Selectability costs body words. A scope table on the `security-audit` model costs 52 words including its gate line (`skills/security-audit/SKILL.md:16-23`), against 24 words of headroom under the ceiling at 876, so it no longer fits at all. (NFR-01). It fits, but barely, and it buys nothing the mode needs.
2. The ranking is the finding (`docs/ideas/standards-that-bind.md:652-653`). A mode whose first offer is "pick a check" presents the ranking as a menu rather than as a result.
3. **It is the only way Q1 gets answered.** If checks are selectable, users will run check 1, because the record advertises it as the highest-yield check. The ranking would then never be tested on a second repository, and open question 5 could never close. Running all four every time is what produces the per-check evidence that answers it.

**This decision does not depend on Q1**, which is what the brief asked to be established. If Q1 comes
back saying the ranking does not generalise, CON-02 loses its ordering and the four checks still run
together. The decision would only be reopened by a cost finding, that running all four is too
expensive on a large repository, which nothing currently suggests.

**Decision 2: the `-standards.md` suffix is stated as a convention, in one place.** The rule is that
a dated report under `<docs_root>/audits/` is named `YYYY-MM-DD-<kind>.md`, where `<kind>` is the
noun of the skill that wrote it: `security` for `security-audit` (`skills/security-audit/SKILL.md:63`),
`standards` for this mode.

It is stated once, on the `audits/` row of the scaffolded documentation table that `bin/keel`
writes, and each skill's report reference follows it. It is **not** in
`docs/02-skill-catalog.md`, which has no such table; an earlier draft said it was. It is not stated in `write-docs`, which would
cost body words in a skill that gains nothing from the rule.

The record's own observation is the argument for stating it at all: in the instance, two of the four
files in the audits directory did not follow the `-security.md` pattern
(`docs/ideas/standards-that-bind.md:619-624`). An unstated convention drifted in the one repository
where it was observed.

## 15. What else moves, with its budget cost

Every routing and documentation surface, measured in this repository at `13d90d9`.

| Surface | Line and current text | Edit | Budget cost |
|---|---|---|---|
| Router | `skills/keel/SKILL.md:28`, `\| what are our conventions, set up linting \| coding-standards \|` | Add an assess phrasing to the trigger cell | About 5 words on a 553 word body with 147 spare to the 700 target (`docs/ideas/standards-that-bind.md:531`) |
| Skill description | `skills/coding-standards/SKILL.md:3`, 181 characters | Append a 32 character assess clause | 213 of 216. Measured |
| Skill body | `skills/coding-standards/SKILL.md`, 683 words | The mode's 193 words | 876 of 900. Measured. Triggers NFR-03 |
| Report format | New file under `skills/coding-standards/references/` | Write it | Zero. References are unbounded (`tests/validate-skills.sh:161-162`) |
| Prompting map | `docs/prompting.md:34`, `\| "what are our conventions", "set up linting", "enforce style" \| coding-standards \| docs/standards.md plus lint config \|` | Add the assess phrasing, and the audits path to the Produces column, following the `security-audit` row at `docs/prompting.md:38` | Zero, documentation. **Not test-enforced**: no test reads this file |
| Cheatsheet template | `templates/prompting-cheatsheet.md:33`, the same row with `{{DOCS_ROOT}}` | Same | Zero. The only check on this file (`tests/validate-skills.sh:312-314`) requires the router's destination name to appear somewhere in it, and `coding-standards` already does, so this edit is for accuracy, not to pass a test |
| Catalog entry | `docs/02-skill-catalog.md:293-308`, "**Does:** two distinct jobs", Derive and Enforce; **Writes:** names only `<docs_root>/standards.md` | Add the third job and the audits output. The catalog already documents modes this way for `security-audit` at `:345-354`, "**Does:** two scopes" | Zero, documentation. Not test-enforced: no test reads this file |
| Scaffolded README table | `bin/keel:499`, `\| \`audits/\` \| \`security-audit\` \|` | Add `coding-standards` | Zero. `bin/keel:482` already creates `audits/` in a scaffolded docs root, so no directory change is needed |
| SessionStart roster | `hooks/session-start:30`, `coding-standards` in the Build line | **No change.** The roster names skills, and the presence check at `tests/validate-skills.sh:323-327` already passes on that mention | Zero |
| Snapshot section template | `skills/repo-snapshot/references/section-templates.md:147,227`, which lists "Coding standards" under **Missing** | Consider, and decide separately: the mode creates a third state, present but unassessed, which this template has no row for | Zero, and out of scope here. Raised as Q5 |
| Skill count claim | `README.md:6`, "25 skills built", enforced by `tests/test-doc-claims.sh:45-47` | **No change.** A mode is not a skill | Zero |

**The SessionStart roster, measured rather than inherited.** Reproducing the validator's own probe
(`tests/validate-skills.sh:340-356`, which measures the whole hook stdout with `wc -c` and estimates
tokens as `chars * 10 / 36`) across all four `response_style` and `explain_level` combinations gives
a worst case of **1,266 characters, 351 tokens**, against the 356 token rule at `:364-366`. That
confirms the record's figure (`docs/ideas/standards-that-bind.md:425-427`).

The record's derived claim is slightly wrong and is corrected here. It says twenty-one characters of
headroom and a maximum new skill name of nineteen characters (`:429-431`). Measured by padding a copy
of the hook, the roster tolerates **19 characters of growth** before crossing 356, so an inserted
name plus its two character separator gives a **maximum name length of 17**. The record's three
sample names (15, 16 and 20 characters) do not discriminate between 17 and 19; 18 fails. This changes
nothing for this PRD, because a mode needs no roster entry, and it strengthens CON-01.

**The eval arm needs a fixture that does not exist, which nothing in the record mentions.** Both
`tests/evals/stage.sh:26` and `tests/evals/run.sh:11` resolve an arm through
`tests/evals/scenarios/<name>.md`, so an arm cannot run without a scenario file. No fixture under
`tests/evals/fixtures/` contains a `standards.md` (`find tests/evals/fixtures -name standards.md`
returns nothing), so unlike the `write-prd` length arm, which reused an existing scenario and fixture
(`tests/evals/results.md:2509-2513`), this arm cannot reuse anything. Adding a scenario file moves
the count claim at `README.md:289`, "8 scenarios exist", which `tests/test-doc-claims.sh:49-51`
enforces. The arm need not join the release gate; the `write-prd` precedent kept the gate unchanged
(`tests/evals/results.md:2497-2499`). This is Q4.

## 16. The second instance, 2026-09-01, and what it falsified

The mode was run in assess mode against a real repository: 388 source files, a 1,271 line
`standards.md`, 169 commits past its derivation commit. Read only, and the report was returned rather
than written, for the reason in defect 2 below. It produced a complete report against every
discipline the reference states. **This is the second instance Q1 needed, and it answers Q1 against
the design.**

### CON-02's ranking is wrong on cost and right on yield

| Check | Measured cost | Findings |
|---|---|---|
| 2, backlog | cheapest by a clear margin | 13 |
| 4, departures | moderate, and reuses check 2's evidence | 5 |
| 1, coverage | most expensive: about 1,500 lines of references before one disposition | 51 |
| 3, sample | tied most expensive, about half the wall clock | 7 |

"Cheapest first" is false. Check 1 is the most expensive on a first run, because an assessor does not
already hold the ten topic references, and `SKILL.md`'s "No code read" is what makes it read as cheap.
The yield claim holds: check 1 found 51 of 76, including three applicable references never opened at
all.

**CON-02 is not withdrawn**, because the ordering it fixes is the report's section order, which is
what makes two runs comparable, and that is unaffected. What is withdrawn is the word "cheapest" as a
justification for it. Anyone re-costing this mode should read the ranking as yield-ordered.

**One counting caveat to carry.** Coverage counts one finding per omitted rule, so a reference nobody
opened contributes seven or eight. "Coverage 51" against "backlog 13" reads as four times more
serious than it is. The header should carry a second number, references skipped whole, which was 3.

### Six defects in what shipped, found by running it

| # | Defect | Where |
|---|---|---|
| D1 | **The reference's worked examples are a real prior assessment's numbers.** The pre-derivation example is "303 of 388 files (78%)"; this run computed exactly 303 of 388. The example cites `partition.service.ts:356,367`; this run independently found `:353,365,383`, the same sites three lines up. An assessor who has read the examples can reproduce them instead of finding them, and cannot tell afterwards which they did | `references/assessment-report.md`, check 3's example block |
| D2 | **On a read-only target the mode cannot run.** Step 0a says write the report; the reference says nothing modifies what is being assessed. Consistent only if a new file under `audits/` is not a modification. Needs a stated fallback: return the report instead | `SKILL.md` Step 0a against `references/assessment-report.md:4-5` |
| D3 | **"Section" is undefined in the sampling rule and the two readings differ six-fold.** The target has 16 H2 sections and about 40 H3. H2 samples across the whole document; H3 samples eight rules all inside the first two sections and never reaches error handling, logging, validation, testing or data access | the sampling rule, check 3 |
| D4 | **No verdict exists for a rule that leaves no artefact in the tree**, and the deterministic rule guarantees one is sampled first. The target's section 0 rule is about what an operator does when a test goes red. All four verdicts would be a false claim | check 3's verdict table |
| D5 | **Check 4's categories do not cover a row that is not a departure.** The target's D-11 reads "Met. No departure"; by the letter it falls to `unclassifiable` and counts as a finding, which is the exact failure the sixth category was added to prevent, one row up. `needs an ADR` versus `stale reason` is also unspecified when both apply | check 4's category table |
| D6 | **"A tracking reference that exists" is unruled** when the reference is an F-number inside the document being assessed. Six rows depended on this reading | check 4, `tracked` |

### One addition the run argues for

A fifth check, nearly free: **do the document's own citations still resolve?** Four were stale in the
target (`main.ts:99` is now `:157`, four TODO line numbers moved, a throw count of nine is now
twelve, a `new Date()` count off by 50). None of the four checks catches this, because a stale
citation is not a rule, a backlog item, a sampled site or a departure. High yield, near-zero cost,
and it is the kind of decay this whole mode exists to surface.

**None of the six defects is fixed here.** They are recorded against the shipped artifacts so the
next change starts from measured behaviour rather than from the design.

