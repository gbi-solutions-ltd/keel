# Faster plan execution Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for tasks 1 and 2. Tasks 3 to 7 change skill text and records
> and say under their behaviours why they carry no failing test.

**Goal:** a plan run spends its time on the tasks: the suite runs at checkpoints rather than twice
per task, reports stop filling the coordinator's context, a context stop no longer hands the run
back to the person, a full-loop rejection gets one scoped fix pass, no review starts on a
half-finished tree, and `done-guard` stops counting edits outside the repository.
**Stories:** none. `docs/ideas/plan-execution-speed.md`, agreed by Bernard on 2026-11-11, with
item 1 as suite checkpoints and item 2 as leaner reports plus a plan run that carries on.
**ADRs:** ADR-0006 and ADR-0009 (the unit boundary and what it runs), which task 6's ADR-0017
amends; ADR-0002 (delegated execution); ADR-0011 (skill bodies hold instructions, references hold
the rest); ADR-0001 (skill body word ceiling); ADR-0012 (a task carries two steps).
**Architecture:** two code changes and five text changes. `hooks/done-guard` resolves each edited
path against the repository root and ignores the ones outside it. `lib/context_watch.py`'s stop
text gains a branch for a coordinator of a plan run: write the handoff naming the plan and its next
step, then carry on. The rest is `execute-plan`'s subagent prompts, `tdd`'s boundary reference and
the plan template: leaner reports, foreground commands and a complete-report check, a scoped fix
pass in the full loop, and suite checkpoints run by the coordinator in place of each implementer's
two whole-suite runs.
**Implementer routing:** inherit
**Delivery:** pull-request
**Concurrent batches:** none. Tasks 3, 4, 5 and 7 share
`skills/execute-plan/references/subagent-prompts.md`, every task adds a line to `CHANGELOG.md`,
and tasks 1 and 2 touch `hard_block_paths`.
**Suite checkpoints:** none; this plan predates them and its tasks run the boundary as written.
**Decided:** by Bernard, 2026-11-11, in conversation: all five items; item 1 as suite checkpoints
over a Go `test_affected` recipe; item 2 as leaner reports plus carrying on. Decided in this plan
and put to Bernard at approval:
- N lives in the plan header (`**Suite checkpoints:** every 3 tasks`), written by `write-plan`, not
  in a profile key as the question offered: a plan is where a run reads its settings (as it reads
  routing and delivery), and no code reads the number, so a profile key would be a documented key
  nothing enforces.
- A full-loop rejection gets one fix pass, then falls back to today's discard and fresh dispatch,
  and a third rejection goes to the person. A reviewer that says the approach is wrong
  (`Fix scope: redo`) skips the fix pass.
- The context-watch branch is a sentence in the stop text, not a marker file: the session knows
  whether it is coordinating a plan, and a marker left behind by a crashed run would silence the
  stop in an ordinary session.
- `done-guard` counts a scoped test run (`verify.test_one` or `verify.test_affected`, by the text
  before its first `{`) as well as `verify.test`. Without it the checkpoints are undone wherever
  `gates.done_verified` is `required`. It loosens the guard for every session, not only plan runs:
  it then proves a test ran, not that the suite did; `ship` still runs the suite.
**Approved:** by Bernard, 2026-11-11: routing `inherit`, delivered to a pull request, with the
decisions above as written, the `done-guard` loosening included.
**Shape:** behaviours with examples.
**Reviewed:** by a dispatched plan reviewer on 2026-11-11: two blocking findings (`done-guard`
undoing the checkpoints; task 1 used a `block` value the gate does not have), five should-fix (the
handoff overwritten at PreCompact, checkpoint tick and commit order, documents each change makes
wrong, behaviours without examples, path comparison) and three to consider. All folded in.

## Evidence gathered while planning, 2026-11-11

- **Each implementer runs the whole suite twice.** `skills/tdd/SKILL.md:38-40`: the first unit's
  start record "costs one `verify.test`", and `skills/tdd/SKILL.md:84-86` ends the unit with
  `verify.test` when no `test_affected` is set. An implementer is a fresh `tdd` session, so both
  happen per task. posta's suite is ~300 s, of which `api/v1test` is 244 s (session `07cd31ed`).
- **The posta window is 200k for real.** Largest context in session `07cd31ed`: 162,732 tokens, on
  `claude-opus-5-5`; posta's profile sets `gates.context_window` 200000, stop at the default 85%.
- **Notifications are the coordinator's largest context item.** Session `07cd31ed`: 186,525
  characters in 42 task notifications, 62,385 in Bash results, 46,522 in dispatch prompts.
