# Story template

The structure of `<docs_root>/stories/<slug>.md`. Adapted from `cursor-starter/planning/user-stories.md`,
with requirement tracing, story kinds, and the two-way coverage proof added.

## Header

```markdown
# Stories: <product or feature name>

| | |
|---|---|
| Derived from | `<docs_root>/prd/<slug>.md`, PRD status `<draft/approved>` |
| Date | YYYY-MM-DD |
| Stories | N (build: a, verify: b, fix: c, decide: d) |
| Coverage | X of Y requirements covered. See the table at the end |

> Story IDs are permanent. Plans trace to them. Retire rather than renumber.
> If the PRD is not approved, every story here is provisional.
```

That last line matters. Stories built from a draft PRD can be cancelled wholesale, and saying so
prevents someone starting the top one on Monday.

## Story shape

```markdown
### S-07 Reject a payout whose currency does not match its account

| | |
|---|---|
| Kind | fix |
| Satisfies | FR-07 |
| Size | M |
| Depends on | S-03 |
| Status of requirement | inferred |

**As a** merchant operations analyst
**I want** a payout in the wrong currency to be refused at submission
**So that** I find the mistake before money moves, not during reconciliation

**Acceptance criteria**

```gherkin
Scenario: currency matches the account
  Given an account denominated in UGX
  When a payout of 50000 UGX is submitted
  Then it is accepted

Scenario: currency does not match the account
  Given an account denominated in UGX
  When a payout of 50000 KES is submitted
  Then it is rejected with error CURRENCY_MISMATCH
  And no ledger entry is written

Scenario: currency is absent
  Given an account denominated in UGX
  When a payout is submitted with no currency
  Then it is rejected with error CURRENCY_REQUIRED
```

**Notes:** the existing code takes currency from the request rather than the account
(`payout.service.ts:212`), which is why this is `fix` and not `build`.
```

### Field rules

- **ID** `S-NN`, permanent. Plans reference these.
- **Kind** exactly one of `build`, `verify`, `fix`, `decide`.
- **Satisfies** one or more requirement IDs from the PRD. Never empty. If you cannot name one,
  the story is invented scope.
- **Size** `S`, `M`, or `L` only. Not hours, not points. Anything bigger than `L` is an epic that
  has not been split.
- **Depends on** other story IDs. Empty is fine and common.
- **Status of requirement** copied from the PRD. An `inferred` or `disputed` requirement makes
  the story provisional, and that must be visible here rather than only in the PRD. Where a story
  satisfies several requirements whose statuses differ, name each rather than picking one:
  `FR-10 confirmed, FR-11 inferred`. One word cannot describe two requirements, and the optimistic
  half is the one a reader remembers.

## Keeping the PRD current

A story frequently settles an open question the PRD lists, because writing acceptance criteria
forces a decision the requirement left vague. When that happens, update the PRD's open questions
row with the answer and the date rather than leaving it open, and mark any requirement it moves
from `inferred` to `confirmed`.

The obligation runs upstream as far as the chain goes: the same rule sends `write-prd` back to the
idea record. Without it every artifact keeps asserting what was true on the day it was written,
which is precisely what `skills/write-docs/references/current-state-prose.md` exists to prevent.

### Acceptance criteria rules

- Gherkin, because it forces the observable outcome into the open.
- One scenario per behaviour. The happy path, then each way it can fail.
- Assert on what a caller or a user can see: a status, an error code, a stored row, a message.
  Never on an internal call.
- Around six scenarios is the ceiling. More means the story needs splitting.
- A scenario that cannot fail is not a scenario. "Then it works" is not an assertion.

## Story kinds in practice

The distinction exists because a PRD written `from-repo` describes a system that mostly already
runs, and treating every requirement as new work produces a backlog that reimplements working
software.

| Kind | The work is | Done when |
|---|---|---|
| `build` | Write the feature | Tests pass and the behaviour is new |
| `verify` | Write tests for behaviour believed correct | Tests pass, or a defect is found and becomes a `fix` story |
| `fix` | Correct a contradiction between code and requirement | A test that failed now passes |
| `decide` | Answer an open question or settle a `disputed` requirement | A written decision. No code. An ADR where it shapes the system, the requirement itself where it is a value |

A `verify` story that fails becomes a `fix` story. Say so in the notes rather than silently
expanding the scope of the `verify`.

**Where a `decide` story's answer goes.** Not every decision is an ADR, and sending threshold values
there buries them. A timeout, a tolerance band, a retry count and a minimum supported version are
**requirement values**: they belong in the `NFR` or `FR` they qualify, which is where anyone
building against them will look. An ADR is for a decision that shapes the system, which is the test
`skills/design-architecture/references/adr-template.md` applies under "when not to write one".

Either way the reasoning survives. Record why the value is what it is, and why the nearby
alternatives lost, in the requirement's `Evidence` column. "30 seconds, because 5 would fail a
healthy board on a reconnect" is worth more than the number alone, and it is the part that is lost
when a decision is recorded as a bare figure.

Say in the story where its answer landed, so the next reader is not hunting for an ADR that was
correctly never written.

## Epics

Group stories that ship together and deliver something noticeable. An epic is not a folder;
if shipping half of it is useless, that is one epic, and if half is useful, split it.

```markdown
## Epic E-02: Currency correctness on money movement

**Goal:** money never moves in the wrong currency, and the ledger proves it.
**Requirements:** FR-07, FR-08, NFR-04
**Stories:** S-07, S-08, S-09
**Ships when:** all three pass and a payout in a mismatched currency is refused in staging.
```

## Coverage table

The last section of the document, and the reason the document can be trusted. Produce it by
tabulating, never by assertion.

```markdown
## Coverage

| Requirement | Status | Stories | Note |
|---|---|---|---|
| FR-01 | inferred | S-01, S-02 | |
| FR-02 | inferred | S-03 | |
| FR-03 | confirmed | S-04 | |
| NFR-01 | inferred | S-11 | |
| NFR-05 | inferred | none | **Gap.** Requires a config change with no owner. See Q6 |
| CON-04 | confirmed | none | Constraint, not work. Correctly uncovered |

**Forward:** 18 of 21 requirements have at least one story. Uncovered: NFR-05 (gap, needs an
owner), CON-04 and CON-05 (constraints, not work).
**Backward:** every story names a requirement that exists in the PRD.
```

Constraints usually have no stories, and that is correct rather than a gap. Say which is which,
because an unexplained blank row reads as an oversight.

## Self-review

1. Every story has a non-empty `Satisfies`, and each ID exists in the PRD.
2. Every `FR` and `NFR` appears in the coverage table with either stories or a stated reason.
3. No story bundles two things that could ship separately. "and" in a title is a prompt to
   check this, not a defect in itself: "upload and download", "rotate and purge", "query and
   list" are each one story, because shipping half of either delivers nothing.

   This is the second place a crude word check has flagged correct output, after the `must`
   rule in `write-prd`. When a mechanical check disagrees with clear English, fix the check.
4. No acceptance criterion asserts on an internal call.
5. Every `decide` story is ordered before the stories that depend on it.
6. Sizes are `S`, `M`, or `L`, and no story is bigger than `L`.

Fix inline. Then report the counts and the gaps rather than a claim that it is complete.
