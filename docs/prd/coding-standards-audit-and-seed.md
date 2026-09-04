# PRD: audit and seed modes for `coding-standards`

| | |
|---|---|
| Status | approved, 2026-09-02 |
| Mode | from-idea |
| Author | Claude, in session with Bernard |
| Date | 2026-09-02 |
| Derived from | `docs/ideas/coding-standards-audit-and-seed-modes.md` and `docs/ideas/standards-that-bind.md`, at commit `bad6844` |
| Approved by | Bernard, 2026-09-02. **The hold was released by the arms, not waited out.** Approval was withheld because section 5.1's argument rested on the claim S-01 and S-02 existed to test, so approving it would have signed off that argument in advance. The arms have reported and the argument is overturned by its own evidence, which ends the reason for the hold rather than being a reason to extend it. Section 5.1 is rewritten around the result. **Execution of S-01 and S-02 began before approval**, by a precondition waived by Bernard on 2026-09-02: those two stories test the argument in section 5.3, so they inform the approval rather than follow it. `keel:execute-plan` step 1 otherwise refuses to start against a draft PRD and gives that condition no exception. The waiver covers S-01 and S-02 and nothing else; S-03 to S-13 stay unplanned. Recorded in full under "Precondition waived" in `docs/plans/2026-09-02-derisk-the-coding-standards-restructure.md` |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

Of the 21 functional requirements below, **11 were stated by Bernard** on 2026-09-02 or settled in
the idea record, 3 are inferred from keel's own files, and **7 are author-added**: FR-06, FR-07,
FR-13, FR-16, FR-17, FR-20 and FR-21. Nobody asked for those seven. Five of them exist because the
budget measurement in section 5 came out differently from the estimate the idea record carried, and
their rows say so. A requirement that was invented stays cheaper to delete than one that was
requested.

Of the 8 non-functional requirements, 4 are confirmed and 4 are author-added. The 5 constraints are
all inherited.

## 1. Executive summary

`coding-standards` has two modes. Author writes a project's `standards.md` from its code; assess
checks an existing one against the tree. Two cases fall between them and neither mode serves either.
A brownfield repository with code and no standards document gets author, which writes a document
nobody has agreed to. A greenfield project with neither gets author, which has nothing to derive
from and produces nothing.

This PRD adds **audit**, which derives conventions from a brownfield tree and writes a dated report
rather than a standard, and **seed**, which writes a starting `standards.md` from the house defaults
where there is no code, and reports back which house references were missing for the stack it found.

**The central constraint is the body budget, and it decides the shape rather than decorating it.**
`coding-standards` is 876 words against ADR-0001's 900 ceiling. Section 5 measures what four modes
cost and concludes that **two new mode bodies do not fit, and neither does one, and neither does a
mode-routing table with no new mode prose at all.** The shape proposed here is therefore smaller
than the idea record's: the mode detail moves to `references/`, the body keeps the routing and the
shared steps, and an eval arm proves each mode is still followed with its steps behind a link.

## 2. Problem statement

Three gaps, in the order they were found.

**A brownfield repository gets a standard it never agreed to.** Author mode's five steps end by
writing `<docs_root>/standards.md`. Run on a repository with existing code and no document, that
produces a file asserting the project must do what it currently does, including whatever it does by
accident. `write-prd`'s own step 3 names this as the failure to avoid, and `coding-standards` has no
equivalent separation. What the situation calls for is a derivation somebody reads and ratifies, not
a standard that arrives pre-agreed.

**A greenfield project gets nothing.** Step 1 is "Derive, do not impose", and with no code there is
nothing to derive from. The skill has no branch for it, so the mode a user gets is the one that
cannot run.

**Nothing tells keel when its own library has a hole.** `lib/detect-stack.sh:430` makes `flutter` a
first-class detected framework. `references/house-defaults.md:31` gates `frontend.md` on
`profile.stack.has_ui` being true **and** `profile.stack.framework` not being `flutter`. There is no
`mobile.md`. A Flutter application is therefore a fully supported stack that receives no UI-layer
house defaults at all, and no mechanism anywhere reports that. Verified 2026-09-02.

