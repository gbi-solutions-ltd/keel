# Type selection

Section 4 of the review is a sweep: every table, every column. This file is what to look for and,
for each, what the wrong type actually costs. The cost is the part that gets a fix scheduled.

**Why the sweep needs a file at all.** The baseline that prompted this skill did excellent work on
the schema's headline defects and never came back for the types. It walked past a `VARCHAR(20)` date
of birth, a `VARCHAR(5)` boolean and an `INT` soft-delete flag. None of those is hard to spot. They
were missed because nothing required a pass over the columns, which is why section 4 requires one.

## Money

**Never binary floating point.** `FLOAT`, `REAL` and `DOUBLE PRECISION` are wrong for money, and the
reason to give is not that it is bad practice.

`SUM()` over floats is not associative, and a parallel aggregation may add the rows in a different
order on each run. So two runs of the same settlement report over the same unchanged rows can differ
in the last place, and a disputed figure cannot be reproduced. That is the sentence that gets it
fixed, because it turns a style point into an audit problem.

Use the engine's exact decimal type with an explicit precision and scale. State the scale: some
currencies are not two places, and a schema that assumes two has made a decision nobody recorded.

Storing minor units in an integer is also correct and is a different decision, not a lesser one. It
needs the unit written down somewhere the reader will find it, because an integer column called
`amount` is ambiguous in a way a decimal is not.

## Dates and times

A date in a string column cannot be compared, ordered, or validated. `date_of_birth VARCHAR(20)`
accepts `1990-13-45`, `unknown`, and an empty string, and every query against it is string
comparison that happens to work for one format.

For timestamps, the question the schema must answer is whether the value carries a time zone. A
naive timestamp is a correct choice when everything is one zone and that is recorded; it is a defect
when it is an accident. Say which one you found.

Ask what the column means before recommending a type. A "date" that is really "the day we consider
this settled in the reporting time zone" is not the same column as an instant.

## Booleans

`VARCHAR(5)` for a boolean admits `'true'`, `'TRUE'`, `'True'`, `'yes'`, `'y'`, `'1'` and `''`, and
every reader has to know which the writer used. `INT` admits every integer.

The cost is that the column has no single correct query. Once two writers disagree, the rows are not
comparable and nothing in the schema says so.

Where the engine has a boolean type, use it. Where it does not, use a constrained single character
or integer with a check constraint, and the check constraint is the part that matters.

## Soft deletes

`deleted INT` and `deleted VARCHAR` carry no deletion time and no actor. The flag answers "is this
row hidden" and nothing else, so the first question anyone asks of a deleted row, when and by whom,
is unanswerable.

A nullable `deleted_at` timestamp answers both the flag question and the time question in one
column, and is the usual smallest correct change. Where the actor matters, it is a second column,
not a wider first one.

Check what enforces the flag. A soft delete that only the application honours means every direct
query, every report and every export sees deleted rows.

## Integer width, and the one that bites

This is the type question that becomes an outage, and it is only visible when the type is read
together with a row count.

A 32 bit signed key stops at 2,147,483,647. At 1.5 billion rows and growing, that is months away,
and sooner than the row count suggests because every rolled-back insert burns a value that is never
reused. The baseline found exactly this, unprompted, and it is the shape section 7 exists to make
repeatable rather than lucky.

For every integer key: the type's ceiling, the current maximum value, and the growth rate. Where the
gap is small, give the stopgap and its condition as well as the real fix, because widening a key on
a large table is not a change anyone makes this week.

## Strings

An unbounded text column is not a defect on its own. It becomes one when it holds something with a
known shape, because then nothing rejects the malformed value, and when it holds something sensitive,
because unbounded columns are where copies accumulate unnoticed.

A card number beside an existing last-four column is the case to look for, and the finding is not
only the column: it is every other column that value has been copied into.

Where a string has a fixed vocabulary, say whether the schema constrains it. An unconstrained status
column is a set of values nobody can enumerate without querying production.

## What to write in the review

One row per finding: the table, the column, its current type, what it means, and the cost of the
mismatch in the terms above. Then the smallest correct change.

Where the sweep found nothing, `None found`, and only after every table has actually been read.
