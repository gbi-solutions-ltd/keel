# PostgreSQL

Only what changes an answer on this engine. Everything else is in the engine-agnostic sections.

## Types

`numeric(p, s)` is the exact decimal for money. `money` exists and is not it: its fractional
precision is set by a database-wide setting, so the same column means different things on two
installations.

`timestamptz` stores an instant; `timestamp` stores a wall-clock reading with no zone. Choosing
`timestamp` is defensible and choosing it by accident is the usual case. `timestamptz` does not store
a zone, it normalises to UTC, so a column that must remember which zone the user was in needs a
second column.

`text` and `varchar(n)` are the same type with a length check. There is no performance argument for
`varchar(n)`, so the length is a constraint decision and should be justified as one.

`boolean` exists. A boolean in a string or integer column is always a finding here.

## Keys, and the SERIAL question

`serial` is not a type. It is `integer` plus a sequence plus a default, and the integer is **32 bit**,
stopping at 2,147,483,647. `bigserial` is the 64 bit form.

This is the finding worth going looking for. A `serial` key on a table with a billion rows is a
scheduled outage, and it arrives sooner than the row count implies because every rolled-back insert
consumes a value that is never returned. The query that settles it:

```sql
SELECT last_value, max_value FROM <sequence_name>;
```

Widening it is `ALTER TABLE ... ALTER COLUMN ... TYPE bigint`, which rewrites the table and holds an
exclusive lock for the duration. On a large table that is not a weeknight change, so the stopgap is
worth stating alongside: a signed sequence can be restarted into its negative range, which buys the
same number of values again, and only where every consumer handles negative ids.

Prefer `GENERATED ... AS IDENTITY` for new work. It is standard, and it does not hand out the
sequence as a separately grantable object.

**`serial` does not create a primary key.** A table with `id serial` and no `PRIMARY KEY` is common
and is a real finding: logical replication needs a replica identity, and without a primary key or a
declared unique index every `UPDATE` and `DELETE` fails to replicate. Since logical replication is
how large tables are usually migrated with less downtime, the missing key blocks the tool the other
findings need.

## Indexes

`CREATE INDEX CONCURRENTLY` builds without holding writes out, takes longer, and can leave an invalid
index if it fails, which then needs dropping. On any table worth calling large, recommend the
concurrent form and say that the failure mode exists.

A unique constraint and a unique index are not interchangeable: only the constraint can be the target
of a foreign key. Recommend the constraint.

Partial and expression indexes are the two that most often make a targeted index small enough to be
worth its write cost. Both are `optimize-performance` territory when they come from a slow query, and
this file's territory when they come from the model.

## Partitioning

Declarative partitioning, `PARTITION BY RANGE | LIST | HASH`. The practical constraints to check
before recommending it:

- Every unique constraint and primary key must include the partition key. A table whose natural key
  does not include it cannot be partitioned without changing the key, and that is the real cost.
- Attaching an existing table as a partition validates its constraint unless one already proves the
  range, so the migration path matters as much as the design.
- Range partitioning by a time column plus dropping whole partitions is the case that pays. Say
  which column and what the retention rule becomes.

## Checking what is actually there

Row counts from `pg_class.reltuples` are an estimate and are enough for sizing. Where a finding turns
on the number, count exactly and say which you used.

`pg_stat_user_indexes.idx_scan` at or near zero over a meaningful window is the evidence for an index
nobody queries. It resets on restart, so say how long the window was.