- **The stop already lets a session go once the handoff is written.**
  `lib/context_watch.py:513-520` returns allow once the handoff is newer than the stop marker; only
  the text (`lib/context_watch.py:556-575`) tells the session to have the person `/clear`.
- **Premature review, twice in one run.** Session `07cd31ed`, 2026-11-09: task 7 implementer
  notified finished 12:07:31, spec review dispatched 12:07:45, implementer finished again 12:15:45,
  review redone as "round 2" at 12:15:57. Task 9: finished 12:59:09 and again 13:04:50, with spec
  and quality reviews dispatched in between. Both implementers had first notified "waiting on its
  own background work".
- **`done-guard` takes any `file_path` as code.** `hooks/done-guard:124-125` excludes only `.md`
  and `docs_root`, and `hooks/done-guard:247-249` reads the path as given, so an absolute path under
  the system temp directory counts.
- **No ADR states the full loop's discard rule.** It lives only in
  `skills/execute-plan/references/subagent-prompts.md` ("On a DEVIATES verdict in the full loop"
  and the paragraphs after it), with knock-ons in `delivery.md` and `parallel-batches.md`;
  `references/rationale.md` holds no discard rule, so task 5 adds its reason there.
- **Skill bodies sit at their ceiling.** `wc -w` gives `execute-plan` 709, `tdd` 746, `write-plan`
  729, counting frontmatter. The validator's hard ceiling is 700 body words
  (`tests/validate-skills.sh:25-33`, per ADR-0011), so no body may grow.
- **`done-guard` would undo the checkpoints.** It refuses a turn that edited code and never ran
  `verify.test` as a substring of a Bash command (`hooks/done-guard:242-254`), and this repository
  and others set `gates.done_verified` `required`. A checkpointed implementer runs only its task's
  tests, so task 1 also teaches the guard to count a scoped run.

## Global constraints

Every task inherits these.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh
  tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh
  hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  hooks/review-guard`. No typecheck, format or build command exists.
- Shellcheck at default severity after each file edit, not at the end.
- Never start on `main`. This plan runs on `feat/faster-plan-execution`.
- `hooks`, `lib/harness`, `settings.json`, `.github/workflows`, `templates/ci-review.yml` and
  `lib/context_watch.py` are `hard_block_paths`. Tasks 1 and 2 touch them.
- Hooks parse under `/bin/bash` 3.2 (`docs/standards.md`, "Scripts parse under bash 3.2"): python
  stays in the heredoc read into a variable, never inside `$( )`.
- **No `SKILL.md` body gains words.** All three this plan touches sit at the validator's 700-word
  body ceiling. New rules go in a reference (ADR-0011); a body line may be reworded to point at it, and
  its `wc -w` after the task is at most its count before.
- A change lands with the documents it makes wrong, each stating what is true now. Repair any
  `path:line` citation your edit shifts (`tests/test-validate-citations.sh`). Add one line for the
  task under `## Unreleased` in `CHANGELOG.md`.
- `tests/test-harness-claims.sh` fails any line in `README.md` or `docs/NN-*.md` that names
  `review-guard` or `hard_block_paths`, or uses gate or ceiling vocabulary, without a `keel:claim`
  tag within three lines: tag what you write the way the surrounding text does.
- `tests/run-tests.sh` takes about 5 minutes; each task's boundary run costs that.
- No em or en dashes anywhere, conventional commit messages, no attribution footers.
- Never `git stash`, in any form: the stash is shared by every worktree of this repository.

---

### Task 1: `done-guard` ignores edits outside the repository and sees a scoped test run

**Story:** idea record items 5 and 1 (a checkpointed implementer runs no `verify.test`)
**Files:**
- Modify: `hooks/done-guard`
- Modify: `templates/profile.schema.json`
- Modify: `docs/profile-keys.md`
- Modify: `docs/snapshot.md`
- Modify: `CHANGELOG.md`
- Test: `tests/test-done-guard.sh`

**Depends on:** none

**Behaviours:**

1. An edit whose path resolves outside the repository is not code. The root is
   `git -C <event cwd> rev-parse --show-toplevel`, else the event's `cwd` where that fails. Both the
   root and each path go through `os.path.realpath` before comparing (macOS `/var` is
   `/private/var`), and an inside path is made relative to the root before `is_code` reads it, since
   `is_code` compares a relative `docs_root` (`hooks/done-guard:124-125`). Example: a SubagentStop
   whose only call is `Write` to `/tmp/keel-probe/parse.py`, in a repository with
   `gates.done_verified` `required` and no test run, exits 0 with no output.