## 3. Goals and non-goals

**Goals.** A brownfield derivation that is explicitly not a standard. A greenfield starting document
that says where it came from. A report that tells keel's maintainers which house references its
library is missing. All three within the existing word ceiling, with no gate weakened to fit.

**Non-goals.** Changing what author or assess do. Changing the house defaults themselves. Making the
skill enforce anything at the point of work: that is the open question at
`docs/ideas/standards-that-bind.md:624` and section 12 explains why this PRD does not touch it.

## 4. Users and personas

Whoever runs `coding-standards` in a repository, which is one developer at a terminal or an agent
mid-task. Plus, for FR-09 only, a second reader who does not exist in the other modes: **a keel
maintainer**, who is the audience for seed's library-gap report and who is not the person running
the command.

## 5. The budget, resolved

This section is first among the requirement sections because it is what most plausibly kills the
shape, and deferring it to the plan would mean discovering it after the stories were written.

### 5.1 What the body costs today, and why the constraint is discharged

**This section was rewritten on 2026-09-02, after the arms it existed to justify reported.** It used
to argue that nothing could be added to the body and the only question was what came out. That is no
longer true, and what made it untrue is the work this PRD asked for: `4889f7a` moved assess's four
checks into `references/assess.md`, which is FR-19 applied to one mode. The body went from 876 to
**756**, and the four-mode router lands at a measured **795 with 105 words spare**. The constraint
is discharged rather than merely eased, and the honest way to record that is to rewrite the argument
rather than to update a number inside it.

**The counting convention, stated because the whole of this section once disagreed with itself.**
Every figure below is **heading-inclusive**, counted the way `tests/validate-skills.sh:88`'s
`body_of` counts: it keeps every `##` line, so the body it measures starts at `# Coding Standards`.
A first draft of this table mixed the two conventions, taking the step sizes heading-exclusive and
the four-mode router heading-inclusive, and produced a headline number six words wrong in the
direction that made the finding look stronger than it is. The nine rows below sum to 756, the
three-word title above the first heading included, so the convention is self-checking.

Measured at `4889f7a`, section by section, and the rows sum to the total rather than being asserted
against it.

| Section | Words | Author needs | Assess needs | Audit needs | Seed needs |
|---|---|---|---|---|---|
| Overview | 37 | yes | yes | yes | yes |
| Step 0, mode routing | 73 | yes | yes | yes | yes |
| Step 1, derive | 150 | yes | no | **yes** | **no** |
| Step 2, split mechanical from judgement | 111 | yes | no | **yes** | no |
| Step 3, wire the mechanical pile | 133 | yes | no | no | no |
| Step 4, write the judgement pile | 75 | yes | no | no | **yes** |
| Step 5, verify and report | 45 | yes | no | yes | yes |
| Common mistakes | 129 | yes | yes | yes | yes |
| Title, before the first heading | 3 | yes | yes | yes | yes |
| **Total body** | **756** | | | | |

**Assess's row is gone, and that is the whole change.** The 119 words this table used to spend on
Step 0a now sit in `references/assess.md`, and a passing arm on 2026-09-02 confirmed the mode still
runs all four checks in order from behind that link, recorded in `tests/evals/results.md` under
"the assess arm after the reference move".

**The structural fact this section turns on is unchanged.** Measured heading-inclusive at
`4889f7a`, the four modes need 100%, 72%, 48% and 32% of the body they load, author first and
assess last. The body is still the union of the modes' needs rather than any one mode's, and a
union body still gets worse for every reader each time a mode is added. What has changed is that
the union is now cheap enough to extend: the argument for FR-19 was never the ceiling, it was the
union, and the ceiling was only what made it urgent.

### 5.2 What four modes cost, measured rather than estimated

