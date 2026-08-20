# Idea: route simpler tasks to cheaper models

| | |
|---|---|
| Raised by | Bernard, 2026-08-16 |
| Status | built 2026-08-17 in its reduced form, and documented. The central mechanism asked for does not exist |
| Recommendation | Build something smaller: name a model on the subagent briefs keel already dispatches, and announce it. Do not build a complexity router |
| Next | `docs/plans/2026-08-16-done-conditions-model-pins-and-install-docs.md`, task 6 |

## The problem

A session pinned to the most expensive model pays that price for work that did not need it, such as
bulk file reading, mechanical renames, and format-shaped edits.

**Evidence.** Asserted from use. No per-task cost measurement exists for keel.

## What was asked for

> Curious about auto-model-routing. Even if the session started in Fable, if a task is simpler,
> could it automatically be sent to sonnet or opus depending on the complexity. I guess this is the
> advisor strategy. If the user also has codex, requests could be routed to it where necessary. If
> possible, when there are other competent but fairly price models (cheaper than Anthropic's) that
> can be used to simpler tasks, suggestions could be made to have them installed. It would also be
> nice to announce when switching to another model.

## The case against

**Strongest argument for not building this at all.** The mechanism at the centre of the request is
not available. A session's model cannot be changed by a plugin, a hook, or the model itself; that is
the user's `/model`, and no hook event exposes model selection. So "the session started in Fable and
a simple task goes to Sonnet" cannot be built. What remains is delegating to a subagent that runs on
a named model, which keel skills already do for other reasons, so the whole idea reduces to adding a
`model:` field to briefs that exist.

And the reduced version has its own problem. Delegation is not free: a subagent starts cold and
re-reads the context the main thread already holds, so a genuinely small task can cost more in total
on the cheap model than it would have cost inline on the expensive one. Routing pays where the work
is *long and mechanical*, not where it is *simple*. A router that keys on guessed complexity will
therefore be wrong in the direction nobody notices, because a cheap model doing a poor job on
something that mattered produces plausible output, not an error.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | Some real waste stays on the table |
| Do it manually | The user runs `/model` when they know a stretch is mechanical | Available today, and for the session-level case it is the only thing that works |
| Buy it | Nothing available | Third-party routers exist but sit outside Claude Code's model selection |
| Build something smaller | One frontmatter line per brief | Captures the available win without a router |

**Variants of building it**

| Variant | Note |
|---|---|
| `model:` on the subagent briefs keel already dispatches | Available. Values: `sonnet`, `opus`, `haiku`, `fable`, a full id, or `inherit` |
| Ship `agents/` definitions pinned to cheap models | Available. keel ships none today |
| Announce the model in one line when delegating | Free. Should be a rule regardless of the rest |
| A complexity classifier that picks a tier per task | Rejected. Keys on the wrong variable, fails quietly |
| Route to `codex` or another CLI over Bash | Rejected for now. Sends the repo to a third party with nothing to verify the result, and cuts across `sensitive-guard` |
| Suggest installing cheaper third-party models | Rejected. keel does not get to recommend where a client's code is sent |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A cheaper model is adequate for the delegated brief | The brief is mechanical and its output is checkable | Only by running the Tier 3 evals with the model pinned | **Yes, 2026-08-20. False for `haiku` on `repo-snapshot`: see "What shipped"** |
| Delegation saves more than it costs | The task is long relative to the context it must re-read | Needs one measured comparison | **Yes, 2026-08-20. False for `repo-snapshot` at 187 files: inline cost $1.48 less. See "What shipped"** |
| A pinned model survives a keel release | The alias set is stable | Aliases have changed before. A full model id would pin harder and rot faster | No |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| No hook event can change the model | Claude Code hooks documentation, checked 2026-08-16: hooks have no access to model selection | The session-level half of the request is not buildable. Record this so it is not re-proposed |
| Subagent definitions take `model:` | Claude Code sub-agents documentation: `sonnet`, `opus`, `haiku`, `fable`, a full id, or `inherit`, defaulting to `inherit` | The delegation half is buildable today |
| Plugins may ship `agents/` | Claude Code plugins reference | keel ships none, so every dispatch currently inherits the session model |
| Five skills already dispatch subagents | `repo-snapshot`, `port-assess`, `apex-port-plan`, `shape-idea`, `execute-plan` | The insertion points exist. This is an edit, not a feature |
| Briefs must go to subagents verbatim | `skills/execute-plan/SKILL.md`, step 3 | A cheaper model gets less benefit of the doubt, so the verbatim rule matters more, not less |
| Ambient context cost is already governed | `docs/05-token-and-memory-design.md`; `hooks/context-watch` | keel measures context, not spend. Any claim of saving here is currently unmeasurable |

## Open questions

1. **Which dispatches are actually mechanical?** `repo-snapshot`'s wide reads are the strongest
   candidate. `execute-plan`'s per-task implementation is the weakest, because it writes code under
   the TDD gate.
2. **Alias or full model id?** An alias tracks the vendor's current model and can shift under a
   pinned keel release. A full id is reproducible and goes stale.
3. **Is there a measurement worth taking first?** ~~One `repo-snapshot` run with briefs on
   `haiku` against one on `inherit`, compared on output quality and total spend, would settle most
   of this.~~ **Taken 2026-08-20. Answered below: haiku loses.**

## Recommendation

**Build something smaller.** Add `model:` to the subagent briefs keel already dispatches, chosen by
the *shape* of the work (wide mechanical reading goes cheap, code under a gate does not), and
require the dispatching skill to announce the model in one line, which the request asked for and
which costs nothing.

Do not build a complexity router, and do not route to third-party CLIs.

Record in this repo that session-level model switching is unavailable to a plugin, with the date it
was checked, so the idea is not reopened from scratch.

## Not decided here

Which briefs get which model; alias against full id; whether the eval suite should pin models.

## What shipped

Built as task 6 of `docs/plans/2026-08-16-done-conditions-model-pins-and-install-docs.md`, released
in 0.8.0, and documented in `README.md` and `docs/standards.md` on 2026-08-17. The three questions
this record left open are answered as follows.

**Which dispatches are mechanical.** The four fan-outs: `repo-snapshot`, `port-assess`,
`apex-port-plan` and `shape-idea`. Everything in `execute-plan` stays `inherit`, because it either
writes code under the TDD gate or judges another agent's verdict.

**Alias or full id.** Alias. A full id is reproducible and goes stale inside a pinned release, and
the validator's job is to catch the stale case, which it can only do against a known alias set.

**The measurement worth taking first.** Taken 2026-08-20, in full, and recorded in
`tests/evals/results.md`. It changes two things this record used to say.

**Haiku is not adequate on the fan-out briefs, so no brief should name it.** One `repo-snapshot`
run with its six briefs on `haiku` against one as shipped on `sonnet`, same 187-file tree, same
prompt but for the one pinned word, same `claude-opus-5[1m]` dispatcher. Both dispatched all six
`Explore` agents in one message on the model they were pinned to, read off the `tool_use` blocks.

| | Haiku | Sonnet |
|---|---|---|
| Fan-out cost | $1.16 | $2.03 |
| Total run | $3.76 | $5.20 |
| Structural rules (`path:line` present, section 10 items, did-not-check line) | all pass | all pass |
| Files cited that do not exist | none | none |
| **Citations that do not support their claim** | **35%** | **15%** |

The cost win is real: **43% off the delegated reading**, and that is the honest figure, because the
rest of the 28% total gap is dispatcher turn-count variance one run cannot separate from noise.
It does not buy the quality. Haiku's citations resolve to real files and real lines and are wrong
about twice as often, systematically so, one line low on `.keel/profile.json` in three separate
sections. `repo-snapshot`'s core principle is that a confident snapshot which is wrong is worse than
none, because the next three decisions inherit the error, and that is the exact property haiku fails.

**This is the failure mode "The case against" above predicted**, which is the part worth keeping:
a cheap model doing a poor job on something that mattered produces plausible output, not an error.
Every structural check passed. The defect was reachable only by opening the cited lines. Wide
mechanical reading looked like the safest thing to route down, and it was not, so "route by the
shape of the work" is now a weaker heuristic than this record claimed.

**The cost claim is no longer a gap, and is smaller than it looked.** keel now has one measured
figure: the fan-out is $2.03 of a $5.20 `repo-snapshot` run, so the entire budget the `model:` pins
can move is 39% of that skill's spend, and the cheaper end of it costs accuracy. The `sonnet` pins
stay where they are, and they stay a shape judgement for the other five skills, which were not
exercised.

**Measured 2026-08-20, and the answer is that delegation loses on cost.** The second unchecked
assumption in the table above, taken the same way: the recorded `sonnet` arm above against one new
arm reading the same byte-identical 187-file tree inline, same dispatcher, the prompt differing only
where it delegates. Recorded in `tests/evals/results.md`.

| | Delegated | Inline |
|---|---|---|
| Total run | $5.20 | **$3.72** |
| Fan-out | $2.03 | none, by construction |
| Dispatching thread | $3.17 | $3.72 |
| Document | 482 lines, 11 sections | 512 lines, 11 sections |

Removing the fan-out saved $2.03 and the absorbing thread grew $0.55, which is inside the $0.56 noise
floor this repository's own arms establish. Net **$1.48 against delegating**, on a document that is
structurally identical: same section count, same seven section 10 items, same did-not-check line.

**So the assumption is false for this fan-out**, and that reaches further than the row. `repo-snapshot`
Step 2 opens "**This is why the skill exists**", and the `sonnet` pins on the four fan-outs are a shape
judgement that presumes the fan-out is worth doing at all. On this repository, at this size, the prior
question of whether to delegate now has one measurement against it. The entry above asked which model
should receive the fan-out; this one asks whether it should be sent.

**Two things it does not license.** It says **nothing about quality in either direction**. The
coverage measure applied to it turned out to count itemised rows rather than claims, so it scored the
delegated document's prose sections as zero rows while counting one itemised inline finding as six;
the inline document carries 68 `path:line` citations against the delegated document's 52 and still
scored worse. That axis is void, not close, and the quality question is **open rather than settled in
delegation's favour**. And it does not touch
`skills/repo-snapshot/SKILL.md:46-47`, which claims delegation exists for **context hygiene**, not
cost. That sentence is untested in either direction, and this result must not be read as evidence for
it.

**Wall clock is not evidence here either.** The delegated baseline was measured with both arms of the
haiku run overlapping on one machine, twelve subagents deep; the inline arm ran alone. The bias runs
toward inline and the axis is void.

**So the run lands with two axes void and one clean**, and on the clean one the row is false. The cost
decomposition is the mechanism: reading the files inline cost the dispatching thread $0.55 more, which
is inside the noise floor, while delegating the same reading cost $2.03.

**Still not measured:** the same comparison on the other four fan-outs, on a repository that is not
keel, or at a size where inline would not fit. The assumption's own "true if" is *the task is long
relative to the context it must re-read*, and 187 files in a 1M window is not that case.
