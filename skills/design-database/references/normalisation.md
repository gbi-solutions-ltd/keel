# Normalisation

Section 5 of the review. The forms, stated as questions a reviewer answers per table, and the test
that separates deliberate denormalisation from duplication nobody decided on.

**Why this is a required section.** Normalisation is asked for and then not done. A child table
carrying a copy of a column that already exists on its parent is not subtle, and reviews go past it
anyway, because nothing made them answer the question table by table. This section is what asks.

## The questions, per table

Work through them in order. Each is answerable from the schema plus what the columns mean.

**Is there a key?** Every non-key column must depend on something. A table with no primary key has no
key to depend on, so the later questions cannot be asked, and that is the finding.

**Does every column depend on the whole key?** With a composite key, a column that depends on only
part of it belongs in a smaller table. The symptom is a value that repeats identically across every
row sharing one half of the key.

**Does any column depend on another non-key column?** A city that follows from a postcode, a rate
that follows from a currency, a name that follows from an id. The symptom is two columns that always
change together and never independently.

**Does any column hold more than one value?** A comma-separated list, a JSON array standing in for a
child table, a `phone1`, `phone2`, `phone3` run. Each is a table that was not created.

## The duplicated column, which is the common one

A column that also exists on a parent, reached through a foreign key, is the case that appears in
almost every schema of any age: `merchant_name` on the transaction as well as on the merchant,
`customer_email` on the transaction as well as on the customer.

**It is not automatically a defect.** It is one of three things, and the review must say which.

| It is | What makes it that | What to do |
|---|---|---|
| A deliberate copy, kept in step | A recorded decision, and a mechanism: a trigger, a job, or a write path that updates both | Leave it. Note the mechanism, so the next reader does not undo it |
| A deliberate snapshot | The column is meant to record the value **as it was**, not as it is now | Leave it, and say so. The name usually lies: `merchant_name` should be `merchant_name_at_capture` |
| Duplication | Neither of the above. Nobody decided; it accumulated | A finding. The parent already holds the truth |

**The snapshot case is the one to get right**, and getting it wrong in either direction is expensive.
An invoice that must show the address as it was on the day is not denormalised, it is correct, and
"fixing" it silently changes historical documents. Equally, a column that everyone assumes is a
snapshot but which some write path updates gives two answers to the same question.

The test is not the shape. It is whether anything keeps the copies in step, and whether anyone meant
them not to be.

## When denormalisation is the right answer

For a read path that is measurably too slow, and only after the normalised form has been measured.
That measurement belongs to `optimize-performance`, not here. What belongs here is the record: which
columns are copies, what keeps them current, and what breaks if that mechanism fails.

A denormalised column with no recorded reason is indistinguishable from an accident a year later,
which is why the record is the requirement rather than the denormalisation itself.

## What to write in the review

Per table, the questions above that it fails, with the columns named. For each duplicated column,
which of the three it is and the evidence that makes it that.

Where nothing was found, `None found`, after every table has been read rather than after the obvious
ones have.