The idea record estimated a four-mode Step 0 at 63 words against the current 74, a saving of 11.
**That estimate was wrong, and the error is worth recording because it inverts the conclusion.** The
63-word version dropped the mode routing and the disambiguation sentences, which are the parts that
do the work. A Step 0 that actually routes four modes, names where each mode's steps live, and keeps
the "ask once" rule was estimated at 98 words. That estimate was never measured against a written
router. The router in `docs/plans/2026-09-02-the-four-mode-router-and-audit.md`, landed 2026-09-03,
measures **112 words**, heading included, the same way everything else here is counted, and every
figure below is that measurement rather than an estimate.

| Shape | Body | Against the 900 ceiling |
|---|---|---|
| Before `4889f7a`, two modes with Step 0a inline | 876 | passed, 24 spare |
| That body with a four-mode Step 0 swapped in, nothing moved, on the superseded 98-word estimate | **900** | passed, and nothing was left. The measured 112-word router gives **914**, over the ceiling by 14 |
| **Today, after `4889f7a`** | **756** | passes, 144 spare |
| **Today with the four-mode Step 0 swapped in** | **795** | **passes, 105 spare**, over the 700 target |

**The finding has been overturned by its own evidence, and the last row is why.** The second row was
this section's headline: an honest four-mode router consumed all 24 spare words exactly, before
audit or seed contributed one of their own, so nothing could be added and the only question was what
came out. The measured router makes that point harder, not softer: it consumes 38 and overruns them
by 14. Moving Step 0a answered the question the headline posed, and it was the answer this PRD
proposed. `756 - 73 + 112` is **795**, reached by doing what the old table said it would take. The
old arithmetic reached 781 by costing the router at the estimated 98, so the body lands 14 words
above the prediction.

**What the last row costs, carried forward rather than banked.** 795 is under the 900 ceiling and
over ADR-0001's 700 target, so the router owes a passing eval arm at that length, recorded in
`tests/evals/results.md`. NFR-05 already requires an arm per mode, so this is another reason for the
arms rather than a new obligation.

**A first draft of this section said 906 and called it a failure by six words.** That came from
subtracting a heading-exclusive Step 0 of 68 from a heading-inclusive router of 98, which is the
mixed convention section 5.1 now states and guards against. The correct arithmetic is 876 minus 74
plus the router's cost, against the body as it then stood: 900 on the 98-word estimate, and 914 on
the measured 112, which is over the ceiling. The correction stands as a record of how
the number was got wrong. Its conclusion, that no version of this change adds prose to the body, was
true of that body and is not true of this one.

### 5.3 What can come out, and the rule that forbids the obvious answer

`docs/standards.md:42-49` records that `write-plan`'s sections were checked and left in the body
because they are instruction at the point of use, and states the rule: reach for a reference because
a reader needs it at one step, not as a way to buy words. Step 0a's four checks in a fixed order are
instruction at the point of use by that test. Moving them to buy room for two new modes is buying
words, and this PRD does not pretend otherwise.

**The counter, and why it is accepted here rather than waved through.** With two modes, the body is
a union and every reader loads the other mode's steps. With four, a reader loads three modes they
are not in. At that point the mode's steps stop being "the next thing this reader does" and become
"the thing one of four readers does", which is the definition of reference material rather than a
reframing of it. Step 0 becomes the point-of-use instruction, and each mode's steps become a file
the reader loads once, immediately, having just been routed there.

**That argument is plausible and unproven, so it is tested rather than asserted.** NFR-05 requires
a passing eval arm per mode with its steps behind a link. If a mode stops being followed once its
steps move, the arm fails and this shape is wrong. That is the whole reason the arms are in this
document rather than the plan.

### 5.4 The smaller shape, if the arms fail

**Status, 2026-09-02: available and not triggered.** The arms S-01 and S-02 ran and passed, and
section 5.1's constraint is discharged, so nothing has fallen back to this shape. It stays written
down because the remaining modes still have no arms and the condition below is still the condition.

Recorded so it is not invented under pressure later. If NFR-05 cannot be met, the fallback is
**one mode, not two**: audit only, because the brownfield case is the common one and seed's output
can be approximated by author on a skeleton. Audit as a terminal branch of author, stopping before
Step 4 and writing a report, costs about 15 body words and needs 9 to come from somewhere. Seed is
dropped and its library-gap report becomes a separate concern.

