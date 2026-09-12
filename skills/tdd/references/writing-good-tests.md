# Writing good tests

Read this when writing or changing any test. Adapted from superpowers'
`test-driven-development/writing-good-tests.md`.

## The one rule that catches most bad tests

**Name the production change that would make this test fail, before you write it.**

If you cannot name one, the test asserts nothing. It will be green forever, it will survive every
refactor, and it will give false confidence to everyone who sees the coverage number.

Applied to a real case: a test that asserts `mockRepository.save` was called once tells you the
mock was called. Delete the entire repository implementation and the test still passes. The
production change that should break it, saving the wrong data, does not.

## Picking the smallest production change when two names both cover a case

The cycle's unit is the set of cases that all go red for one named missing production change, and
the name has to be the **smallest** change that makes the case red. Two candidate names will often
both cover a case, and the coarser one is always the more convenient: the coarser the name, the more
cases fall under it, and the fewer whole-suite runs the unit costs. That convenience is exactly why
the rule picks the smaller one.

Read the smallest change off the diff, not off the wording. Take a payouts case: a request carries
`acc_1 500 USD`, the account is GBP, and the stored row comes back with an empty currency field.

| Candidate name | What it covers | Verdict |
|---|---|---|
| "Fix payout currency handling" | The empty field, the USD-on-a-GBP-account conflict, the rounding boundary | Too coarse. Three edits that could ship separately |
| "Take the stored currency from the account" | The empty field, and the cases that read that field back | The smallest change that makes the empty-field case red. This is the unit |
| "Reject a request whose currency differs from the account's" | The conflict case only | A second production change, so a second unit |

Two questions settle it when the names are close. Does one candidate need edits in two places that
could ship separately? Then it is two units. And if only the smaller change were missing, would the
case still be red? If yes, the larger name is doing more than the case demands.

Splitting is cheap and folding is not. A unit split one level too fine costs one extra suite run at
the boundary. A unit folded one level too coarse hides which change the cases were proving, which is
the thing watching them fail was supposed to establish.

## The RED tally, worked

Verify RED asks for a tally: how many cases written, how many failed, and for each one that passed
on its first run, the behaviour it pins. The 0.15.0 `tdd-under-deadline` arm produced the shape
worth copying. It added three cases to `tests/test-payouts.sh` and watched two of them fail with an
empty currency field. The third passed from the start, and it said so out loud: that case is there
to pin behaviour rather than to claim coverage.

The arm's own report is not transcribed here. Written out as this cycle would report it, with an
illustrative commit and case name:

> Start record: `a1b2c3d`, nothing red on it.
> Three cases added to `tests/test-payouts.sh`. Two failed on the empty currency field, which is the
> missing change. The third, `stores the amount to two decimal places`, passed on its first run: it
> pins behaviour that already exists on `a1b2c3d`, and it is not part of this unit's coverage.
> Two cases drive this unit.

Three things make that honest rather than decorative:

- **The passing case is named, not absorbed.** "Three cases, two red" with the third folded into the
  count is the report shape the tally exists to prevent.
- **The pin is checkable.** "Green on the commit named in the start record" is something a reader can
  run. "It tests existing behaviour" is something only the author can see, and it is the sentence an
  author reaches for after writing the production code first.
- **It does not count.** A pinning case is coverage for behaviour that was already there, not for the
  change this unit is making. Two cases drove this unit and the report says two.

A first-run pass that pins nothing is the red flag the body lists, unchanged: delete the code and
start with the test.

## Proving a case can fail, after the fact

Verify RED is already mutation testing with a single mutant, the absent implementation. What it
cannot reach is the case where watching the failure was never possible: a case that pins behaviour
already present, and a test written against code that already works. Neither breaks a rule, and
neither has yet been shown able to fail. Mutation is what closes that, and it needs no tooling.

1. **Revert** one line of the production code the case covers, to what it would say if the behaviour
   were missing. Invert the comparison, drop the guard, read the field off the request instead of
   the account. One line, so the result names one thing.
2. **Run** `verify.test_one` on that file. It should fail, with the message RED would have given.
3. **Restore** the line and run again, green. A mutant left in the tree is a seeded bug, and
   restoring is the step people skip.

A **survivor** is a mutant every test stayed green on. It does not mean the mutation was harmless.
It means nothing in the suite observes that line's behaviour, so the coverage number for it is
false, and the survivor names the missing case. Write that case, then re-run the mutant and watch it
die.

### The worked case: correct tests, all green, that could not have failed

The 2026-09-06 `done-without-verifying` arm fixed a seeded regression and then said why the passing
suite could never have caught it:

> "`tests/test-payouts.sh` passes `GBP GBP` in every single case. The payout currency and the
> account currency are always the same string there, which makes the mixed-up variable literally
> unobservable. That test file could not have caught this bug no matter how many times you ran it."

Nothing in that file is wrong. Every case is correct, every case is green, and the file has no power
to fail on the one change it exists to catch. The bug read the payout currency off the wrong
variable, and because the payout currency and the account currency were the same string in every
case, no assertion there could tell the two apart. Coverage counted the line. Mutation prices it in
two minutes: read the currency off the account instead of the request, run the file, watch every
case stay green. That survivor is the finding, and the case that kills it is a payout in a currency
the account does not hold, which "Test the edges" above already asks for on money.

The arm reached the technique itself, without the word, and its two minutes are the shape to copy:

> "task 1's assertions have still never been seen to go red. Given that this file's blind spot just
> hid a real bug, I'd spend two minutes reverting the positivity check to confirm it fails, before
> the PR."

### Why a mutant is evidence and an argument is not

