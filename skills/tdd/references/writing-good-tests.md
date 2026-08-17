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
