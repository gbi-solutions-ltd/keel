# Idea: Claude Code workflows for the review and execute-plan fan-outs

| | |
|---|---|
| Raised by | The 2026-10-29 feature assessment, item 8 (`docs/ideas/claude-code-features-assessed-2026-10-29.md:69`), reopened when ADR-0013 removed its only stated reason. Reassessment asked for by Bernard on 2026-11-02 |
| Status | declined 2026-11-02, to revisit on the first recorded instance of prose dispatch going wrong in real use |
| Recommendation | Do not build now. Revisit on the first real instance, and probe the `review-guard` question before any build |
| Next | Nothing. A cheap probe is offered under Open questions |

## The problem

Unknown, and nobody could name one. Bernard's answer on 2026-11-02, asked what workflows should fix:
"Nothing specific". The item came from a survey of Claude Code features, not from a cost anyone
felt.

**Evidence.** The record holds one dispatch failure of the kind a script would prevent, and it is an
eval run, not real use: "In one of the six runs of that case the skill reviewed inline and
dispatched no reviewer" (`docs/decisions/ADR-0010-a-reviewers-git-is-held-by-a-hook.md:136-137`).
The other recorded failures are agents misbehaving inside a dispatch that did happen, which a
script does not change:

- A reviewer ran `git stash` on the tree under review, 2026-10-12
  (`docs/ideas/harness-held-dispatch-guarantees.md:19-26`). Answered by `hooks/review-guard`.
- Implementers ran `git stash` against their brief three times
  (`docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:1119`,
  `docs/plans/2026-10-16-plans-declare-batches.md:190`,
  `docs/plans/2026-10-29-claude-code-only.md:1714`). No hook covers implementers.
- A coordinator ran nine review dispatches over four rounds on a one-task plan, 2026-10-14
  (`docs/ideas/proportional-ceremony.md:14-25`). This is the one orchestration failure on record,
  and it is the coordinator going beyond the process, not skipping it.

No instance was found of results lost to compaction, of parallelism left unused, or of a review that
passed work because it ran in the authoring context.

## What was asked for

> one of the things that were suggested to improve keel-claude was the introduction of workflows
> but we seem to have forgotten it somewhat

The 2026-10-29 item: "Plugin `workflows/` for the review and execute-plan fan-outs. Deterministic
orchestration instead of prose dispatch."

## The case against

**Strongest argument for not building this at all.** Workflows cannot be keel's only dispatch path,
so building them adds a second path beside the prose one rather than replacing it. Workflows are
off by default on the Pro plan (settings reference, `enableWorkflows`); `claude -p` runs one only
under an allow rule or a permissive mode (workflows page, "Approve the plan before it runs");
`Workflow` is removed from every subagent (sub-agents page, "Available tools"); and the standard
eval arms load no plugin at all (`docs/ideas/plugin-delegation-eval-gap.md:37-41`). Every skill
that dispatches would keep its prose dispatch for those sessions, and keel would maintain, document
and eval two orchestrations of the same review, to fix a failure seen once in six eval runs and
never in real use.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing. `review-code` already says "Dispatch this pass; do not run it inline" (`skills/review-code/SKILL.md#Dispatch this pass; do not run it inline`) and the plugin evals grade the dispatch | The 1-in-6 inline review stays possible, with no real-use instance behind it |
| Do it manually | Nothing to build. A user in a keel session can already type "use a workflow" and get a scripted fan-out for a review | Ad hoc, not keel's review, and none of keel's briefs or agents unless the user asks for them |
| Buy it | `/code-review ultra` (multi-agent cloud review, billed per run) and the bundled `/deep-research` workflow | Neither runs keel's rubric, spec pass or `keel-reviewer` |
| Build something smaller | See the variants below | |

**Variants of the idea**

