# Idea: a skill for designing and reviewing databases

| | |
|---|---|
| Raised by | Bernard, 2026-08-19 |
| Status | **built 2026-08-30**, to `docs/plans/2026-08-30-design-database.md`. Scope decided 2026-08-19 |
| Recommendation | One skill, `design-database`, scoped to what a baseline agent omits rather than to database review as a whole |
| Next | nothing. See "What landed" below for what stayed out |

## What landed, 2026-08-30

`skills/design-database`, the 25th skill. A body of 544 words carrying the routing seams and the
required output shape, plus five references: `review-template.md`, `normalisation.md`,
`type-selection.md`, `indexing-and-partitioning.md`, `postgres.md` and `oracle.md`.

**It passes `create-skill` Step 4 on all four criteria**, measured 2026-08-30 with both arms run
against a rebuilt fixture and written up in `tests/evals/results.md`. The margin is the sweep: a
subsection per table and a row per column against the baseline's bullet list, plus the ERD the
baseline again omitted. The ERD earned its place by producing findings rather than by being filled
in, which is the best evidence this record's "structural, not prose" call was right.

**The cost prediction in this record was wrong in the cheap direction.** It expected a body of
roughly 700 words and got 544, and it named five reference files where six were written.

**What stayed out, and why:**

- **SQL Server, MySQL, MariaDB and MongoDB references.** Decided here on 2026-08-19: writing five
  engine references on speculation is content nobody has validated. MongoDB is further out than the
  other three, because the template's sections assume a relational model.
- **The "documenting database objects" half of the original ask.** `write-docs` owns producing
  documents. The review template is a review output, not a reference document for a schema.
- **A second Step 4 pass.** The treatment complied at the first attempt, so there was no loophole to
  close. Stability is therefore unmeasured.

**One thing this record assumed that no longer holds.** Its case rests on a 2026-08-19 baseline that
omitted all four sweeps. Re-run on 2026-08-30 against the rebuilt fixture, a skill-less arm named
denormalisation, found three type defects and gave two of the three partitioning answers. The skill
still wins, but by less than this record predicts, and the fixture the original was measured on no
longer exists to settle whether the model moved or the rebuild is easier.

**The ask.** An agency with many running databases and new ones to design wants one place for:
designing a fresh schema, reviewing an existing one and remediating gaps and normalisation,
documenting database objects, performance work such as partitioning and indexing candidates, and
drawing an ERD in mermaid. Across Oracle, PostgreSQL, SQL Server, MySQL and MariaDB, and MongoDB.

## Step 0 found that three skills already claim parts of this

| Concern | Existing owner | Verdict |
|---|---|---|
| Designing a fresh database | `design-architecture`'s description claims "choosing a stack or datastore" | Router collision. It claims the job; its body says nothing about schema design |
| Reviewing an existing one, gaps, normalisation | Nobody | Genuine gap, and the largest |
| Performance tuning | `optimize-performance` Step 3 covers N+1, missing indexes, `SELECT *`, and reading the query plan | Mostly covered. Partitioning is absent |
| An ERD in mermaid | `design-architecture/references/mermaid-patterns.md`, section "ER", with a rule to label every relationship | Already exists |
| Documenting database objects | `write-docs` owns producing documents | Partial. Nothing says what a database document must contain |
| Engine specifics | Nothing. `apex-export` is Oracle APEX only | Genuine gap |

**Decided:** one skill, handing the overlaps off rather than competing with them. It owns schema
design and existing-database review. Latency work routes to `optimize-performance`, the document
itself to `write-docs`, the ERD to `mermaid-patterns`. `design-architecture` keeps datastore choice,
which engine, and hands schema design over. Its description needs the seam stated, or the router
picks arbitrarily and neither skill improves, which is `create-skill` Step 0's warning.

**Decided:** PostgreSQL and Oracle references first, body engine-agnostic, the other three added when
a project needs one. Writing five engine references on speculation is content nobody has validated.

## The baseline is why the skill's shape is not what was asked for

`create-skill` Step 1, run 2026-08-19. A no-skill arm, `claude-opus-5[1m]`, 8 turns, $1.14, against a
six table payments schema seeded with `FLOAT` money, a `card_pan` column, no primary keys, one index,
a 400 million row `transactions` table and operator notes about a settlement job that went from
twenty minutes to nine hours. Recorded in `tests/evals/results.md`, 2026-08-19.

**It performed well, and better than the seeding.** It found an unseeded and more urgent defect than
any planted one: `transaction_events.id` is a 32 bit `SERIAL` at about 1.5 billion rows, roughly 85
days from every insert failing, with the one query that settles it and a negative-range stopgap. It
found the PCI exposure in `card_pan` and traced it into three unbounded text columns. It explained
why `FLOAT` money means a disputed settlement figure cannot be reproduced. It found two live
double-payment paths from missing unique constraints. It identified that `id SERIAL` is not a primary
key and that the absence blocks logical replication, which is the tool the other migrations need. It
named the root cause as a Django project with no migrations tool. It stated two caveats unprompted:
the schema file is hand-regenerated so may not describe production, and integrity may be enforced in
application validators it could not see.

**So the skill's value is not in the findings.** This is the outcome `create-skill` Step 0 already
recorded once, for a repo-audit workflow that turned out to be covered by `repo-snapshot` and
`security-audit`. A skill written to teach database review would be teaching something the model
does well.

## What the baseline did omit, which is the skill's actual content

Everything it missed is a systematic sweep rather than an insight:

- **Column types nobody looked at.** `date_of_birth VARCHAR(20)`, `active VARCHAR(5)` for a boolean,
  `deleted INT` as a soft delete flag. It went after the headline defects and never swept the types.
- **Denormalisation.** `transactions.merchant_name` and `transactions.customer_email` duplicate
  columns that already exist on their parents. Never mentioned, though normalisation was in the ask.
- **No ERD.** Nothing drew the model it had just reconstructed.
- **Partitioning.** Mentioned once in passing as something to combine with a rebuild, never as a
  decision with a partition key and a retention consequence.

**Which fixes the form.** `create-skill` Step 2: an omission from something the model already
produces is fixed structurally, by a required field in the template it fills in, not by prose
reminders and not by prohibitions. So this skill is a required-sections output template plus engine
references, and its body should not spend words teaching review technique the baseline already has.

## Cost, stated before it is built

Body of roughly 700 words plus references. Design and review and documentation and tuning across
five engines cannot share one body under ADR-0001's 900 word ceiling; `coding-standards` is the
precedent at 17 references, 22,752 words, and a body of 795. Expect `normalisation.md`,
`type-selection.md`, `indexing-and-partitioning.md`, a review output template, and `postgres.md` and
`oracle.md`. Adding a skill also moves `tests/test-doc-claims.sh`'s pinned skill count and adds a
body to the distribution ADR-0001 asks to re-measure at each release.
