# PRD template

The structure of `<docs_root>/prd/<slug>.md`. Adapted from `cursor-starter/planning/prd-from-idea.md`
and `prd-refactor-existing.md`, with requirement IDs, statuses, and the observed-versus-required
split added.

## Rules that apply to every section

1. **Every requirement is testable.** If nobody can tell whether it is met, it is not a
   requirement, it is a wish. Rewrite it as an observable outcome or move it to Open questions.
2. **Every requirement has an ID and a status.** IDs are permanent; renumbering breaks the trace
   from user stories and plans. Retire an ID rather than reusing it.
3. **No invented specifics.** If a number, a metric, or a deadline was not given, write
   `Unknown, needs a decision` and add it to Open questions. A fabricated success metric is
   worse than an absent one, because it will be measured.
4. **"Should" is banned.** It hides an undecided question. Use `must`, or move it to
   Out of scope, or ask. Prohibitions are requirements too and need no `must`: "No token,
   signature, or full request body may be logged" is correctly phrased. Do not rewrite a clear
   prohibition into worse English to satisfy a word check.
5. **Sections may be short.** A one-line section that says the true thing beats a padded one.
   An empty section is a bug; `Not applicable, because X` is not empty.
6. **The artifact this one came from is updated too.** A PRD written `from-idea` answers questions
   the idea record lists as open, and the record does not know it. Left alone it keeps asserting
   that a settled question is undecided, which is the exact failure `write-docs` names: a document
   stating what was true when it was written rather than what is true now. So when this PRD settles
   one, strike it through in the record with the answer and where it now lives, as `CON-02` or
   `A4` or an `FR`. Keep the row rather than deleting it, so the decision keeps its trace. The
   same obligation runs the other way for anything downstream: `write-user-stories` updates this
   PRD's open questions when a story settles one.

## ID scheme

| Prefix | For | Example |
|---|---|---|
| `FR-NN` | Functional requirement, something the system does | `FR-07 The system must reject a payout whose currency does not match its account.` |
| `NFR-NN` | Non-functional: performance, availability, security, compliance, operability | `NFR-03 A settlement report must be produced within 5 minutes of period close.` |
| `CON-NN` | Constraint, imposed from outside and not up for negotiation | `CON-02 Card data must never be persisted in plaintext.` |

## Status values

| Status | Means | Where it comes from |
|---|---|---|
| `confirmed` | A person with authority has said yes, this is required | The user, in this conversation or in a cited document |
| `inferred` | Derived from code, docs, or reasoning. Nobody has confirmed it | `from-repo` mode, before review |
| `disputed` | Two sources disagree, or the user is unsure | Contradictions found in step 3 |
| `author-added` | Nobody asked for it and nothing implies it. You judged it necessary | You, and it says so |

In `from-repo` mode **every requirement starts `inferred`**. Statuses only improve when the user
says so. Never write `confirmed` on the user's behalf.

`author-added` is the one you will be tempted to skip, because a requirement you invented reads
exactly like one you derived. It is not a confession, it is the mark that makes a requirement cheap
to delete: an `author-added` row can be struck out with nothing else unravelling, and that is worth
saying in the row itself.

Measured on a one-sentence brief: a run produced 18 requirements, of which **2 came from the user
and 7 were invented outright**, including durable delivery across restart in a service whose queue
is an in-memory array. Nothing in the skill was violated. Every anti-invention rule it holds is
about numbers, metrics and deadlines, and all seven inventions were features.

So the count matters more than any single row. State it where the reader cannot miss it, above the
requirements table:

```markdown
Of 18 requirements below, 2 were stated by the user, 9 derived from code or context, and 7 are
author-added. The author-added ones are listed in Open questions as a single question: are they
wanted at all?
```

## Header

```markdown
# PRD: <product or feature name>

| | |
|---|---|
| Status | draft / in review / approved |
| Mode | from-idea / from-repo / revise |
| Author | <who ran this> |
| Date | YYYY-MM-DD |
| Derived from | `<docs_root>/snapshot.md` at commit `<sha>`, and this conversation |
| Approved by | <name and date, or "not yet approved"> |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.
```

The `Approved by` row is the gate made visible. While it says "not yet approved", no plan should
exist.

## 1. Executive summary

Three to five sentences. What this is, who it is for, why now. Someone should be able to read
only this and know whether the rest concerns them.

## 2. Problem statement

The problem in the users' terms, not the solution's. What happens today, what it costs, and how
we know. Evidence beats assertion: a number, a support volume, a quoted complaint.

In `from-repo` mode this is the section most likely to be genuinely unknown, because code shows
what was built and never why. Ask, or record `Unknown`.

## 3. Goals and non-goals

Goals as outcomes, not features. Non-goals matter more than they look: they are what stops scope
returning later as an assumption.

## 4. Users and personas

Who uses this, what they are trying to achieve, and what they know. For an internal service the
users may be other services and their operators; say so rather than inventing a persona.

## 5. Functional requirements

The core of the document. A table, ordered by importance rather than by discovery.