**Splitting into a 26th skill was considered and is not proposed.** The description budget allows
it, at 1,130 tokens of 1,320 with room for about four more skills, but
`docs/07-open-decisions.md:340`
says to revisit granularity as "which of these should merge" rather than by adding, and a second
skill would put convention derivation in two places. Recorded as rejected rather than unconsidered.

## 6. Functional requirements

| ID | Requirement | Status | Source |
|---|---|---|---|
| FR-01 | The skill has four modes: author, assess, audit, seed. | confirmed | Bernard, 2026-09-02 |
| FR-02 | Mode is chosen from two facts, whether `<docs_root>/standards.md` exists and whether the repository has code to read, plus the request's words. Chosen before reading anything else. | confirmed | idea record |
| FR-03 | **Audit** runs on a repository with code and no `standards.md`. It derives conventions using the existing Step 1 and Step 2, and writes `<docs_root>/audits/YYYY-MM-DD-standards-audit.md`, per FR-07. | confirmed | Bernard, decision 2, path corrected 2026-09-02 |
| FR-04 | Audit writes nothing else. It does not write `standards.md`, and it does not edit any file it read. | confirmed | Bernard, decision 2 |
| FR-05 | Audit's report states in its own header that it is a derivation and not an agreed standard. | confirmed | idea record |
| FR-06 | Audit offers to author at its end, and does not author without being asked. | author-added | see note below |
| FR-07 | Audit's report and assess's report have different filenames, because decision 2 puts both at `<docs_root>/audits/YYYY-MM-DD-standards.md` and two modes writing one path is a collision. Audit writes `YYYY-MM-DD-standards-audit.md`. | author-added | the collision is real and unresolved in the record |
| FR-08 | **Seed** runs where there is no `standards.md` and no code. It writes `<docs_root>/standards.md` from `references/house-defaults.md` and the applicable topic references. | confirmed | Bernard, 2026-09-02 |
| FR-09 | Seed reports which house references were missing for the stack it detected, **in its reply and not in a file**. The finding is addressed to keel's maintainers, not to the project, and a report written into the project's tree is addressed to the wrong reader. | confirmed | Bernard, decision 1, placement settled 2026-09-03 |
| FR-10 | Seed's document states that it was seeded from the house defaults and not derived from code. | confirmed | idea record |
| FR-11 | Seed's body says explicitly that it inverts Step 1, and why: Step 1's rule assumes a codebase that exists, and where there is none the choice is between the house defaults and nothing. | confirmed | Bernard, 2026-09-02 |
| FR-12 | External adopters inherit `references/house-defaults.md` unchanged. No overlay file, no profile key. Disagreement is expressed only through the project's own departures ledger. | confirmed | Bernard, decision 3 |
| FR-13 | `references/house-defaults.md` states FR-12 in its opening, since the current wording leaves it implicit. | author-added | idea record names it as implicit; making it explicit was not requested |
| FR-14 | **The bottom-right cell is answered rather than dropped.** Where `standards.md` exists and there is no code, assess runs. Check 1 is fully valid, since `SKILL.md:33` says it reads no code. Check 4's ledger structure is valid. Checks 2 and 3 report "no corpus" and the reason, in the section each already has. | confirmed | Bernard required it answered or the axis dropped; the answer is author-added |
| FR-15 | Assess gains a second coverage check counting `references/house-defaults.md`'s twelve rule sections, reported as its own named number. | confirmed | Bernard, decision 14 and 2026-09-02 |
| FR-16 | That number never feeds the header's `coverage` figure and the two are never summed. | confirmed | Bernard, 2026-09-02 |
| FR-17 | The second check excludes two sections by name, "The other references, and when each applies" and "What is deliberately not here", and counts every other `##`. It does not subtract a fixed number and does not judge whether a heading reads like a rule. | confirmed | Bernard, 2026-09-02 |
| FR-18 | The second check is reported as check 1b, immediately after check 1 in the fixed section order. | author-added | reason in section 9 |
| FR-19 | Each mode's steps live in `references/`, and the body carries the routing, the shared steps and Common mistakes. | author-added | done for assess in `4889f7a`, and it is what paid for the router. Section 5.2. The 60% figure that section 5.1 carried until 2026-09-03 was false for author and audit; the measured spread is now in 5.1. |
| FR-20 | Every mode degrades to a stated outcome when its precondition is wrong. Asked to assess with no document, say so and offer to seed or audit by which precondition holds. Asked to seed over an existing document, name it and ask first. | inferred | generalises the two rules Step 0 already carries |
| FR-21 | Audit and seed change no behaviour at the point of work. Neither adds a gate, a hook, or a read enforced elsewhere. | inferred | section 12 |

