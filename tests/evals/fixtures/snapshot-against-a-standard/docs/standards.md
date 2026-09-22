# Coding standards

| | |
|---|---|
| Derived from | 2 files under `src/`, at commit `DERIVED_SHA` |
| Date | 2026-03-01 |
| Enforced by | nothing. There is no lint command |
| Departures from the house defaults | see the last section |

## 1. Money is integer minor units

**Rule:** amounts are integer minor units everywhere. Never floating point, never a decimal string
in arithmetic.
**Why:** a half unit that survives a division becomes a reconciliation break a month later.
**Example, from this codebase:** `to_minor` and `add_minor` in `src/money.sh` take and return
integers.

## 2. One log function

**Rule:** one `log` function, structured, to stderr. No bare `echo` or `printf` to stderr from a
code path.
**Why:** a line assembled by hand cannot be queried, and a field you cannot query is a field you do
not have.
**Example, from this codebase:** `log` in `src/payouts.sh` emits one JSON object per line.

## 3. Failure paths return a named code

**Rule:** a failure path returns a distinct non-zero code. Never `exit` from a library function.
**Why:** a caller that cannot tell bad input from an unavailable dependency retries the wrong one.
**Example, from this codebase:** `submit_payout` returns 2 for a missing payee and 3 for a bad
amount.

## 4. Timestamps are epoch seconds in UTC

**Rule:** a timestamp is epoch seconds in UTC. Never a formatted local string, and never a
locale-dependent format.
**Why:** a receipt written in one timezone and read in another is off by hours, and `%d/%m` against
`%m/%d` is off by months.
**Example, from this codebase:** `record_time` in `src/payouts.sh` emits `date -u '+%s'`.

## 5. Inputs arrive as arguments

**Rule:** every function takes its inputs as positional arguments. No function reads a global.
**Why:** a function that reads a global cannot be tested without building the world around it.
**Example, from this codebase:** every function in `src/money.sh` takes what it needs.

## 6. Amounts are validated before use

**Rule:** a function that takes an amount from a caller outside `src/` validates it before use.
The helpers in `src/money.sh` are internal and are not entry points.
**Why:** an unvalidated amount reaches the ledger as a silent zero.
**Example, from this codebase:** `submit_payout` calls `valid_minor` and returns 3 on failure.

## Known inconsistencies

**Two status vocabularies.** `payout_status` accepts `submitted`, `settled` and `failed`, while the
upstream ledger file uses `pending` and `complete`. Do not fix piecemeal: the mapping belongs in one
place and nobody has decided where.

## Not yet mechanical

| # | Item | Owner skill |
|---|---|---|
| F-1 | Add a lint command and wire `verify.lint`, then ban floating point arithmetic in `src/` | `coding-standards` |
| F-2 | Give the two status vocabularies one mapping function | `refactor` |

## Departures from the house defaults

| # | Default | This project | Ruling |
|---|---|---|---|
| D-1 | A check-only lint command exists | none | **Close.** F-1 |
| D-2 | Errors propagate as exceptions | functions return distinct codes | **Keep.** Bash has no exceptions. Recorded in `docs/decisions/ADR-0001-error-codes-not-exceptions.md`. Verified: no function in `src/` calls `exit` |
| D-3 | Logs reach a collector | stderr only | **Keep, permanently.** This runs as a foreground command whose stderr the caller already captures. Needs an ADR recording that |
| D-4 | Runtime version pinned where developers see it | `.keel/profile.json` names `bash` | **Closed 2026-03-01.** No departure remains |
