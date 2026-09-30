# PRD: addressable plan steps

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Claude, in session with Bernard |
| Date | 2026-09-28 |
| Derived from | `docs/ideas/addressable-plan-steps.md` at commit `04c906a`, and this conversation |
| Approved by | Bernard, 2026-09-28 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

Of the 19 functional requirements below, **13 were stated or ruled on by Bernard** (FR-01 to FR-05,
FR-07, FR-11 to FR-15, FR-17, FR-18), **6 are derived** from the idea record and the rules the skills
already carry (FR-06, FR-08, FR-09, FR-10, FR-16, FR-19), and **none remain author-added**: FR-13 and FR-17
were, and Bernard kept both on 2026-09-28 (Q2 and Q1).

## 1. Executive summary

Every step in a keel plan gets an id unique within that plan, and two new commands read and change
steps by id: `keel plan status` says where a plan stands, and `keel plan tick` marks one step. A step
can also be deferred or not applicable, each with a reason. This is for the model coordinating a
plan and for `ship`'s checkbox gate. It matters now because plans run to 35,000 words, and finding
the next step or ticking the right box currently means reading and editing a file whose step labels
repeat once per task.

## 2. Problem statement

The coordinator ticks a plan's checkboxes by editing markdown in which every step label appears once
per task: the latest plan holds 30 checkboxes and each of its five labels six times, so a tick edit
needs surrounding text to find its line. After a compaction the only way to learn where a plan stands
is to reread it, and this repository's plans run from 10,000 to 35,000 words. Boxes get missed
(commit `5621b9e`, 2026-09-01, ticked two after the fact), and concurrent ticks from a batch can lose
one another (`skills/execute-plan/references/parallel-batches.md:101`). Plans also already hold boxes
left open on purpose, which today are indistinguishable from forgotten ones without reading the
note beside each.

## 3. Goals and non-goals

**Goals**
- A step can be named unambiguously, by id, in a command and in conversation.
- A plan's progress can be read without reading the plan.
- A step left open on purpose is distinguishable from one forgotten.

**Non-goals**
- A structured plan format. Plans stay markdown; XML and JSON were rejected in the idea record.
- Migrating the 31 existing plans.
- Any reader of plans other than the model and keel's own commands.

## 4. Users and personas

- **The coordinating model** running `execute-plan`: ticks steps after reviews pass, and after a
  compaction needs to find where the plan stands.
- **The model running `ship`**: checks that no step is left open.
- **The maintainer** reading a plan or its diff in a pull request: ticks and reasons must stay
  visible in the markdown.

## 5. Functional requirements

**The format**

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | A plan remains a markdown file, readable and reviewable as today. | confirmed | Bernard, 2026-09-28: "Only the model and keel's own commands", ids in markdown |
| FR-02 | Every step checkbox in a plan written from the template carries an id unique within that plan, naming its task and its step (for example `1b.2`). | confirmed | Bernard, 2026-09-28 |
| FR-03 | A step is in exactly one of four states: open, done, deferred, not applicable. | confirmed | Bernard, 2026-09-28, idea record open question 2 |
| FR-04 | A deferred or not-applicable step carries a reason, readable in the plan beside the step. | confirmed | Bernard, 2026-09-28, idea record open question 2 |
| FR-12 | Plans written before this change are not migrated. | confirmed | Bernard, 2026-09-28 |
| FR-13 | `tests/validate-skills.sh` fails when the plan template's steps carry no id, as it already does for a missing `**Done when:**` marker. | confirmed | Bernard, 2026-09-28, Q2. Author-added first, after the existing marker check in `tests/validate-skills.sh`: it stops a later trim of the template silently dropping the ids |

**`keel plan status`**

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-05 | `keel plan status <plan>` prints, for each task, how many of its steps are in each state, and the id of the first open step in the plan. | confirmed | Bernard asked for the command, 2026-09-28; the output answers the idea record's "where a plan stands" |
| FR-06 | `keel plan status` names every deferred or not-applicable step that has no reason, and exits non-zero when there is one. | inferred | Follows from FR-04 |
| FR-11 | On a plan with no step ids, `keel plan status` and `keel plan tick` change nothing, say the plan is unaddressable, and exit non-zero. | confirmed | Bernard, 2026-09-28, idea record open question 1: "report them" |