**On FR-06.** The idea record's table says audit is followed by "then offer to author". Whether the
offer is a requirement or a courtesy was never stated. It is written as a requirement because an
audit that silently stops leaves the user holding a derivation with no next step, which is the
failure FR-05 creates by design.

**On FR-07.** Decision 2 puts audit's report at the same path assess writes. The idea record lists
the collision under "Not decided here". This resolves it in the only direction that keeps both
reports, and it is the requirement most worth overruling if a different name is preferred.

**On FR-11, and what "body" means in it.** Confirmed 2026-09-04. It means the mode's own text,
`references/seed.md`, and not the part of `skills/coding-standards/SKILL.md` after the frontmatter,
which is what `tests/validate-skills.sh` and ADR-0001 mean by the word. Satisfied at
`references/seed.md:6`, and nothing about inverting Step 1 is in the skill body. This is the reading
FR-19 forces on every other mode, whose steps all live behind links, and the argument is set out at
`docs/plans/2026-09-03-seed-mode-and-its-arm.md:81-95`. The row is unchanged: the ambiguity was in
the word, not in what Bernard confirmed on 2026-09-02.

## 7. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | The body stays at or under ADR-0001's 900 word ceiling. No gate is weakened to fit. | confirmed | Bernard, 2026-09-02, and `docs/standards.md:345-353` |
| NFR-02 | A body over the 700 target carries a passing eval arm at that length. The proposed shape lands at a measured 795, so this applies. | confirmed | `ADR-0001:52` |
| NFR-03 | The delegation and doc-claim checks that shipped on 2026-09-02 continue to pass. | inferred | `tests/validate-skills.sh`, `tests/test-doc-claims.sh` |
| NFR-04 | No mode makes a network request, and audit and seed run offline. | inferred | matches assess, `references/assessment-report.md:5` |
| NFR-05 | **Each of the four modes has a passing eval arm with its steps behind a link.** This is what tests section 5.3's unproven claim, and a failure is the signal to take section 5.4's smaller shape. | author-added | see below |
| NFR-06 | **Author mode gets an eval arm or a recorded acceptance that it ships unexercised.** | confirmed | Bernard, 2026-09-02 |
| NFR-07 | Seed's library-gap report is verified against the Flutter case, which is a known true positive. | author-added | section 2 |
| NFR-08 | The reports of audit and seed are comparable between two runs the way `references/assessment-report.md:11-12` requires of assess: fixed section order, fixed counting units, stated before any number. | author-added | consistency with the mode that already ships |

**On NFR-06, and why it is larger than it looks.** Author mode has never been exercised in a
recorded run. One scenario names this skill, `assess-a-stale-standard`, and it injects
`coding-standards` to run assess. No arm has ever run author. Both new modes make author load
bearing: audit ends by offering it, and seed is author's Step 4 with a different source. So the mode
with no evidence behind it becomes the one two new modes depend on. Either an arm covers it or the
gap is written down where the next reader meets it.

**On NFR-05, and its known limit.** `docs/ideas/plugin-delegation-eval-gap.md` records that no arm
can load a plugin, so any conditional in these modes will be measured on its fallback branch only.
That limit is inherited and not introduced here, and NFR-05 is not blocked by it: what NFR-05 tests
is whether a mode's steps are followed from a reference, not whether a plugin works.

