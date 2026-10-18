# A reviewer's git is held by a hook, not only by its prompt Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for task 1. Tasks 2 and 3 change reference text and records
> and say under their behaviours why they carry no failing test.

**Goal:** on Claude Code, every dispatch that judges another agent's work runs as a `keel-reviewer`
agent, and a `review-guard` hook refuses that agent the git commands that would change the author's
checkout or the state every worktree shares, so the 2026-10-12 `git stash` cannot recur by a
reviewer forgetting its prompt.
**Stories:** none. Item 2 of `docs/ideas/factory-reliability.md`, decided by Bernard.
**ADRs:** ADR-0003 and ADR-0004 (a gate is active only where the harness provides what it requires,
and a guarantee belongs to a repository and harness pair); ADR-0002 (the coordinator reviews through
dispatches). Task 3 writes ADR-0010 for this guard and amends `docs/07-open-decisions.md` section 3,
which reserved hook-level blocking for the payments case.
**Architecture:** a PreToolUse hook on `Bash`, `hooks/review-guard`, reads the hook input's
`agent_type`. Only when it is `keel:keel-reviewer` does it look at `tool_input.command`, and it
refuses a listed git command with `permissionDecision: deny` and a reason the reviewer reads. The
dispatch instructions in three reference files name `keel-reviewer` as the agent type and keep the
`inherit: ` description. The capability manifest gains the primitive the guard needs, provided on
Claude Code by the probe above and not recorded for Codex, so the guard is dark there.
**Implementer routing:** inherit
**Delivery:** hand-off
**Concurrent batches:** none. Each task depends on the one before: task 2 dispatches the agent
task 1 creates, and task 3 records both.
**Decided:** Bernard, 2026-10-17, choosing among options put to him: every judging dispatch runs
as `keel-reviewer` (execute-plan's spec and quality passes, review-code's rubric pass, write-plan's
plan reviewer); a caught command is refused, not asked about or logged; the dispatch keeps its
`inherit: ` description, only the agent type changes. Earlier the same day, in
`docs/ideas/factory-reliability.md`: "Prove agent_id separates the main session, then block
tree-changing git in keel reviewers only".
**Shape:** behaviours with examples.
**Reviewed:** by a dispatched plan reviewer on 2026-10-17, ISSUES; every finding is folded in, and
"What the review changed" records it.
**Approved:** by Bernard, 2026-10-17: routing `inherit`, delivered by hand-off.

## The probe this plan rests on

Run 2026-10-17 in a Linux cloud workspace, Claude Code 2.1.302, `claude -p --plugin-dir` with a
throwaway plugin whose PreToolUse hook on `Bash` logged its input, $0.57. The session ran one Bash
command itself, dispatched a `general-purpose` agent to run one, and dispatched the plugin's own
agent `reviewer` to run `echo` and then `git stash list && git stash`.

| Call from | `agent_id` | `agent_type` | Other keys |
|---|---|---|---|
| the main session | absent | absent | `cwd`, `permission_mode`, `session_id`, `tool_input`, `tool_name`, `transcript_path` and the rest |
| a `general-purpose` subagent | present | `general-purpose` | the same |
| the plugin's own agent | present | `hprobe:reviewer`, the plugin name, a colon, the agent name | the same |

The hook printed a JSON `hookSpecificOutput` with `permissionDecision: deny` and exited 0 for the
`git stash` call under `--permission-mode bypassPermissions`, and the stash did not run: the session
relayed the reviewer's tool error as "PreToolUse:Bash hook error: probe: a reviewer may not run git
stash" and reported nothing stashed. So the three things the guard needs hold on Claude Code: a
reviewer's calls are distinguishable by agent type, the main session's are not mistaken for a
reviewer's, and a deny holds under bypass.

**A second probe, the same day, $0.24, settled where a command acts.** The plugin's agent ran
`cd /tmp/hp-other && pwd`, then `pwd`, then `git -C /tmp/hprobe-work stash list`, one per call. The
hook's `cwd` was the session's starting directory, `/tmp/hprobe-work`, on all three calls, and the
second `pwd` printed `/tmp/hprobe-work`: a `cd` does not carry into the next call. So a command acts
on the hook's `cwd`, the author's checkout, unless that same command changes directory with `cd` or
points git elsewhere with `-C`, `--git-dir` or `--work-tree`.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). If `command -v shellcheck` prints nothing,
  say the lint was not run and that CI will run it. The lint in one call may be OOM-killed on a
  small VM; lint the changed shell files directly with `shellcheck -x` and say so.
