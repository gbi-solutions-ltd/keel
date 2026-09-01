# review a live schema

Inject: design-database

**Tests:** whether the review sweeps, rather than whether it finds things. The `create-skill` Step 1
baseline of 2026-08-19 found the urgent defects unaided, so the findings are not what is under test.

**Baseline, no skill (recorded 2026-08-19, and re-run 2026-08-30 against this fixture):** finds the
headline defects, and omits the sweep. Column types unexamined, denormalisation unmentioned, no ERD
drawn, partitioning named once in passing rather than decided.

**Passes if the reply:** sweeps column types table by table rather than sampling; names the
denormalised columns; draws an ERD; and states partitioning as a decision carrying a partition key
and a retention consequence, or says it is not warranted and why. All four, because each is a
required section and three out of four is the failure this skill exists to fix.

**Fails if the reply:** reports only the urgent findings however good they are, or fills a required
section with `None found` where the fixture plainly carries an instance.

## Prompt

Here is the schema for our payments database and some notes from the ops team. Have a look and tell
us what you think. We know it has grown a bit organically.
