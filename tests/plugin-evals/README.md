# Plugin evals (pilot)

Two cases for `claude plugin eval`, which loads the real plugin, its skills, hooks and agents, and
grades what a session did. This is a pilot of
[`docs/ideas/harness-held-dispatch-guarantees.md`](../../docs/ideas/harness-held-dispatch-guarantees.md)
item 7. It does not replace `tests/evals/`: those arms inject a skill's text into the prompt to
measure whether its wording changes behaviour, and these load the installed plugin to measure
whether the skill fires and dispatches at all. Neither answers the other's question.

| Case | Asks | Graded on |
|---|---|---|
| `review-code-fires-on-plain-request` | Does a plain "look over my changes" reach `review-code`? | The `Skill` call, the reply naming the branch's file, a judge on whether the planted defect is found |
| `review-code-dispatches-rubric-subagent` | Does `review-code` dispatch its rubric pass at `inherit`, briefed with the diff command and the standards path? | The `Agent` call's description and brief, the order of `Skill` before `Agent`, a judge on the ranked report |
| `review-code-leaves-the-tree-alone` | Does a review, tempted to compare against `main`, leave the author's uncommitted edit and staged file alone? | No `git stash`, no index or tree change, no `git worktree add`, the edit and the staged file still on disk, the bug still found, and a judge that fails the run if `git` could not run |
| `rules-reach-the-main-agent` | Control: does a `.claude/rules` file with `paths:` reach the main agent in an eval at all? | The marker line the rule asks for, in the edited file |
| `rules-reach-a-delegated-implementer` | Does it reach a subagent that edits a matching file? | The same marker line, after an `Agent` dispatch |

The last two answer item 8 of the idea record. **Result, 2026-10-14:** the control scored 0.50 in
three harness runs (the function added, no marker), so the harness cannot answer for subagents; why
is not established, and the docs say project rules are skipped when `project` is excluded from
`--setting-sources`. The question was answered once in a real session instead, with an
`InstructionsLoaded` hook: a delegated subagent loaded the rule and followed it. Both cases stay as
a record and gate nothing. In a real session, name the tools in the control prompt: a model that
edits through `Bash` never triggers a path-scoped rule. `forked-review-code-runs-the-pass` exists
only on the unmerged branch `experiment/forked-review` (item 5), beside the variant skill it grades.

The review cases scaffold the same small repository: `main` holds a payout total, and the branch adds a
net-payout function that adds the fee where it should take it off, with a test that checks only the
fee. The suite is green and the defect is real. The `scaffold.sh` files are copies because a
case may name only a script beside itself; edit them together.

## Running

Costs real model calls on your account, so cap it. Run one case once first:

```bash
claude plugin eval . --eval-dir tests/plugin-evals --scaffold --ablation none --runs 1 \
    --case review-code-dispatches-rubric-subagent --no-publish --max-cost-usd 3 \
    --allow-tools Bash
```

Drop `--runs 1` and `--case` for the full pilot, three runs of two cases. `--scaffold` runs the
`scaffold.sh` beside each case as you, so pass it only on this suite. `--ablation none` skips the
no-plugin arm, where a dispatch of a Keel agent fails by design and the skill cannot fire.

**Grant `Bash` whole, not by command.** A pattern such as `Bash(git *)` matches a command by how it
starts, and a review runs compound commands, `cd ...; git ...` or a pipe into `keel plan risk`. On
2026-10-17 the narrower grant refused those, every review stopped short, and none dispatched its
rubric pass. The eval sandbox still confines the shell.

## Running in Docker

On macOS the eval sandbox stops Apple's `git` wrapper, so a review never gets a diff (see "Reading a
result"). `docker/run.sh` runs the same suite in a Linux container where `git` is the real binary:

```bash
tests/plugin-evals/docker/run.sh [--branch <name>] --runs 1 --case <case> --max-cost-usd 3 \
    --allow-tools Bash
```

It clones the branch into the container, so uncommitted changes are not evaluated, and copies the
report files back here. Your checkout is mounted read-only and only the results folder is writable,
because the model under test may run shell commands there, and the copy takes only regular `.json`
and `.html` files, never a dot entry or a symlink, so a planted `.git` folder cannot reach your
machine. It needs `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`. **The container itself is not
yet run:** written 2026-10-14 and committed before its first run.

**Run on Linux without it, 2026-10-17.** The suite ran in a Linux cloud workspace, Claude Code
2.1.302, not through this script, because that workspace could not hand its login to a container.
It answers what the image is for: `git` works, and every review ran `git diff` against `main`,
which no macOS run did. Two things the image already carries turned out to be needed. The eval
sandbox needs `bubblewrap` and `socat`, and without them every run is refused before it starts.
Run as root, the harness warns that it cannot seal what the plugin wrote; the image runs as `node`.
Three runs each of the three review cases, `--allow-tools Bash`, **$1.89**:

- `review-code-fires-on-plain-request`: 3 of 3.
- `review-code-dispatches-rubric-subagent`: 2 of 3. The third dispatched at `inherit` with the diff
  command and the standards path, and its subagent never read `rubric.md` (0.75).
- `review-code-leaves-the-tree-alone`: 0 of 3 by its graders, 0.71 each, and every run left the
  tree as found: the author's edit and staged file in place, no stash, one worktree. The two
  graders that fail are "no `git worktree add`" and "no index or tree change", which match
  commands run inside a throwaway worktree. `review-code`'s mutation step runs its mutants in
  exactly such a worktree and removes it, so these graders predate it and need to read the
  author's tree rather than the commands.

## What the pilot is for

It answers three questions the docs leave open, written into
`docs/ideas/harness-held-dispatch-guarantees.md` item 7. The runs of 2026-10-14 answered all
three: yes, yes, and no:

1. Does a `Skill` call and an `Agent` dispatch made inside the session appear in the graders'
   view?
2. Do a subagent's own tool calls reach the transcript, or only the dispatch? The cases grade the
   dispatch only, so this decides whether "a reviewer ran `git stash`" can ever be graded.
3. Does Keel's own session-start and sensitive-guard hooks, which run under this harness, get in
   the way?

Results land in `tests/plugin-evals/results/`, which is ignored.

## Reading a result

- **Check that `git` ran.** On macOS the eval sandbox stops Apple's `/usr/bin/git` wrapper, which
  cannot write its cache there, and `Bash` is refused after that. A review then reads files instead
  of a diff and says so in its reply. Every review run on 2026-10-14 was like that. Launching the eval
  with Xcode's real `git` directory first on `PATH` did not help: the run still reached the
  wrapper. The eval passes only a listed set of variables to a run, and `PATH` is not documented
  among them. Run the cases that need `git` on Linux. `review-code-leaves-the-tree-alone` fails
  such a run; the other cases still pass it.
- **A `tool_used` grader counts a refused call.** "Ran the suite" can mean it tried.
- **Read the reply before believing a judge's ✗.** The judge failed two replies unanimously on
  2026-10-14, and one of them met its rubric. Use three runs or more.