- **`tests/run-tests.sh` takes about 2m30s.** Run it in the background and read its log to the end
  within one tool call.
- **`hooks` and `lib/harness` are in `hard_block_paths`.** Task 1 gets the full review loop.
- **How the hook reads its input.** `hooks/sensitive-guard` does cheap bash substring filters first
  and reads the JSON with `python3` only after them, and asks when `python3` is absent. The guard
  does the same: a bash substring check for `keel:keel-reviewer` first, so every other call returns
  at once without `python3`; then `python3` (`json`, `shlex`) for behaviours 3 to 5; behaviour 6
  when `python3` is absent or the JSON will not parse.
- **Precondition: the working tree is clean and nothing is staged.** Each task stages named paths
  only and hands over; the coordinator commits. Never `git add -A`, `git add .` or `git commit -a`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Commits carry no attribution footers; this repository sets `conventions.no_attribution_footers`.
- **Line citations.** Cite by phrase (`file#phrase`). Run `tests/validate-citations.sh` after each
  edit and repoint any live citation a move breaks.
- **Plans are scanned for links.** Write paths in backticks, never as markdown links, in this plan.
- **Every rule carries its reason.**
- Never `sed -i` on this repository's mount: it drops the exec bit. Edit with a read-modify-write.
- **A pipeline that feeds `grep -q` is not tested under `pipefail`.** Read into a variable first.
- **Skill bodies are not edited.** `execute-plan` is at 894 words, `write-plan` at 893 and
  `review-code` at 728, and each body edit would owe an ADR-0001 arm; the dispatch instructions live
  in references, which is where this plan changes them.

## What the review changed

- **`hooks/hooks.json` is generated**, by `tests/generate-harness-artifacts.sh`, and
  `tests/test-harness-claims.sh` fails a hand-wired entry; task 1 adds the gate to the generator
  and regenerates both manifests.
- **`tests/test-harness-resolve.sh` lists the gates active on Claude Code** in four places; task 1
  adds `review-guard` to them.
- **Behaviour 4 is restated from the second probe**: a command's target is the hook's `cwd` unless
  the same command moves it, a target must be under the temp directory and outside the author's
  checkout, which may itself sit under `/tmp` as an eval workspace does, and a target that cannot be
  resolved is refused, with a reason saying to write it as `"${TMPDIR:-/tmp}/<name>"`, since
  `TMPDIR` is often unset on Linux. A re-review the same day added the outside-the-checkout clause,
  the `${TMPDIR:-/tmp}` form, `shlex` splitting, the read forms of `tag` and behaviour 6's narrower
  match.
- **The suite and the lint name files one by one**, so task 1 adds the new test to
  `tests/run-tests.sh` and the new hook and test to the profile's lint.
- **Routing is `inherit`**, as the template asks of a plan with a task on `hard_block_paths`, unless
  Bernard says otherwise at approval.
- **Task 2 says "agent type `keel-reviewer`", never "delegation profile"**, because
  `tests/test-harness-claims.sh` requires a Codex `.toml` for every delegation profile a reference
  names, and this guard is Claude Code only.
- **The plugin-eval runs come between tasks 2 and 3**, so task 3 can record them. The `no-stash`
  grader of `review-code-leaves-the-tree-alone` counts a refused `git stash` as a call, so a run
  that tries and is refused fails it, which is the right reading: the reviewer still tried.
- **Task 3 uses `skills/design-architecture/references/adr-template.md`** and also updates
  `docs/01-architecture.md`'s gate count and the repository layout's test listing.

## What this plan does not build

- **No guard on the implementer or the coordinator.** No incident is on record for either, and
  `docs/ideas/independence-of-a-delegated-review.md` asks for a named instance before machinery.
- **No tool restriction on `keel-reviewer`.** It keeps `Edit` and `Write`, because its mutants are
  made in its own throwaway worktree, and a hook on git is the decided scope.
- **Nothing on Codex.** Whether Codex's hook input names the dispatched agent is unrecorded, so
  the guard requires a primitive Codex does not provide and is dark there, and the prompts keep the
  rule.
