# Idea: let the harness show and hold what a dispatch promises

| | |
|---|---|
| Raised by | Bernard, 2026-10-13, choosing items 1 and 2 from an assessment of Claude Code features keel does not use yet, after the delegated-review build merged |
| Status | variants A and C built 2026-10-13, via docs/plans/2026-10-13-harness-held-dispatch-guarantees.md; item 4 built 2026-10-14, via docs/plans/2026-10-14-opt-in-ci-review.md; item 8 answered once in a real session on 2026-10-14; item 5 piloted twice without git, undecided |
| Recommendation | Build something smaller: ship the subagent status line, block file edits for `keel-fanout`, and add the two prompt sentences the incidents call for. Do not put reviewers in harness worktrees |
| Next | Nothing for variants A and C. Item 4 is built (the workflow file is the switch), item 6 is dropped, item 7 is piloted with a verdict, item 8 is answered once (a delegated subagent loaded and followed a path-scoped rule), and item 5 is undecided, waiting on pilot runs in which `git` works inside the eval sandbox |

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
- **The label is unverifiable, and that is recorded.** `CHANGELOG.md`, 0.23.0: "Known gap, not
  closed: the validator checks that a dispatch names a model, in any skill, and never the
  `inherit: ` label". **No instance of a label that lied is on record**, so item 1 rests on the gap
  and not on a failure.

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
| 6. Codex resolves the profile in its own file | `lib/harness/codex.sh` (deleted after v0.26.0) writes `.codex/agents/keel-fanout.toml` with a model and an effort | Any field added to the Claude agent has no Codex counterpart until someone checks the toml format |
| 7. The rubric pass already owns its worktree in prose | `skills/review-code/references/rubric-pass.md#Create it with`, and four open gaps at `docs/plans/2026-10-12-independence-of-a-delegated-review.md:1241` to `:1244` | D would not close those gaps: untracked files and dependencies are absent from a harness worktree too |
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

4. **Review in CI is opt-in, and the workflow file is the switch.** Decided by Bernard, 2026-10-13
   and 2026-10-14: running `review-code` through the Claude Code GitHub Action is off unless the
   user explicitly turns it on, and turning it on means running a keel command that writes
   `.github/workflows/keel-review.yml`. There is no profile key, so there is nothing for keel to
   read or keep in sync. Built in `4e485eb` (`docs/plans/2026-10-14-opt-in-ci-review.md`); the
   workflow is unrun against a real repository and the action is not pinned to a commit.
5. **Should `review-code` run as a forked skill** (`context: fork` with `agent:`), so the harness
   rather than the body enforces independence? It moves the suite run and the plugin step into the
   fork and answers open question 3 of the delegated-review record by default. **Pilot written,
   not run, 2026-10-14**, on the unmerged branch `experiment/forked-review`: a variant skill
   `review-code-forked` and the case `forked-review-code-runs-the-pass`, which asks whether the fork
   still runs the suite, reads the rubric, makes no nested dispatch (a subagent cannot dispatch one)
   and reports a ranked finding, at what cost against the $0.53 of the dispatch version. **Run
   twice, 2026-10-14, Claude Code 2.1.299, one run each:** the first scored 0.80, failed by the
   judge on the ranked finding with the reply lost; the second scored 1.00 at $0.39, against $0.42
   to $0.57 for five dispatch runs the same day. The fork fired, made no nested dispatch, read the
   rubric itself and reported the planted bug as Blocking with its `file:line`. Neither version
   could run `git` (see item 7), and the fork's one attempt at the suite was refused, so its "ran
   the suite" means it tried. **Undecided:** two runs without `git` show a fork can do the pass,
   not that it does it as well as the dispatch.
6. **Dropped, 2026-10-14.** `/skill-doctor` run in a repository using keel showed all 25 keel
   listings cost about 1,600 tokens a turn, and `disable-model-invocation` on the apex trio would
   free about 200. Hiding `incident-response` or `ship` would defeat their point, so nothing is
   worth the change. The larger cost is outside keel: 19 never-used skills synced from claude.ai,
   about 4,900 tokens a turn, which the user can turn off on claude.ai.
