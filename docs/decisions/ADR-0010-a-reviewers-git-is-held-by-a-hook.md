# ADR-0010: A keel reviewer's git is held by a hook, not only by its prompt

| | |
|---|---|
| Status | accepted |
| Date | 2026-10-17 |
| Deciders | Bernard Tebandeke, decided 2026-10-17 |
| Requirements | none; driver is item 2 of `docs/ideas/factory-reliability.md` and the 2026-10-12 incidents in `docs/ideas/harness-held-dispatch-guarantees.md` |
| Supersedes | none; amends section 3 of `docs/07-open-decisions.md`, which reserved hook-level blocking for the payments case |

## Context

On 2026-10-12 a judging subagent changed the tree it was judging. The spec review of a plan step,
briefed "do not edit anything", ran `git stash` on the author's working tree to measure a baseline
word count, then `git stash pop --index`. Nothing was lost. The same day the quality review of that
step made a detached worktree under the temp directory and did not remove it, and the coordinator
removed it by hand.

Both were answered on 2026-10-13 by prompt text: each review prompt now names the git commands it
must not run and makes its worktree's removal unconditional. A prompt binds only as far as the
model follows it. The next reviewer that reaches for a habit is stopped by nothing.

Section 3 of `docs/07-open-decisions.md` settled that gates are enforced with escape hatches, and
kept a hook-level block for one case, a sensitive commit in a payments repository. Bernard chose on
2026-10-17, as option (b) of open question 2 in `docs/ideas/factory-reliability.md`, to prove first
that a hook can tell a reviewer's call from the main session's, and then to block tree-changing git
in keel reviewers only.

Two probes on 2026-10-17, in a Linux cloud workspace on Claude Code 2.1.302, settled what a hook
can see. The first, $0.57, logged a plugin PreToolUse hook's input on `Bash`. The main session's
calls carried no `agent_id` and no `agent_type`, a `general-purpose` subagent's carried
`general-purpose`, and the plugin's own agent's carried `hprobe:reviewer`: the plugin name, a colon
and the agent name. The hook's deny of that agent's `git stash` held under `bypassPermissions`, and
the stash did not run. The second, $0.24, showed that the hook's `cwd` is the session's starting
directory on every call and that a `cd` does not carry into the next call. So a command acts on the
author's checkout unless that same command moves its target with `cd`, `git -C`, `--git-dir` or
`--work-tree`.

The dominant force: the hook sees the agent type and never the dispatch's description. A guard can
only hold a reviewer that runs as a named agent type.

## Decision

**On Claude Code every dispatch that judges another agent's work runs as the agent type
`keel-reviewer`, and a PreToolUse hook on `Bash`, `hooks/review-guard`, refuses that agent the git
commands that would change the author's checkout or the state every worktree shares.** The judging
dispatches are `execute-plan`'s spec and quality reviews, `review-code`'s rubric pass and
`write-plan`'s plan reviewer; each keeps its `inherit: ` description and model. The hook acts only
when the input's `agent_type` is `keel:keel-reviewer`, so the main session and every other agent are
untouched. It refuses state every worktree shares wherever the command runs: the stash, commits,
refs, tags, notes, config and a remote, a branch made by `checkout -b`, `switch -c` or a `worktree
add` without `--detach`, a `fetch` into a local ref, `replace` and `filter-branch`. It refuses a
change to an index or a working tree unless every place the command writes, the work tree and the
repository whose index it uses, is under the system temp directory and outside the author's
checkout, and it refuses a target it cannot resolve. A caught command is denied, not asked about or
logged, with a reason that names the command and says what to do instead. Where `keel-reviewer` does
not exist, on Codex or without the plugin, the dispatch falls back to a general agent with the same
brief, and the prompt keeps the rules.

## Alternatives considered

### A: Prose only, as built on 2026-10-13

The review prompts already name the commands a reviewer must not run, and that holds on every
harness. It loses as a complete answer because it is the state the 2026-10-12 reviewer was in: a
brief that said "do not edit anything" and a model that ran `git stash` anyway. It stays, as the
rule on every harness and the reason the hook's refusals read as expected.

### B: A tool restriction on `keel-reviewer`

`disallowedTools` in the agent's frontmatter. Both incidents ran through `Bash`, which a reviewer
needs for `git diff` and the test command, so removing `Bash` breaks the review and removing
`Edit` and `Write` stops neither incident. The rubric pass also writes its mutants in its own
worktree, which needs `Edit`.