- **Not a security boundary.** The guard reads a command string. `sh -c "git stash"` or an alias
  passes it. It stops a model following a habit, which is what both incidents were, not an
  adversary.

---

### Task 1: the `keel-reviewer` agent and the `review-guard` hook

**Files:**
- Create: `agents/keel-reviewer.md`
- Create: `hooks/review-guard`
- Create: `tests/test-review-guard.sh`
- Modify: `hooks/hooks.json`
- Modify: `hooks/hooks.codex.json`
- Modify: `tests/generate-harness-artifacts.sh`
- Modify: `tests/test-harness-resolve.sh`
- Modify: `tests/run-tests.sh`
- Modify: `.keel/profile.json`
- Modify: `lib/harness/capabilities`
- Modify: `docs/harness-support.md`

**Depends on:** none

**Behaviours:**

1. `agents/keel-reviewer.md` is an agent with `model: inherit` whose body says it judges another
   agent's work, changes nothing it was asked to judge, and that a hook refuses it the git commands
   behaviour 3 lists. It passes `tests/validate-skills.sh`'s agent rules. Example: a dispatch with
   `subagent_type` `keel-reviewer` from a session with keel installed runs with `agent_type`
   `keel:keel-reviewer`, which the plugin-eval grader of task 2 checks; the name follows from
   `"name": "keel"` in `.claude-plugin/plugin.json` and the probe's `hprobe:reviewer`.
2. `hooks/review-guard` does nothing unless the input's `agent_type` is `keel:keel-reviewer`.
   Example: the same `git stash` from the main session (no `agent_type`), from a `general-purpose`
   agent and from `keel:keel-fanout` exits 0 with no output.
3. For `keel:keel-reviewer`, it refuses, wherever it runs, a git command that changes state every
   worktree shares: `stash` in any form, `commit`, `push`, `merge`, `rebase`, `cherry-pick`, `am`,
   `revert`, `tag`, `update-ref`, `config`, and `branch` with `-d`, `-D`, `-m`, `-M`, `-c`, `-C` or
   `-f`, matched as whole subcommand words after git's global options (`-C`, `-c`, `--git-dir`,
   `--work-tree`, `--no-pager`). Example: `git stash list && git stash` and `cd /tmp/wt && git
   commit -m x` are refused; `git merge-base main HEAD` is not, and `tag` is allowed only in its
   read forms: no arguments, `-l` or `--list`.
4. For `keel:keel-reviewer`, it refuses a git command that changes an index or working tree (`add`,
   `rm`, `mv`, `reset`, `restore`, `checkout`, `switch`, `clean`, `apply`, and `worktree remove`)
   unless its target is the reviewer's own: under the system temp directory and outside the author's
   checkout, the top level of the hook's `cwd` (`git -C "$cwd" rev-parse --show-toplevel`), since
   the checkout may itself sit under a temp directory, as a `claude plugin eval` workspace does. The
   command line is split into segments with `shlex` (`punctuation_chars=True`) on `&&`, `||`, `;`
   and `|`, and on newlines handled separately, so a quoted `-m "a; b"` stays whole. Within a
   segment the target is the hook's `cwd`, changed by an earlier `cd <dir>` in the same command line
   or by `git -C <dir>`, `--git-dir` or `--work-tree`. A target counts as temp when it is a literal
   path, or begins `$TMPDIR`, `${TMPDIR}` or `${TMPDIR:-/tmp}` (expanded from the hook's
   environment, else `/tmp`), and resolves, through its nearest existing ancestor with `pwd -P`,
   under `/tmp`, `/private/tmp`, `/var/folders` or the expanded `TMPDIR`. Any other target,
   including one held in another variable such as `"$wt"`, is refused. Example: `git checkout --
   src/a.sh` with `cwd` in the repository is refused, and so is `git reset --hard` with `cwd` in a
   repository under `/tmp`; `cd "${TMPDIR:-/tmp}/rv" && git checkout -- src/a.sh`, `git -C /tmp/rv
   reset --hard` and `git diff HEAD | git -C "${TMPDIR:-/tmp}/rv" apply` are allowed when `/tmp/rv`
   is outside the checkout; `wt=$(mktemp -d); git -C "$wt" apply` and `cd /tmp/x; cd -; git reset`
   are refused.
