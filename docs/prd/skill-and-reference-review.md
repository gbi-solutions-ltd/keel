# PRD: skill and reference review

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Claude, in session with Bernard |
| Date | 2026-09-28 |
| Derived from | `docs/ideas/skill-and-reference-review.md` at commit `04c906a`, and this conversation |
| Approved by | Bernard, 2026-09-28 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

Of the 12 functional requirements below, **9 were stated or ruled on by Bernard** (FR-01, FR-04 to
FR-08, FR-10 to FR-12), **3 are derived** from the idea record and the repository's rules (FR-02,
FR-03, FR-09), and **none remain author-added**: FR-07, FR-08 and FR-12 were, and Bernard kept all
three on 2026-09-28 (Q2).

## 1. Executive summary

One review reads every keel skill body, description and reference file, records what it finds, then fixes every
defect and rewords for clarity across all 25 skills. It is for the model following a keel skill in
any project, which is to meet each rule once, stated plainly, and never a fact about keel's own
repository dressed as a rule. It matters now because at least one such fact already ships to every
project, and nobody has read the skills together to find the rest.

## 2. Problem statement

A model following a keel skill reads a body of about 730 words and the references it opens, where a
rule can be stated several times, a table can repeat the steps above it, and keel's own facts can
sit among rules meant for every project. `skills/tdd/SKILL.md:87` told every project its suite takes
313 seconds, which was keel's own `tests/run-tests.sh` as measured for ADR-0006, until commit
`268a950`. How often a body's wording causes a wrong action is unknown: the one failed eval arm on
record (commit `a132794`, 2026-08-19) broke a rule stated plainly, and 15 of the 25 skills have no
scenario to measure.

## 3. Goals and non-goals

**Goals**
- No skill or reference states a fact about keel's own repository as if it held for the project
  being worked on.
- No skill contradicts itself, its references, or another skill.
- Every reference a skill makes resolves.
- Each rule is stated once, plainly, where the model needs it.

**Non-goals**
- A lower word count, or a new word target. Bernard, 2026-09-28: the goal is clarity, not a number.
- New eval scenarios: `docs/ideas/eval-scenarios-for-uncovered-skills.md`.

## 4. Users and personas

- **The model following a skill**, in any project and harness keel supports: the reader the changes
  are for.
- **The maintainer**: reads the findings, and rules on any change that removes a rule.

## 5. Functional requirements

**The findings pass**

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | The review reads all 25 `SKILL.md` bodies and all 62 reference files under `skills/`. | confirmed | Bernard, 2026-09-28: references are in scope |
| FR-02 | Each finding records its file and `path:line`, and its kind: a defect (a repository fact leaking into a skill, a contradiction, or a stale or broken reference) or a clarity change. | inferred | The idea record's recommendation names these kinds |
| FR-03 | The findings are written to a file under `docs/audits/` before any skill file changes. | inferred | The idea record: a read-only findings pass first; `docs/audits/` holds this repository's review records |

**The changes**

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-04 | Every defect the findings record is fixed. | confirmed | The idea record's recommendation, agreed 2026-09-28 |
| FR-05 | Clarity changes are made in every skill, including the 15 with no eval scenario. | confirmed | Bernard, 2026-09-28, idea record open question 1 |
| FR-06 | Where a changed skill is named by a scenario's `Inject:` line, that scenario is re-run after the change, and the change lands only if it passes. | confirmed | The idea record's recommendation, agreed 2026-09-28 |
| FR-07 | No rule a skill states before the review is absent after it, unless its finding records the removal and Bernard approves it. | confirmed | Bernard, 2026-09-28, Q2. Author-added first, from the idea record's case against: the repetition that looks like clutter may be why a rule holds |
| FR-08 | A sentence stating the reason for a rule is not removed as a clarity change. | confirmed | Bernard, 2026-09-28, Q2. Author-added first: a stated reason is what lets a model apply a rule to a case the body never names |
| FR-09 | Every citation into a changed file, and every test pin on its text, still passes after the change. | inferred | Over 200 citations point into skill files; `tests/test-eval-harness.sh:480` pins `execute-plan` text |
| FR-10 | The review writes no new eval scenario. | confirmed | Bernard, 2026-09-28, idea record open question 2 |
| FR-11 | Each skill's `description` frontmatter is reviewed with its body, and gets defect fixes and clarity changes like any other text. | confirmed | Bernard, 2026-09-28, Q1: fully in scope |
| FR-12 | Every trigger a skill's `description` names before the review is still named after it, unless its finding records the removal and Bernard approves it. | confirmed | Bernard, 2026-09-28, Q2. Author-added first: a description decides when a skill fires, so rewording one changes routing; this is FR-07's rule applied to triggers |

## 6. Non-functional requirements

Not applicable, because the review changes documents, not a running system. Its limits are
the constraints below.

## 7. Constraints

| ID | Constraint | Imposed by |
|---|---|---|
| CON-01 | A skill body stays under 900 words, and one over 700 after the change owes a passing eval arm at its new length. | ADR-0001 |
| CON-02 | One skill body serves every harness; no change forks a body per harness. | ADR-0005 |
| CON-03 | `tests/run-tests.sh` and the profile's `shellcheck` command pass after each change. | `.keel/profile.json` and the engineering standard in `CLAUDE.md` |
| CON-04 | Each `description` stays within 216 characters, and all descriptions together within 1,320 tokens. | `tests/validate-skills.sh`, `docs/05-token-and-memory-design.md` Budget table |

## 8. Observed but not required

Not applicable, because this PRD is `from-idea`, not `from-repo`.

## 9. Success metrics

Unknown, needs a decision. See Q3.

## 10. Milestones

Unknown, needs a decision. None were given.

## 11. Out of scope

- New scenarios: FR-10.
- Any change to the word target or ceiling.

## 12. Assumptions

| # | Assumption | Falsified if |
|---|---|---|
| A1 | Stating a rule once, clearly, is followed at least as well as stating it several times. | A re-run arm under FR-06 fails where it passed before |
| A2 | Findings sort cleanly into defect and clarity change. | The findings file holds entries the maintainer cannot place |
| A3 | `tdd`'s leaked timing is not the only defect. | The findings pass finds no other |

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | ~~Are skill `description` lines in scope, or left alone?~~ Answered 2026-09-28: fully in scope. Now FR-11, with FR-12 and CON-04 | Bernard | none |
| Q2 | ~~Are the author-added FR-07, FR-08 and FR-12 wanted?~~ Answered 2026-09-28: all three kept, now confirmed | Bernard | none |
| Q3 | Is there a success metric beyond every defect fixed and every re-run arm passing? | Bernard | Section 9 |
