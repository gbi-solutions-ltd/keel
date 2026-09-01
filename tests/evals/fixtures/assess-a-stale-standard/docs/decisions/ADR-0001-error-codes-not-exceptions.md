# ADR-0001: Failure paths return distinct codes

| | |
|---|---|
| Status | accepted |
| Date | 2026-02-14 |
| Deciders | the payouts team |

## Context

Bash has no exception mechanism. A function that fails can signal it by returning a non-zero code,
by writing to stderr and returning 1, or by calling `exit` and taking the caller down with it.

## Decision

Every failure path in `src/` returns a distinct non-zero code. No function in `src/` calls `exit`.

## Consequences

A caller can tell a missing payee from an unusable amount without parsing a message. The cost is
that a caller who ignores `$?` sees nothing, which the test suite guards against by asserting the
code rather than the output.
