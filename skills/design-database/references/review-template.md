# Review template

The sections a schema review or a schema design produces, in this order.

**Why this file is the skill.** A `create-skill` Step 1 baseline on 2026-08-19, recorded in
`tests/evals/results.md`, reviewed a six table payments schema with no skill at all. It found an
unseeded 32 bit key about 85 days from exhausting its range, a PCI exposure traced into three
unbounded text columns, two live double-payment paths, and why float money makes a disputed
settlement figure irreproducible. It needed no help finding things.

What it never did was sweep. Column types went unexamined, denormalisation went unmentioned though
it was in the request, no ERD was drawn though the model had been reconstructed to review it, and
partitioning appeared once in passing. Every one of those is an omission from something the reader
already produces, and `create-skill` Step 2 says that is fixed by a required field rather than by a
reminder. Hence sections, not advice.

## The rule that makes this work

**Every section appears in the output.** A section with nothing in it says `None found`. A section
left out is not permitted.

`None found` is a claim that somebody looked, so it is honest only after the sweep. Writing it
because a section looked unpromising is the exact failure this file exists to prevent, and it is
worse than omitting the section, because it asserts a sweep that did not happen.

## 1. What was read, and what could not be

Name the source of the schema: the live database, a dump, or a checked-in file. Where it was a file,
say so and say what that costs, because a hand-regenerated schema may not describe production and a
review of the wrong artifact reads as authoritative.

State what enforces integrity outside the schema, or record it as unverified. Application-layer
validators are invisible here and they change every finding about a missing constraint.

Give the row counts you used. A schema fact plus a row count is a finding; either alone is not.

## 2. The model, as an ERD

Mermaid, every relationship labelled, per `design-architecture/references/mermaid-patterns.md`.

Never omitted on the grounds that the model is small or obvious. You reconstructed it in order to
review it, so the reader is being asked to reconstruct it too, from prose, in order to follow you.

## 3. Keys and constraints

Every table's primary key, or its absence stated as a finding. Note that a bare auto-increment
column is not a primary key, and say what the absence blocks: replication and any tooling that needs
to identify a row.

Unique constraints the business rules imply and the schema does not have. Each one is a duplicate
somebody can create today, so name the duplicate rather than the constraint: "the same payment can
be recorded twice" lands where "missing unique on `processor_ref`" does not.

Foreign keys declared, and relationships that exist in the application but not in the schema.

## 4. Column types, swept table by table

**This is a sweep, not a search.** Go through every table, every column. The finding is the list.

`None found` here is valid only after every table has been looked at, and the baseline that prompted
this section had walked past a `VARCHAR(20)` date of birth, a `VARCHAR(5)` boolean and an `INT` soft
delete flag while doing excellent work elsewhere.

See [type-selection.md](type-selection.md) for what to look for and what each mismatch costs.

## 5. Normalisation

Duplicated columns, partial dependencies, transitive dependencies. Where denormalisation is
deliberate, say what makes it deliberate: a recorded decision and a mechanism that keeps the copies
in step. Denormalisation with neither is duplication.

See [normalisation.md](normalisation.md).

## 6. Indexes and partitioning

Indexes that the model implies, and indexes that exist for no query anyone can name.

Partitioning stated as a decision with three answers, none of which may be blank: the partition key,
the retention consequence, and what breaks if the key is wrong. `Not warranted, because` is a
complete answer and a blank is not.

A slow query is not this section. Send it to `optimize-performance`, which owns query plans, N+1 and
missing indexes on a specific query.

See [indexing-and-partitioning.md](indexing-and-partitioning.md).

## 7. Capacity

Anything with a ceiling, checked against current values rather than against the schema alone: integer
key ranges, fixed-width columns, and any enumeration with a bounded encoding.

For each, give the one query that settles it. The baseline's best finding was of exactly this shape,
and it was reachable only because it combined a type with a row count.

## 8. What to change first

Ordered by what breaks soonest, not by what is worst in principle. A wrong column type that nothing
is failing on outranks nothing; a key three months from exhaustion outranks everything.

For each, the smallest correct change. Where the smallest correct change is still large, say what
the stopgap is and what it costs, so somebody can act this week and plan for the rest.
