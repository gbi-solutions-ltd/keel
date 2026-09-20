# Idea: which standard produced a change does not survive into history

| | |
|---|---|
| Raised by | Bernard, 2026-09-19, "plan the work that makes keel enforceable outside the agent" |
| Status | shaped |
| Recommendation | A `Keel-Version` commit trailer, added mechanically via a hook under `keel guard install`. Drop the model trailer |
| Next | `write-plan`, as one increment of the outside-the-agent plan |

## The problem

Nothing durable records which `keel_version` (or model) produced a given change. That becomes urgent
the first time a production failure might predate a rule: "was this commit made under the standard
that would have caught this" is currently unanswerable except by cross-referencing dates by hand.

## What already exists, and what it does not cover

**Evidence.** The recent "label a dispatch's model in its own description" work
(`0e83531`, `feat(dispatch): label a dispatch's model in its own description`) changes the live
dispatch description string a delegating skill passes to `Agent(...)`, so descriptions now lead with
`"<profile>: <task>"`. This is a UI label at dispatch time: it makes the model visible to a person
watching the run happen. Whether it is *durable* depends entirely on whether the harness persists
that `Agent` call's description into a transcript that is later archived, and ordinary repositories
keep no such archive. And the label only covers dispatched subagent work; a commit produced directly
by the top-level session, with no dispatch involved, has no model record anywhere, transcript or
otherwise.

**Verdict: the dispatch-model-label work makes the model recoverable only for delegated work, and
only for as long as the transcript survives, which is neither durable nor complete.** It does not make a
model trailer redundant, but it also does not clearly justify one on the same grounds that justify a
`keel_version` trailer. `keel_version` has no record anywhere outside `.keel/profile.json` itself
(confirmed: it appears nowhere else in the tree). That is the clean gap; the model question is
weaker evidence, not the same gap.

## Recommendation

Propose a `Keel-Version` commit trailer, and only that. Add it mechanically, not as a prose
reminder: a `prepare-commit-msg` hook installed by `keel guard install` (the same mechanism that
already manages `.githooks/` for the pre-push ratchet) that appends `Keel-Version: <version>` from
`.keel/profile.json` to every commit made in the repository. This makes the record impossible to
forget rather than asking an agent or a human to remember it, consistent with the house preference
for structural fixes over prose ones (`docs/ideas/standards-that-bind.md`, question 3).

Drop the model trailer from this proposal. The evidence for it is weaker, the UI-label work already
addresses the "invisible during the run" half of the problem it would solve, and adding it without a
settled durability story would be exactly the "claim with no reader" pattern this whole plan exists
to close.

## Open questions

1. Should the trailer read the profile at commit time (subject to whatever `.keel/profile.json` says
   right then) or something more stable, like the plugin's installed version? These can differ.
2. Does this need any interaction with `keel guard`'s pre-push ratchet (`docs/ideas/profile-loosening-goes-unnoticed.md`), e.g. refusing a push whose commits lack the trailer? Not decided here; likely a later, separate call.