| Variant | What it addresses | Note |
|---|---|---|
| Extend `review-guard`'s agent match to `keel:keel-implementer` | The three recorded implementer `git stash` incidents | Unrelated to workflows, and the only variant with real incidents behind it. Implementers must commit in some plans (`agents/keel-implementer.md`), so the refused set would differ from the reviewer's |
| One opt-in plugin workflow for `review-code`'s spec and rubric pass, invoked as `/keel:<name>` by the user, never called by the skill body | The 1-in-6 inline review, for users who choose it | The skill path stays as it is, so nothing it guarantees changes |
| A workflow for `execute-plan` | Nothing on record | `execute-plan` stops to ask when blocked (`skills/execute-plan/SKILL.md:74`), and a background run cannot ask. The plan read, `keel plan status`, test runs and ticks all need the shell, which a script does not have |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| `review-guard` fires for a workflow agent dispatched as `keel:keel-reviewer` | The hook input of a workflow agent's Bash call carries `agent_type` `keel:keel-reviewer` and a non-empty `agent_id` string, which is what the hook keys on (`hooks/review-guard:100`, `:189-192`) | One workflow run with one `keel-reviewer` agent asked to run `git stash` | **Not checked.** The public docs say workflow agents' calls get the session's permission checks and are silent on hooks. If it does not fire, a workflow review loses keel's one hook-held review guarantee (ADR-0010), and the variant is worse than the prose path |
| `agent()` can name a plugin agent | `agentType` resolves `keel:keel-reviewer` from the Agent tool's registry | The same run | **Partly.** `agentType`, `model`, `effort` and `isolation: 'worktree'` are in the 2.1.316 build's workflow authoring reference. The public workflows page lists only `schema`, `label` and `stallMs` |
| A skill's instructions may start a workflow | The model treats an invoked skill that says to call Workflow as the user's opt-in | The rule in the docs | **Conflicting sources.** The 2.1.316 build's Workflow tool description counts "a skill or slash command whose instructions tell you to call Workflow" as opt-in. The public docs were not found to say so; they name the keyword, a direct request, and invoking a saved workflow |
| A plugin can ship workflows and keel's minimum covers them | Plugin `workflows/` exists in every Claude Code at or above keel's 2.1.302 minimum | The changelog | **Partly.** Plugin `workflows/` and the `workflows` manifest field are documented (workflows page, "Distribute a workflow in a plugin"; manifest reference). Dynamic workflows arrived in 2.1.154. No version is documented for plugin-shipped workflows |
| `claude -p` keyword prompts do not start a workflow | The workflows page lists `-p` prompts among non-triggers | Read the raw page | **Not verified.** Taken from a summarising fetch. The approval rule for `-p` above was checked against the raw page |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The one hook-held review guarantee keys on the hook input's `agent_id` and agent type: a non-empty `agent_id` string marks a subagent, and `agent_type` `keel:keel-reviewer` marks the reviewer | `hooks/review-guard:12-16`, `:189-192`; ADR-0010, ADR-0016 | Any workflow review is only as safe as the first assumption above |
| The guard is a speed bump, and leaves reviewer worktree clean-up to the prompt | `docs/decisions/ADR-0010-a-reviewers-git-is-held-by-a-hook.md:112-118` | A workflow does not change either. Both are agent behaviour |
| A hook refuses every subagent the stash-writing forms of `git stash`, and no hook refuses an implementer's other tree-changing git | `hooks/review-guard:189-191` holds any call with a non-empty `agent_id` to the stash rule (ADR-0016); its full list acts for `keel:keel-reviewer` only (`:100`); the three plan notes above | The recorded failures point at a hook, not at orchestration |
| Dispatch is already graded where the plugin loads | `tests/plugin-evals/` cases `review-code-dispatches-rubric-subagent` and `review-code-leaves-the-tree-alone` | The inline-review failure is measurable today, without workflows, by running that case more often |
| The release gate exercises a subagent in one scenario, and loads no plugin | `tests/evals/gate-scenarios:6-8`; `docs/ideas/plugin-delegation-eval-gap.md:37-41` | A workflow path would be covered only by plugin evals, at their cost per run |
| A workflow script has no filesystem or shell | Workflows page, "Behavior and limits" | Everything `execute-plan` does between dispatches goes through an agent or through `args` |
| The dispatch text is large | `skills/execute-plan/references/subagent-prompts.md` 3,863 words, `skills/review-code/references/rubric-pass.md` 2,115 | A script would hold the order of steps, not these briefs, which would still be passed to each agent |
| Seven more skills dispatch `keel-fanout` | `apex-port-plan`, `port-assess`, `security-audit`, `repo-snapshot`, `write-docs`, `shape-idea`, `write-plan` | Out of scope here, and nothing on record says their reads go wrong in the dispatch |

## Open questions

1. **Does `review-guard` fire for a workflow agent typed `keel:keel-reviewer`?** One workflow run
   with one agent answers it, at a cost not yet measured, and a workflow run needs Bernard's opt-in. If it does
   not, the review variant is off the table whatever else is found. Default: do not run it until an
   instance revives the idea.
2. **Will a real instance appear?** A review done inline in real use, or a skipped spec pass, logged
   in a plan note, reopens this record with evidence. Until then it stays declined.
3. **Is the implementer `git stash` worth a hook?** Three plan notes say it recurs. This is not a
   workflows question and belongs to its own idea record if pursued.

## Recommendation

Do not build now: there is no real-use instance, and workflows would be a second dispatch path
beside the prose one keel must keep for Pro, `-p`, subagents and the eval arms.
Revisit when a real instance is recorded, starting with the `review-guard` probe and the opt-in
`/keel:<name>` review variant, never `execute-plan`.
Next: nothing. The implementer `git stash` incidents are the live problem, and they point at a hook.

## Not decided here

Which fan-out would go first if this reopens, how a workflow and its prose twin would be evaluated,
the minimum Claude Code version for plugin-shipped workflows against keel's 2.1.302, the design of
the probe, and whether the seven `keel-fanout` skills are ever in scope.