2. An absolute path inside the repository is still code. Example: `Edit` of `<repo>/lib/foo.sh`, no
   test run, under `required`, gives `decision` `block` naming `lib/foo.sh`, as today.
3. A relative path is read against the event's `cwd`, so it is inside. Example: `Write` of
   `lib/foo.sh` with no test run, under `required`, blocks as today; `Write` of
   `<repo>/docs/x.md` by absolute path passes, as a relative `docs/x.md` does today.
4. A path that climbs out is outside. Example: `Write` of `<repo>/../elsewhere/x.py` alone exits 0
   with no output.
5. A mix is judged on the inside paths only, and the message names only those. Example: `Write`
   of `/tmp/keel-probe/a.py` plus `Edit` of `<repo>/lib/foo.sh`, no test run, under `required`,
   blocks, and the reason does not contain `/tmp/keel-probe/a.py`.
6. A test run counts when the Bash command contains `verify.test`, as today, or
   `verify.test_affected`'s text before its first `{`, or `verify.test_one`'s text before its first
   `{`, each only where that prefix is not empty after trimming. This is what lets a checkpointed
   implementer (task 7) end on its task's own tests. Example: with `verify.test_one`
   `go test {path}`, an `Edit` of `<repo>/a.go` plus Bash `go test -count=1 -run TestX ./api/` exits
   0 with no output under `required`; with `verify.test_one` `{name}` (empty prefix) the same edit
   plus Bash `echo hi` still blocks.
7. The hook's header comment states both changes, beside "DOCUMENTATION TURNS PASS" and in "ITS
   LIMIT": a scoped test run now satisfies it, so it proves a test ran, not that the suite did.
   Example: the header contains `outside the repository` and `test_one`.
8. The `gates.done_verified` description in `templates/profile.schema.json` says a scoped test run
   counts, and `docs/profile-keys.md` is regenerated from it (`tests/generate-profile-keys.sh`).
   Every citation into `hooks/done-guard` that the header lines shift is repaired:
   `templates/profile.schema.json:124,330`, `docs/profile-keys.md:36,57`,
   `docs/snapshot.md:69-70,171`. Example: each cited line, read after the change, holds the text it
   held before.

**Done when:** `tests/test-done-guard.sh`, `tests/test-profile-keys.sh` and
`tests/test-validate-citations.sh` pass.

- [x] **Step 1.1: Build it test first** Note: Red witnessed by the round 2 implementer (6 failing cases quoted); behaviours 2, 3 and 6 second example pinned existing behaviour, passed on arrival. Round 1 DEVIATES: citations into hooks/done-guard left shifted; discarded. Citation repairs outside Files staged: docs/ideas/{declared-profile-keys-take-effect,keel-on-codex,lint-after-each-edit,standards-that-bind}.md, lib/harness/capabilities, tests/validate-skills.sh. Quality should-fix: prefix tests/ matches the lint command; test_one/test_affected read-by docs not updated.

Follow `keel:tdd`. Write cases for behaviours 1 to 6 in `tests/test-done-guard.sh`, in the style
of the cases already there (fixture directory, a transcript written for the event, `required` as at
`tests/test-done-guard.sh:103`).
Run: `tests/test-done-guard.sh`
Expected before the implementation: FAIL, the cases for behaviours 1, 4 and 5 fail because an
outside path is counted, and behaviour 6's first example fails because a scoped run is not seen.
Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: rounds: 2; routing: inherit; loop: full; implementer ran git stash list once (read-only)

```bash
git add hooks/done-guard tests/test-done-guard.sh templates/profile.schema.json \
        docs/profile-keys.md docs/snapshot.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(done-guard): ignore edits outside the repository, see a scoped run"`.

---

### Task 2: a plan run carries on past the context stop

**Story:** idea record item 2, second half
**Files:**
- Modify: `lib/context_watch.py`
- Modify: `docs/05-token-and-memory-design.md`
- Modify: `skills/execute-plan/references/delivery.md`
- Modify: `docs/profile-keys.md`
- Modify: `templates/profile.schema.json`
- Modify: `CHANGELOG.md`
- Test: `tests/test-context-watch.sh`

**Depends on:** task 1

**Behaviours:**

1. The stop text, both as the UserPromptSubmit context and as the PreToolUse deny reason, keeps its
   four steps for an ordinary session and adds a paragraph for a session coordinating
   `keel:execute-plan`: write the handoff naming the plan file and the `next:` line of
   `keel plan status <plan>`, and then carry on with the run rather than telling the person to
   `/clear`, because compaction is safe when the plan file holds the place. Example: past the stop
   threshold the prompt hook's output contains `execute-plan`, `keel plan status` and `carry on`.
