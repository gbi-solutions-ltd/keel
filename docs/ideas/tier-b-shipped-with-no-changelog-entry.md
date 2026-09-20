# Idea: Tier B (Codex) shipped in 0.19.0 with no CHANGELOG entry, including the required CCA warning

| | |
|---|---|
| Raised by | Bernard, 2026-09-12, during the 0.19.0 publish |
| Status | **fixed, 2026-09-12, after 0.19.0 had already shipped.** `CHANGELOG.md`'s 0.19.0 entry now carries a Tier B bullet and section 9's CCA paragraph verbatim; the entry's closing "Known gaps" line gained the Codex-specific ones the release actually shipped with |
| Recommendation | Done for the internal record. The public release notes already carried the CCA paragraph at publish time (see `tests/evals/results.md` and the earlier publish notes); this closes the gap in `CHANGELOG.md` itself, which was the piece still missing it |
| Next | nothing outstanding here. Whether this correction needs its own patch release or lands as a documentation-only commit on the already-tagged 0.19.0 is a separate, smaller decision |

## The problem

`docs/architecture/tiered-multi-harness-support.md` section 9 names a **required** release note:

> **Required release note for the first Tier B release**, to be pasted into the CHANGELOG entry
> verbatim rather than paraphrased or replaced by a link.

`CHANGELOG.md`'s 0.19.0 entry carries no mention of Codex, Tier B, or harnesses at all. Checked
across the whole file: nothing anywhere names it. `docs/architecture/tiered-multi-harness-support.md`
(990 lines), `lib/harness/codex.sh`, `hooks/hooks.codex.json`, three ADRs (0003, 0004, 0005) and
`.codex-plugin/plugin.json` all landed between 2026-09-05 and 2026-09-12, entirely inside the 0.19.0
cycle, the day after `v0.18.0` was tagged. 0.19.0 is the first release, internal or public, to carry
any of it.

## What happened

Found while writing 0.19.0's public release notes, after the version bump and internal merge had
already landed (`sandbox` at `2b23869`, PR #64 merged). Rather than unwind an already-merged,
CI-green release, the public notes were written directly from the architecture doc and the required
paragraph was pasted into them verbatim, so the public-facing obligation the runbook cares about
most (a Codex user needing to know gate enforcement can silently stop) was met at the point that
actually reaches a reader. `CHANGELOG.md` itself is the piece still missing it.

## What is owed

A 0.19.0 CHANGELOG entry, added now even though the version is already tagged: this file's own
convention is that entries land with the release, not that a shipped release's entry is frozen from
further correction, and `docs/ideas/links-into-export-excluded-paths.md` records a comparable
after-the-fact fix to an already-tagged release's document. Carry the CCA paragraph exactly as
section 9 gives it, not a summary. Whether it needs its own patch release or lands as a
documentation-only commit on `sandbox` and `main` is a smaller decision than the one already made
here: that it needs to exist.
