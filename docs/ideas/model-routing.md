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
| A cheaper model is adequate for the delegated brief | The brief is mechanical and its output is checkable | Only by running the Tier 3 evals with the model pinned | No |
| Delegation saves more than it costs | The task is long relative to the context it must re-read | Needs one measured comparison | No |
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
3. **Is there a measurement worth taking first?** One `repo-snapshot` run with briefs on `haiku`
   against one on `inherit`, compared on output quality and total spend, would settle most of this.

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

**The measurement worth taking first.** Not taken, which is why no brief names `haiku`. The
`sonnet` pins are a shape judgement rather than a measured saving, and this record should not be
read as claiming otherwise: keel measures context, not spend, so nothing here has demonstrated a
cost reduction. That remains the honest gap.
