# API contracts

Read this where an API has a consumer you cannot deploy: a partner, a mobile app in the field, or
another team's service. The distinguishing fact is that you cannot fix the caller, so a change that
would be trivial internally is permanent here.

An internal API between two services you deploy together needs almost none of this. Say which kind
you are building, because applying partner rules to an internal endpoint is how a small change
acquires a versioning discussion.

## What counts as a breaking change

**The rule: anything a reasonable existing caller could be relying on.**

The list is not intuitive, which is why it is written out. Additive is not automatically safe.

| Breaking | Not breaking |
|---|---|
| Removing or renaming a field | Adding an optional request field |
| Changing a type, including `"100"` to `100` | Adding a response field, if callers ignore unknown fields |
| Making an optional request field required | Adding a new endpoint |
| Adding a value to an enum a caller switches on | Adding a value to an enum documented as open, where callers were told to handle unknown |
| Narrowing what you accept | Widening what you accept |
| Changing an error code, or the status for a case | Adding a new error code for a genuinely new case |
| Changing default behaviour when a field is absent | Adding a new optional behaviour behind a new field |
| Tightening a rate limit | Raising one |

Two rows deserve their reason. **Adding an enum value breaks callers** who wrote an exhaustive switch,
which is most of them, so an enum is either documented as closed and versioned when it changes, or
documented as open with a stated fallback, and that decision belongs in the contract from day one.
**Changing a type from string to number breaks weakly typed callers silently**, which is worse than
loudly.

For anything moving money, treat a semantic change as breaking even when the shape is identical.
Changing whether an amount includes fees is a breaking change with no schema difference at all.

## Versioning

**The rule: version at the URL path (`/v1/payouts`), and add a version only for a genuinely breaking
change.**

Path versioning over header or query versioning, for one practical reason: it is visible in logs,
routing, and a support conversation. Elegance loses to being able to ask a partner which URL they are
calling.

- **Additive changes do not get a version.** A new version for every change gives you six live
  versions and a matrix nobody can test.
- **Version the API, not each resource.** Per-resource versions produce combinations that were never
  tested together.
- **Two supported versions at once, at most**, unless a contract says otherwise. Each one is a code
  path that has to keep working, and the second one is where the untested behaviour lives.

## Deprecation is a process with dates, not a note in the docs

**The rule: nothing is removed until every caller has been told, given a date, and observed to have
moved.**

1. **Announce**, in writing, with a removal date. For a partner, in the contract channel, not a
   changelog nobody subscribes to.
2. **Signal in the response.** `Deprecation` and `Sunset` headers, plus a log line whenever the
   deprecated path is used.
3. **Measure who is still calling it**, by caller. This is the step that gets skipped, and it is the
   only one that tells you whether removal is safe. If you cannot answer "which partners called this
   last week", you cannot deprecate anything.
4. **Remove only when the count is zero**, or after a deliberate decision to break a named caller who
   was warned.

A deprecation with no measurement is a plan to cause an incident on a date you chose in advance.

## Errors are part of the contract

**The rule: a stable machine-readable code, a human-readable message, and a correlation id. The code
never changes meaning.**

```json
{
  "error": {
    "code": "insufficient_funds",
    "message": "The source account does not have enough available balance.",
    "request_id": "req_8f3a2c",
    "details": { "available": 4200, "required": 5000, "currency": "KES" }
  }
}
```

- **Callers branch on `code`, never on `message`.** So the message may be improved freely and the code
  may not. Say this in the documentation, or partners will parse the prose.
- **Enumerate the codes** in one place, and treat that list as the contract it is.
- **Return a correlation id on every error**, and log it. It converts a support thread from "it failed
  yesterday" into one lookup.
- **Never return an upstream error message**, per `house-defaults.md`. It leaks topology and it makes a
  partner's internal error code part of your contract by accident.
- **Use the status code honestly.** 4xx is the caller's problem and will fail identically on retry;
  5xx is yours and may succeed on retry. Returning 200 with an error body, or 500 for a validation
  failure, breaks every client's retry logic. See `resilience.md`.
- **Validation errors name the field**, all of them at once. Returning the first failure only means a
  caller with five bad fields makes five round trips.

## Pagination, filtering and limits

- **Every collection endpoint is paginated from the first version.** Adding pagination later is
  breaking, and an unpaginated endpoint is a denial of service with a query string once the data
  grows.
- **Prefer cursor pagination** for anything that changes while being read. Offset pagination over a
  table receiving inserts skips and repeats rows, which in a transaction list is a support ticket
  claiming money is missing.
- **Cap the page size server side** and document the cap. A caller asking for 100,000 rows gets the
  maximum, not an outage.
- **Bound everything else a caller controls**: request body size, array lengths, string lengths,
  filter combinations, and date range width on a report.

## Idempotency and long-running work

- **Every state-changing partner-facing endpoint accepts an idempotency key**, per `house-defaults.md`,
  and documents how long keys are retained.
- **A retried key returns the original response**, not a conflict, and not a second execution.
- **Work that can exceed a few seconds returns a reference immediately** and is polled or reported by
  webhook. Holding a partner's connection open for a minute means their timeout decides your
  transaction's outcome.

## Webhooks are an API you provide, with the same rules reversed

- **Sign the payload**, and the signature covers the exact bytes sent. See `security-audit`.
- **Include a timestamp in the signed payload and reject old ones**, or a captured delivery can be
  replayed.
- **You are at-least-once too.** Say so in the documentation and give every delivery an id so
  receivers can deduplicate. Everything in `async-work.md` about consumers applies to your receivers.
- **Retry with backoff and give up visibly**, with a way for the receiver to fetch what they missed.
  A webhook with no catch-up endpoint makes their outage into your support load.

## Documented, and the documentation is generated

**The rule: the schema is generated from the code, or the code is generated from the schema. Never
maintained alongside it.**

Hand-written API documentation is wrong within two releases, and a partner integrating against wrong
documentation costs more than having none, because they trust it. Generate an OpenAPI or equivalent
document in CI and fail the build when it changes without the change being intended, which also makes
every breaking change visible in a diff.

## Testing it

- **A contract test per consumer** where the consumer is internal, run in both pipelines.
- A schema diff in CI that fails on a breaking change unless the version moved.
- The idempotency test: the same key twice returns the same response and executes once.
- Cursor pagination over a collection receiving inserts returns every row exactly once.
- Every documented error code is reachable by a test, or it is not real.
- The deprecated path still works, and emits its header.

## What review looks for

- A field removed, renamed, or retyped in a partner-facing response.
- A new enum value with no statement about how callers handle unknown values.
- An error message changed where a caller might be parsing it, or a code reused for a new meaning.
- A collection endpoint with no pagination, or a page size a caller controls without a cap.
- 200 with an error body, or 5xx for a caller's mistake.
- A new state-changing endpoint with no idempotency key.
- Hand-maintained API documentation next to the code it describes.
- A removal with no evidence that nobody is still calling it.
