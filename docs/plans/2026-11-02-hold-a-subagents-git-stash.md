# Hold a subagent's git stash Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for tasks 1 and 2. Task 3 changes records and says under its
> behaviours why it carries no failing test.

**Goal:** no subagent can run a stash-writing `git stash`: `hooks/review-guard` refuses it to every
call that carries an `agent_type`, and the implementer brief and agent say so, so the four
implementer stashes of 2026-09-19 to 2026-10-29 cannot recur by habit.
**Stories:** none. `docs/ideas/implementers-run-git-stash.md`, agreed by Bernard on 2026-11-02 with
its open question 1 confirmed: the refusal reaches every subagent, a user's own agents included.
**ADRs:** ADR-0010 (a keel reviewer's git is held by a hook), which task 3's ADR-0016 extends;
ADR-0004 and ADR-0014 (a guarantee belongs to a repository and harness pair, and rests on a ledger
row with evidence); ADR-0011 (task 2 edits a skill reference and an agent body, so the release that
ships this owes a gate arm for skill text); ADR-0012 (a task carries two steps).
**Architecture:** `hooks/review-guard` already parses where a git command acts, already refuses
`stash` to the reviewer, and is already registered on every Bash call. It gains a second, narrower
rule: a call whose `agent_type` is present and is not the reviewer's is refused the stash-writing
forms of `git stash` and nothing else. The reviewer's rules are unchanged. The cheap filter widens
from the reviewer's name to the reviewer's name or the word `stash`, so a subagent call that does
not mention a stash still returns without starting python3. No new ledger primitive: the rule rests
on `pretooluse_agent_type`, which `review-guard` already requires.
**Implementer routing:** inherit
**Delivery:** pull-request
**Concurrent batches:** none. Task 1 touches `hard_block_paths` and takes the full loop, task 2's
Files block carries a note, and task 3 records both; `keel plan batches` runs every task alone.
**Decided:** Bernard, 2026-11-02, in the idea record: any subagent, confirmed. Decided in this plan
and put to Bernard at approval: extend `review-guard` rather than add a hook (one parser, one
registration, and the parser is the expensive part); allow `stash list` and `stash show`, which only
read; record the widening as ADR-0016 rather than editing the accepted ADR-0010.
**Approved:** by Bernard, 2026-11-02: routing `inherit`, delivered to a pull request, with the
three decisions above as written.
**Shape:** behaviours with examples.
**Reviewed:** by a dispatched plan reviewer on 2026-11-02: one blocking finding (behaviour 5 said
every existing case still passes, while `tests/test-review-guard.sh:110-111` assert the old scope),
three should-fix (how the fallback and the python split read the stash, and task 2's test passing on
arrival) and two to consider (the filter matching `stash` in a path, and a stale idea-record
sentence). Every one is folded in.

## Evidence gathered while planning, 2026-11-02, Claude Code 2.1.316

- **A user's own agent carries its name as `agent_type`.** A throwaway plugin loaded with
  `--plugin-dir` logged its PreToolUse `Bash` input. The main session's `echo main-session` carried
  no `agent_type` (`None`); an agent defined in the project's `.claude/agents/helper.md` and
  dispatched by the main session carried `'helper'`. With the 2026-10-17 probe in
  `lib/harness/capabilities` (`pretooluse_agent_type`: none for the main session, `general-purpose`
  for a general-purpose subagent, `<plugin>:<agent>` for a plugin's agent), every kind of subagent
  is now seen to carry one. The ledger row is not restamped: the new observation is on 2.1.316, and
  a required row stamped above 2.1.302 would raise keel's minimum.
- **A user's own agent, dispatched as a subagent, carries an `agent_id`.** Recorded after task 3,
  2026-11-02, on 2.1.316: the same throwaway plugin logged `agent_type` `'helper'` and `agent_id`
  `'a07218604e29496a9'` for the Bash call of the project agent `.claude/agents/helper.md`
  dispatched by the main session. So keying the stash rule on a non-empty `agent_id` reaches a
  user's own agents, as the idea record intends.
- **The idea record's open question 2 misdescribes the reviewer's rule.** It says `review-guard`
  allows `stash list` and `stash show`. It does not: `stash` is in `SHARED`
  (`hooks/review-guard#SHARED = {"stash"`), and `judge_git` refuses every subcommand in that set
  whatever its action. This plan keeps the reviewer's rule as it is and allows the two reading forms
  to other subagents only.
- **No keel prompt tells an implementer not to stash.**
  `skills/execute-plan/references/subagent-prompts.md` forbids `stash` in the two review prompts
  only, and `agents/keel-implementer.md` names commit and staging rules only.

## Global constraints

Every task inherits these.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh
  tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh
  hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  hooks/review-guard`. No typecheck, format or build command exists.
- Shellcheck at default severity after each file edit, not at the end.
- Never start on `main`.
- `hooks`, `lib/harness`, `settings.json`, `.github/workflows`, `templates/ci-review.yml` and
  `lib/context_watch.py` are `hard_block_paths`. Task 1 touches them, which is why routing is
  `inherit` unless the person approving says otherwise.
- `hooks/review-guard` must parse under `/bin/bash` 3.2 (`docs/standards.md`, "Scripts parse under
  bash 3.2"): its python stays in the heredoc read into a variable, never inside `$( )`.
- The main session is never touched. A call with no `agent_type` is allowed whatever it runs, and a
  main-session command that merely mentions `agent_type` or `stash` in its text is not refused.
- A change lands with the documents it makes wrong, each stating what is true now. Repair any
  `path:line` citation your edit shifts (`tests/test-validate-citations.sh`).
- `tests/test-harness-claims.sh` fails any line in `README.md` or `docs/NN-*.md` that names
  `review-guard` or `hard_block_paths` without a `keel:claim` tag within three lines: tag what you
  write the way the surrounding text does.
- `tests/run-tests.sh` takes about 5 minutes; each task's boundary run costs that.
- No em or en dashes anywhere, conventional commit messages, no attribution footers.
- Never `git stash`, in any form: the stash is shared by every worktree of this repository.

---

### Task 1: `review-guard` refuses a stash-writing `git stash` to every subagent

**Story:** the idea record's recommendation, first half
**Files:**
- Modify: `hooks/review-guard`
- Test: `tests/test-review-guard.sh`

**Depends on:** none

**Behaviours:**

1. A subagent that is not the reviewer is refused every stash-writing form, with a reason it can
   read and its own wording (not the reviewer's "from a keel reviewer"). Example: with `agent_type`
   `general-purpose`, each of `git stash`, `git stash push -m x`, `git stash pop`, `git stash
   apply`, `git stash drop`, `git stash clear`, `git stash -u` and `git stash -m list` gets
   `permissionDecision` `deny`, and the reason says the stash is shared by every worktree and names
   `keel review-guard`.
2. The two reading forms are allowed to it, read as git reads them: only the first word after
   `stash` is a subcommand, so the test is that word, not the first non-option word (`action` at
   `hooks/review-guard:453` is the latter, and would read `git stash -m list` as `list`). Example:
   `git stash list` and `git stash show -p stash@{0}` from `general-purpose` print nothing and exit
   0.
3. The forms the parser already follows are followed for it too. Example: from `general-purpose`,
   `cd /tmp/x && git stash`, `git -C /tmp/x stash`, `env A=1 git stash` and `git status && git
   stash` are each refused.
4. Nothing else changes for a subagent that is not the reviewer. Example: from `general-purpose`,
   `git add a.txt`, `git commit -m x`, `git reset --hard` and `git checkout -b x` print nothing and
   exit 0; and an agent type a user defined, `helper`, is refused `git stash` exactly as
   `general-purpose` is.
5. The main session and the reviewer are unchanged. Example: `git stash` with no `agent_type` prints
   nothing and exits 0; from `keel:keel-reviewer`, `git stash list` is still refused, and every
   existing reviewer and main-session case in `tests/test-review-guard.sh` still passes. Two
   existing cases assert the old scope and are changed, not kept: `tests/test-review-guard.sh:110`
   (`general-purpose` may `git stash`) and `:111` (`keel:keel-fanout` may `git stash`) become deny
   cases, and the comments at `:3-5`, `:106-108` and `:307-309` that describe a reviewer-only scope
   are rewritten.
6. The fallback, when python3 is absent or the input will not parse, holds the same line. `blind()`
   (`hooks/review-guard#blind() {`) exits today unless `agent_type` names the reviewer, and refuses by
   word with a bash ERE, which has no lookahead, so telling `stash` from `stash list` needs a second
   pattern or a loop over the matches. Example: with python3 off the PATH and `agent_type`
   `general-purpose`, `git stash` and `git stash list && git stash` are refused, `git stash list`
   and `git commit -m x` are allowed; a main-session command whose text contains `"agent_type":
   "general-purpose"` and `git stash` (JSON-escaped inside the command string) is allowed.
7. A subagent call whose input does not contain the word `stash` returns without starting python3.
   The filter reads the whole event, so a `cwd` or `transcript_path` containing `stash` still starts
   python3; the answer stays correct, only the cost differs, and the header says so. Example: with a
   `python3` shim beside `bash` on the PATH that only records that it ran (as `pyfail` at
   `tests/test-review-guard.sh:352-355` is built), `git commit -m x` from `general-purpose` leaves
   no record, and `git stash` from `general-purpose` does.

Where the change goes in the python: the early exit at `hooks/review-guard:107-108` splits into
three (no agent type: allow; the reviewer: today's rules; any other subagent: the stash rule), and
every refusal path in `judge_git` (`:356`, `:358-404`) applies to the reviewer only, or behaviour 4
fails.

The header comment says who the hook touches now (the reviewer for the full list, every other
subagent for the stash alone), why the stash and nothing else (the four implementer instances in
`docs/ideas/implementers-run-git-stash.md`, and that implementers must keep `add` and `commit` in
their own worktrees), and that the main session is never touched.

**Done when:** `tests/test-review-guard.sh` passes, and the profile's lint command passes.

- [x] **Step 1.1: Build it test first**

Follow `keel:tdd` for behaviours 1 to 7 in `tests/test-review-guard.sh`, using its existing event
builder, with an agent type other than `-` and other than the reviewer's, and turn
`tests/test-review-guard.sh:110-111` into deny cases. Run it and watch behaviours 1, 3, 4's
`helper` case, 6's refusals, 7's `git stash` record and the two turned cases fail because the hook
exits at once for any agent that is not the reviewer. Then change the hook and its header.
Run: `tests/test-review-guard.sh`
Expected before the implementation: FAIL on those cases. Expected after: PASS. Quote the failing
output in your report, and name the cases that passed on arrival.
Also run the hook under `/bin/bash` by name, as the existing cases do, so a bash 3.2 parse failure
shows.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality nothing blocking; a coordinator probe after it showed a main session started with --agent carries agent_type, which the staged rule would refuse, so task 1b keys on agent_id and also takes the --attr-source and fallback gaps; committed rather than discarded because the rest of the work stands, a departure from the full loop recorded here; the implementer ran a read-only git stash list against its dispatch

```bash
git add hooks/review-guard tests/test-review-guard.sh
git status --porcelain
```

Stage exactly those paths, plus any doc whose citation you repaired, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "feat(review-guard): refuse a stash-writing git stash to every subagent"`. Paste the
`git status --porcelain` output into your report.

---

### Task 1b: tell a subagent from the main session by `agent_id`, and close two parser gaps

**Story:** task 1's quality review, 2026-11-02, and a probe the coordinator ran after it
**Files:**
- Modify: `hooks/review-guard`
- Test: `tests/test-review-guard.sh`

**Depends on:** task 1

**Behaviours:**

1. A main session started with `--agent` is never touched. Probe, Claude Code 2.1.316, 2026-11-02:
   `claude -p --agent helper` logged `agent_type` `'helper'` and `agent_id` `None` for the main
   session's own Bash call, so `agent_type` alone does not mean a subagent. The stash rule applies
   only when the event carries a non-empty `agent_id`, on the python path and in the fallback.
   Example: an event with `agent_type` `helper` and no `agent_id` running `git stash` prints nothing
   and exits 0; the same event with an `agent_id` is refused. The reviewer's rules keep keying on
   `agent_type`, unchanged.
2. `--attr-source` takes a value, so `git --attr-source HEAD stash` is read as a stash. Example: from
   a subagent it is refused; from the reviewer, `git --attr-source HEAD commit -m x` is refused.
3. The fallback reads any option word between `git` and `stash`, so it can only refuse more.
   Example: with python3 off the PATH, a subagent's `git -P stash`, `git --bare stash` and
   `git --namespace n stash` are refused, and `git -P stash list` is allowed.

The header comment says the subagent test is `agent_id`, and why (the `--agent` probe).

**Done when:** `tests/test-review-guard.sh` passes, and the profile's lint command passes.

- [x] **Step 1b.1: Build it test first**

Follow `keel:tdd` for behaviours 1 to 3 in `tests/test-review-guard.sh`; the event builder gains an
`agent_id` the subagent cases set. Run it and watch behaviour 1's main-session case, behaviour 2 and
behaviour 3's refusals fail. Then change the hook and its header.
Run: `tests/test-review-guard.sh`
Expected before the implementation: FAIL on those cases. Expected after: PASS. Quote the failing
output in your report.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named.

- [x] **Step 1b.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality nothing blocking, consider: a main session started as --agent keel:keel-reviewer still gets the reviewer rules; the ledger records only pretooluse_agent_type though the rule reads agent_id; no fallback case for an empty agent_id

```bash
git add hooks/review-guard tests/test-review-guard.sh
git status --porcelain
```

Stage exactly those paths, plus any doc whose citation you repaired, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "fix(review-guard): key the stash rule on agent_id, and read two more git forms"`.

---

### Task 2: the implementer brief and agent say never to stash

**Story:** the idea record's recommendation, second half
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md` (section 1, the implementer prompt's
  `=== RULES ===`)
- Modify: `agents/keel-implementer.md`
- Modify: `tests/evals/scenarios/commit-outside-a-worktree.md`,
  `tests/evals/scenarios/implement-a-five-step-task.md`,
  `tests/evals/scenarios/implement-a-two-step-task.md` and
  `tests/evals/scenarios/implement-a-batched-task.md` (added during execution: each carries section
  1's `=== RULES ===` block verbatim, which `tests/test-eval-harness.sh` checks)
- Test: `tests/test-agents.sh`

**Depends on:** none

**Behaviours:**

1. The implementer prompt carries the rule, with its reason. Example: section 1's `=== RULES ===`
   holds a line saying never to run `git stash` other than `list` or `show`, because the stash is
   shared by every worktree and a stash can hide a task's whole diff from the coordinator, and that
   a hook refuses it.
2. The agent body carries the same rule. Example: `agents/keel-implementer.md` names `git stash`
   among the rules that hold whatever the brief says, and its "Four rules hold" (`:10`) becomes
   "Five rules hold".
3. A test pins both, so the rule cannot be dropped silently. Example: `tests/test-agents.sh` fails
   when `agents/keel-implementer.md` stops naming `git stash`, or when section 1's `=== RULES ===`
   block of `subagent-prompts.md` (from `=== RULES ===` to `=== REPORT ===`) does; the case reads
   that block alone, because the review prompts in the same file already name `git stash` and a
   grep over the whole file would pass on arrival.
4. Both stay inside their budgets. Example: `tests/validate-skills.sh` passes, with no new warning
   for `execute-plan`'s references or the agent.

**Done when:** `tests/test-agents.sh` and `tests/validate-skills.sh` pass.

- [x] **Step 2.1: Build it test first**

Follow `keel:tdd` for behaviour 3: add the case to `tests/test-agents.sh`, run it, and watch it fail
because neither file names `git stash` for the implementer. Then add the two rules.
Run: `tests/test-agents.sh`
Expected before the implementation: FAIL on behaviour 3. Expected after: PASS. Quote the failing
output in your report.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [x] **Step 2.2: Hand over** Note: rounds: 2; routing: inherit; loop: light; first pass left tests/test-eval-harness.sh red (four eval scenarios carry the RULES block verbatim), so the coordinator added them to the Files list and a fix pass copied the rule in; spec COMPLIES; no quality review, review-code covers it

```bash
git add skills/execute-plan/references/subagent-prompts.md agents/keel-implementer.md \
        tests/test-agents.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(execute-plan): tell the implementer never to stash"`. Paste the
`git status --porcelain` output into your report.

---

### Task 3: the records say what is true now

**Story:** the records tasks 1 and 2 make wrong
**Files:**
- Create: `docs/decisions/ADR-0016-a-subagents-stash-is-held-by-a-hook.md`
- Modify: `docs/07-open-decisions.md` (section 3, the sentence on `hooks/review-guard`)
- Modify: `docs/01-architecture.md` (the layer 1 sentence naming `review-guard`)
- Modify: `docs/06-repo-layout.md` (the `review-guard` comment)
- Modify: `docs/ideas/implementers-run-git-stash.md` (Status, Next, open question 2, and the
  "cheap filter passes only the reviewer's calls" finding, and the rows that scope by `agent_type`,
  which task 1b changed to `agent_id`)
- Modify: `docs/ideas/workflows-for-the-fan-outs.md` (`:88`, "No hook refuses an implementer's
  tree-changing git")
- Modify: `CHANGELOG.md` (an Unreleased section)

**Depends on:** tasks 1, 1b and 2

**Behaviours:**

1. ADR-0016 records the decision in the shape of `docs/decisions/ADR-0000-template.md`. Example:
   status accepted, deciders Bernard 2026-11-02, it extends ADR-0010 without superseding it, its
   context cites the four instances by `path:line` from the idea record, its decision is the stash
   rule for every subagent and the two reading forms, its consequences name that a user's own agents
   lose the stash-writing forms, and its verification cites `tests/test-review-guard.sh`. It says the
   rule keys on a non-empty `agent_id`, citing the 2026-10-17 probe (ADR-0010's context: subagents
   carry `agent_id`, the main session does not) and the 2026-11-02 `--agent` probe in this plan's
   task 1b (a main session started with `--agent` carries `agent_type` but no `agent_id`).
2. `docs/07-open-decisions.md`, `docs/01-architecture.md` and `docs/06-repo-layout.md` say the hook
   holds the reviewer's git and every subagent's stash. Example: none of them says the hook touches
   keel reviewers only, and each cites ADR-0016 beside ADR-0010.
3. The idea record says what was built. Example: Status reads built 2026-11-02, Next reads nothing,
   and open question 2's statement that `review-guard` allows `list` and `show` is corrected to say
   the reviewer is refused every form and other subagents may read.
4. `CHANGELOG.md` has an Unreleased entry for the guard and one for the implementer rule.
5. `docs/ideas/workflows-for-the-fan-outs.md:88` no longer says no hook refuses an implementer's
   git without naming the stash. Example: it says a hook refuses every subagent the stash-writing
   forms (ADR-0016), and an implementer's other tree-changing git is still not refused.

There is no failing test for this task: it changes records. `tests/test-validate-citations.sh`,
`tests/test-doc-claims.sh` and `tests/test-harness-claims.sh` check what can be checked.

**Done when:** `tests/run-tests.sh` passes.

- [x] **Step 3.1: Write the records and run the suite**

Make the edits, then run `tests/run-tests.sh` and quote its summary.

- [x] **Step 3.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; no quality review, review-code covers it

```bash
git add docs/decisions/ADR-0016-a-subagents-stash-is-held-by-a-hook.md \
        docs/07-open-decisions.md docs/01-architecture.md docs/06-repo-layout.md \
        docs/ideas/implementers-run-git-stash.md docs/ideas/workflows-for-the-fan-outs.md \
        CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs: record that every subagent's stash is held by a hook"`. Paste the
`git status --porcelain` output into your report.

---

### Task 4: the review-guard follow-ups from review and audit

**Story:** the follow-ups in "Delivery" below and the security audit's "worth checking" list,
2026-11-02, which Bernard asked to handle before merging
**Files:**
- Modify: `hooks/review-guard`
- Modify: `lib/harness/capabilities`
- Modify: `docs/harness-support.md` (regenerated)
- Test: `tests/test-review-guard.sh`
- Test: `tests/test-harness-claims.sh`

**Depends on:** tasks 1, 1b and 3

**Behaviours:**

1. The event reaches python3 on stdin, not in an environment variable, so an event too large for
   the environment is still judged by the parser. Example: `hooks/review-guard` no longer sets
   `KEEL_EVENT`; python3 is started with the script as an argument (`-c`) or from a file, and reads
   the event from stdin; every existing case in `tests/test-review-guard.sh` still passes. (Added
   by a fix pass after review: a 1.1 MB event, its padding in `tool_input.description`, is refused
   by the parser in under half a second.)
2. The reviewer's rules apply only to a subagent too: an event with `agent_type`
   `keel:keel-reviewer` and no `agent_id` is a main session started as `--agent keel:keel-reviewer`
   and is never touched. Example: that event running `git stash list` or `git commit -m x` prints
   nothing and exits 0, on the python path and in the fallback; the same event with an `agent_id`
   is refused, as today. The two task 1b cases "a reviewer with no agent_id is still refused" are
   turned into allow cases.
3. The fallback decides by `agent_id` presence and the exact reviewer name, so an odd agent name
   cannot let a stash through. Example: with python3 off the PATH, an event whose `agent_type` is
   `we"ird` (JSON-escaped) and which carries an `agent_id` is refused `git stash`.
4. The ledger records `agent_id` and the guard requires it, without moving the minimum. Example:
   `lib/harness/capabilities` holds
   `provides|claude|pretooluse_agent_id|probe:a plugin PreToolUse hook on Bash logged an agent_id for a general-purpose subagent and a plugin agent and none for the main session, docs/plans/2026-10-17-reviewer-git-guard.md, and on 2.1.316 none for a main session started with --agent and one for a project agent from .claude/agents, docs/plans/2026-11-02-hold-a-subagents-git-stash.md|2.1.302|2026-11-02`
   and `requires|review-guard|pretooluse_agent_id`; the comment above the rows says the guard needs
   `agent_id` to tell a subagent from the main session; regenerated `docs/harness-support.md`
   still reads "Minimum Claude Code version: 2.1.302"; `tests/test-harness-claims.sh` pins both
   rows.
5. The header states the two limits the review found, as limits: the fallback's catch-all option
   pattern applies to the reviewer's fallback as well as a subagent's, and only refuses more; and a
   subagent's `echo git stash` or a heredoc body that names `git stash` is refused, because the hook
   reads every `git` word and heredoc bodies as commands, which errs toward refusing. Example: the
   header names both, and a test pins that a subagent's `echo git stash` is refused, so the limit is
   stated and observed rather than discovered.

**Done when:** `tests/test-review-guard.sh` and `tests/test-harness-claims.sh` pass, and the
profile's lint command passes.

- [x] **Step 4.1: Build it test first**

Follow `keel:tdd` for behaviours 2 to 5: write or turn the cases, run them and watch behaviour 2's
allow cases, behaviour 3's refusal and behaviour 4's rows fail. Behaviour 1 is a refactor that the
existing cases cover: make it after the others pass, and run the whole file again. Then change the
hook, its header, the ledger, and regenerate `docs/harness-support.md`.
Run: `tests/test-review-guard.sh` and `tests/test-harness-claims.sh`
Expected before the implementation: FAIL on those cases. Expected after: PASS. Quote the failing
output in your report.
Also run the hook under `/bin/bash` by name, as the existing cases do.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named.

- [x] **Step 4.2: Hand over** Note: rounds: 2; routing: inherit; loop: full; spec COMPLIES; quality nothing blocking, should fix: the stdin case was only a grep; a fix pass on top of the reviewed attempt added a real 1.1 MB case, made agent_id string-only and corrected the header, checked COMPLIES; consider left: a non-string agent_type with a string agent_id differs between paths (live events carry strings)

```bash
git add hooks/review-guard lib/harness/capabilities docs/harness-support.md \
        tests/test-review-guard.sh tests/test-harness-claims.sh
git status --porcelain
```

Stage exactly those paths, plus any doc whose citation you repaired, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "fix(review-guard): read the event on stdin, key the reviewer on agent_id too, and record agent_id"`.

---

### Task 5: the records for task 4

**Story:** the records task 4 makes wrong
**Files:**
- Modify: `docs/decisions/ADR-0016-a-subagents-stash-is-held-by-a-hook.md`
- Modify: `docs/ideas/implementers-run-git-stash.md`
- Modify: `docs/ideas/workflows-for-the-fan-outs.md` (the row near `:86` that says the guarantee
  keys on the agent type)
- Modify: `tests/test-harness-resolve.sh` (the comment saying `pretooluse_agent_type` alone sets the
  2.1.302 minimum)
- Modify: `CHANGELOG.md`

**Depends on:** task 4

**Behaviours:**

1. ADR-0016 says what is true after task 4. Example: it no longer says a main session started as
   `--agent keel:keel-reviewer` gets the reviewer's rules, nor that the ledger names only
   `pretooluse_agent_type`; it says both rules key on `agent_id`, and names the two stated limits.
2. The idea record's open question 2 states the two rules side by side as current state. Example:
   it reads that the reviewer is refused every form of `stash` and other subagents may run
   `list` and `show`, with no sentence framed as a correction.
3. `CHANGELOG.md`'s Unreleased entry for the guard says the reviewer is held only as a subagent.
4. Task 4's review found three more sentences made wrong. Example: ADR-0016 and the idea record say
   "a non-empty `agent_id` string" where they say the subagent test; the workflows row says the
   guarantee keys on `agent_id`; the `tests/test-harness-resolve.sh` comment names both
   `pretooluse_agent_type` and `pretooluse_agent_id` as setting the 2.1.302 minimum.

There is no failing test for this task: it changes records. `tests/test-validate-citations.sh`,
`tests/test-doc-claims.sh` and `tests/test-harness-claims.sh` check what can be checked.

**Done when:** `tests/run-tests.sh` passes.

- [x] **Step 5.1: Write the records and run the suite**

Make the edits, then run `tests/run-tests.sh` and quote its summary.

- [x] **Step 5.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; consider: ADR-0016 attaches the 2.1.302 stamp to the requires rows where it is the provides row that carries it; ADR-0010 left as written, ADR-0016 records the change

```bash
git add docs/decisions/ADR-0016-a-subagents-stash-is-held-by-a-hook.md \
        docs/ideas/implementers-run-git-stash.md docs/ideas/workflows-for-the-fan-outs.md \
        tests/test-harness-resolve.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs: record the review-guard follow-ups"`.

---

### Task 6: a subagent's stash rule reads only commands that run, and bounds its time

**Story:** the "Remaining, by decision" items on PR #11, which Bernard asked to close on
2026-11-02
**Files:**
- Modify: `hooks/review-guard`
- Test: `tests/test-review-guard.sh`

**Depends on:** tasks 4 and 5

**Behaviours:**

1. For a subagent's stash rule, a heredoc's body is not read as commands. Example: from a subagent
   (non-empty `agent_type` and `agent_id`), `cat <<'EOF' > notes.md` / `run git stash to save` /
   `EOF` and `git commit -F - <<EOF` / `fix: avoid git stash` / `EOF` are allowed, and so is the
   `<<-EOF` form with a tab-indented delimiter; `cat <<EOF` / `x` / `EOF` / `git stash` (a stash
   after the body ends) is refused.
2. For a subagent's stash rule, a `git` word counts only where it runs: at command position after
   any assignments, or as the command a wrapper runs (`env`, `command`, `exec`, `nice`, `nohup`,
   `time`, `timeout`, `sudo`, `xargs`, each with its own options and arguments skipped as the
   wrapper reads them). Example: from a subagent, `echo git stash`, `printf 'git stash\n'` and
   `grep -n "git stash" notes.md` are allowed; `env A=1 git stash`, `timeout 5 git stash`,
   `command git stash`, `xargs git stash`, `nice -n 5 git stash`, `/usr/bin/git stash` and
   `A=1 git stash` are refused.
3. The reviewer's rules are unchanged: it still reads every `git` word and heredoc bodies. Example:
   from `keel:keel-reviewer` with an `agent_id`, `echo git stash` is still refused, and every
   existing reviewer case passes.
4. A subagent command too long to parse in time is refused without parsing, and quickly. The bound
   is a named constant of 64 KB on the command's length. Example: a subagent's `git status` padded
   past 64 KB with a trailing `# stash` comment is refused in under a second with a reason saying
   the command is too long to read; the same command under the bound is allowed; a reviewer's
   command past the bound that names `git` is refused the same way; a main session's 1 MB command
   is allowed, because the main session exits before any of this.
5. The fallback (no python3) is unchanged and still errs toward refusing, and the header says the
   two refinements above apply on the python path only. Example: with python3 off the PATH, a
   subagent's `echo git stash` is still refused; the header states it.

**Redesigned during execution, 2026-11-02.** The first build counted a subagent's `git` only at
command position or after a closed list of wrappers. Its quality review found real stashes it newly
allowed: a `<<` inside arithmetic read as a heredoc, a second `find -exec` action, `{fd}>`
redirections, a heredoc whose line opens `$(`, wrappers such as `arch` and `caffeinate`, and nested
`$(` pushing a sub-64 KB parse past 10 s. So the design is inverted, so that the unknown is refused:
a subagent's commands keep the old every-`git`-word scan, with one exemption, a segment whose command
(after assignments) is a known non-executing reader, `echo`, `printf`, `grep`, `egrep`, `fgrep` or
`rg`, whose arguments are not read as git; and a heredoc body is skipped only when its delimiter is
quoted (`<<'EOF'` or `<<"EOF"`) and the line it starts on ends balanced. Heredoc stripping runs once,
at the top level, and substitution nesting is capped, so a command under the bound parses quickly.
Behaviour 1's unquoted `<<EOF` example is therefore refused when its body names `git stash`, which
errs toward refusing; behaviour 2's wrapper refusals hold through the every-word scan. The size bound
applies to the reviewer too, which refuses a long command where it once timed out and let it run.

**Second review of the redesign, 2026-11-03.** It found three real stashes the redesign allowed
and HEAD refused, so three rules tighten it: the reader exemption applies only to a top-level segment
not piped onward (`|` or `|&`), and never inside a substitution, so `$(echo git stash)`,
`x=$(echo git stash); $x`, `eval "$(echo git stash)"` and `echo git stash | sh` are refused; `rg` is
not a reader, because `rg --pre` runs a program; and a heredoc body is skipped only when the
delimiter word is wholly `'WORD'` or `"WORD"`, so `<<$'EOF'` and `<<$"EOF"` keep their bodies read.
Its timing finding is HEAD's too: the scan grows faster than linearly in `git` words, and some
commands under 64 KB pass the 10 s hook timeout, so the bound does not promise a fast parse.
Its fix pass left two allowed that HEAD refused, `bash <<'EOF'` with a body naming `git stash`
and `echo git stash > f; sh f`, so a fourth rule closes them: a command in which any segment's
command word (after assignments) is a shell or evaluator, `sh`, `bash`, `zsh`, `dash`, `ksh`,
`fish`, `eval`, `source`, `.`, `exec` or `xargs`, gets neither the reader exemption nor heredoc
stripping, and is read by the every-word scan alone.

**Decided, 2026-11-03, Bernard.** Its review still found about 30 forms that write text naming
`git stash` and then run it (`echo git stash > f; ./f`, `env bash <<'EOF'`, `crontab f`) allowed
where HEAD refused them. Task 6 lands as staged, and the bar is restated to match ADR-0016's threat,
a habit and not an adversary: every direct `git … stash` form, and every form HEAD's tests refuse,
is refused; text written and then run is a stated limit, named in the hook's header, of the same
class as `sh -c 'git stash'`, which HEAD allows. The 10 s timeout gap (a command under 64 KB with
about 16,000 `git` words outlasts the hook, which then allows it, as at HEAD) is a follow-up, not
part of this plan.

The header's "ITS LIMIT" paragraph is rewritten to state what is true now: the subagent rule reads
commands that run and skips heredoc bodies; the reviewer's rule and the fallback read every `git`
word; the size bound and its reason.

**Done when:** `tests/test-review-guard.sh` passes, and the profile's lint command passes.

- [x] **Step 6.1: Build it test first**

Follow `keel:tdd` for behaviours 1, 2 and 4: write the cases, run them, and watch the allow cases
of 1 and 2 and the refusal and timing of 4 fail (today the parser reads every `git` word and
heredoc bodies, and has no bound). Then change the hook and its header.
Run: `tests/test-review-guard.sh`
Expected before the implementation: FAIL on those cases. Expected after: PASS. Quote the failing
output in your report. Also run the file under `/bin/bash` by name.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named.

- [x] **Step 6.2: Hand over** Note: rounds: 4; routing: inherit; loop: full; the first build's quality review found real stashes it newly allowed, so the design was inverted; two adversarial reviews and two fix passes tightened it; Bernard then restated the bar (text written and then run is a stated limit) on 2026-11-03; the last fix pass was not re-reviewed; committed as 04b259c with a message stating the final design, not the plan's

```bash
git add hooks/review-guard tests/test-review-guard.sh
git status --porcelain
```

Stage exactly those paths, plus any doc whose citation you repaired, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "fix(review-guard): read only commands that run for a subagent, and bound the parse"`.

---

### Task 7: a scripted re-probe of `agent_id`, run at each release

**Story:** the "Remaining, by decision" item on PR #11 that the guard depends on subagents carrying
`agent_id`, which Bernard asked to close on 2026-11-02
**Files:**
- Create: `tests/probe-agent-id.sh`
- Modify: `docs/runbooks/cutting-a-release.md`
- Modify: `docs/decisions/ADR-0016-a-subagents-stash-is-held-by-a-hook.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 6

**Behaviours:**

1. `tests/probe-agent-id.sh` re-runs the three observations this guard rests on against the
   installed Claude Code, with a throwaway plugin loaded by `--plugin-dir` and a throwaway project
   under the system temp directory, and exits 0 only when all three hold. Example: it prints the
   Claude Code version, then one line per case, `main session: no agent_id`,
   `main session started with --agent: agent_type set, no agent_id` and
   `project agent subagent: agent_type and agent_id set`, each `PASS` or `FAIL`, and removes its
   temp directory on exit. It is not in `tests/run-tests.sh`, because it needs a signed-in Claude
   Code and spends tokens, and its header says so.
2. Its parts that need no Claude Code are checked: it parses under `/bin/bash` 3.2 and passes
   shellcheck (the profile's lint covers `tests/*.sh`), and run with `claude` absent from the PATH
   it exits non-zero with a message naming the missing command. Example: `PATH=/usr/bin:/bin
   tests/probe-agent-id.sh` prints that `claude` was not found and exits 2.
3. The release runbook runs it. Example: `docs/runbooks/cutting-a-release.md` section 0 gains a
   step: when the Claude Code version is newer than the one the last release recorded, run
   `tests/probe-agent-id.sh`, and do not release on a FAIL, because `hooks/review-guard` then no
   longer tells a subagent from the main session.
4. ADR-0016 names the probe and the runbook step as the control for its dependency on `agent_id`,
   and `CHANGELOG.md`'s Unreleased section has an entry for the probe and for task 6's change.
5. ADR-0016 says what task 6 made true. Example: where it says the hook reads every `git` word and
   heredoc body so a subagent's `echo git stash` is refused, it says a subagent's rule, on the
   python path, keeps the every-word scan with two exemptions, a top-level `echo`, `printf`, `grep`,
   `egrep` or `fgrep` not piped onward, and a heredoc body under a wholly quoted delimiter, both
   dropped when the command runs a shell or evaluator; that text written and then run is a stated
   limit; and that the reviewer's rule and the fallback read every `git` word. Its verification list
   says a subagent's `echo git stash` and `git commit -F - <<'EOF'` body are allowed, its
   `echo git stash | sh` and `bash <<'EOF'` body are refused, the reviewer's `echo git stash` is
   refused, and a command past 64 KB is refused unread.

**Done when:** `bash -n tests/probe-agent-id.sh` and the profile's lint command pass, and the
missing-`claude` run exits 2. Then run the probe once for real and quote its output.

- [x] **Step 7.1: Build it, check what runs without Claude Code, then run it**

Write the script, run the missing-`claude` check and watch it exit 2 with the message, run the
lint, then run the probe for real against the installed Claude Code and quote every line it prints.
Then edit the runbook, ADR-0016 and CHANGELOG.
Run: `tests/run-tests.sh`
Expected: PASS.

- [x] **Step 7.2: Hand over** Note: rounds: 2; routing: inherit; loop: full; spec DEVIATES on one CHANGELOG clause and quality found the probe ran under bypassPermissions with the user's whole config; a fix pass narrowed it to the two marker commands and Agent in dontAsk mode, project settings only, no MCP servers, and re-ran the probe on 2.1.317, 3 of 3 PASS; committed as 655bd6f

```bash
git add tests/probe-agent-id.sh docs/runbooks/cutting-a-release.md \
        docs/decisions/ADR-0016-a-subagents-stash-is-held-by-a-hook.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -m "test: a scripted re-probe of agent_id, run at each release"`.

---

## Notes for the coordinator

- **Concurrent batches.** `keel plan batches` on 2026-11-02 printed every task alone:

  ```
  why: task 2 has a Files block not in the strict form, so its paths are unknown
  why: task 3 has a Files block not in the strict form, so its paths are unknown
  ```
- **Release.** This plan does not bump the version. `ship` does, after task 3. ADR-0011: task 2
  edits a skill reference and an agent body, so the release owes a gate arm for skill text.
- **Not in this plan:** a hook on the main session's stash, and anything a command string hides
  (`sh -c "git stash"`, an alias, a script), which `hooks/review-guard`'s header already states as
  its limit.

## Delivery

- review-code: nothing blocking, no standards violation open (2026-11-02, base 1327bc8, re-review of 75fe56a)
- review-code round 1: 3 blocking (2026-11-02, base 1327bc8)
  - a mutant making an empty `agent_id` count survived: no fallback case for it (hooks/review-guard:133)
  - a mutant narrowing `list|show` to `list` survived: no fallback case for `stash show` (hooks/review-guard:143)
  - a mutant dropping `--config-env` from the fallback's value options survived; `--super-prefix` has the same shape (hooks/review-guard:128)
- follow-ups taken as tasks 4 and 5 (2026-11-02, Bernard asked to handle them before merging): all
  but the heredoc and `echo` refusal, which task 4 states as a limit rather than removes
- tasks 4 and 5: spec and quality passes on task 4 (one fix pass), spec pass on task 5, a security audit of the hook change with 0 findings; not re-run through review-code (2026-11-02)
- tasks 6 and 7: spec and adversarial quality passes on each, four rounds on task 6 and two on
  task 7; the probe ran for real on Claude Code 2.1.317, 3 of 3 PASS (2026-11-03)
- follow-up:
  - consider: the ledger requires only `pretooluse_agent_type` while the rule keys on `agent_id`; a separate row could follow (lib/harness/capabilities)
  - consider: a main session started as `--agent keel:keel-reviewer` gets the reviewer rules (hooks/review-guard header)
  - consider: the fallback's catch-all option pattern widens the reviewer's fallback too; the header says it only for a subagent (hooks/review-guard:128)
  - consider: open question 2 in the idea record reads as a correction rather than current state (docs/ideas/implementers-run-git-stash.md)
  - follow-up: a command under 64 KB with about 16,000 `git` words outlasts the hook's 10 s timeout, which then allows it, as at HEAD; a bound on `git` words would close it (hooks/review-guard, decided 2026-11-03)
  - consider: record 2.1.317 on the `pretooluse_agent_id` row (lib/harness/capabilities)