## 8. Constraints

| ID | Constraint | Source |
|---|---|---|
| CON-01 | 900 word body ceiling, 700 enforced as a warning. | `ADR-0001` |
| CON-02 | Descriptions sum to at most 1,320 tokens; 1,130 used. | `tests/validate-skills.sh` |
| CON-03 | Skill granularity is revisited as "which should merge", not by adding a skill. | `docs/07-open-decisions.md:340` |
| CON-04 | A reference is reached for because a reader needs it at one step, never to buy words. | `docs/standards.md:42-49` |
| CON-05 | Nothing in an assessment modifies what is assessed, and this extends to audit. | `references/assessment-report.md:3-5` |

## 9. Where check 1b sits, and why

Proposed: a new section immediately after check 1, shifting checks 2 to 4 down by one and leaving
the trend and not-covered sections last.

**The reason is adjacency, and it is the whole argument.** The two numbers answer different
questions and must never be summed, which FR-16 fixes. But a reader comparing them needs them
together, because the interesting result is which of the two failed: a topic reference is skipped
because nobody judged it applicable, a house default is skipped because nobody opened the file. Put
1b last and a reader who stops after check 1 sees half the coverage picture and does not know it.

**The cost, stated because it is real.** `references/assessment-report.md:39-48` calls the section
order fixed, and inserting into the middle renumbers three sections in every future report and
breaks comparison against `docs/audits/2026-09-02-standards.md`. Calling it **1b** rather than 2 is
what keeps the existing numbers stable: checks 2, 3 and 4 keep their numbers and their meanings, and
the only new thing in the order is a lettered section between 1 and 2.

## 10. Success metrics

Unknown, needs a decision, for adoption. There is one repository using this skill and no usage data.

What is measurable now: audit run on this repository produces a derivation whose findings a reader
agrees with, and seed run on a Flutter skeleton reports the missing `mobile.md`. Both are one-shot
verifications rather than metrics, and calling them metrics would be inventing one for the slot.

## 11. Out of scope

Writing `mobile.md`, or any house reference seed reports as missing. Changing the house defaults.
Any mechanism that makes a rule bind at the point of work. Fixing the eval harness so it can load a
plugin, which `docs/ideas/plugin-delegation-eval-gap.md` records as deliberately not planned.

## 12. Assumptions

**Both new modes route around the open question rather than answering it.**
`docs/ideas/standards-that-bind.md:624` leaves "Why does a loaded rule not bind?" open and calls it
keel's precondition for any wording change. Both modes create a document and neither adds a
reminder, a gate or a read at the point of use, so neither touches the precondition and neither is
blocked by it. **That holds only while they stay document-producing.** FR-21 makes it a requirement
rather than an accident, and the moment either mode gains a rule intended to change behaviour at the
point of work, it inherits the blocker and this assumption fails.

## 13. Open questions

1. **FR-07's filename.** `-standards-audit.md` resolves the collision decision 2 creates. Any other
   name works as well; this one is a choice, not a finding.
2. **Whether audit and seed are one mode or two.** They share no steps: audit runs 1 and 2, seed
   runs 4. This PRD treats them as two on that basis, and the idea record left it open.
3. **What audit does when the tree contradicts itself**, which Step 1 handles for author by counting
   and recording the minority as the rule where the majority is a defect. Audit inherits that and it
   has not been tested against a real brownfield tree.

## 14. What this PRD closes

**The bottom-right cell**, at FR-14, by answering it rather than dropping the axis: assess runs,
check 1 is fully valid because it reads no code, and checks 2 and 3 report no corpus.

**The budget**, at section 5, by measuring rather than estimating, and by correcting the idea
record's own figure. The four-mode router costs 30 words and does not save 11. Two full mode
bodies do not fit; neither does one; neither does the router alone. The shape proposed is smaller
than the one the idea record sketched, and section 5.4 records the fallback if the arms disagree.

**The check 1b placement**, at section 9, with adjacency as the reason and the renumbering cost
stated.