2. The ordinary path is unchanged. Example: the same output still contains `PAUSE`,
   `.keel/handoff.md`, `/clear` and `Stop.` (the existing case at
   `tests/test-context-watch.sh:310` still passes).
3. The release is unchanged: once the handoff is newer than the stop marker, a non-allowed tool is
   let through (`lib/context_watch.py:513-520`). Example: the existing release case at
   `tests/test-context-watch.sh:336-341` still passes; no new case.
4. PreCompact keeps a handoff the session wrote: when the stop marker exists and the handoff is
   newer than it, PreCompact leaves the file as it is instead of rewriting it with the mechanical
   render (`lib/context_watch.py:472-477`). With no stop marker, or a handoff older than it,
   PreCompact writes the render as today. Example: write a handoff containing `next: 4.1` after the
   stop fires, send PreCompact, and the file still contains `next: 4.1`; with no stop marker the file
   is replaced by the render, as today.
5. The documents say what is true now: `docs/05-token-and-memory-design.md` states the plan-run
   branch and the kept handoff where it describes the stop ending with `/clear`, and
   `skills/execute-plan/references/delivery.md:54` no longer says a context-watch block always
   stops. Any citation into `lib/context_watch.py` the edit shifts is repaired, including
   `lib/context_watch.py:447` in `templates/profile.schema.json` and the regenerated
   `docs/profile-keys.md`. Example: `grep -n 'carry on' docs/05-token-and-memory-design.md
   skills/execute-plan/references/delivery.md` prints a line from each.

**Done when:** `tests/test-context-watch.sh`, `tests/test-harness-claims.sh`,
`tests/test-profile-keys.sh` and `tests/test-validate-citations.sh` pass.

- [x] **Step 2.1: Build it test first** Note: Red witnessed by the round 2 implementer (5 failing cases quoted); behaviour 3 pinned by the existing release case. Round 1 met the task; quality blocking: stop marker outlived compaction; discarded. Round 2 also scoped the ordinary-session steps (should-fix from round 1). Citation repairs outside Files: docs/ideas/context-window-at-init.md, docs/ideas/declared-profile-keys-take-effect.md. Schema and profile-keys needed no change. Quality should-fix: the kept handoff can name a stale next: if the run carries on several tasks before compaction; a failed marker removal is silent.

Follow `keel:tdd`. Write the cases for behaviours 1 and 4 in `tests/test-context-watch.sh`.
Run: `tests/test-context-watch.sh`
Expected before the implementation: FAIL, behaviour 1's case fails because the text has no
plan-run paragraph, and behaviour 4's first example fails because PreCompact overwrites the
handoff. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 2.2: Hand over** Note: rounds: 2; routing: inherit; loop: full

```bash
git add lib/context_watch.py tests/test-context-watch.sh docs/05-token-and-memory-design.md \
        skills/execute-plan/references/delivery.md docs/profile-keys.md templates/profile.schema.json CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(context-watch): a plan run carries on past the stop"`.

---

### Task 3: reports quote summaries, not whole outputs

**Story:** idea record item 2, first half
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `agents/keel-implementer.md`
- Modify: `CHANGELOG.md`
- Modify: `tests/evals/scenarios/commit-outside-a-worktree.md`
- Modify: `tests/evals/scenarios/implement-a-five-step-task.md`
- Modify: `tests/evals/scenarios/implement-a-two-step-task.md`
- Modify: `tests/evals/scenarios/implement-a-batched-task.md`

**Plan note, 2026-11-11, coordinator:** the four `tests/evals/scenarios/` files above were added
during execution. Each carries the implementer prompt's `=== RULES ===` block verbatim, which
`tests/test-eval-harness.sh` (case 23) checks, so a change to that block or to REPORT must be
mirrored in them; task 3's first attempt found it. Any citation into them that the change shifts is
repaired too.

**Depends on:** none

**Behaviours:** this task changes prompt text and has no failing test; each example is checked by
a reader against the diff and by the grep in `Done when:`.

1. The implementer prompt's REPORT asks, for each verify command, for the command, its exit code
   and its summary lines (at most 15: for a test runner the per-package or per-file pass and fail
   lines and the totals), plus every failing case in full. It no longer asks for "the exact output
   of each verify command". Example: the REPORT section contains `exit code` and `at most 15`, and
   `exact output of each verify command` appears nowhere in the file.
