# 0001. Amounts are whole numbers

**Status:** accepted, 2026-06-02

## Context

Payouts are made in UGX and KES, and receipts showed `1500.00` for amounts that never have a
fractional part.

## Decision

Amounts are passed and stored as whole numbers. Formatting never adds decimals or rounds.

## Consequences

A currency with a fractional unit needs a new decision before it is supported.