**`keel plan tick`**

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-07 | `keel plan tick <plan> <id>` marks that step done, and changes no other step's line. | confirmed | Bernard asked for the command, 2026-09-28 |
| FR-08 | `keel plan tick` accepts a note and writes it beside the step, for a step the ticker did not witness. | inferred | `skills/execute-plan/SKILL.md` Step 4: every unwitnessed step gets its own note in the plan |
| FR-09 | `keel plan tick` can mark a step deferred or not applicable, and refuses to without a reason. | inferred | Follows from FR-03 and FR-04 |
| FR-10 | Given an id the plan does not hold, `keel plan tick` changes nothing and exits non-zero naming the id. | inferred | FR-02 makes an id's absence detectable; a silent no-op would be a tick that lies |
| FR-16 | Two `keel plan tick` runs on the same plan at the same time both land. | inferred | The batch race in `parallel-batches.md:96`, which the idea record gives as evidence |

**The skills**

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-14 | `execute-plan` tells the coordinator to tick with `keel plan tick` and to find its place with `keel plan status`. | confirmed | Bernard, 2026-09-28, Q1: required, with FR-17's fallback |
| FR-15 | `ship` treats a plan as ready when no step is open and every deferred or not-applicable step has a reason, and reads that from `keel plan status`. | confirmed | Bernard, 2026-09-28: "`ship` accepts either when its reason is present"; `skills/ship/SKILL.md` step 7 |
| FR-17 | Where `keel` is not on the PATH the model's shell sees, `execute-plan` and `ship` still work, by editing and reading the plan by step id. | confirmed | Bernard, 2026-09-28, Q1. Author-added first: the plugin puts `keel` on Claude Code's Bash PATH (`docs/03-install-and-distribution.md`, "The two PATHs"); nothing states the same for other harnesses, and ADR-0005 keeps one skill body across them |
| FR-18 | For a plan with no step ids, `ship` checks its checkboxes by reading the file, as it does today, rather than refusing the plan as unaddressable. | confirmed | Bernard, 2026-09-28, Q4: plans written before this change must still ship |
| FR-19 | For a plan with no step ids, `execute-plan` ticks by editing the file, as it does today. | inferred | Follows from FR-18: a plan that can still ship can still be finished |

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | `keel plan status` on the largest existing plan shape (about 35,000 words, 2,000 lines) completes in under a second. | confirmed | Bernard, 2026-09-28, Q3. Author-added first: the command replaces a reread |

## 7. Constraints

| ID | Constraint | Imposed by |
|---|---|---|
| CON-01 | `bin/keel` runs under `set -uo pipefail` on bash 3.2. | The project's Global constraints and macOS's `/bin/bash` |
| CON-02 | Every changed shell file passes the profile's `shellcheck` command. | `.keel/profile.json` |
| CON-03 | A skill body stays under 900 words, and one over 700 owes a passing eval arm at its new length. | ADR-0001 |
| CON-04 | `tests/test-eval-harness.sh:480` pins `execute-plan` Step 4's tick sentence word for word; changing the sentence moves the pin with it. | The test suite |

## 8. Observed but not required

Not applicable, because this PRD is `from-idea`, not `from-repo`.

## 9. Success metrics

Unknown, needs a decision. See Q3.

## 10. Milestones

Unknown, needs a decision. None were given.

## 11. Out of scope

- Migrating existing plans: FR-12.
- XML, JSON, or a status file beside the plan: rejected in the idea record.
- The id syntax, flags and output format: design, not requirements.
- Any plan reader outside keel.

## 12. Assumptions

| # | Assumption | Falsified if |
|---|---|---|
| A1 | The template is the only place the step format is stated, so ids land for every new plan through it. | A skill or reference writes plan steps in its own format |
| A2 | Four states cover every reason a box is left today. | A plan holds an open box whose note fits neither deferred nor not applicable |
| A3 | ~~A plan without ids is never one `ship` must pass after this lands.~~ Falsified by Bernard, 2026-09-28, Q4: old plans must still ship. Now FR-18 and FR-19 | Not applicable: already decided |

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | ~~Does `execute-plan` require the commands (FR-14), or only mention them beside the edit it does today?~~ Answered 2026-09-28: required, with an edit by step id where `keel` is not on the PATH. Now FR-14 and FR-17 | Bernard | none |
| Q2 | ~~Is the author-added FR-13 wanted?~~ Answered 2026-09-28: kept. Now FR-13, confirmed | Bernard | none |
| Q3 | Is there a success metric, and is NFR-01's one second the right bound? The bound was answered 2026-09-28: one second, now NFR-01 confirmed. The success metric is still open | Bernard | Section 9 |
| Q4 | ~~A3: does any plan written before this change need `ship` to pass it?~~ Answered 2026-09-28: yes. Now FR-18 and FR-19 | Bernard | none |
