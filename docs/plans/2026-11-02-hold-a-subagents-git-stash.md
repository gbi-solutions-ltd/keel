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
   `hooks/review-guard:405` is the latter, and would read `git stash -m list` as `list`). Example:
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
   (`hooks/review-guard:69-70`) exits today unless `agent_type` names the reviewer, and refuses by
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
