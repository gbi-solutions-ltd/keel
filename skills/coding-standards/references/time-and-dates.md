# Time and dates

Read this on any project. It is short, and the defect rate per line of code it governs is the highest
of any file here, because time looks simple and every language's default handling of it is wrong in a
way that only shows up in another timezone, on one day a year, or at a month boundary.

The money rules in `house-defaults.md` have an exact twin here. "Never a float for an amount" is the
same kind of rule as "never a local time in storage": both are about a representation that is
approximately right, drifts, and produces a discrepancy nobody can explain later.

## Store UTC, with an offset-aware type

**The rule: every timestamp is stored in UTC, in a type that carries the offset. Convert at the edge,
never in the middle.**

*Why:* a local time without an offset is ambiguous twice a year and unorderable across regions. The
hour that repeats at the end of daylight saving contains two distinct instants that store identically,
so two transactions an hour apart can compare as equal or in the wrong order.

Concretely:

- **Postgres:** `timestamptz`, never `timestamp`. The name is misleading, `timestamptz` does not store
  a zone, it normalises to UTC and returns in the session zone, which is what you want.
- **MySQL:** `DATETIME` stores no zone. Either use `TIMESTAMP` and understand its range limit, or
  store `DATETIME` with the server pinned to UTC and say so.
- **Application:** an instant type (`Instant`, `OffsetDateTime`, `datetime` with `tzinfo`), never a
  naive one. Ban the naive constructors in the linter if the language has them.
- **Wire format:** RFC 3339 with an explicit offset, `2026-08-13T14:02:11Z`. Never a bare local
  string, never epoch seconds where a human will read it, never a locale-formatted date.

**Set the process timezone to UTC everywhere**, including developer machines and containers, so
"works locally" is not a function of where the developer sits.

## A date is not a timestamp

**The rule: where the business means a day, store a date, not a timestamp.**

A value date, a settlement date, a date of birth, and an invoice date are days, not instants. Storing
a date as midnight-in-some-zone means the day changes when the zone changes, so a customer's birthday
moves and a settlement lands in the wrong reporting period.

The reverse also holds: a thing that happened happened at an instant. Do not store it as a date and
lose the ordering.

## Business time is not wall clock time

The payments-specific section, and the one that produces disputes rather than bugs.

- **A cutoff has a timezone, and it is the business's, not the server's.** "Settlement cutoff 16:00"
  is meaningless without the zone. Store the zone with the rule, and evaluate it by converting the
  instant into that zone. Never by adding an offset, which is wrong for half the year.
- **Business days are a calendar, not arithmetic.** "T+2" is not "add 48 hours", and it is not "add 2
  weekdays" either, because public holidays differ per market and change per year. Holidays are data,
  loaded and versioned, never a constant in code.
- **Say which instant a day boundary belongs to.** A transaction at 23:59:59 local on the last day of
  the month belongs to that month's reconciliation in the business's zone and possibly the next
  month's in UTC. Pick one, write it down, and make the report and the ledger agree.
- **An expiry is an instant, and inclusive or exclusive is a decision.** "Valid until the 31st" has
  cost real money in both directions. State it in the code, at the comparison.

## Durations and elapsed time use a monotonic clock

**The rule: measure elapsed time with a monotonic clock, never by subtracting wall clock readings.**

*Why:* the wall clock moves. NTP steps it, a leap second smears it, a VM resumes with it wrong, and a
daylight saving transition shifts it by an hour. A timeout measured across a backward step waits
forever; one measured across a forward step fires immediately. Every language has a monotonic source
(`monotonic()`, `nanoTime()`, `Instant.now()` is **not** it), and using the wrong one produces a bug
that reproduces roughly twice a year.

Store durations as a number with a unit in the name, `timeout_ms`, `ttl_seconds`. A bare integer
called `timeout` is read as seconds by the next person and it was milliseconds.

## Arithmetic that looks right and is not

- **Adding 24 hours is not adding a day.** On a daylight saving boundary it is 23 or 25. Use the
  calendar-aware addition your language provides, on a zoned type, when you mean a day.
- **Adding a month is lossy.** 31 January plus one month is a decision, not a fact. Whatever the
  library does, state which rule you are relying on where it matters, such as a subscription renewal.
- **Never compare a formatted string.** Compare instants. String comparison happens to work for RFC
  3339 in UTC and stops working the moment an offset varies.
- **Clock skew between machines is real.** Never derive ordering from timestamps taken on two
  different hosts. Use a sequence, a version, or the database's own clock.

## Time is an input, not an ambient fact

**The rule: production code reads the time through an injected clock, never a static call.**

*Why:* code calling `now()` directly can only be tested by sleeping or by waiting for the calendar,
so the cutoff logic, the expiry logic, and the retention logic are the parts that never get tested.
Every rule in this file is testable only if the clock can be moved.

This is the same rule as the injected clock in `rate-limiting.md` and `caching.md`, and it is the one
that makes those testable too.

## Testing it

The cases below are cheap once the clock is injectable and impossible before:

- A daylight saving forward and backward transition in the business's zone, across a cutoff.
- The ambiguous repeated hour: two events an hour apart still order correctly.
- A cutoff evaluated from a machine whose zone is not the business's.
- Month and year boundaries, including 29 February and 31 January plus a month.
- A backward wall clock step during a timeout, which must not extend it.
- A date-only field round-tripped through the API and the database without shifting a day.

## What review looks for

- A naive datetime, a `timestamp` without time zone column, or a date stored as a string.
- `now()` called inside business logic rather than passed in.
- Elapsed time computed by subtracting two wall clock readings.
- A cutoff, expiry, or business-day rule with no zone attached.
- Holidays or business days computed arithmetically, or hardcoded.
- A duration field whose name does not carry its unit.
- A date rendered for a user in the server's zone rather than theirs.
- Any ordering derived from timestamps produced by two different machines.
