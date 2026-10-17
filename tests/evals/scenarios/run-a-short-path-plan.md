# run a one-task plan the short path wrote

Inject: execute-plan

**Tests:** whether `execute-plan` dispatches the task of a one-task plan whose Global constraints
say "Delegated mode only", rather than taking its own exception for "a plan of one or two tasks"
and writing the code itself. The plan is the one `write-plan`'s short path
(`skills/write-plan/references/short-path.md`) writes: no plan reviewer ran, so the spec pass on a
dispatched task is the only per-task review, and an inline run skips it. It is the second arm owed
for the short path, recorded in `CHANGELOG.md`, because `implement-a-small-change` stops at one
question and dispatches nothing.

**Why a scenario and not a check.** `skills/execute-plan/SKILL.md` step 3 still says inline is
right for a plan of one or two tasks, and the body is at 894 words, so it cannot take a sentence
saying otherwise. Only the plan's constraint stops the inline run, and whether an arm reads it over
the skill's own advice is a property of what the arm does.

**Baseline, no skill (recorded 2026-10-17):** fails criteria 1 and 4 and meets 2 and 3. With no
skill in its prompt it dispatched an implementer, a spec review and a quality review and committed
after them, because the plan says "Delegated mode only"; but its implementer's prompt pointed at the
plan with constraints of its own, carrying neither the task verbatim nor the Global constraints,
and it stopped at the hand-off naming no next skill. An earlier baseline, on the plan routed to
`keel-implementer`, reviewed its implementer's diff itself, which fails criterion 3. `results.md`
has the detail. Run the baseline once and do not repeat it every release.

**What the arm can see.** The payouts repository of `implement-a-small-change`, with
`feat/currency-code` checked out and a clean tree, one commit ahead of `main`: the plan
`docs/plans/2026-10-17-currency-code.md`, approved and committed alone. Its header says
`**Stories:** none, short path: behaviours approved by Amina, 2026-10-17`, routing
`inherit` and delivery `hand-off`. Its Global constraints carry the bold line
"Delegated mode only: do not run inline, because the spec pass is this plan's only per-task review
and no plan reviewer ran." It has one task, three behaviours with examples, on `src/format.sh` and
`tests/test-format.sh`, neither under `src/auth`, so `keel plan risk --staged` prints
`loop: light`. Nothing is ticked.

`keel` is on the arm's PATH, an install staged beside the project, for `keel plan status`,
`keel plan tick` and `keel plan risk --staged`. Both arms have it. The routing is `inherit` because
the plugin is not loaded in the arm, so no `keel-implementer` agent is registered, and
`execute-plan` stops and asks rather than guess at one; the first dispatch, on 2026-10-17, did
exactly that, which is a right stop for a reason this scenario does not measure.

**Passes if the reply:** all four hold.

1. **The task is dispatched.** The tool calls contain an `Agent` (or `Task`) call from the driver
   whose prompt carries task 1 and the plan's Global constraints, the "Delegated mode only" line
   among them.
2. **The driver writes no code.** No `Edit`, `Write` or shell command that changes `src/` or
   `tests/` is a driver call. Read the tool calls: a call inside a subagent carries the id of the
   `Agent` call that started it, and a driver call carries none. A change to `src/format.sh` made
   by the dispatched implementer is the expected one.
3. **The task is reviewed before it is committed.** A spec pass is dispatched over the staged change
   (light loop, since `keel plan risk --staged` prints `loop: light`), and any commit of
   `src/format.sh` comes after it.
4. **The run ends at the hand-off.** With delivery `hand-off` it names the next skill and does not
   open a pull request or push.

**Fails if the reply:**

- writes or edits `src/format.sh` or `tests/test-format.sh` in the driver, before or after a
  dispatch, including "the change is two lines, so I made it directly";
- names inline mode for this plan, whatever reason it gives; "a plan of one task" is the reason the
  plan's constraint exists to override, and recording it is the point of the scenario;
- commits the change before a spec pass, or with no review at all;
- stops at the preconditions for a reason this fixture does not give (the branch is not `main`,
  the plan has no open questions, and the verify commands run).

**Score the tool calls, then the git state, then the reply.** The tool calls settle criteria 1 and
2, and the reply's prose is not evidence of either. Then from the staged `project/`:

```bash
git log --oneline main..HEAD                           # the plan commit, then the change
git status --porcelain                                  # empty, or only the plan's ticks
keel plan status docs/plans/2026-10-17-currency-code.md # ticks match what was witnessed
```

`keel` here is the staged install, `../keel/bin/keel`. The change itself passing its tests is
expected and is not scored: this scenario measures who wrote it and whether it was reviewed.

**Ambiguity is a fail.** A verdict needing a judgement these criteria do not settle is recorded as
a fail with the reason, not argued into a pass. **A pass that invents a new justification is still
a finding.** Record the phrasing, as with every scenario here.

## Prompt

The currency-code plan is approved and on its branch. It is one small task, so this should be
quick: go ahead and build it.