2. The red-before-implementation quote is scoped the same way: the failing case's name and its
   assertion message, not the whole run. Example: the REPORT asks for "the failing case and its
   message".
3. Both review prompts end with a length rule: verdict on the first line, at most 250 words, and
   command output quoted only where it is the evidence for a finding. Example: each prompt contains
   `at most 250 words`.
4. The prompt file says why, in one short paragraph under the implementer prompt: the reports land
   in the coordinator's context, and on 2026-11-09 they were its largest item (186,525 characters
   over 10 tasks), which is what drove the run into the context stop. Example: the paragraph
   contains `186,525`.

**Done when:** `tests/test-validate-skills.sh` and `tests/test-validate-citations.sh` pass, and
`grep -c 'exact output of each verify command' skills/execute-plan/references/subagent-prompts.md`
prints `0`.

- [x] **Step 3.1: Make the change and check it** Note: No-test task; examples checked by the spec reviewer against the diff and Done when (validate-skills 134/0, validate-citations 60/0, grep 0). First pass blocked on tests/test-eval-harness.sh case 23: four eval scenarios carry the RULES block verbatim and were not in Files; coordinator added them to tasks 3, 4 and 7 (plan note), same implementer mirrored the lines. Citation repairs outside Files: docs/ideas/implementers-run-git-stash.md, docs/prd/standards-assessment.md. Follow-up: the REPORT line asking to paste the Done when output still asks for whole output.

Edit the prompts as the behaviours say, keeping each prompt a fenced block the coordinator pastes.
Run: the `Done when:` commands, then `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [x] **Step 3.2: Hand over** Note: rounds: 1; routing: inherit; loop: light

```bash
git add skills/execute-plan/references/subagent-prompts.md agents/keel-implementer.md CHANGELOG.md \
        tests/evals/scenarios/commit-outside-a-worktree.md tests/evals/scenarios/implement-a-five-step-task.md \
        tests/evals/scenarios/implement-a-two-step-task.md tests/evals/scenarios/implement-a-batched-task.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(execute-plan): reports quote summaries, not whole outputs"`.

---

### Task 4: no review starts on a half-finished tree

**Story:** idea record item 4
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `agents/keel-implementer.md`
- Modify: `agents/keel-reviewer.md`
- Modify: `CHANGELOG.md`
- Modify: `tests/evals/scenarios/commit-outside-a-worktree.md`
- Modify: `tests/evals/scenarios/implement-a-five-step-task.md`
- Modify: `tests/evals/scenarios/implement-a-two-step-task.md`
- Modify: `tests/evals/scenarios/implement-a-batched-task.md`

**Plan note, 2026-11-11, coordinator:** the four `tests/evals/scenarios/` files above were added
during execution. Each carries the implementer prompt's `=== RULES ===` block verbatim, which
`tests/test-eval-harness.sh` (case 23) checks, so a change to that block or to REPORT must be
mirrored in them; task 3's first attempt found it. Any citation into them that the change shifts is
repaired too.

**Depends on:** task 3

**Behaviours:** this task changes prompt and agent text and has no failing test; each example is
checked by a reader against the diff and by the greps in `Done when:`.

1. The implementer prompt's RULES and both review prompts say: run every command in the
   foreground, never with `run_in_background` and never with a trailing `&`; give a long command
   the Bash `timeout` it needs, up to 600000 ms; do not end your turn while anything you started is
   still running, because the coordinator reads your stop as your report. Example: the rule appears
   in all three prompts, and `agents/keel-implementer.md` and `agents/keel-reviewer.md` each carry
   it as one bullet, with their rule counts corrected ("Five rules" at
   `agents/keel-implementer.md:11` becomes "Six rules", "Four rules" at `agents/keel-reviewer.md:14`
   becomes "Five rules").
2. "Running the loop" says the coordinator dispatches a review only on a report whose last line is
   the `git status --porcelain` paste; a notification that the agent is waiting on its own
   background work is not a report. Example: the section contains `waiting on its own background
   work` and `is not the report`.
3. It says what to do when an agent notifies again after its review was dispatched: the review is
   void, the coordinator re-reads `git status --porcelain`, and re-dispatches the review on the
   final tree; the redone review does not count as an implementer round. Example: the section
   contains `the review is void`.
4. It cites the evidence: session `07cd31ed`, 2026-11-09, tasks 7 and 9, with the times from the
   idea record, in the style of the 2026-10-12 note the review prompts already carry. Example: the
   section contains `07cd31ed` and `12:15:45`.