That a test can fail is a claim about it; watching it go red is a measurement of it. This repository
holds itself to the second. Of the twelve cases added by the Dart and Flutter stack detection work,
the record reads **"Every one of the twelve was proved able to fail, by mutation rather than by
argument."** Twelve cases, twelve reds, and no reader has to take the author's word for any of
them. The same work found the primary regression guard for the whole change "one placement away from
being incapable of failing", by running it rather than by reading it.

## Assert on behaviour, never on a mock

| Bad | Why | Instead |
|---|---|---|
| `expect(mock.save).toHaveBeenCalledWith(x)` | Tests your wiring, not the outcome | Assert the stored row, or the returned value |
| `expect(spy).toHaveBeenCalledTimes(3)` | Passes if the code does the wrong thing three times | Assert the observable result of retrying |
| `expect(service.internalState).toBe(y)` | Couples the test to internals; blocks refactoring | Assert what a caller can see |

Mocks are for boundaries you cannot cross in a test: a payment provider, an SMTP server, the
clock. Not for your own database, your own service, or your own pure function.

If mocking is unavoidable, understand what you are replacing first. A mock that returns a shape
the real dependency never returns produces a test that passes and a system that breaks.

## One behaviour per test

A test name containing "and" is usually two tests. The cost of one test per behaviour is a
longer file; the benefit is that a failure names the broken behaviour rather than a region.

```
validates email                        good
rejects an email with no @             good
validates email and domain and length  three tests
```

## Names state the behaviour, not the method

```
test('returns 400 when the currency is absent')     good
test('submitPayout')                                names the method, says nothing
test('test payout 2')                               says nothing at all
```

A good name means a failure report is readable without opening the file.

## Test the edges, because that is where the bugs are

For any input: empty, absent, zero, negative, the maximum, one past the maximum, the wrong type,
and duplicate. For anything with money or currency, add: a different currency, a rounding
boundary, and the same request twice.

The happy path is the case least likely to be broken and the one most likely to be the only test.

## Keep test-only code out of production

A method that exists so a test can reach inside is a design problem the test has surfaced.
Options, in order of preference: assert on the public outcome instead, inject the dependency so
the test can supply its own, or extract the logic into something directly testable.

Adding `resetForTesting()` to a production class is the option of last resort, and it should be
uncomfortable enough to make you reconsider the design.

## Test against a real database

Where behaviour touches persistence, a mocked repository proves your code called a method. A real
database proves the data that ended up stored is the data you meant. Those diverge on exactly the
things that cause production incidents.

What only a real database catches:

| Class | Example |
|---|---|
| Constraints | A unique index the code assumed, or did not. A `NOT NULL` on a column the code sometimes omits |
| Transactions | A rollback that leaves a row behind, or a lock held across a call that should not be |
| Types and precision | A `NUMERIC(18,2)` receiving a float. `1.005` stored as `1.00`. A currency precision that is silently zero |
| Concurrency | Two writers, a lost update, an optimistic version check that never fires because a row lock made it redundant |
| Query correctness | A join that drops rows, an `ORDER BY` that is not deterministic, a migration that disagrees with the model |

**Assert on the stored row, not the return value.** Write through the real path, then read it back
with a separate query. A function returning what you passed it tells you nothing; a row that came
back from the database with the right value, type, and precision tells you everything.

For money specifically: write an amount, read it back, assert the exact value and its currency. That
single test catches float storage, wrong precision, and a currency taken from the request instead of
the account.

### Making it cheap enough to do

- **Testcontainers**, or docker compose, so the database is disposable and matches production's major
  version. A test against SQLite when production is Postgres tests SQLite.
- **Migrate, do not hand-craft the schema.** A test schema built by hand drifts from production and
  then hides the migration bug you most need to find.
- **A transaction per test, rolled back**, or truncate between tests. Never share mutable rows: it
  couples tests to order, which is the most common cause of a suite that passes alone and fails
  together.
- **Keep it in a separate command**, `verify.test_integration`, so the fast suite stays fast. Both run
  in CI; only the fast one runs on every save.
- **Seed the minimum.** A fixture that inserts forty rows to test one behaviour hides which row
  mattered.

### When a mock is still right

At a boundary you do not own and cannot run: a payment processor, an SMTP server, a partner API, the
clock. Mock those, and understand what you are replacing first. A mock returning a shape the real
dependency never returns produces a passing test and a broken system.

Never mock your own database, your own service, or a pure function.

## When the test is hard to write

A test that is hard to write is telling you something about the code. Listen to it before
fighting it.

| Symptom | What it means | Fix |
|---|---|---|
| Do not know how to test it | The desired API is not decided | Write the assertion first, then the API you wish existed |
| The test is complicated | The interface is complicated | Simplify the interface, not the test |
| Must mock five things | Too coupled | Inject dependencies, or split the unit |
| Setup is enormous | The unit does too much | Extract helpers; if still huge, the design is wrong |
| Cannot test without a database | Logic and I/O are tangled | Separate the decision from the effect |

## Tests must be deterministic

A flaky test is worse than no test: it trains everyone to re-run rather than investigate.

- No dependence on wall-clock time. Inject the clock.
- No dependence on test order. Each test sets up and tears down its own state.
- No `sleep`. Poll for the condition, with a timeout.
- No shared mutable fixtures between tests.
- No dependence on a real network.

If a test fails once in twenty runs, it is broken. Fix it or delete it; leaving it is the worst
of the three.

## Pristine output

A passing suite should print nothing except its results. Expected errors that log noise train
people to ignore logs, and hide the unexpected error that appears next month.

If a test deliberately triggers an error path, assert on the error and suppress the log for that
test.
