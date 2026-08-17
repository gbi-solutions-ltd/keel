# Design document template

The structure of `<docs_root>/architecture/<slug>.md`. Adapted from
`cursor-starter/planning/architecture-design.md` and `tech-stack-selection.md`, merged because
in practice they are one conversation.

## Header

```markdown
# Architecture: <name>

| | |
|---|---|
| Status | draft / accepted |
| Mode | new / existing |
| Date | YYYY-MM-DD |
| Requirements | `<docs_root>/prd/<slug>.md` |
| Stories | `<docs_root>/stories/<slug>.md` |
| Extends | `<docs_root>/architecture/<other>.md`, in `existing` mode where one exists |
| ADRs | ADR-0007, ADR-0008 |
```

In `existing` mode the design being extended gains an `Extended by` row pointing back, and the rows
this design makes wrong are corrected in it. See [existing-mode.md](existing-mode.md).

## 1. Summary

Three sentences: what is being built, the shape chosen, and the one thing that shape optimises
for. Someone should be able to read this alone and predict the rest.

## 2. Forces

The constraints that actually drove the design, ordered, with the dominant one named.

```markdown
| Force | Source | Weight |
|---|---|---|
| Card data must never be recoverable from our store | CON-02, PCI | **Dominant** |
| A balance read must complete within 50ms | NFR-04 | High |
| The team has no Kafka experience | Team | Medium |
| Must integrate with an existing partner contract | CON-01 | Fixed, not negotiable |
```

Most architecture arguments are disagreements about which force dominates. Naming it here turns
a taste argument into a decision, and makes the ADRs write themselves.

## 3. Approaches considered

Two or three, each with: how it works in three sentences, cost, what it forecloses, and when it
would be wrong. Then the recommendation and why the others lost.

Never present one. A single option is a preference wearing a decision's clothes.

In `existing` mode, "continue with the current pattern" is always one of the options, and often
the right one. Deviating needs its own ADR.

## 4. Structure

**Name the stack, in words, before the diagrams.** Language, runtime, and framework or the explicit
decision to use none, for each thing that runs. This document merged `tech-stack-selection.md` and
has to carry that job: a design that names no stack passes every check below and still cannot be
planned against, because `write-plan` cannot write a line of code without knowing what it is written
in. Found exactly that way on the first greenfield run.

Naming the stack is not the same as naming a version, and self-review item 5 is about versions.
"TypeScript, no UI framework" is required here. "TypeScript 5.4" is a claim that needs checking
first, and usually belongs in the plan rather than here. A stack choice a reasonable engineer would
question is an ADR, not a line in this section.

Then a context diagram and a container diagram. See `mermaid-patterns.md`, whose container nodes
carry their technology for this reason.

Then a component table:

```markdown
| Component | Responsibility | Satisfies | Depends on |
|---|---|---|---|
| `TokenService` | Exchange a PAN for a token; never persist the PAN | FR-04, CON-02 | Vault |
| `RoutingEngine` | Choose a processor for a transaction | FR-07 | Config store |
```

The `Satisfies` column is what makes the design traceable back to the PRD. A component
satisfying nothing is either infrastructure or scope creep, and you should say which.

## 5. Data

The model, the ownership, and the lifecycle. Who writes each table, who reads it, what the
retention is, and what happens on delete.

State explicitly whether any value is derived or stored, and if stored, what reconciles it.
That single question causes more production incidents than any other data decision.

## 6. Critical paths

A sequence diagram per path that matters, with the failure branches drawn. One diagram per path,
not one diagram for everything.

For each: what happens when each participant is slow, unavailable, or returns garbage.

## 7. Failure modes

The section that separates a design from a sketch.

```markdown
| Failure | Detection | Behaviour | Recovery |
|---|---|---|---|
| Processor times out mid-authorisation | 5s timeout | Transaction held `pending`, not failed | Reconciliation job queries processor after 60s |
| Redis unavailable | Connection error | Rate limiting fails **closed**, not open | Alert; service degrades to no-rate-limit only on explicit operator action |
| Two workers process the same job | Optimistic lock version mismatch | Second write rejected | Job retried with fresh read |
```

Say whether each degradation fails open or closed, and why. That is a decision, not an accident,
and it belongs in an ADR when the answer is "open".

## 8. Security architecture

Trust boundaries, what crosses them, and what is checked at each. Where secrets live and how
they reach the runtime. What an attacker who holds each credential can do.

Not a full audit; `security-audit` does that. This is the design-time view that audit checks
against.

## 9. Operations

How it is deployed, observed, and recovered. What is logged, what is measured, and what alerts.
What the runbook will need to say.

## 10. Requirement coverage

```markdown
| Requirement | Addressed by | Note |
|---|---|---|
| FR-01 | `IngestController`, `RoutingEngine` | |
| NFR-04 | Stored balance, ADR-0007 | 50ms budget met by avoiding the ledger scan |
| NFR-09 | **Not addressed** | Needs a decision on log retention. See open questions |
```

Every requirement appears. "Not addressed" is a legitimate row and far better than omission.

That rule is written for `new` mode, where one design covers the whole product. A scoped `existing`
design covers a slice and points at the design that covers the rest, per
[existing-mode.md](existing-mode.md). Copying the full table into a second design guarantees the two
drift apart.

## 11. Open questions

What the design could not settle, who must settle it, and what it blocks. Same shape as the
PRD's.

Ask the blocking ones as choices before presenting the design, per
[../../keel/references/asking-questions.md](../../keel/references/asking-questions.md). A design
question left in this section is one `write-plan` will hit later, when it is more expensive to
answer and the plan has already been shaped around a guess.

## Self-review

1. Every component's `Satisfies` names a requirement that exists, or is marked infrastructure.
2. Every requirement appears in section 10, addressed or explicitly not.
3. Every critical path has a failure branch, and every failure mode says open or closed.
4. Every material decision has an ADR, and every ADR is referenced from the header.
5. No library version is named that was not checked. This is about versions, not about the stack:
   see item 7.
6. Every mermaid block renders. Paste-check the syntax rather than assuming.
7. **The stack is named in section 4**, for every thing that runs, and any choice a reasonable
   engineer would question has an ADR. A design that reaches `write-plan` without this stops it
   dead, and the question then gets answered by whoever is planning rather than by whoever designed.
