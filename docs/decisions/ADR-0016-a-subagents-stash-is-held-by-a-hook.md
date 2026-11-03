# ADR-0016: Every subagent's `git stash` is held by a hook, not only by its prompt

| | |
|---|---|
| Status | accepted |
| Date | 2026-11-02 |
| Deciders | Bernard Tebandeke, decided 2026-11-02 |
| Requirements | none; driver is [`docs/ideas/implementers-run-git-stash.md`](../ideas/implementers-run-git-stash.md) |
| Supersedes | none; extends [ADR-0010](ADR-0010-a-reviewers-git-is-held-by-a-hook.md), whose reviewer rule now holds the reviewer only as a subagent |

## Context

Implementers ran `git stash` on a tree whose stash every worktree shares four times between
2026-09-19 and 2026-10-29:

- `docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:580-586`: a stash made
  "apparently to isolate a test run" and never popped, holding "the entire staged diff for this
  plan including the correct fix already made".
- `docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:1119-1123`: the fix's
  implementer stashed "despite being explicitly told not to", and `git stash pop` conflicted.
- `docs/plans/2026-10-16-plans-declare-batches.md:190`: "the implementer used git stash once against
  its rules", in worktree `g6-t1`.
- `docs/plans/2026-10-29-claude-code-only.md:1714`: "implementer ran git stash and pop once on the
  shared tree".

No work was lost, but each cost an audit of the stash and the tree. Nothing at a task boundary
finds a stray stash: the coordinator checks `git status --porcelain`, and a stash empties the tree,
so status reads clean while the stash holds the work.

None of the four ran as a keel agent type. Three predate `agents/keel-implementer.md`, and the
fourth ran on `inherit` routing, which dispatches by model and description. A rule keyed on
`keel:keel-implementer` would have caught none of them.

What a hook can see. The 2026-10-17 probe (ADR-0010's context, and the table at
`docs/plans/2026-10-17-reviewer-git-guard.md:51-53`) found `agent_id` present on a
`general-purpose` subagent's and a plugin agent's calls, and absent with `agent_type` on the main
session's. On 2026-11-02, Claude Code 2.1.316, an agent defined in a project's `.claude/agents/`
carried its own name as `agent_type`, and `claude -p --agent helper` logged `agent_type` `helper`
and `agent_id` `None` for the main session's own Bash call
(`docs/plans/2026-11-02-hold-a-subagents-git-stash.md:202-204`). So `agent_type` alone does not
mean a subagent, and a non-empty `agent_id` string does.

The dominant force: the stash is shared by every worktree, so a stash made by any subagent anywhere
can hide a task's whole diff from the coordinator, and no check finds it afterwards.

## Decision

**`hooks/review-guard` refuses every subagent a stash-writing `git stash`, wherever the command
runs, and tells a subagent by its PreToolUse input carrying a non-empty `agent_type` and a non-empty
`agent_id` string.** A `git stash` is allowed to a subagent only when the first word after `stash`,
which is its subcommand as git reads it, is `list` or `show`, so `git stash -m list` is a push and
is refused. Every other git command a subagent runs is left alone, because an implementer keeps
`add` and `commit` in its own worktree. The reviewer's rules from ADR-0010 stand for the subagent
whose `agent_type` is `keel:keel-reviewer`, and refuse it every form of `stash`. Both rules key on
`agent_id`: the main session carries none, with or without `--agent`, so it is never touched, and a
main session started as `--agent keel:keel-reviewer` is not held to the reviewer's rules. The hook
hands the event to `python3` on stdin, so an event too large for the environment is still judged by
the parser. Without `python3`, the fallback applies the same two tests and the exact reviewer name,
and refuses any `git stash` whose following word is not `list` or `show`, reading any option words
between `git` and `stash`. The implementer prompt
(`skills/execute-plan/references/subagent-prompts.md` section 1) and `agents/keel-implementer.md`
carry the same rule, with its reason.

## Alternatives considered

### A: Do nothing

Each instance costs an audit of the stash and tree, about one every ten days so far. It loses
because a stash can hold a plan's whole staged work unseen, and a `git stash drop` or `clear` before
anyone looks loses it.

### B: Prose only, in the implementer brief and agent

It holds on every model and costs nothing. It loses as a complete answer because the second
2026-09-19 implementer was told in its dispatch prompt not to stash and stashed anyway. It stays, as
the rule the hook's refusal reads as expected.

### C: A permission rule, `deny: Bash(git stash:*)`

A permission rule cannot tell a subagent from the main session, so it also refuses the person their
own `git stash`. It matches the same command string a hook reads, with the same `sh -c` gap.

### D: Key on `keel:keel-implementer`

It would have caught none of the four instances: three predate the agent type, and `inherit`
routing never uses it.

### E: Key on any non-empty `agent_type`

Every subagent carries one, and so does a main session started with `--agent`, which would then be
refused its own `git stash`.

**Why the chosen option won:** the harm is the shared stash, not an implementer's git in general,
and it is the same whoever dispatched the subagent. `agent_id` is the one field that marks every
subagent and no main session, so the narrowest rule that would have caught all four instances is the
stash's writing forms for any call carrying a non-empty `agent_id` string.