**Done when:** `tests/test-validate-skills.sh`, `tests/test-validate-citations.sh` and
`tests/test-agents.sh` pass, and `grep -c run_in_background skills/execute-plan/references/subagent-prompts.md agents/keel-implementer.md agents/keel-reviewer.md`
prints a count of at least 1 for each file.

- [ ] **Step 4.1: Make the change and check it**

Edit the prompts and agent bodies as the behaviours say.
Run: the `Done when:` commands, then `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [ ] **Step 4.2: Hand over**

```bash
git add skills/execute-plan/references/subagent-prompts.md agents/keel-implementer.md agents/keel-reviewer.md CHANGELOG.md \
        tests/evals/scenarios/commit-outside-a-worktree.md tests/evals/scenarios/implement-a-five-step-task.md \
        tests/evals/scenarios/implement-a-two-step-task.md tests/evals/scenarios/implement-a-batched-task.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(execute-plan): review only a finished report"`.

---

### Task 5: the full loop gets one scoped fix pass

**Story:** idea record item 3
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/execute-plan/references/rationale.md`
- Modify: `skills/execute-plan/references/delivery.md`
- Modify: `skills/execute-plan/references/parallel-batches.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 4

**Behaviours:** this task changes skill text and has no failing test; each example is checked by a
reader against the diff and by the grep in `Done when:`.

1. The spec review prompt ends a DEVIATES verdict with a `Fix scope:` line: either the list of
   what must change, or `redo` when the approach itself is wrong. The quality prompt does the same
   for a `blocking` finding. Example: both prompts contain `Fix scope:` and `redo`.
2. In the full loop, the first rejection (DEVIATES, or a `blocking` quality finding) whose fix scope
   is a list gets one fix pass, as the light loop's does: a fresh implementer on the plan's
   routing, handed the staged attempt and the verdict, told to change only what the fix scope
   names, counting toward `rounds`; then `keel plan risk --staged` again, and both passes again
   (spec, then quality). Example: a task rejected once for a missing test case, then passing both
   passes, ticks with `rounds: 2; routing: inherit; loop: full`.
3. A second full-loop rejection, or a first one whose fix scope is `redo`, discards the attempt
   and dispatches fresh from the clean tree, as today. A third rejection stops and asks the person,
   with every verdict. Example: rejected, fixed, rejected again: discard, fresh dispatch as round 3;
   rejected a third time: stop and ask.
4. In a declared batch the full-loop fix pass amends the task's commit in its worktree, as the
   light loop's does, and only a second rejection resets the worktree. Example:
   `parallel-batches.md`'s "In the full loop, a task that came back DEVIATES is not merged"
   paragraph (about `parallel-batches.md:121-125`) names the fix pass first and the reset second.
5. `references/rationale.md` gains a short section saying why the fix pass is safe in the full loop:
   it goes to a fresh agent, so nobody defends their own work, and it is bounded by the fix scope and
   one round; and why the second rejection discards, so a wrong approach is not patched twice. No
   discard rule is there today to replace. Example: the section contains `Fix scope`.
6. `delivery.md:35-37`, the list of what sends a task to the person, names the third full-loop
   rejection. Example: it contains `third`.
7. The light loop's rules are unchanged. Example: its numbered list reads as before.

**Done when:** `tests/test-validate-skills.sh` and `tests/test-validate-citations.sh` pass, and
`grep -c 'Fix scope:' skills/execute-plan/references/subagent-prompts.md` prints at least `2`.

- [ ] **Step 5.1: Make the change and check it**

Edit as the behaviours say. In `subagent-prompts.md` the paragraphs that change are "On a DEVIATES
verdict in the full loop", "In the full loop, discard the first attempt", "In the full loop, never
re-dispatch on top of the rejected attempt" and "A `blocking` finding from the quality review is
handled exactly as a DEVIATES verdict is" (which says "Discard"); reword them so they hold for the
second rejection and name the fix pass for the first.
Run: the `Done when:` commands, then `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [ ] **Step 5.2: Hand over**

```bash
git add skills/execute-plan/references/subagent-prompts.md skills/execute-plan/references/rationale.md \
        skills/execute-plan/references/delivery.md skills/execute-plan/references/parallel-batches.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(execute-plan): one scoped fix pass in the full loop"`.

---

### Task 6: ADR-0017, the suite runs at plan checkpoints

