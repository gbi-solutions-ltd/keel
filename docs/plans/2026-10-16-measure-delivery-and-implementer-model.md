# Measure delivery, and let a plan name a cheaper implementer Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for tasks 1 and 2. Tasks 3 and 4 change skill text and carry no
> failing test; they are checked by `tests/validate-skills.sh`, the doc checks and a reviewer.

**Goal:** keel can say how long a planned feature took, how many implementer dispatches each task
needed and on which routing, and whether the feature came back as a fix; and a plan can route its
implementers to a cheaper delegation profile while planning and review stay on the session's model.
**Stories:** none. See "There are no stories" below.
**ADRs:** ADR-0005 (one skill body across harnesses; routing by delegation profile, never a vendor
alias) shapes task 2: the cheaper implementer is a profile, `keel-implementer`, not a model name.
Task 2 writes ADR-0008, which records that an implementer may run on that profile when its plan
names it, against the rule in `docs/standards.md` that code under a gate stays `inherit`. ADR-0002
(the coordinator writes no code) is unchanged. ADR-0001 governs the body edits in tasks 3 and 4.
**Architecture:** no new storage. `keel plan report <plan>` derives everything from git history and
committed copies of the plan: author times, tick notes, one header line, and a body line in fix
commits. A plan gains `**Implementer routing:**`, which `execute-plan` honours for implementer
dispatches only.
**Implementer routing:** keel-implementer
**Decided:** Bernard, 2026-10-16, in `docs/ideas/delivery-flow-gaps.md` ("Decided": gap 7 first)
and in conversation the same day (a cheaper implementer, folded into gap 7 because the measurement
must record it).
**Shape:** gap 1 of that record decided that a task names its behaviours with example values, its
files and its `Done when:`, with no verbatim implementation. This plan is the first trial of that
shape.
**This plan runs before its own routing exists.** Tasks 1 and 2 are dispatched by the coordinator on
the model `agents/keel-implementer.md` will name, `sonnet`, through the dispatch tool's model
parameter, labelled `keel-implementer: `, and each task's last tick note records `routing:
keel-implementer (sonnet, by hand)`. Tasks 3 and 4 were meant to use the profile once task 2 landed;
the session running this plan does not load keel's own agents, so they were dispatched the same way,
by hand, and their notes say so.
**Reviewed:** by a dispatched plan reviewer on 2026-10-16; "What the review changed" records it.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). CI runs that lint and **info findings fail
  it**. If `command -v shellcheck` prints nothing, say the lint was not run and that CI will run it.
- **`tests/run-tests.sh` takes about 2m30s.** Where a tool call cannot run that long, run it in the
  background and read its log. Say which ran.
- **Precondition: the working tree is clean and nothing is staged**, apart from untracked files no
  task names. Each commit stages named paths only, checked with `git diff --cached --name-only`.
  Never `git add -A`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Every commit carries its own documentation, `CHANGELOG.md` included.
- Commits and pull requests carry no attribution footers, and this repository sets
  `conventions.no_attribution_footers`, so a commit message is a title and a body only.
- **No vendor model alias in any skill body or reference.** `tests/validate-skills.sh` fails one.
  Routing is named by delegation profile (ADR-0005). The alias appears only in `agents/*.md` and
  `lib/harness/*.sh`.
- **Skill bodies:** `execute-plan` is at 889 of ADR-0001's 900, so nothing is added to its body.
  A body edit to a skill over 700 words owes a passing eval arm under ADR-0001; tasks 3 and 4 say
  how each is handled.
- Bash 3.2 compatible: no `${x^}`, no associative arrays, no `mapfile`.

## There are no stories

These are changes to keel's own tooling, specified by a decided idea record. The tests and the
review pin the behaviour a story would. Recorded so the absence is a choice.

## What this plan does not build

- **No profile key for routing.** The plan names it, so the person approving the plan sees it and
  can change it there, which is the checkpoint asked for. A project default would bump
  `SCHEMA_VERSION`.
- **No reviewer routing.** Reviews stay `inherit` whatever the plan says.
- **No timing inside a task.** Git cannot see inside one. Per-task times and dispatch counts are
  what gaps 5 and 1 need.
- **No `keel plan tick` timestamp.** The idea record's gap 7 said tick would stamp the time. Ticks
  are committed with their task, so the commit's author time is that stamp already; recorded in the
  idea record by task 4.
- **No rework window.** Any later commit naming the plan counts.
- **No change to the behaviour-list approval or the unattended run.** That is gap 4.

## File structure

| File | Change |
|---|---|
| `bin/keel` | `keel plan report`; dispatch, help and the "Try status or tick" error |
| `tests/test-plan.sh` | Report cases, in temporary git repositories |
| `agents/keel-implementer.md` | New delegation profile, `model: sonnet`, edit tools allowed |
| `lib/harness/codex.sh` | The profile's Codex mapping, marked unmeasured as `keel-fanout`'s is |
| `lib/subagent_statusline.py` | `keel-implementer: ` in `LABELS` |
| `tests/test-agents.sh`, `tests/test-subagent-statusline.sh` | Cases for the new profile |
| `docs/decisions/ADR-0008-a-plan-may-route-its-implementer.md` | New, `accepted` |
| `docs/standards.md` | The dispatch rule names the exception |
| `docs/ideas/model-routing.md` | "What shipped" gains the implementer profile |
| `skills/write-plan/references/plan-template.md` | The header line and when to choose it |
| `skills/write-plan/SKILL.md` | Step 6 commits the plan and names its routing |
| `skills/execute-plan/references/subagent-prompts.md` | The routing rule and the tick note |
| `skills/execute-plan/references/parallel-batches.md` | Batch implementers follow the same routing |
| `skills/debug/references/rework-link.md`, `skills/debug/SKILL.md` | The rework line, and a pointer |
| `skills/ship/SKILL.md` | The report in the pull request body |
| `docs/03-install-and-distribution.md`, `CHANGELOG.md` | Each task's documentation |
| `docs/ideas/delivery-flow-gaps.md` | Gap 7 built |

**Concurrent batches:** none. Each task builds on the one before.

---

### Task 0: commit this plan

The coordinator commits this file alone before task 1, `docs(plans): measure delivery and route
the implementer`, so the report has a planned-at time for it. Not a step: a plan's own commit is
what task 3 makes `write-plan` do.

---

### Task 1: `keel plan report`

**Story:** none.
**Files:**
- Modify: `bin/keel`, `tests/test-plan.sh`, `docs/03-install-and-distribution.md`, `CHANGELOG.md`

**Interfaces:**
- Produces: `keel plan report <plan> [--json]`. Exit 0 on a plan it can read; 1 on a missing file;
  3 on a plan with no step ids, as `status` and `tick` use 3; 4 on a plan with no committed history.
- Consumes: committed copies of the plan (`git rev-list` and `git show <commit>:<path>`, with the
  path made root-relative by `git ls-files --full-name`), `PLAN_AWK_LIB`, and `json_str_array` or a
  scalar escaper written beside it.

**Depends on:** none

**Behaviours, with the examples the tests use.** One case or more each in `tests/test-plan.sh`, in a
temporary repository whose commits set `user.name`, `user.email`, `GIT_AUTHOR_DATE` and
`GIT_COMMITTER_DATE`, as `tests/test-keel.sh` does.

1. **Times are author times**, because a rebase rewrites committer times and the measurement is of
   when the work was done. Displayed in UTC as `2026-10-16T09:00:00Z`; arithmetic on the epoch.
2. **Planned** is the author time of the first commit that added the plan. Added at `09:00`: prints
   `planned: 2026-10-16T09:00:00Z`.
3. **A task's time** is the author time of the last commit in which one of its steps left open, by
   any mark (done, deferred or not applicable), read by parsing each committed copy of the plan. A
   step already closed in the commit that adds the plan counts as closed at that commit. Task 1
   closed in a commit at `10:30` prints `task 1: done 2026-10-16T10:30:00Z`. A task with an open
   step prints `task 2: open`.
4. **Dispatches and routing** for a task come from the last `rounds: <n>` and the last `routing:
   <text>` in the notes of that task's done steps. `rounds: 2` and `routing: keel-implementer` print
   `, rounds 2, routing keel-implementer`; absent, `rounds unknown` and `routing unknown`.
5. **Delivered** is the latest task time, once every step is closed in the committed copy; otherwise
   `delivered: not yet`.
6. **Lead time** is delivered minus planned in hours to one decimal: `09:00` to `13:20` prints
   `lead time: 4.3h`; not delivered prints `lead time: not yet`.
7. **Planned routing** is the plan's `**Implementer routing:**` header value, or `inherit (not
   stated)`.
8. **Rework** counts commits reachable from `HEAD` whose message contains the line
   `Reworks <plan path>` (root-relative, matched as a fixed string on its own line), with their
   short hashes: two print `rework: 2 (<hash> <hash>)`, none prints `rework: 0`. A line naming
   another plan does not count.
9. `--json` prints the same facts as one object, `null` where the text says `not yet` or `unknown`,
   accepted by `python3 -m json.tool`.
10. The working-tree copy is not read: an uncommitted tick does not change the report. Renames are
    not followed, and the docs say so.
11. A missing file exits 1 naming it; a plan with no step ids exits 3; an uncommitted plan exits 4
    saying it has no history yet. Run from a subdirectory with a relative path, it reports the same.

**Done when:** `bash tests/test-plan.sh` prints no FAIL and `bin/keel --help | grep 'plan report'`
prints a line.

- [x] **Step 1.1: Write the failing cases** for behaviours 1 to 11, in the file's existing style. Note: implementer on sonnet; 25 cases first, 41 report cases after the fix pass
- [x] **Step 1.2: Run them and watch them fail** for the missing subcommand, not a fixture error. Note: not witnessed by me; the implementer reported 53 passed, 24 failed, all for the missing subcommand
- [x] **Step 1.3: Implement `plan_report`** beside `plan_status`, reusing `PLAN_AWK_LIB` per Note: implemented by a sonnet subagent, fixed in one fix pass after a blocking quality finding on merged branches
  committed copy. No dependency beyond `git`, `awk` and `date`; hours computed in `awk`.
- [x] **Step 1.4: Run the test file until no FAIL**, then the profile's lint if `shellcheck` exists. Note: witnessed by me in the full suite: test-plan.sh green; shellcheck 0.11.0 clean per two reviewers
- [x] **Step 1.5: Mutation checks.** Each alone must fail a named case: count a line naming another Note: not witnessed by me; the implementer and two reviewers each ran the mutations and more, each failing a named case
  plan; take the first closing commit instead of the last; read the working-tree copy; use committer
  times; print delivered while a step is open; drop `--json`'s nulls.
- [x] **Step 1.6: Docs.** `docs/03-install-and-distribution.md`: a `keel plan report` block after Note: docs by the implementer; doc-claims 63/0 and citations OK per the final reviewer
  `keel plan tick`, each line's meaning, that every number comes from git and committed copies, and
  that renames are not followed. `CHANGELOG.md`, Unreleased: one entry.
- [x] **Step 1.7: Check and commit.** `bash tests/test-doc-claims.sh`, Note: rounds: 2; routing: keel-implementer (sonnet, by hand); full run-tests.sh witnessed by me, all passed; commit follows this tick
  `tests/validate-citations.sh`, the full `tests/run-tests.sh`. Stage the four files and this plan.
  Commit: `feat(cli): keel plan report, lead time and rework from git`.

---

### Task 2: the `keel-implementer` delegation profile

**Story:** none.
**Files:**
- Create: `agents/keel-implementer.md`,
  `docs/decisions/ADR-0008-a-plan-may-route-its-implementer.md`
- Modify: `lib/harness/codex.sh`, `lib/subagent_statusline.py`, `tests/test-agents.sh`,
  `tests/test-subagent-statusline.sh`, `docs/standards.md`, `docs/ideas/model-routing.md`,
  `docs/03-install-and-distribution.md`, `CHANGELOG.md`

**Interfaces:**
- Produces: the delegation profile name `keel-implementer`, resolvable on every harness in the set,
  and the status-line label `keel-implementer: `.
- Consumes: `agents/keel-fanout.md` as the pattern, and its Codex mapping in `lib/harness/codex.sh`.

**Depends on:** task 1

**Behaviours.**

1. `agents/keel-implementer.md` exists with `model: sonnet` and **no** `disallowedTools`: it writes
   code. Its body says it implements one task under `keel:tdd`, stages and stops, never commits,
   and is reviewed on the session's model. `tests/test-agents.sh` pins both fields.
2. `lib/harness/codex.sh` writes `.codex/agents/keel-implementer.toml` beside `keel-fanout.toml` and
   lists it in `harness_config_paths`, with the same "the model is unmeasured" comment.
3. `lib/subagent_statusline.py` recognises `keel-implementer: `: a dispatch so labelled shows its
   row with the profile's model. `tests/test-subagent-statusline.sh` has the case.
4. `tests/validate-skills.sh`'s check that a named profile resolves for every harness passes for
   `keel-implementer`, run to confirm rather than assumed.
5. ADR-0008, `accepted`, decided by Bernard 2026-10-16: an implementer may run on `keel-implementer`
   when its plan says so; reviews stay `inherit`; the reason the old rule gives (a cheaper model's
   miss is invisible) is answered by tests watched failing first, a review on the session's model,
   the label, and the routing recorded per task. It names ADR-0005 as the mechanism and the
   standards rule it amends, and its Verification is gap 7's rework number by routing.
6. `docs/standards.md`'s "A dispatch names its model" rule names the exception and cites ADR-0008.
   `docs/ideas/model-routing.md`'s "What shipped" says `execute-plan`'s implementer may now be
   routed, and where.

**Done when:** `bash tests/test-agents.sh`, `bash tests/test-subagent-statusline.sh` and
`tests/validate-skills.sh` 0 FAIL.

- [x] **Step 2.1: Write the failing cases** in the two test files for behaviours 1 and 3. Note: cases written by a sonnet subagent; failing-first reported 2/2 and 37/1
- [x] **Step 2.2: Run them and watch them fail.** Note: not witnessed by me; reported failing for the missing agent file and label
- [x] **Step 2.3: Add the profile, the Codex mapping and the label** for behaviours 1 to 3. Note: by the subagent; settings.json regenerated from the generator and staged, which the file list missed
- [x] **Step 2.4: Run both test files and `tests/validate-skills.sh`** for behaviour 4. Note: test-agents 4/0, statusline 38/0, validate-skills 0 FAIL per the reviewer; item 8's resolve check covers the profile only once task 3 names it
- [x] **Step 2.5: ADR-0008, the standards rule, model-routing and the docs** for behaviours 5 and 6, Note: ADR-0008 and docs by the subagent; one should-fix pass corrected the commit rule, ADR overclaims and stale docs
  and the `docs/03` and `CHANGELOG.md` entries.
- [x] **Step 2.6: Check and commit.** The doc checks and the full `tests/run-tests.sh`. Stage the Note: rounds: 2; routing: keel-implementer (sonnet, by hand); one combined review as gap 5 decided; full run-tests.sh witnessed by me, all passed
  ten files and this plan. Commit: `feat(agents): keel-implementer, a routed implementer profile`.

---

### Task 3: plans name their routing, and execution records it

**Story:** none.
**Files:**
- Modify: `skills/write-plan/references/plan-template.md`, `skills/write-plan/SKILL.md`,
  `skills/execute-plan/references/subagent-prompts.md`,
  `skills/execute-plan/references/parallel-batches.md`, `docs/03-install-and-distribution.md`,
  `CHANGELOG.md`

**Interfaces:**
- Consumes: `keel-implementer` (task 2) and the note fields `rounds:` and `routing:` that task 1's
  report reads.

**Depends on:** task 2

**Behaviours.**

1. **The template carries the line.** Header: `**Implementer routing:** inherit`, with one
   paragraph: the values are `inherit` and `keel-implementer`; `keel-implementer` fits where every
   task has a `Done when:` command and concrete behaviours; a task touching `hard_block_paths` stays
   `inherit` unless the person approving says otherwise.
2. **`write-plan` step 6 commits the plan alone** (`docs(plans): <slug>`) and reports the routing in
   the hand-off, so the person approving sees it and can change the line before `execute-plan`.
3. **Execution honours it for implementers only.** In `subagent-prompts.md`, "Which model each
   prompt goes to": the implementer goes to the plan's routing, `inherit` when absent, its
   description starting with the profile name and a colon; both reviews stay `inherit`; the routing
   is announced in one line before the first dispatch. `parallel-batches.md`'s dispatch paragraph
   says the same for batch implementers. The reference names the profile with the exact phrase
   "delegation profile `keel-implementer`", which is what `tests/test-harness-claims.sh` item 8
   resolves on every harness. (Added during task 2's review, 2026-10-16: task 2 behaviour 4 cited
   `tests/validate-skills.sh`, but the resolve check lives there and only covers named profiles.)
4. **The tick note records it.** Where the coordinator ticks after both passes: the last step it
   ticks done in a task carries a note that starts `rounds: <n>; routing: <profile>`, `n` being the
   number of implementer dispatches the task took; any other text follows after a further `; `,
   because the report reads a field only at the start of the note or after `; `. (Changed during
   task 1's review, 2026-10-16.)
5. **ADR-0001.** `write-plan` is over 700 words, so its step 6 edit owes an eval arm. No scenario
   loads `write-plan` (`docs/ideas/bodies-over-the-target-with-no-arm.md`), so the owed arm is
   recorded in `CHANGELOG.md`'s known gaps rather than claimed. `execute-plan`'s body is not edited.
6. Docs: `docs/03`'s `keel plan report` block says where routing and rounds come from;
   `CHANGELOG.md` entry.

**Done when:** `tests/validate-skills.sh` 0 FAIL with `write-plan` at or below 900 and
`execute-plan` unchanged at 889; the doc checks pass; the reviewer finds behaviours 1 to 4 stated.

- [x] **Step 3.1: Edit the template, `write-plan` step 6, and the two references** for 1 to 4. Note: edited by a sonnet subagent; one should-fix pass made routing plan-wide for hard_block_paths, kept write-plan off the default branch, and covered unknown values and inline mode
- [x] **Step 3.2: Run `tests/validate-skills.sh`** and read the two body counts. Note: write-plan 798 words, execute-plan unchanged at 889, per the implementer and reviewer
- [x] **Step 3.3: Docs and the owed arm** for behaviours 5 and 6. Note: docs and the owed write-plan arm recorded in CHANGELOG known gaps; harness-claims item 8 now resolves keel-implementer on claude and codex
- [x] **Step 3.4: Check and commit.** The doc checks and the full `tests/run-tests.sh`. Stage the Note: rounds: 2; routing: keel-implementer (sonnet, by hand); one combined review, COMPLIES; full run-tests.sh witnessed by me, all passed
  six files and this plan. Commit: `feat(skills): a plan names its implementer routing, and
  execution records it`.

---

### Task 4: rework names its feature, `ship` reports delivery, and the record

**Story:** none.
**Files:**
- Create: `skills/debug/references/rework-link.md`
- Modify: `skills/debug/SKILL.md`, `skills/ship/SKILL.md`, `docs/03-install-and-distribution.md`,
  `CHANGELOG.md`, `docs/ideas/delivery-flow-gaps.md`

**Interfaces:**
- Consumes: `keel plan report` (task 1).

**Depends on:** task 3

**Behaviours.**

1. **The link is mechanical.** `rework-link.md`: after the fix is verified, find the commit that
   introduced the cause (`git log -L` or `git blame` on the lines the fix changed); if that commit
   also changed a file under `profile.artifacts.plans`, else `<docs_root>/plans`, the fix's commit
   message body carries the line `Reworks <that plan's root-relative path>`. A body line, not a
   trailer, so it holds where `conventions.no_attribution_footers` is true. None found: no line, and
   the report says so. Whoever commits the fix writes it, `ship` included.
2. **`debug`'s phase 4** gains one sentence pointing to `rework-link.md`. `debug` stays at or below
   700 words, so no arm is owed; if it would cross, the sentence moves into the reference's link.
3. **`ship`** adds `keel plan report <plan>` output to the pull request body, after how it was
   tested, when the branch changed a plan; a non-zero exit is reported as such, not hidden. `ship`
   is over 700 words, so this one sentence owes an arm, recorded in `CHANGELOG.md`'s known gaps.
4. **The record.** `docs/ideas/delivery-flow-gaps.md`: Status names the commits, Next names gap 5,
   and gap 7's text says ticks are timed by their commits rather than stamped.
5. Docs: the `Reworks` line in `docs/03`'s `keel plan report` block, and `CHANGELOG.md`.

**Done when:** `tests/validate-skills.sh` 0 FAIL, the doc checks pass, and `bin/keel plan report`
on this plan prints tasks 1 to 3 with times, `rounds` and `routing keel-implementer`.

- [x] **Step 4.1: Write `rework-link.md` and edit `debug` and `ship`** for behaviours 1 to 3. Note: reference, debug pointer and ship sentence by a sonnet subagent; one small fix pass made the blame read HEAD and the line copyable
- [x] **Step 4.2: Run `tests/validate-skills.sh`** and read the two body counts. Note: debug under 700 words, ship 790 of 900, per the implementer and reviewer
- [x] **Step 4.3: Run the report on this plan** and read tasks 1 to 3 in it. Note: the reviewer proved a copied Reworks line is counted end to end: rework 1
- [x] **Step 4.4: The record and the docs** for behaviours 4 and 5. Note: idea record and docs by the subagent; ADR-0008 answer 4 updated as the coordinator asked
- [x] **Step 4.5: Check and commit.** The doc checks and the full `tests/run-tests.sh`. Stage the Note: rounds: 2; routing: keel-implementer (sonnet, by hand); one combined review, COMPLIES; full run-tests.sh witnessed by me, all passed
  six files and this plan. Commit: `feat(skills): rework names its feature, and ship reports
  delivery`.

---

## What the review changed

A plan reviewer read the first draft on 2026-10-16 against the codebase. Applied:

- **Blocking: a vendor alias in skill text breaks ADR-0005** and `tests/validate-skills.sh`. The
  model is now the delegation profile `keel-implementer` (task 2), with ADR-0008 recording the
  exception to the standards rule.
- **Blocking: planned-at would equal delivered**, because `write-plan` never committed a plan. Task
  0 commits this plan; task 3 makes `write-plan` commit every plan.
- The report records the routing each task ran on, not only the one asked for; times are author
  times in UTC; exit 3 keeps its meaning and history-less plans exit 4; a task's time counts every
  closing mark; the committed copy is read, never the working tree.
- The rework link is a body line, not a trailer, because this repository allows no footers, and its
  rule is mechanical: the causing commit changed a plan file.
- `debug`'s text goes to a reference; the owed ADR-0001 arms for `write-plan` and `ship` are named.
- `keel:tdd` is required for tasks 1 and 2 only.
