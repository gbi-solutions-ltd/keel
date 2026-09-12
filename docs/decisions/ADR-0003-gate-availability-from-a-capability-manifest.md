# ADR-0003: Derive gate availability from a capability manifest rather than declaring it per harness

| | |
|---|---|
| Status | accepted |
| Date | 2026-09-05 |
| Deciders | Bernard Tebandeke, accepted 2026-09-05 |
| Requirements | none written; driver is `docs/ideas/keel-on-codex.md` as amended 2026-09-05 |
| Supersedes | none |

## Context

keel is adding a second supported harness at a lower tier. Three of its four Layer 1 gates work on
Codex CLI; `sensitive-guard` does not, because `permissionDecision: "ask"` is accepted by Codex's
wire schema and then discarded while the tool call proceeds (`openai/codex#28437`, open since
2026-06-16).

The idea record that established this declined the whole harness on one argument: **a gate that
looks installed and is not is worse than no gate.** Tiering does not dissolve that argument. It
relocates it. The new failure is a tier claim that drifts: README says Codex is Tier B, Tier B is
defined as three named gates, and at some later commit the code has stopped delivering one of them.
The claim lives in prose and the delivery lives in code, and nothing forces them to agree. The
person harmed is the same person in the same position, believing they have cover they do not have.

The dominant force is therefore not "support Codex". It is **that no person, at any point, can hold
a belief about a gate that the code does not deliver.**

Four things must agree for that to hold: the hook manifest each harness loads, what `keel init`
writes into a repository, what `keel doctor` reports, and what the documentation claims. Today the
first three are code in three places and the fourth is prose in nineteen.

## Decision

We state each harness's provided primitives and each gate's required primitives once, in a
checked-in flat data file, and derive everything else from it. A gate is active on a harness if and
only if the harness provides every primitive the gate requires. The per-harness hook manifests, the
tier table in `docs/harness-support.md`, `keel init`'s writes and `keel doctor`'s report are all
generated or resolved from that file, and two tests fail the build when a generated artifact is
stale or a document claims a gate the manifest does not grant.

## Alternatives considered

### A: Inline branches at each coupling point

`bin/keel` has 76 Claude-coupled lines. Each gains a conditional on the active harness, and a second
hook manifest is maintained by hand. Zero new concepts and the smallest diff.

It loses on the dominant force alone. A branch is exactly as easy to write wrongly as rightly:
nothing prevents someone registering `sensitive-guard` on Codex, and no check would fail if they
did. It leaves the tier claim as a convention, which is the thing that must not be a convention.

### B: Strategy files with a fixed function contract

`lib/harness/claude.sh` and `lib/harness/codex.sh` implementing the same seven functions, with
`bin/keel` calling only through the contract. This is a real improvement on A and it is where the
per-harness writers should live regardless.

It loses because a function contract is still a convention. `harness_write_config` in `codex.sh` can
write whatever its author types, including a registration for a gate that cannot run. B constrains
the shape of the code and says nothing about the truth of the claim.

**Why the chosen option won.** Only the manifest makes the claim a derived artifact. Under A and B,
the README tier table is a sentence someone maintains; under this decision it is generated, and a
document that disagrees with the manifest is a red build rather than a wrong sentence. That is a
direct answer to the dominant force, and it is the only one of the three that is.

## Consequences

**What becomes easier.** Adding a third harness becomes a data change plus writers, not an audit of
every claim in the repository. Answering "what does this harness actually give me" becomes one
lookup instead of a reading exercise. A gate that stops working somewhere becomes a build failure.

**What becomes harder.** There is a generator to run and a regeneration step in the release routine.
Two new test files exist. A contributor must learn one new concept before editing a hook manifest,
and will be told off by CI if they edit one by hand. The manifest becomes a file where a careless
edit has wide blast radius, which is the price of it being the only place the fact lives.

**What this forecloses.** Per-harness special-casing that is not expressible as a capability. If a
difference between harnesses cannot be stated as "provides this primitive or does not", this design
has no place to put it, and the honest response will be to add a primitive rather than to add a
branch.

**What must be true for this to keep working.** That the primitives are the right granularity: that
gates genuinely decompose into capabilities harnesses either have or lack. If a gate turns out to
work *partially* on a harness, the binary model is wrong and this ADR needs revisiting rather than
a `partial` value being smuggled into the data.

Also that the manifest itself is checked. A data file asserting "codex does not provide
`pretooluse_ask`" has moved the trust, not removed it. Every row carries provenance: a pinned vendor
artifact with a URL and a date, or a dated probe result, and **a primitive with no evidence is
treated as not provided.** Absent evidence fails, never passes.

## Verification

The design is holding if these are all true, and each is checkable:

- `tests/test-harness-claims.sh` passes in CI on every push and pull request, and has at some point
  failed for a real reason. A check that has never fired is a check nobody has tested.
- Regenerating the artifacts produces no diff against what is checked in.
- No document states which harnesses have a gate, anywhere except `docs/harness-support.md`.
- Every manifest row has a probe or fixture date no older than the current release train.

It is not holding if a per-harness conditional appears in `bin/keel` outside `lib/harness/`, or if
someone adds a claim tag to silence the checker rather than to record a fact.