5. Read-only commands and the worktree's own lifecycle are allowed. Example: `git diff`, `git log`,
   `git show`, `git status`, `git ls-files -z --others --exclude-standard | tar --null -T - -cf -`,
   `git worktree add --detach "${TMPDIR:-/tmp}/rv" HEAD` and `git worktree remove --force
   "${TMPDIR:-/tmp}/rv"` all exit 0 with no output; `git worktree remove` of a path outside the temp
   directory is refused by behaviour 4, because in a concurrent batch the author's tree is itself a
   linked worktree.
6. A refusal is `permissionDecision: deny` with a reason that names the command, says why, and says
   what to do instead (read it with `diff`, `log`, `show` or `status`; change your own worktree with
   `cd <worktree> &&` or `git -C <worktree>`). Example: the reason for `git stash` says the stash is
   shared by every worktree and names the 2026-10-12 incident; the reason for an unresolvable target
   says to write the worktree path as `"${TMPDIR:-/tmp}/<name>"` or a literal temp path. When
   `python3` is absent or the JSON will not parse but the raw input names `keel:keel-reviewer`, it
   refuses a command in which a word behaviours 3 and 4 list directly follows `git` (after any of
   its global options), with a reason saying it could not read its input, and allows the rest, so
   `git diff` and `rm -rf /tmp/x` still run; without `python3` the rubric pass's worktree steps are
   refused too, and its items 5 and 6 are reported as not done; when the raw input does not name it,
   the guard allows, because it cannot tell a reviewer from anyone else and must not block the main
   session.
7. The guard is a gate. `tests/generate-harness-artifacts.sh` adds `group review-guard review-guard
   10 'Bash'` under PreToolUse beside `sensitive-guard`, and both manifests are regenerated
   (`hooks/hooks.codex.json` comes out unchanged, the guard being dark on Codex).
   `lib/harness/capabilities` gains a `provides|claude|pretooluse_agent_type|probe:...` row whose
   source is written out in full with no `|` in it, ending with this plan's path, as the
   `agent_tool_denylist` row does, with `2.1.302|2026-10-17`, and
   `requires|review-guard|pretooluse_deny` and `requires|review-guard|pretooluse_agent_type`.
   `docs/harness-support.md` is regenerated. `tests/test-harness-resolve.sh`'s four lists of gates
   active on Claude Code gain `review-guard`. `tests/run-tests.sh` runs
   `tests/test-review-guard.sh`, and `.keel/profile.json`'s lint names `hooks/review-guard`;
   `tests/test-review-guard.sh` is covered by its existing `tests/*.sh` glob. Example: the
   regenerated page has a `review-guard` row reading yes for claude and no for codex.

**Done when:** all of these:
- `bash tests/test-review-guard.sh` passes, with a case for every example in behaviours 2 to 6,
  fed as hook input JSON on stdin, as `tests/test-sensitive-guard.sh` feeds its hook.
- `bash tests/test-harness-claims.sh` and `tests/validate-skills.sh` pass, and the harness tests
  that check a gate has both a file and a `requires` row pass.
- `shellcheck -x hooks/review-guard tests/test-review-guard.sh` is clean if `shellcheck` is
  installed.
- No global git configuration write in the tests: the supply-chain scan's `persist-global` rule
  matches one, and it would change the machine running the suite.

- [x] **Step 1.1: Write the failing tests** in `tests/test-review-guard.sh` for behaviours 2 to 6.
- [x] **Step 1.2: Run them and watch them fail.** Run: `bash tests/test-review-guard.sh`.
  Expected: FAIL, because `hooks/review-guard` does not exist.
- [x] **Step 1.3: Write the hook and the agent** for behaviours 1 to 6.
- [x] **Step 1.4: Run them and watch them pass**, then do behaviour 7: the generator, the manifest
  rows, the regenerated `hooks/hooks.json`, `hooks/hooks.codex.json` and `docs/harness-support.md`
  (all three generated, never edited by hand), the resolve test, the suite list and the lint.