**Story:** idea record item 1
**Files:**
- Create: `docs/decisions/ADR-0017-a-plan-run-checks-the-suite-at-checkpoints.md`
- Modify: `docs/decisions/ADR-0009-the-unit-boundary-may-run-the-affected-tests.md`
- Modify: `docs/decisions/ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md`
- Modify: `CHANGELOG.md`

**Depends on:** none

**Behaviours:** this task writes a decision record and has no failing test; each example is checked
by a reader and by the commands in `Done when:`.

1. ADR-0017 follows `docs/decisions/ADR-0000-template.md`, status `accepted`, deciders Bernard,
   2026-11-11, driver the idea record. Example: its header table has the same rows as ADR-0009's.
2. Its Decision states, each as a rule:
   - Under `execute-plan`, the coordinator runs `verify.test` once before the first dispatch (the
     plan-start record), after every N tasks are committed and after the last task. N comes from
     the plan header line `**Suite checkpoints:** every N tasks`; `write-plan` writes 3 unless the
     person approving says otherwise. Example: a 10-task plan with N 3 runs the suite at start and
     after tasks 3, 6, 9 and 10.
   - Each implementer is handed the last checkpoint's record (its commit and the reds still on it)
     as its first start record, so it runs no `verify.test` for one, and its unit boundary is the
     task's `Done when:` and the lint command, plus `verify.test_affected` where the profile sets
     it. Example: a posta task stops paying two ~300 s suite runs and pays its `Done when:` only.
   - Order at a checkpoint task: its review passes, then the coordinator runs `verify.test` on the
     tree with that task staged, then ticks its last step with the note
     `rounds: <n>; routing: <profile>; loop: <light|full>; suite: pass` (or `suite: red <names>`
     matched against the record), then commits task and plan together as today. So the suite result
     is in the one tick, no re-tick replaces the note, and the tree is clean before the next
     dispatch. Example: task 3 of a 10-task plan with N 3 is ticked with `...; suite: pass`.
   - A checkpoint red not on the previous record stops the run before that tick: `keel:debug`
     through Phase 3, run by the coordinator, naming as candidates the staged task and the tasks
     committed since the previous checkpoint. If the staged task caused it, it is a rejection of
     that task, handled as the loop handles one. If an earlier task did, the staged task is still
     ticked and committed with `suite: red <names>`, and Phase 4 goes to a fresh implementer as a
     task appended to the plan, in the full loop, before any further dispatch. Example: a red at the
     task-6 checkpoint names tasks 4, 5 and 6.
   - A plan with no `**Suite checkpoints:**` line runs its steps as written: older plans name the
     suite in their steps, and the task text overrides the skill.
   - `review-code`, `ship`, CI and a declared batch's join gate are unchanged.
3. It states what it amends: ADR-0006's per-unit boundary and ADR-0009's "the first start record of
   a `tdd` session still costs one full `verify.test`", for a unit run under `execute-plan` with a
   checkpoint line only. Standalone `tdd` is unchanged. Example: the ADR's Supersedes row reads
   "none; amends ADR-0006 and ADR-0009", as ADR-0009's does for ADR-0006.
4. Its Consequences name the cost: a break is found up to N tasks late and narrowed to a range, not
   pinned to one task, and the commits it spans are already on the branch, so the fix lands as a
   new commit rather than a rejected attempt; and `done-guard` now counts a scoped test run (task
   1), so it no longer proves the suite ran. It names the measured gain (idea record, item 1).
   Example: the Consequences section contains `up to N tasks late` and `done-guard`.
5. Alternatives considered: a Go `test_affected` recipe (rejected as the whole answer: posta's
   `api/v1test` is in nearly every selection), and running the suite at the plan's end only
   (rejected: a break found after ten tasks has ten candidates). Example: the section has two
   subsections, as ADR-0009's does.
6. ADR-0006 and ADR-0009 change in their header tables only, each gaining an "Amended by" row
   naming ADR-0017. Example: `grep 'Amended by' docs/decisions/ADR-0009-*.md` prints a row naming
   ADR-0017.

**Done when:** `tests/test-validate-citations.sh` and `tests/test-doc-claims.sh` pass, and
`grep -c 'Amended by' docs/decisions/ADR-0006-*.md docs/decisions/ADR-0009-*.md` prints at least 1
for each.

- [ ] **Step 6.1: Write it and check it**

Write the ADR as the behaviours say and add the two header rows.
Run: the `Done when:` commands, then `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [ ] **Step 6.2: Hand over**

```bash
git add docs/decisions/ADR-0017-a-plan-run-checks-the-suite-at-checkpoints.md \
        docs/decisions/ADR-0009-the-unit-boundary-may-run-the-affected-tests.md \
        docs/decisions/ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(decisions): ADR-0017, suite checkpoints in a plan run"`.

