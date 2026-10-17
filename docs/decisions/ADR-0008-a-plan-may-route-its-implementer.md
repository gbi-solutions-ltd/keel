# ADR-0008: A plan may route its implementer to a cheaper delegation profile

| | |
|---|---|
| Status | accepted |
| Date | 2026-10-16 |
| Deciders | Bernard Tebandeke, accepted 2026-10-16 |
| Requirements | none; driver is gap 7 of `docs/ideas/delivery-flow-gaps.md` and the conversation of 2026-10-16 that folded a cheaper implementer into it |
| Supersedes | none; amends the rule in `docs/standards.md`, "A dispatch names its model, and says so" |

## Context

`docs/standards.md` says that anything writing code under a gate, or judging another agent's
verdict, stays `inherit`. The reason it gives is the one `docs/ideas/model-routing.md` measured on
2026-08-20: a cheaper model doing a poor job produces plausible output, not an error, so its miss is
invisible. Every structural check passed on the haiku arm and the defect was reachable only by
opening the cited lines. The rule therefore keeps `execute-plan`'s implementer on the session's
model, whatever it costs.

Bernard asked on 2026-10-16 for a plan to be able to name a cheaper implementer, and for the
measurement of gap 7 to record which routing each task ran on, so that the cost of the choice is
visible rather than argued.
[ADR-0005](ADR-0005-one-skill-body-per-skill-across-harnesses.md) settles how it is named: a
delegation profile that each harness resolves to its own model, never a vendor alias in a skill
body. The profile is `keel-implementer`, in `agents/keel-implementer.md` for Claude
Code and `.codex/agents/keel-implementer.toml` for Codex. What ADR-0005 does not settle is whether
the standards rule may be bent for it, and that is this decision.

## Decision

**An implementer may run on `keel-implementer` when its plan says so.** The plan names it in a
header line, `**Implementer routing:** keel-implementer`, so the person approving the plan sees it
and can change it there. A plan that says nothing keeps the implementer on `inherit`, as today.

**Reviews stay `inherit`.** The spec pass, the final review and the plan reviewer judge another
agent's work, and that stays on the session's model whatever the plan says. There is no reviewer
routing.

**Why the old rule's reason no longer carries the whole weight.** The rule says a cheaper model's
miss is invisible. For an implementer routed this way it is answered four ways. Answers 1 to 3 are
in the repository with this decision. Answer 4 is built too (task 3 of
`docs/plans/2026-10-16-measure-delivery-and-implementer-model.md`):

1. **The tests are watched failing first.** `keel:tdd` is the implementer's brief, and a case that
   was not seen to fail proves nothing. The cheaper model's code is held to the same cases as the
   dearer one's.
2. **The review is on the session's model.** The work is read by the model the rule trusts, before
   it reaches the shared tree. The implementer stages its task's paths and stops; it commits only
   when its task's own final step says so, which happens only in a private worktree, where nothing
   reaches the shared tree until the coordinator merges it back after review. The review sees the
   implementer's report of the failure it watched, not the failure itself.
3. **The label shows it, on Claude Code only.** A dispatch leads its description with
   `keel-implementer: `, and `lib/subagent_statusline.py` writes the resolved model beside it, so
   the routing is on the row for as long as the dispatch runs. Nothing is shown on Codex, as
   `docs/standards.md` says.
4. **The routing is recorded per task.** Each task's last tick note records the routing it ran
   on, and `keel plan report` reads those notes, so how a task was routed is in git rather than
   in anyone's memory. The note is written by `10afbeb` and read by `keel plan report` (`e5dd976`,
   `c93dcda`).

**Mechanism and scope.** ADR-0005 is the mechanism: a profile name resolved per harness, with
`tests/validate-skills.sh` rejecting a vendor alias in any skill body. This ADR amends one rule in
`docs/standards.md`, and only for the implementer dispatch of a plan that names the profile.
Everything else under that rule is unchanged, and so is ADR-0002: the coordinator still writes no
code.

## Alternatives considered

### A: Keep the implementer on `inherit` always

The standards rule as it stood. Safe, and the cost is the point: every implementer dispatch is paid
at the session's rate. It loses because Bernard asked for the choice, and because the rule's reason
is an argument about unobserved misses, which the four answers above make observable.

### B: A project default in the profile

A key in `.keel/profile.json` routing every implementer. It would route work the person approving a
plan never saw routed, and it would bump `SCHEMA_VERSION`. It loses to the plan header, which is the
checkpoint already asked for.

### C: Name a vendor alias in the skill body

`` model `sonnet` `` beside the dispatch. It passes the validator's old rule and names nothing on a
second harness; ADR-0005 rejected it as its alternative A, and `tests/validate-skills.sh` now fails
it.

## Consequences

**What becomes easier.** A plan can say, once, that its implementers run cheaper, and the person
approving the plan sees it. The same measurement that shows lead time shows what the choice cost.

**What becomes harder.** The standards rule has an exception to carry, and a reader of a plan must
know that `keel-implementer: ` means a different model from the review beside it. The cheaper model
now writes code under a gate, and the review is the only thing between its miss and the commit.

**What this forecloses.** Little. It adds no profile key, no reviewer routing and no automatic
choice of routing from guessed complexity, which `docs/standards.md` already declines to do.

**What must be true for this to keep working.** That the review on the session's model catches what
the cheaper model misses, and that the tests the implementer watched fail are the tests that matter.
Neither is established here.

**What is not yet known.** Whether the implementer profile is the right model on either harness. On
Claude Code `agents/keel-implementer.md` names `sonnet`, which is the model the fan-out measurements
used and has not been measured for writing code. On Codex the profile is the fan-out guess carried
over unchanged, chosen from a price list, and nothing has measured it for this work.

## Verification

Holding if gap 7's rework number, split by routing, shows tasks routed to `keel-implementer` coming
back as fixes no more often than tasks on `inherit`. `keel plan report <plan>` gives both: the
routing each task's tick notes record, and the commits carrying a `Reworks <plan path>` line. The
sample is small and a difference inside it means nothing, so the clause reads the numbers across
plans and does not decide on one.

Not holding if routed tasks rework visibly more often, or if the review finds defects in routed
work that it does not find in `inherit` work. Either reopens this decision: supersede it, and return
the standards rule to `inherit` for implementers.

Not checked on the day of this decision: no plan has yet run its implementers on the profile, so
neither number exists. This plan's own tasks 1 and 2 ran on `sonnet` by hand and record that in
their tick notes, which makes them the first two data points.