```markdown
| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | A merchant must be able to submit an account for onboarding with a named partner bank. | confirmed | `OnboardingController.java:48`, confirmed by user 2026-08-11 |
| FR-02 | An account whose outcome has not returned must be reported as `pending`. | inferred | `accountDao.java:40` writes `'pending'` on insert |
| FR-03 | Registration outcome must be accepted asynchronously from the partner bank. | inferred | `OnboardingController.java:88` |
```

The `Evidence` column is what makes `from-repo` mode trustworthy. For `from-idea` it holds who
asked for it and when.

**Evidence takes whichever form is least brittle**, not always `path:line`. A route
(`POST /api/partner/callback`), a cited document (`docs/security-review.md`, finding S-04), or a test that
pins the behaviour are all stronger than a line number for a requirement, because a requirement
outlives the line it currently lives on. Use `path:line` when the evidence is one specific
statement, such as a literal default or a hardcoded branch.

Group into subsections when there are more than about fifteen.

## 6. Non-functional requirements

Performance, availability, security, compliance, operability, data retention. Same table shape.

For anything a number belongs to, either give the number or write `Unknown, needs a decision`.
"Fast" and "secure" are not requirements.

## 7. Constraints

`CON-NN` entries: regulatory, contractual, platform, or an existing integration whose contract
cannot change. Say who imposes each one, because that is what makes it non-negotiable.

## 8. Observed but not required

**`from-repo` mode only, and the most useful section in the document.**

Behaviour the code exhibits that is not a requirement. Label each with one of these five kinds.
The vocabulary is fixed so the column can be scanned and sorted:

| Kind | Means | Typical action |
|---|---|---|
| `accident` | Nobody decided this; it grew | Confirm, then usually fix |
| `bug` | Actively wrong, and the code disagrees with itself or with a doc | Fix. Never a requirement |
| `deliberate stopgap` | A known compromise someone chose, with a reason | Keep, and record it as a `CON` if clients depend on it |
| `deliberate deferral` | Recognised as needed, consciously postponed | Keep out of scope until the deferral is revisited |
| `deliberate consequence` | A real trade-off of the design, not an oversight | Record as an `NFR` or a `CON`, or accept explicitly |

The last three are all deliberate but are not interchangeable: a stopgap has a replacement in
mind, a deferral has a trigger, and a consequence is permanent unless the design changes.

Example rows:

```markdown
| Behaviour | Kind | Evidence | What to do |
|---|---|---|---|
| Every endpoint returns 200 with an error body | accident | `GlobalExceptionHandler.java:68` | Confirm intended; likely a defect |
| Two endpoints declare `application/xml` and return JSON | deliberate stopgap | `LegacyController.java:33`, recorded in a security review | Keep. Existing clients depend on it. Worth a CON entry |
| The routing engine's chosen provider is discarded | bug | `payment.service.ts:62` | Fix. Not a requirement |
```

This section is why the mode exists. Promoting an accident to a requirement means the next
engineer defends it forever.

## 9. Success metrics

How anyone will know this worked, with a number and a source. If none exists, say
`Unknown, needs a decision` and list it in Open questions rather than inventing one.

## 10. Milestones

Only if the user gave them. Otherwise `Unknown, needs a decision`. Do not invent a timeline; it
will be quoted back.

## 11. Out of scope

Explicit exclusions, each with one line on why. This section prevents the most expensive class of
argument later.

## 12. Assumptions

What must hold for this PRD to make sense. Each one is a risk if wrong, so write it as something
falsifiable.

## 13. Open questions

Everything the document could not settle, with who needs to answer it. A PRD with open questions
is honest. A PRD with none, written from a codebase, is not.

**Write them here and ask the blocking ones as choices.** This section is the record, not the
mechanism: a question that only lives in a table at the end of a long document is read past, and
comes back as an assumption three weeks later. Anything blocking a requirement goes to the user
through `AskUserQuestion` before the PRD is presented, following
[../../keel/references/asking-questions.md](../../keel/references/asking-questions.md). Update the
row with the answer rather than deleting it, so the decision keeps its trace.

```markdown
| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | Is the `pending` to `approved` window bounded by an SLA? | Ops | NFR-02 |
| Q2 | Should a declined registration be retryable, or terminal? | Product | FR-09 |
```

## Self-review before presenting

Run this yourself, not as a subagent dispatch:

1. **Testability:** every `FR` and `NFR` has an observable outcome. Any that do not, fix or move.
2. **Banned words:** search for "should", "fast", "secure", "user-friendly", "robust", "scalable"
   without a number. Fix each.
3. **Invented specifics:** every number traces to the user or a cited source. Any that do not
   become `Unknown, needs a decision`.
4. **Conflicts:** any two requirements that cannot both hold. Mark both `disputed` and ask.
5. **Status honesty:** in `from-repo` mode, nothing is `confirmed` that the user did not confirm.
6. **Empty sections:** none. `Not applicable, because X` where genuinely so.
7. **Did anyone ask for this?** Go requirement by requirement. Each one traces to something the
   user said, to a citation, or it is `author-added`. Count the three and write the count in.
   Checks 1 to 6 all pass a requirement nobody wanted, because a well-formed invention is still
   well formed.

Fix inline and move on. Then present, naming the `inferred`, `disputed` and `author-added` items
explicitly, because those are what approval actually turns on.
