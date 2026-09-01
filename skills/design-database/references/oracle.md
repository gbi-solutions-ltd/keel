# Oracle

Only what changes an answer on this engine. Everything else is in the engine-agnostic sections.

## Types

`NUMBER(p, s)` is the exact decimal for money. `BINARY_FLOAT` and `BINARY_DOUBLE` are the binary
floating point types and carry the reproducibility problem in the money section; a bare `NUMBER` with
no precision is variable precision and is a different decision from `NUMBER(19, 4)`, so an unqualified
`NUMBER` on a money column is worth asking about rather than assuming.

`DATE` includes a time component, which surprises readers who expect a calendar date, and it has
second resolution. `TIMESTAMP` carries fractional seconds. `TIMESTAMP WITH TIME ZONE` keeps the
offset; `TIMESTAMP WITH LOCAL TIME ZONE` normalises on the way in and renders in the session's zone
on the way out, which means two sessions can read the same row differently. Say which one the column
uses, because the three behave differently in exactly the case that matters.

**There is no boolean type in the SQL layer** before 23c. A boolean is therefore a
`NUMBER(1)` or `CHAR(1)` with a check constraint, and the check constraint is the whole of the
enforcement. A `VARCHAR2(5)` holding `'TRUE'` is the finding.

`VARCHAR2` is the string type; `VARCHAR` is reserved and should not be used. Length semantics are
bytes or characters depending on how the column was declared, and on a multi-byte character set a
`VARCHAR2(20)` declared in bytes does not hold twenty characters. Where a column stores names or
addresses, check which it is.

**The empty string is `NULL`.** This is unique among the engines here and it changes every
`NOT NULL` and every comparison against `''`. A column that means to distinguish "empty" from
"unknown" cannot do so.

## Keys and sequences

Older schemas use a sequence plus a trigger; `GENERATED AS IDENTITY` is available from 12c and is
what new work should use. Where you find the trigger form, check that the trigger actually fires on
every path, because a direct load that bypasses it produces null or duplicate keys.

`NUMBER` has no 32 bit ceiling, so the integer-exhaustion finding that dominates on other engines is
usually not the risk here. The equivalent is a sequence with `MAXVALUE` set and `NOCYCLE`, which
fails on exhaustion, or with `CYCLE`, which silently reissues values that are already in use. Check
both, since the second is worse and quieter.

Check `CACHE` on any sequence feeding a high-rate insert, and note that cached values are lost on
instance restart, so gaps are expected and are not a defect.

## Indexes

An index created without `ONLINE` locks the table for the build. Recommend `ONLINE` on anything
large, and note that it is an Enterprise Edition feature, because a recommendation that the licence
does not permit is not actionable.

A unique constraint is backed by an index that Oracle may or may not drop with the constraint,
depending on how it was created. Where a review recommends dropping a constraint, say what happens to
its index.

Function-based indexes require the query to use the same expression, which is the usual reason one
exists and is never used.

Bitmap indexes are for low-cardinality columns on tables that are not concurrently updated, and they
serialise DML at the block level. On a transactional table they are a finding, not a fix.

## Partitioning

Partitioning is a separately licensed option. **Check the licence before recommending it**, because
this is the one recommendation in this file that can create a compliance problem rather than a
technical one.

Where it is licensed, range partitioning on a time column with interval partitioning removes the
maintenance job that creates next month's partition, and that job's absence is a common cause of
failed inserts at a month boundary.

A local index is partitioned with its table and a global index is not. A global index goes unusable
when a partition is dropped unless the drop specifies `UPDATE INDEXES`, so a retention policy that
drops partitions and a global index are a combination to name.

## Checking what is actually there

`ALL_TABLES.NUM_ROWS` is only as current as the last statistics gathering, so it can be badly stale.
Where a finding turns on the number, count and say so.

`ALL_TAB_COLUMNS` for the type sweep, and `ALL_CONSTRAINTS` with `ALL_CONS_COLUMNS` for the keys.
Prefer the `ALL_` views over `USER_` when reviewing a schema you are not connected as.
