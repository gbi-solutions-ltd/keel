# ADR-0014: The capability manifest becomes a Claude Code feature ledger that sets keel's minimum version

| | |
|---|---|
| Status | proposed |
| Date | 2026-10-29 |
| Deciders | The maintainer of keel. Bernard chose this shape on 2026-10-29 in the design conversation; acceptance is a separate act |
| Requirements | None written. Driver is [`docs/architecture/claude-code-only.md`](../architecture/claude-code-only.md) |
| Supersedes | ADR-0003 |

## Context

ADR-0003 made `lib/harness/capabilities` the one place stating which primitives each harness provides
and which each gate requires, with every row carrying a source, a version and a date, and with
`docs/harness-support.md`, the hook manifests, `keel init` and `keel doctor` derived from it. Its
dominant force was that nobody may hold a belief about a gate the code does not deliver.

With ADR-0013 there is one harness, so the question "which harness runs this gate" has one answer.
The force does not go away. It moves from harnesses to versions: a gate built on a Claude Code
feature does not run on a Claude Code older than that feature, and keel declares no minimum version
anywhere. The 2026-10-29 assessment found exactly this when it proposed `onFailure: "block"`, which
needs 2.1.295.

The ledger already records the version each Claude Code primitive was verified on, from 2.1.261 to
2.1.302. **The dominant force is that the minimum Claude Code version keel needs is derived from what
its gates use, so it cannot drift from them.**

## Decision

We keep `lib/harness/capabilities` and `lib/harness/resolve.sh` with Claude Code rows only, and give
the ledger one new consumer: keel's minimum Claude Code version is the highest version among the
`provides|claude` rows that a shipped gate requires. `keel doctor` compares it with the installed
version, and README and `docs/harness-support.md` carry it as generated text. The multi-harness
plumbing goes: `profile.harnesses`, `--harness`, `harness_each`, `harness_set_for_repo` and the
`harness=codex` claim markers.

## Alternatives considered

### A: Remove the layer entirely

Delete `lib/harness/` and the claim checker, hard-code each gate, and keep the minimum version as a
constant in `bin/keel`. It is less code, and with one harness `harness_gate_active` can only turn
false when a row loses its evidence. It loses because the constant is written by hand: the next
feature adopted can need a newer Claude Code and nothing makes the constant follow, which is the
drift ADR-0003 was written to make impossible.

### B: Keep the layer unchanged, Codex rows deleted

The smallest diff. It keeps `harness_each`, the harness set and the six-function contract with one
implementation, which is indirection that answers a question nobody asks any more, and it still
leaves the minimum version undeclared.

**Why the chosen option won.** It is the only option where adopting a feature that needs a newer
Claude Code raises keel's stated minimum in the same edit, which is ADR-0003's guarantee carried over
to versions. It keeps the evidence rule, so a feature nobody verified is still treated as not
provided.

## Consequences

**What becomes easier.** Answering "which Claude Code does keel need, and why" is one lookup with a
reason per row. Adopting a newer feature states its version cost where it is adopted.

**What becomes harder.** Every adopted feature needs a ledger row with evidence before a gate may
depend on it, which is the cost ADR-0003 already charged. The minimum version can only rise when the
ledger says so, so a fix that needs a newer Claude Code without a gate depending on it must still add
a row.

**What this forecloses.** Recording another harness here. A port keeps its own manifest, as
`keel-cursor` does.

**What must be true for this to keep working.** That `claude --version` stays readable from a shell,
since `keel doctor` reads it. If it stops being readable, the check reports that it cannot tell
rather than passing.

## Verification

Holding if: the minimum version printed by `keel doctor`, README and `docs/harness-support.md` is the
same number and changes when a row's version does; the generated-artifact test fails when they
disagree; and no `harness` set, flag or Codex row remains.

Not holding if a feature is adopted in a hook or a skill without a ledger row, so that keel quietly
needs a newer Claude Code than it states.
