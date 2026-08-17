# ADR template

The structure of `<docs_root>/decisions/ADR-NNNN-<slug>.md`.

## The rules that make ADRs worth writing

1. **Append-only.** Never edit an accepted ADR. A decision that changes gets a new ADR that
   supersedes it, and the old one gets a `Superseded by` line. The value of the record is that
   it shows what was believed and when; editing destroys exactly that.
2. **Number sequentially, never reuse.** `ADR-0007` means one thing forever.
3. **One decision per ADR.** Two decisions in one file cannot be superseded independently.
4. **Write it when the decision is made**, not at the end of the project. The reasoning
   evaporates within days and what you reconstruct later is a justification, not a record.
5. **Alternatives are mandatory.** An ADR with no rejected option is a preference. If you truly
   had no alternative, the alternative was "do nothing" and you should say why that lost. State
   each option by its properties, never as an episode: "we tried it and it was slow" cannot be
   re-evaluated when the constraints change, and a number can.
6. **Never write `accepted` on a human's behalf.** An ADR you generate is `proposed`, and its
   `Deciders` row names the roles that must decide, not a person who has not spoken. Only a
   person moves an ADR to `accepted`. Marking your own analysis as an accepted decision
   manufactures an agreement that never happened, and every downstream skill will treat it as
   settled.

## Template

```markdown
# ADR-0007: Store wallet balances rather than deriving them from the ledger

| | |
|---|---|
| Status | proposed / accepted / superseded by ADR-NNNN / rejected |
| Date | YYYY-MM-DD |
| Deciders | who actually decided, by name |
| Requirements | FR-12, NFR-04 |
| Supersedes | ADR-0003, if any |

## Context

What is true that forces a decision now. The constraints, the numbers, the deadline, the thing
that broke. Written so someone with no memory of this month can follow it.

State the dominant force explicitly: "reads outnumber writes roughly 400 to 1" is the kind of
sentence that makes the rest of the ADR obvious.

## Decision

One paragraph, in the active voice, stating what will be done. Not "we could" or "it is
proposed that". "We store the balance on the wallet row and reconcile it against the ledger
nightly."

## Alternatives considered

### A: Derive the balance from the ledger on every read

How it works, in two sentences. Why it lost, concretely: a number, a constraint it violates, or
an operational cost. "Slower" is not a reason; "adds roughly 40ms to every balance read at
current ledger depth, against an NFR-04 budget of 50ms for the whole request" is.

### B: Materialised view refreshed on write

Same shape.

**Why the chosen option won:** one paragraph tying back to the dominant force from Context.

## Consequences

**What becomes easier.** Be specific.

**What becomes harder.** This section is the one people skip and the one that earns the ADR.
Every real decision costs something.

**What this forecloses.** Options that are now expensive or impossible.

**What must be true for this to keep working.** The assumptions that, if they break, mean
revisiting this. These are the trigger conditions for a superseding ADR.

## Verification

How anyone will know this decision is holding up, and what would signal it is not. For the
example above: "the nightly reconciliation reports drift; sustained non-zero drift means the
stored balance is wrong and this ADR needs revisiting."
```

## Status values

| Status | Means |
|---|---|
| `proposed` | Written, not yet agreed. Nothing should be built on it |
| `accepted` | Agreed. This is what we do |
| `superseded by ADR-NNNN` | Replaced. Keep the file; it explains why the current answer looks odd |
| `rejected` | Considered and declined. Worth keeping, because the same idea returns |

`rejected` ADRs are the cheapest to write and among the most useful. They stop an idea being
re-proposed every six months.

## Sizing

Most ADRs are half a page. The Context and Consequences sections carry the value; Decision is
usually two sentences. If an ADR runs past two pages it is probably two decisions.

## When not to write one

- Reversible in an afternoon with no data migration.
- Nobody would question it.
- It is a coding convention, which belongs in `<docs_root>/standards.md`.
- **It is a requirement value rather than a shape.** A timeout, a tolerance band, a retry count, a
  minimum supported version: these belong in the `NFR` or `FR` they qualify, with the reasoning in
  its `Evidence` column, because that is where anyone building against them looks. An ADR for "the
  interval is 30 seconds" buries the number somewhere nobody reads while writing code. This is the
  same test from the other side of `write-user-stories`, whose `decide` stories frequently answer
  exactly this kind of question.
- **The decision has not been made yet.** A `decide` story hands off to an ADR, but only once its
  answer exists. Where the story is waiting on a lawyer, a measurement, or a person who has not
  spoken, there is nothing to record, and writing one anyway invents a decision and hands the next
  reader a conclusion nobody reached. This is the same failure as writing `accepted` on a human's
  behalf, arriving one step earlier. Leave the story open and say in the design which requirement
  it blocks.

  Observed on the first greenfield run: four `decide` stories, none of them answerable at design
  time, and the skill's instruction read as though four ADRs were owed.

When unsure, write it. An unnecessary ADR costs ten minutes; a missing one costs the next
engineer a day of archaeology and often a wrong guess.