### C: A harness worktree, `isolation: worktree`

Finding 1 of `docs/ideas/harness-held-dispatch-guarantees.md` rules it out. A harness worktree
branches from the default branch unless `worktree.baseRef` is `"head"`, and checks out only
tracked files, so the reviewer would judge `main`, not the change. `worktree.baseRef` is a settings
key a plugin cannot ship. Its isolation also blocks git into the author's checkout, by finding 2 of
the same record, which stops the uncommitted diff `review-code` reviews today.

### D: All three guards, on the coordinator, the reviewer and the commit, advisory first

Option (c) of the same open question. Only the reviewer guard has an instance on record, and
`docs/ideas/independence-of-a-delegated-review.md` asks for a named instance before machinery.

**Why the chosen option won:** the probes showed the hook can see the agent type and that a deny
holds under bypass, so the one rule with an incident gets a check the model cannot talk its way
past, and nothing else changes for anyone else.

## Consequences

**What becomes easier.** A reviewer that reaches for `git stash`, `git checkout -- <file>` or
`git reset --hard` in the author's checkout is refused before the command runs, and is told to read
with `diff`, `log`, `show` or `status` and to change only its own worktree.

**What becomes harder.** It holds only on Claude Code. Whether Codex's hook input names the
dispatched agent is unrecorded, so `lib/harness/capabilities` records `pretooluse_agent_type` for
Claude Code alone and the guard is dark on Codex, as ADR-0003 and ADR-0004 require. A reviewer must
write its worktree path as `"${TMPDIR:-/tmp}/<name>"` or a literal temp path, because a target held
in another variable is refused. It must join a `cd` to its command with `&&`: after `;`, `||` or a
newline, a `cd` that failed or was skipped leaves the command running in the author's checkout, so
the hook carries a `cd` only across `&&`. A `--work-tree` named alone does not move the index, which
git still finds from where it runs, so that form is refused from the author's checkout too. Some
read-only forms, such as `git config --get` and `git apply --check`, are refused in the author's
checkout, since the hook judges the subcommand and not its flags. Without `python3` the guard falls
back to refusing any listed subcommand directly after `git`, so the rubric pass's worktree steps are
refused too and are reported as not done.

**It is a speed bump, not a security boundary.** The hook reads a command string. `sh -c "git
stash"`, an alias, a script, or an earlier `export GIT_DIR=...` reaches git without passing
through it. It stops a model following a habit, which is what the 2026-10-12 incident was, and not
an adversary. `reflog expire`, `submodule deinit` and `worktree lock` are allowed, as is a `fetch`
whose refspecs name no local destination, because each touches shared state in a way that loses no
committed work; a `fetch` into a local ref is refused. It does not stop a reviewer leaving its own
worktree behind, the second 2026-10-12 incident: that stays answered by the prompt.

**What this forecloses.** Little. The guard is one entry in the generated hook manifest and two
`requires` rows; removing them returns the review to prose.

**What must be true for this to keep working.** That Claude Code keeps putting `agent_type` in a
PreToolUse hook's input in the form `<plugin>:<agent>`, and keeps leaving it absent for the main
session. That a deny keeps holding under `bypassPermissions`. That every judging dispatch keeps
naming `keel-reviewer`, which `tests/plugin-evals/review-code-dispatches-rubric-subagent` grades
for the rubric pass.

## Verification

Checked on 2026-10-17 by plugin-eval runs on Linux, Claude Code 2.1.302, model claude-opus-5-5.
`review-code-dispatches-rubric-subagent` passed 3 of 3, and every rubric pass was dispatched as
`keel:keel-reviewer`. `review-code-leaves-the-tree-alone` passed 3 of 3, after a first batch of 2
of 3 whose one failure was the `no-stash` grader matching a `git stash` call whose trace was not
kept, likely a read-only `stash list`. In every run the author's tree, index, `HEAD` and commits
were left intact and no worktree was left behind. In one of the six runs of that case the skill
reviewed inline and dispatched no reviewer, so the guard had nothing to hold.
`tests/test-review-guard.sh` feeds the hook its input for every refused and allowed form.

Holding if no judging dispatch on Claude Code changes the author's checkout or its shared state
again, and the plugin-eval graders keep seeing `keel:keel-reviewer`.

Not holding if a reviewer's tree-changing git runs on Claude Code without a refusal, if the main
session or another agent is refused a command, or if a judging dispatch runs as a general agent
where `keel-reviewer` exists.