7. **Piloted, 2026-10-14.** `claude plugin eval` loads the real plugin and grades the tool calls,
   which `tests/evals/` never does, but it has no git-state grader and each run starts in an empty
   workspace, so it complements the release gate and does not replace it. `/skill-doctor` reports
   what each skill costs and how often it ran; it does not report triggering collisions. Two pilot
   cases are in `tests/plugin-evals/`: whether a plain review request reaches `review-code`, and
   whether it dispatches its rubric pass at `inherit`. **Run 2026-10-14, Claude Code 2.1.296,
   three runs of each case, $2.16:** all six runs scored 1.00. A plain request reached
   `review-code` 3 of 3 and found the planted bug (one judge vote in nine dissented). The dispatch
   case saw `Skill` first, the `inherit: ` description, and a brief carrying the diff command and
   the standards path, 3 of 3. An `Agent` dispatch works inside an eval, keel's hooks did not stop
   a run, and the dispatch is gradable. **A subagent's own tool calls reach the
   transcript.** The first probe matched the driver's own read of `rubric-pass.md` and proved
   nothing; narrowed to `rubric.md`, which only the subagent reads, it passed on a rerun (one run,
   $0.53, so a reviewer's `git stash` is now gradable, though no case grades it yet). **Verdict:**
   adopt `claude plugin eval` beside the release gate, not in place of it, for what the gate cannot
   see: whether a skill fires and whether it dispatches. Three runs is evidence the path works, not
   a rate. **Found later the same day:** in every review run on the owner's Mac, on 2.1.296 and
   2.1.299, `git` failed inside the eval sandbox (Apple's `/usr/bin/git` wrapper cannot write its
   cache there) and `Bash` was refused after that. Each review read the files instead of a diff, and
   most ran no suite. So the runs show the skill fires, dispatches and reads the rubric, not a
   review working with `git` inside the harness. Launching the eval with Xcode's real `git`
   directory first on `PATH` changed nothing: the run still reached the wrapper, and `PATH` is not
   among the variables the eval is documented to pass through. Two more things seen: a `tool_used`
   grader counts a refused call, and the judge is noisy, with two unanimous FAILs in the day's runs,
   one of them on a reply read afterwards and found to meet the rubric.
8. **Item 3 of the assessment, path-scoped rules written by `keel init`**, needed one experiment:
   whether a delegated implementer loads a `.claude/rules/` file whose `paths:` match the files it
   edits. **Answered once, 2026-10-14, in a real session on Claude Code 2.1.299, not in the eval
   harness.** The setup was a scratch repository built by the case's `scaffold.sh`, with an
   `InstructionsLoaded` hook logging every load. A prompt that only read `src/fees.sh` loaded the
   unconditional rule at session start and four path-scoped rules, the scaffold's `src/fees*.sh`
   among them, on that read. In the delegated run the log shows `fees.md` loaded by the subagent
   (the event carries its `agent_id`, and names `src/fees.sh` as the trigger), and the file came
   back with the `# FEE-RULE:` line the rule asks for. **That is one run. It shows a delegated
   implementer can load and follow a path-scoped rule, not how often it does.** The control, the
   same task given to the main agent, loaded nothing and wrote no marker: its transcript shows two
   `Bash` commands, a compound `cat` and a `printf` append, and no `Read` or `Edit` call, and the
   docs name `Read`, `Write`, `Edit` and a single-file `cat` or `head` as what triggers a load. The
   three eval-harness runs of the control also wrote no marker with only `Read`, `Glob`, `Grep`,
   `Edit` and `Write` allowed, and the cause is not established. The docs say project rules are
   skipped when `project` is excluded from `--setting-sources`, which would fit, but the harness's
   flags have not been seen. The two cases stay as written and gate nothing. Rules are context and
   not enforcement, the docs say, so a hook is still what holds a constraint.

## Recommendation

**Build something smaller.** Ship variant A, the subagent status line, and variant C,
`keel-fanout` without edit tools, plus the two prompt sentences that answer the incidents directly.
Do not put reviewers in harness worktrees: the harness checks out the default branch and tracked
files only, so variant D would review the wrong tree and still not close the gaps it was for.

Landed: variant A in ce4c8f6, variant C in 7673566, the prompt sentences in e0c09be, and item 4, the
opt-in CI review, in 4e485eb. Variant A landed as a script inlined into the plugin's `settings.json`
as a `python3 -I -c` command, because `${CLAUDE_PLUGIN_ROOT}` did not resolve there when probed.
Variant C's tool denial holds for the agent file, and nothing pins that a `keel-fanout: ` dispatch
selects that agent. The row format, its colours (none, the row is plain text) and truncation, and
the `docs/harness-support.md` rows listed under "Not decided here" were decided in the build, so
only item 5 remains open.

## Not decided here

- The status line's exact row format, its colours, and whether it truncates the label or the model
  first in a narrow pane.
- The `docs/harness-support.md` rows for the new claims and the probe that fills them.
- Item 5: whether `review-code` becomes a forked skill. Its two pilot runs had no `git`.
- Whether `keel init` writes path-scoped rules. Item 8's result shows a delegated implementer can
  load one; it does not decide this.