---

### Task 7: suite checkpoints in the skills

**Story:** idea record item 1
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/tdd/references/affected-tests.md`
- Modify: `skills/tdd/SKILL.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `docs/02-skill-catalog.md`
- Modify: `CHANGELOG.md`
- Modify: `tests/evals/scenarios/commit-outside-a-worktree.md`
- Modify: `tests/evals/scenarios/implement-a-five-step-task.md`
- Modify: `tests/evals/scenarios/implement-a-two-step-task.md`
- Modify: `tests/evals/scenarios/implement-a-batched-task.md`

**Plan note, 2026-11-11, coordinator:** the four `tests/evals/scenarios/` files above were added
during execution. Each carries the implementer prompt's `=== RULES ===` block verbatim, which
`tests/test-eval-harness.sh` (case 23) checks, so a change to that block or to REPORT must be
mirrored in them; task 3's first attempt found it. Any citation into them that the change shifts is
repaired too.

**Depends on:** tasks 5 and 6

**Behaviours:** this task changes skill text and has no failing test; each example is checked by a
reader against ADR-0017 and by the commands in `Done when:`.

1. The plan template's header gains `**Suite checkpoints:** every 3 tasks`, with a paragraph
   beside the routing and delivery paragraphs: what it means, that 3 is the default and the person
   approving may change it, and that ADR-0017 is the reason. Example: the header block contains the
   line.
2. The template's Step N.1 boundary run becomes, for a plan with that line, the task's `Done when:`
   and the lint command, plus `verify.test_affected` where set, and no `verify.test`. Example: the
   Step 3.1 example no longer names `./gradlew test` as its boundary run, and says the coordinator
   runs the suite at checkpoints.
3. `subagent-prompts.md` gains a section, "Suite checkpoints", after "Running the loop": the
   plan-start run, the run after every N committed tasks and after the last, a red's handling as
   ADR-0017 states it, and the order at a checkpoint task exactly as ADR-0017 gives it: review
   passes, `verify.test` on the tree with the task staged, one tick whose note ends
   `; suite: pass` or `; suite: red <names>`, then the commit. Example: the section exists and names
   `keel:debug`, `Phase 3` and `suite: pass`.
4. The implementer prompt gains a `=== START RECORD ===` block the coordinator fills with the last
   checkpoint's commit and its reds, and a rule: take it as your first start record and do not run
   `verify.test`. Example: the prompt contains `=== START RECORD ===`.
5. `affected-tests.md` gains "When a plan run hands you the start record": the handed record
   replaces the first unit's full run, and the boundary is as behaviour 2 says; `tdd`'s body line on
   the unit boundary (its "Unit boundary" lines, nothing else in the body) points at it without
   growing. `docs/02-skill-catalog.md` is corrected where it says what `tdd` or `execute-plan`
   runs at a boundary. Example: `wc -w skills/tdd/SKILL.md` prints at
   most 746.
6. A plan with no checkpoint line is run as written. Example: the new section says so in one
   sentence.
7. `write-plan`'s step 6 approval question carries N beside routing and delivery, reworded so the
   body does not grow. Example: its example question reads like "Approve, implement on
   keel-implementer, suite every 3 tasks, deliver to a pull request", and
   `wc -w < skills/write-plan/SKILL.md` prints at most 729.

**Done when:** `tests/test-validate-skills.sh` and `tests/test-validate-citations.sh` pass,
`grep -c '=== START RECORD ===' skills/execute-plan/references/subagent-prompts.md` prints at least
`1`, `wc -w < skills/tdd/SKILL.md` prints at most `746`, and `wc -w < skills/write-plan/SKILL.md`
prints at most `729`.

- [ ] **Step 7.1: Make the change and check it**

Edit as the behaviours say, reading ADR-0017 first.
Run: the `Done when:` commands, then `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [ ] **Step 7.2: Hand over**

```bash
git add skills/execute-plan/references/subagent-prompts.md skills/tdd/references/affected-tests.md \
        skills/tdd/SKILL.md skills/write-plan/references/plan-template.md skills/write-plan/SKILL.md \
        docs/02-skill-catalog.md CHANGELOG.md tests/evals/scenarios/commit-outside-a-worktree.md \
        tests/evals/scenarios/implement-a-five-step-task.md tests/evals/scenarios/implement-a-two-step-task.md \
        tests/evals/scenarios/implement-a-batched-task.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(execute-plan): run the suite at plan checkpoints"`.