- [x] **Step 1.5: Check and stage.** Run the `Done when:` checks and the full `tests/run-tests.sh`, Note: rounds: 3; routing: inherit; loop: full; red 0 of 89 (no hook), then 90, 166 and 199 passed over two fix passes; spec DEVIATES (pull, worktree move, branch create allowed) then COMPLIES; quality BLOCKING (a cd before ; or || still moved the target) then NOTHING BLOCKING with should-fix items closed in a targeted pass; the guard grew past the plan's list: a cd carries only across &&, a cd after || is unresolved, and stage, bisect, checkout-index, read-tree, update-index, sparse-checkout, submodule update, symbolic-ref writes, notes writes, worktree move and prune, pull, branch creation by checkout -b, switch -c and worktree add -b, and remote writes are refused; full suite run in batches by the implementer, all passed
  stage the eleven files by path (`hooks/hooks.codex.json` regenerates unchanged, so `git status`
  shows ten), show `git status --porcelain`, and stop. The coordinator commits after both review
  passes: `feat(hooks): a keel reviewer is refused the git commands that would change the author's
  tree`.

### Task 2: every judging dispatch runs as `keel-reviewer`

**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/review-code/references/rubric-pass.md`
- Modify: `skills/write-plan/references/plan-review.md`
- Create: `tests/plugin-evals/review-code-dispatches-rubric-subagent/graders/dispatched-as-keel-reviewer.md`

**Depends on:** task 1

**Behaviours:**

1. `subagent-prompts.md`, where it says both reviews go to model `inherit`, adds that on a harness
   that has the agent type `keel-reviewer` each review is dispatched with it, keeping the `inherit:
   ` description, and why: the hook can see the agent type and not the description. The text says
   "agent type", never "delegation profile", for the reason under "What the review changed". Both of
   its worktree paragraphs, for the spec and the quality reviewer, say to write the path as
   `"${TMPDIR:-/tmp}/<name>"` or a literal temp path, because the guard refuses a target it cannot
   resolve. Example: "dispatch the spec and quality reviews as `keel-reviewer` where the harness has
   it".
2. `rubric-pass.md`'s opening says the same for the rubric pass, and its git rules section says the
   guard enforces them on Claude Code and the prompt still states them for every harness. Where it
   creates the throwaway worktree, it says to write the path as `"${TMPDIR:-/tmp}/<name>"` or a
   literal path under the temp directory, because the guard refuses a target it cannot resolve and
   `TMPDIR` is often unset on Linux.
3. `plan-review.md`'s opening says the same for the plan reviewer.
4. Where the agent does not exist, the dispatch falls back to a general agent with the same brief,
   and the text says so, so a Codex session or one without the plugin still reviews. Example: one
   sentence in each of the three references.
5. A new grader in the `review-code-dispatches-rubric-subagent` case checks the `Agent` call names
   `keel-reviewer`. Example: a `tool_used` grader on `Agent` with `input_match` for
   `"subagent_type"\s*:\s*"(keel:)?keel-reviewer"`.

There is no failing test: these are dispatch instructions in references, proved by the plugin-eval
runs the coordinator makes after this task and before task 3: three of
`review-code-dispatches-rubric-subagent` and three of `review-code-leaves-the-tree-alone`, in the
Linux cloud workspace.

**Done when:**
- `tests/validate-citations.sh`, `tests/validate-skills.sh` and `bash tests/test-doc-claims.sh`
  pass, and `git diff --stat` touches no `SKILL.md`.

- [x] **Step 2.1: Edit the three references** for behaviours 1 to 4.
- [x] **Step 2.2: Add the grader** for behaviour 5.
- [x] **Step 2.3: Check and stage.** Run the `Done when:` checks and the full `tests/run-tests.sh`,
  stage the four files by path, show `git status --porcelain`, and stop. The coordinator commits:
  `feat(skills): every judging dispatch runs as keel-reviewer where the harness has it`. Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES, with one optional nit left for the
  final review (rubric-pass.md's "a hook enforces these rules" could say "these git rules"); full
  suite run in batches by the implementer, all passed. Plugin evals on Linux, Claude Code 2.1.302:
  `review-code-dispatches-rubric-subagent` 3 of 3, every rubric pass dispatched as
  `keel:keel-reviewer`, $2.24; `review-code-leaves-the-tree-alone` 3 of 3, $1.40, after a first batch
  of 2 of 3 whose one failure was `no-stash` matching a `git stash` call whose trace was not kept (its
  reply says the stash was checked empty, likely a read-only `stash list`, which the grader counts);
  in one of the six runs of that case the skill reviewed inline and dispatched no reviewer, so the
  guard had nothing to hold, and the tree was still left alone.

### Task 3: the decision and the records

**Files:**
- Create: `docs/decisions/ADR-0010-a-reviewers-git-is-held-by-a-hook.md`
- Modify: `docs/07-open-decisions.md`
- Modify: `docs/ideas/factory-reliability.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/06-repo-layout.md`
- Modify: `docs/01-architecture.md`

**Depends on:** tasks 1 and 2

**Behaviours:**

1. ADR-0010, in `skills/design-architecture/references/adr-template.md`'s shape, records the
   decision, the two probes, the
   alternatives (prose only; a tool restriction; a harness worktree, which
   `docs/ideas/harness-held-dispatch-guarantees.md` finding 1 rules out), and the consequences:
   Claude Code only, a speed bump not a boundary, and the incident it answers.
2. `docs/07-open-decisions.md` section 3 gains a dated line: hook-level refusal now also holds a
   keel reviewer's git, by ADR-0010, beside the payments case. A line naming a gate carries a
   `keel:claim` tag within three lines, as `tests/test-harness-claims.sh` requires.
3. `docs/ideas/factory-reliability.md`: item 2 is built, with the commits the coordinator passes in
   the dispatch, and Next names the ADR-0001 prune.
4. `CHANGELOG.md` gains entries under `## Unreleased` for tasks 1 and 2, and the coordinator's
   plugin-eval runs made between tasks 2 and 3, with scores and cost, as passed in the dispatch.
