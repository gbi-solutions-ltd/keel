# Idea: let the harness show and hold what a dispatch promises

| | |
|---|---|
| Raised by | Bernard, 2026-10-13, choosing items 1 and 2 from an assessment of Claude Code features keel does not use yet, after the delegated-review build merged |
| Status | built 2026-10-13, via docs/plans/2026-10-13-harness-held-dispatch-guarantees.md |
| Recommendation | Build something smaller: ship the subagent status line, block file edits for `keel-fanout`, and add the two prompt sentences the incidents call for. Do not put reviewers in harness worktrees |
| Next | Nothing for variants A and C. Items 4 to 8 are decided together |

## The problem

A person running keel cannot see which model a dispatched subagent actually ran on, and a judging
subagent can still change the author's working tree, because both guarantees live only in prose
the dispatched model is asked to follow. It costs trust on every delegated run, and on 2026-10-12
it cost a hand clean-up twice.

**Evidence.**

- **2026-10-12, a judging subagent changed the author's tree.** The spec review of step 3.7 of
  `docs/plans/2026-10-12-independence-of-a-delegated-review.md`, briefed "do not edit anything", ran
  `git stash` on the author's working tree to measure a baseline word count, then `git stash pop
  --index`. Nothing was lost, and it said so. The prompt it was given forbade edits and said
  nothing about git commands that move the index or the tree.
- **2026-10-12, a reviewer left a worktree behind.** The quality review of the same step created a
  detached worktree at `928a03d` under the device's temp directory and did not remove it. The next
  review found it in `git worktree list` and the coordinator removed it by hand.
- **The label is unverifiable, and that is recorded.** `CHANGELOG.md:29`: "Known gap, not closed:
  the validator checks that a dispatch names a model, in any skill, and never the `inherit: `
  label". **No instance of a label that lied is on record**, so item 1 rests on the gap and not on a
  failure.

## What was asked for

> From your current assessment of the keel plugin, which other functionality of Claude Code can be
> adopted to enhance current functionality

> Yes we start here. I would however also like to know that the other items 5-7 could also be
> considered for appropriate implementation and we'll decide on them together. For 4, i think
> review in CI should be made optional so the user explicitly toggles it on

"Here" is items 1 and 2 of that assessment: a subagent status line that shows each subagent's
resolved model, and the agent frontmatter fields keel does not use (`tools`, `disallowedTools`,
`maxTurns`, `effort`, `isolation`).

## The case against

**Strongest argument for not building this at all.** Both items move a guarantee from text every
harness reads to machinery only Claude Code has, so keel would hold the same promise at two
strengths depending on the harness, and the evidence for item 2 does not need machinery. The two
incidents above came from subagents the coordinator briefed by hand, and both are missing sentences
in a prompt: nothing said "no `git stash`", and nothing made the worktree's removal unconditional.
A tool restriction would not have stopped either, because both ran through Bash, which a reviewer
needs for `git diff` and the test command. And the harness's own worktree isolation, the obvious
machinery for item 2, turns out not to check out the change under review at all (see the first
finding below). The cheap fix for the evidence is two sentences in two prompts.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The label stays unverifiable, and the next reviewer that stashes may not pop |
| Do it manually | Two sentences each in `rubric-pass.md` and the two review prompts in `subagent-prompts.md`: no git command that changes the index, the tree or the stash; remove any worktree you made, unconditionally | **This is part of the recommendation.** It answers the evidence directly and holds on both harnesses. It does nothing for item 1 |
| Buy it | Anthropic's managed Code Review runs reviews off the author's machine | It reviews pull requests, not the in-session delegated reviews these incidents came from, and it knows none of keel's checks |
| Build something smaller | The status line, plus a tool restriction on `keel-fanout` only | The recommendation, with the manual fix above |

**Variants of building it**

| Variant | What it adds | Verdict |
|---|---|---|
| A. A `subagentStatusLine` script shipped in the plugin's `settings.json` | Each running subagent's row shows the resolved model next to the label keel wrote | **Build.** The only way the label becomes checkable by the person watching, which is who the label was for |
| B. A. plus a mismatch flag | The row is marked when a `keel-fanout: ` label runs on anything but the profile's model | Open question 1. Needs the script to know each harness's profile resolution |
| C. `keel-fanout` gains `disallowedTools: Edit, Write, NotebookEdit` and a `maxTurns` | "Report leads, not verdicts" stops depending on the model for file edits; a runaway read is capped | **Build**, scoped to edits. Bash stays, so this is partial, and the record says so |
| D. A new `keel-review` agent with `model: inherit` and `isolation: worktree`, used by the rubric pass and execute-plan's two reviews | The harness creates, guards and removes the reviewer's worktree | **Do not build yet.** See findings 1 and 2 |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A plugin can ship a subagent status line | Plugin `settings.json` keys take effect on install | Claude Code plugin components docs, "Default settings": "Two keys take effect, `agent` and `subagentStatusLine`" | **Checked 2026-10-13 against the docs.** Not yet tried in a session |
| The status line receives the model the subagent actually runs on | The row input carries a resolved model ID | Status line docs, task fields: `model` is the "ID of the resolved model the task runs on", Claude Code v2.1.205 or later | **Checked against the docs.** Not probed. A probe goes in `docs/harness-support.md` per ADR-0004 |
| A user's own `subagentStatusLine` is not overwritten | User settings rank above plugin defaults | Plugin components docs: "plugin defaults are the lowest layer" | **Checked against the docs** |
| `disallowedTools` is honoured on a plugin agent | It is in the supported plugin-agent field list | Plugin components docs, "Frontmatter fields in plugin agents" lists `tools`, `disallowedTools`, `maxTurns`, `effort`, `isolation` as supported and `permissionMode`, `hooks`, `mcpServers` as ignored | **Checked against the docs** |
| Codex has an equivalent of either | Codex renders dispatch rows and accepts tool limits in `.codex/agents/*.toml` | Codex documentation | **Not checked.** Unknown, and declared dark until it is |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| 1. A harness worktree does not hold the change under review | Claude Code worktrees docs: subagent worktrees "branch from your repository's default branch unless `worktree.baseRef` is set to `"head"`", and creation "checks out only tracked files" | Variant D's reviewer would review `main`, not the branch. `worktree.baseRef` is a settings key a plugin cannot ship, so keel would have to write it into a project's settings, which changes every worktree that project makes |
| 2. Isolation blocks git into the author's checkout | Same page: it blocks a Bash command "that redirects git into the main checkout", including `git -C` | Would have prevented the `git stash` incident, and also prevents reading an uncommitted diff, which `review-code` reviews today |
| 3. A changed subagent worktree is kept until a sweep | Same page: a worktree "with changes stays on disk until the periodic sweep" | The revert check leaves changes unless it restores the line, so D would not have prevented the leftover worktree either |
| 4. The label is confirmed rendered on Claude Code and unchecked on Codex | `docs/standards.md#Confirmed on Claude Code` | Variant A is Claude Code only, the same position the label already has |
| 5. `keel-fanout` sets only a model | `agents/keel-fanout.md:4`; its rules are prose, `agents/keel-fanout.md:17` | Variant C is a frontmatter edit. `tests/validate-skills.sh` checks name, description and model only, so new fields pass |
| 6. Codex resolves the profile in its own file | `lib/harness/codex.sh:86` writes `.codex/agents/keel-fanout.toml` with a model and an effort | Any field added to the Claude agent has no Codex counterpart until someone checks the toml format |
| 7. The rubric pass already owns its worktree in prose | `skills/review-code/references/rubric-pass.md:76`, and four open gaps at `docs/plans/2026-10-12-independence-of-a-delegated-review.md:1241` to `:1244` | D would not close those gaps: untracked files and dependencies are absent from a harness worktree too |
| 8. A recorded claim may be stale | `docs/standards.md#a session's model cannot be changed by a plugin` says no plugin can change the session's model. Skill frontmatter now takes a `model` that "applies for the rest of the current turn" (Claude Code skills docs) | Out of scope here. Re-check before anything else cites that sentence; it bears on `model-routing.md` |
| 9. The label rule leaves a question open that A answers | `docs/ideas/independence-of-a-delegated-review.md`, open question 4: does a profile label lose the self-documentation `inherit: ` has | With A, the row shows the model whatever the label says, so a profile name in the label stops costing that |

## Open questions

Questions 1 to 3 were surfaced as choices and answered by Bernard on 2026-10-13. They are kept
here rather than deleted so each decision keeps its trace.

1. ~~Should the status line flag a label that does not match the model, or only show the model?~~
   **Answered: only show it.** A flag needs the script to know what `keel-fanout` resolves to per
   harness, which duplicates `codex.sh` and the agent file; showing the model already lets a person
   see the mismatch.
2. ~~Do the two missing prompt sentences land in this build?~~ **Answered: yes, in this build.**
   They are the direct fix for both incidents, they hold on Codex, and they cost about forty words
   across three prompts that are pasted, not loaded, so no body budget is touched. **Built
   2026-10-13: about 330 words landed across the prompts, against the "about forty" estimated
   here.** The estimate was low, and this record is where it was made. Counted as net new words in
   the commit, 118 landed in each of the two `execute-plan` review prompts and 96 in the rubric
   pass, because each block names the git commands to avoid, the ones to read with, the worktree's
   creation and removal, and the incident it answers.
3. ~~Is `keel-fanout`'s restriction edits only, or also Bash?~~ **Answered: edits only.** Fan-out
   readers run `git log` and `grep` through Bash, and removing it would break the reads the
   profile exists for.

### Raised in the same assessment, to decide together

Recorded so they are not lost; none blocks the build above.

4. **Review in CI is opt-in.** Decided by Bernard, 2026-10-13: running `review-code` through the
   Claude Code GitHub Action is off unless the user explicitly turns it on. Not decided: where the
   switch lives. A profile key would have to declare its reader like every other key does.
5. **Should `review-code` run as a forked skill** (`context: fork` with `agent:`), so the harness
   rather than the body enforces independence? It moves the suite run and the plugin step into the
   fork and answers open question 3 of the delegated-review record by default. To decide together.
6. **Should run-on-purpose skills set `disable-model-invocation: true`**, which removes their
   description from every session's context and frees room under decision 6? Candidates named so
   far: `apex-export`, `port-assess`, possibly `ship`. To decide together.
7. **Should keel measure itself with Claude Code's `/skill-doctor` and `claude plugin eval`** before
   building more of its own eval harness? `docs/ideas/plugin-delegation-eval-gap.md` waits on
   exactly a runner that loads a plugin. To decide together.
8. **Item 3 of the assessment, path-scoped rules written by `keel init`**, is not raised for
   decision yet: it needs one experiment first, whether a delegated implementer loads a
   `.claude/rules/` file whose `paths:` match the files it edits.

## Recommendation

**Build something smaller.** Ship variant A, the subagent status line, and variant C,
`keel-fanout` without edit tools, plus the two prompt sentences that answer the incidents directly.
Do not put reviewers in harness worktrees: the harness checks out the default branch and tracked
files only, so variant D would review the wrong tree and still not close the gaps it was for.

Landed: variant A in ce4c8f6, variant C in 7673566, the prompt sentences in e0c09be. Variant A
landed as a script inlined into the plugin's `settings.json` as a `python3 -I -c` command, because
`${CLAUDE_PLUGIN_ROOT}` did not resolve there when probed. Variant C's tool denial holds for the
agent file, and nothing pins that a `keel-fanout: ` dispatch selects that agent. The row format,
its colours (none, the row is plain text) and truncation, and the `docs/harness-support.md` rows
listed under "Not decided here" were decided in the build, so only the opt-in switch for item 4 and
items 5 to 8 remain open.

## Not decided here

- The status line's exact row format, its colours, and whether it truncates the label or the model
  first in a narrow pane.
- The `docs/harness-support.md` rows for the new claims and the probe that fills them.
- Where the opt-in switch for item 4 lives, and everything about items 5 to 8.