## Consequences

**What becomes easier.** A subagent that reaches for `git stash`, `git stash push` or
`git stash pop` is refused before the command runs, and is told to keep its work in its own worktree
with `git add` and `git commit`.

**What becomes harder.** A user's own agents, defined in `.claude/agents/` or another plugin, lose
the stash-writing forms in a project with keel installed. The refusal names `keel review-guard`, so
the user can see where it comes from. The cheap filter in `hooks/review-guard` passes every call
that carries `"agent_type"` and contains `stash` anywhere in its event, including its `cwd` or
`transcript_path`, so those calls start `python3`. The capability ledger's `requires` rows for
`review-guard` name `pretooluse_agent_type` and `pretooluse_agent_id`. The `agent_id` row is stamped
2.1.302, the version of the 2026-10-17 probe that first saw the field, so keel's minimum stays
2.1.302.

**It is a speed bump, not a security boundary**, as ADR-0010 says of the reviewer rule. `sh -c "git
stash"`, an alias or a script reaches git without passing through the hook, and so does text
written and then run (`echo git stash > f; ./f`, `env bash <<'EOF'` with `git stash` in its body):
Bernard decided on 2026-11-03 that this is a stated limit of the same class, named in the hook's
header, because the threat is a habit and not an adversary. A subagent's rule, on the `python3`
path, reads every `git` word as a command with two exemptions: the arguments of a top-level `echo`,
`printf`, `grep`, `egrep` or `fgrep` not piped onward, and a heredoc body under a wholly quoted
delimiter (`<<'EOF'` or `<<"EOF"`). Both exemptions drop when any segment's command word is a shell
or evaluator (`sh`, `bash`, `eval`, `source`, `xargs` and the rest the header lists), so a
subagent's `echo git stash` passes while `echo git stash | sh`, or `bash <<'EOF'` with `git stash`
in its body, is refused. The reviewer's rule and the fallback without `python3` read every `git`
word and every heredoc body, so the reviewer's `echo git stash` is refused, and so is a subagent's
without `python3`; both err toward refusing. The fallback takes any word starting with `-` between
`git` and the subcommand as an option, for the reviewer's word list as for a subagent's stash, so
an option it does not know can only make it refuse more. A command longer than 64 KB that names
`git` for the reviewer or `stash` for another subagent is refused unread, because a hook killed at
its 10-second timeout gives no decision; the bound caps size, not time.

**What this forecloses.** Little. The rule is one branch in an existing hook; removing it returns
the stash to the prompt.

**What must be true for this to keep working.** That Claude Code keeps putting a non-empty
`agent_id` string in every subagent's PreToolUse input and none in the main session's, including one
started with `--agent`. `agent_id` was observed for a `general-purpose` subagent and a plugin agent
on 2.1.302. For an agent defined in `.claude/agents/`, a non-empty `agent_id` was observed on
2.1.316, 2026-11-02, with `agent_type` `helper`
(`docs/plans/2026-11-02-hold-a-subagents-git-stash.md:55`). That a deny keeps holding under
`bypassPermissions`. The control for the `agent_id` dependency is `tests/probe-agent-id.sh`, which
re-runs the three observations (the main session without and with `--agent`, and a project agent as
a subagent) against the installed Claude Code; section 0 of `docs/runbooks/cutting-a-release.md`
runs it when Claude Code is newer than the last release recorded, and a `FAIL` blocks the release.
It passed all three on 2.1.317, 2026-11-03.

## Verification

`tests/test-review-guard.sh` feeds the hook its input for each form. A subagent's `git stash`,
`stash push`, `stash pop`, `stash apply`, `stash drop`, `stash clear`, `stash -u` and `stash -m
list` are refused, and its `stash list` and `stash show` allowed. With `python3` off the `PATH` its
`git stash` is refused and its `stash list` allowed. A user-defined `helper` agent is refused. An
event with `agent_type` `helper` and no `agent_id`, an empty one, or the number 7, is allowed `git
stash`. An event with `agent_type` `keel:keel-reviewer` and no `agent_id` is allowed `git stash
list` and `git commit -m x`, and the same event with an `agent_id` is refused both, with and
without `python3`. Without `python3`, a subagent whose `agent_type` is `we"ird` is refused `git
stash`. A subagent's `git stash` in an event past 1 MB is refused by the parser. A subagent's
`echo git stash` and the body of its `git commit -F - <<'EOF'` are allowed, its `echo git stash |
sh` and a `bash <<'EOF'` body naming `git stash` are refused, and without `python3` its `echo git
stash` is refused. The reviewer's `echo git stash` is refused. A command past 64 KB is refused
unread, with a reason saying it is too long to read, and a main session's 1 MB command is allowed.
Some cases run the hook under `/bin/bash` by name.

Holding if no implementer's stash turns up in a plan's notes or in `git stash list` at a task
boundary. Not holding if a subagent's stash-writing `git stash` runs without a refusal, or if the
main session is refused a command.
