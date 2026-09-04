# Indexing and partitioning

Section 6 of the review.

**Read the seam first.** `optimize-performance` Step 3 already owns N+1, missing indexes on a slow
query, `SELECT *` and reading the query plan, and it does that better than a second copy would. This
file exists for the part that is a modelling decision rather than a query fix, and the most useful
thing it does is send you away when you have arrived with a slow query.

| You have | Goes to |
|---|---|
| A query that is too slow | `optimize-performance`. It reads the plan; this file does not |
| A plan showing a sequential scan you want fixed | `optimize-performance` |
| A table with no index that the model says needs one | Here |
| An index nobody can name a query for | Here |
| A table whose size, not whose query, is the problem | Here, as partitioning |

The distinction that decides it: a slow query is evidence about a query, and a table that has grown
past what any single-table design can serve is evidence about the model.

## Indexes, as a modelling question

Every foreign key is a candidate, and the absence of an index on one is worth naming even with no
slow query attached, because the join that needs it exists in the model whether or not anyone has
run it yet.

Every unique constraint the business rules imply is an index you get for free by declaring the
constraint. Declare the constraint, not the index: the constraint enforces the rule and the index
follows, and an index alone enforces nothing.

**Indexes nobody can name a query for are a finding too.** Each one is paid for on every insert,
update and delete. A schema with one index across the whole database and a schema with forty
untraceable ones are both worth reporting, in opposite directions.

Say what an index costs where you recommend one. On a large table the recommendation is not "add an
index" but "add an index, which will take this long and hold this lock unless built concurrently",
and the second half is what makes it actionable.

## Partitioning, as a decision with three answers

Partitioning gets mentioned in passing, as something to combine with a rebuild one day. That is the
failure this section fixes: mentioned, not decided.

**A partitioning recommendation is incomplete unless all three are answered.** A blank is not an
answer; `Not warranted, because` is a complete one for the whole section.

**1. The partition key.** Which column, and why that one. Almost always the column that also decides
retention, because a partition you can drop whole is the main thing partitioning buys.

**2. The retention consequence.** What becomes possible that was not: dropping a period in constant
time instead of a delete that runs for hours and leaves the table bloated. If nothing about retention
changes, say so, because then partitioning is buying less than it looks.

**3. What breaks if the key is wrong.** The question people skip. A key that does not appear in the
common query's predicate means every query touches every partition, so you have paid the cost and
bought nothing. A key that is updated after insert means rows move between partitions, which some
engines forbid outright.

## The case worth recognising

A 400 million row table whose nightly settlement job went from twenty minutes to nine hours is the
shape that prompted this file, and the instructive part is that an index is the wrong answer.

The job is not slow because a lookup is slow. It is slow because it reads a period out of a table
that holds six years, and the volume it must touch grows every month while the period does not. An
index makes finding the period cheaper and does not stop the table growing under it. Partitioning by
the period column means the job reads one partition, and the retention question becomes a drop rather
than a delete.

That reasoning is what the section wants written down. Recommending partitioning without it is the
"mentioned, not decided" failure with more words.

## What to write in the review

Indexes: the ones the model implies and the schema lacks, and the ones present with no query behind
them. For each recommendation, its cost on a table of the size actually measured.

Partitioning: the three answers, or `Not warranted, because`, with the reason.

Anything that is really a slow query: named, and handed to `optimize-performance` rather than
half-answered here.