5. `docs/06-repo-layout.md` lists `keel-reviewer.md` under `agents/`, `review-guard` under `hooks/`
   and `test-review-guard.sh` under `tests/`, as it lists the others, and
   `docs/01-architecture.md`'s "On Claude Code it is four gates" counts five, with the claim tag the
   harness test requires.

There is no failing test: records, checked by the validators.

**Done when:**
- `tests/validate-citations.sh`, `bash tests/test-doc-claims.sh`,
  `bash tests/test-harness-claims.sh` and `tests/validate-skills.sh` pass.
- No em or en dash in any added line, and added prose lines are at most 100 columns.

- [x] **Step 3.1: Write the ADR and amend section 3** for behaviours 1 and 2.
- [x] **Step 3.2: Write the records** for behaviours 3 to 5.
- [x] **Step 3.3: Check and stage.** Run the `Done when:` checks and the full `tests/run-tests.sh`,
  stage the six files by path, show `git status --porcelain`, and stop. The coordinator commits:
  `docs: a reviewer's git is held by a hook, ADR-0010`. Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; a seventh file,
  `docs/ideas/leon-van-zyl-skill-collection.md`, had a stale line-number citation into
  `docs/07-open-decisions.md` repointed by phrase so the citation check passed; three optional
  wording fixes left for the final review's fix pass; full suite run in batches, all passed.

## Final review

`review-code` over `7703c31...HEAD`, with mutation, because the change edits `.keel/profile.json`
and that makes every changed file sensitive. Routing: inherit.

- Round 1 at `13ebc0e`: four Blocking. A `--work-tree` or `GIT_WORK_TREE` named alone left the
  author's index unchecked, and a reviewer's `reset --hard` that way unstaged a staged file. Three
  mutants survived: the agent-type early exit, the `GIT_WORK_TREE` mapping and the python3 check.
  Should fix: `worktree add` without `--detach` and short clusters such as `checkout -qb` created
  a branch. Consider: a `fetch` with a refspec moved a local branch, and `replace` and
  `filter-branch` were allowed. The fix pass, `d8c9a84`, closed all of them: 16 new cases red
  first, 227 passed.
- Round 2 at `d8c9a84`: the three survivors died, finding 1 and the branch forms were closed, and
  no reviewer work was over-refused. Two mutants survived, both test gaps with the hook correct:
  the work-tree and git-dir mapping swap, which a variable and an option naming the same temp path
  exposes, and the empty fetch destination. The fallback without python3 did not refuse `fetch`.
  The skill sends a still-blocking re-review to the person; Bernard chose one more pass of tests
  and no third review round.
- The follow-up pass, `7eff299`: two denies and one allow pinned the survivors, each shown failing
  under its mutant on a scratch copy; the fallback refuses `fetch`; fetch option values are
  skipped so `git fetch --depth 1 <url>` is allowed. 234 cases pass.
