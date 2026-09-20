# Review rubric

Work down in order. Stop escalating severity once you find something blocking; finish the pass,
but the blocker is the headline.

## 1. Correctness

- Does it do what the plan said? Compare against the task, not against your idea of the feature.
- Off-by-one, boundary, and empty-collection cases.
- `null` and `undefined` paths, especially where the type system is not strict.
- Error paths: what does a caller see when each dependency fails?
- Concurrency: two callers at once, a retry arriving after a timeout, the same request twice.
- For anything with money: currency source, rounding direction, idempotency, and whether a
  balance stays reconcilable.
- If the change writes data that is cached anywhere, does the same commit invalidate it? An
  invalidation deferred to a follow-up is one that covers only the write path someone remembered.
- If the change adds a cache, does it state the staleness it is accepting, and does its key carry
  everything that changes the value?
- A cache under load from many concurrent requests for the same key: does it use single flight,
  serve-stale-while-revalidating, or probabilistic early refresh, or does every concurrent miss hit
  the source at once? See `caching.md`, "Stampede."
- A cache with no TTL, or one whose TTL is set in a different file from the code that reads it, or
  a new cache with no hit-rate metric. See `caching.md`, "Never without a TTL" and "Measure it, or
  it is not a cache, it is a memory leak."
- A cache added in place of an index or in place of fixing an N+1, or a cache delete inside a
  transaction. See `caching.md`, "Database query caching."
- **Any new outbound call: is there a timeout?** Read the client construction, not the call site.
  This is the highest-yield single question in a review of a service, and the answer is no more often
  than anyone expects.
- A retry: bounded, jittered, only on retryable failures, and not stacked on top of another layer's
  retry. A retried write carries an idempotency key or it is not retryable.
- On a partner or dependency timeout, is the transaction left in an explicit pending state rather
  than marked failed or succeeded? A timeout means unknown, and unknown is a state.
- Async: is anything published inside a transaction, or committed with the publish unrecorded? Is
  the consumer idempotent, given that delivery is at least once? Is there a dead letter path?
- Time: a timestamp stored without a zone, a duration measured from wall clock readings, or `now()`
  read inside the logic rather than passed in.
- Time, the other half: a cutoff, expiry, or business-day rule with no zone attached; holidays or
  business days computed arithmetically or hardcoded; a duration field whose name does not carry
  its unit; an ordering derived from timestamps produced by two different machines. See
  `time-and-dates.md`, "A date is not a timestamp", "Business time is not wall clock time", and
  "Arithmetic that looks right and is not."

## 2. Security

Not a full audit; `security-audit` does that. This pass catches what a reviewer should never let
through:

- A credential, key, or token in the diff, including in a test fixture or a comment.
- String-concatenated SQL, shell, or path.
- User input reaching a filesystem path, a template, or a deserialiser without validation.
- An authorisation check that is opt-in per route rather than enforced by default.
- A permission check with no object check: the route is annotated correctly and then loads a record
  by an id straight from the path. Ask what stops another tenant's id.
- A branch on a role name rather than a permission, or a tenant id read from the request rather
  than the session.
- A cache key that omits the principal or the tenant on a value that varies by either. This one
  serves one customer's data to another, so it is blocking on sight.
- A cached permission set: is it invalidated when a role changes, or left to expire on its own
  TTL? See `authorisation.md`, "Revocation."
- A money-movement approval path: can one principal hold both the initiating and approving
  permission, with no check comparing the two actors? See `authorisation.md`, "Money, and
  separation of duties."
- A permission string that appears nowhere in the central enumeration, or 403 for an existing
  object and 404 for an absent one on the same endpoint, which tells a caller what exists. See
  `authorisation.md`, "Check permissions, never roles" and "Object-level checks, which is the one
  everybody misses."
- Authorisation logic in frontend code with no server-side counterpart. See `authorisation.md`,
  "Server-side only, and log the decisions."
- A new endpoint with no rate limit, or a limiter doing a get-then-set against shared state, which
  enforces N times its configured rate across N instances.
- A limiter keyed on something the caller controls (a header, a query parameter, the leftmost
  `X-Forwarded-For` entry), or no limit at all on login, password reset, token issue, or anything
  that sends an email or an SMS. See `rate-limiting.md`, "The key is the identity, and it must not
  be spoofable" and "Layer the limits, because one number cannot express the requirement."
- A rejection that is not a 429, a 429 with no `Retry-After`, or an in-process limiter documented
  as a service-wide one. See `rate-limiting.md`, "What the caller gets back" and "The check must be
  atomic, or the limit is per-instance."
- An upstream error message returned to a caller.
- A check that fails open where it should fail closed.
- A secret reaching a log, an artifact, or an image.
- Certificate verification disabled anywhere, in any environment, or an encryption key in the
  repository or an environment variable with no rotation path. See `data-protection.md`,
  "Encryption, and being clear which threat each one stops."

## 3. Tests

- Does a new behaviour have a test, and would that test fail if the behaviour were removed?
- **On a diff that adds tests: how many of the added cases have been proved able to fail, and by
  what?** A case watched going red in RED is proved. A case that could not be watched, one pinning
  behaviour that already existed or one written against code that already worked, is proved only
  once someone reverted the line it covers and saw it go red. Ask for the count and for what
  produced it. "They all pass" is the answer this question exists to catch.
- **A suite that cannot fail is a finding, and it outranks a missing case.** Read what the added
  cases hold constant. Where every case passes the same value on both sides of the distinction the
  change turns on, `GBP GBP` where the bug is a payout currency read from the wrong variable, every
  case is correct, every case is green, and none of them could have caught it. `verify.test` is
  already running from step 3, so this costs two minutes: revert the line, run the file, restore it.
  A green run is the finding, and the fix is the case that would kill it. The recipe and the worked
  example are in
  [../../tdd/references/writing-good-tests.md](../../tdd/references/writing-good-tests.md).
- Does the test assert on observable behaviour, or on a mock having been called?
- Was it written first? Check commit order, not the author's word.
- Is the failure path tested, or only the happy path?
- Does the suite still pass? Run `verify.test`; do not take the diff's word for it.

## 4. Standards

Check against `<docs_root>/standards.md` only. Do not import preferences that project has not
adopted, and do not raise anything the linter already covers: if a formatting issue reached
review, the tooling is the defect.

## 4b. Contracts, where the caller cannot be redeployed

Only where the diff touches a partner-facing or public API, a webhook payload, or a shared schema.
The distinguishing test is whether you could fix every caller yourself; if not, this pass applies.

- A field removed, renamed, or retyped. A new value in an enum a caller might switch on. An optional
  request field made required. All of these are breaking even though nothing errors at build time.
- A semantic change with no shape change, which is the one that gets through review. Whether an
  amount now includes fees is a breaking change with an identical schema.
- An error code reused for a new meaning, or a message changed where a caller might be parsing it.
- A new collection endpoint with no pagination and no server-side page cap.
- A new state-changing endpoint with no idempotency key.
- A 200 carrying an error body, or a 5xx for a caller's mistake. See `api-contracts.md`, "Errors
  are part of the contract."
- A new version added for an additive change, or a third supported version live at once. See
  `api-contracts.md`, "Versioning."
- A deprecation with no removal date, no `Deprecation` and `Sunset` headers, or no per-caller
  measurement of who still calls it. See `api-contracts.md`, "Deprecation is a process with dates,
  not a note in the docs."
- A webhook this service sends with an unsigned payload, no timestamp inside the signed bytes, no
  delivery id, or no way for a receiver to fetch what it missed. See `api-contracts.md`, "Webhooks
  are an API you provide, with the same rules reversed."
- A removal with no evidence that nobody is still calling it.

## 4c. Personal data, where the diff adds or moves any

- A new personal field with no stated purpose, no classification, and nothing that reads it.
- Personal data reaching a log, an error reporter, an analytics call, a fixture, or a seed script.
- A new store, index, or cache holding personal data that the deletion path does not know about.
- A retention period documented with nothing scheduled to enforce it. See `data-protection.md`,
  "Retention is a schedule that runs, not a policy document."
- A support or admin endpoint that exports in bulk under the same permission as a single lookup,
  or an access to sensitive records that is not logged. See `data-protection.md`, "Access to
  personal data is authorisation, and it is logged."
- A new store holding personal data that the subject export path does not know about; the bullet
  above covers deletion, this one covers the other half. See `data-protection.md`, "Subject rights,
  built once rather than by hand each time."
- A new managed service or third-party integration whose region nobody stated, or personal data
  reaching a new processor with no entry in the processor list. See `data-protection.md`, "Third
  parties and borders."

## 4d. Resilience and async work, where the diff touches a network call, a queue, a worker, or a scheduled job

Section 1 already covers timeouts, retries, the partner-timeout pending state, and the dead letter
path. This section catches what section 1 does not; both reference files are in
`skills/coding-standards/references/`.

- A dependency behind a circuit breaker: does it have all three states, closed, open, and half
  open, and is half open bounded to a small number of trial calls rather than reopening to full
  traffic? See `resilience.md`, "Circuit breakers."
- A `catch` around a network call that returns a default value: a fallback nobody decided on and
  nothing will alert about. See `resilience.md`, "Circuit breakers", the paragraph "Say what
  happens when it is open."
- A slow or failing dependency: is it isolated to its own connection pool or concurrency limit, or
  does it share one with an unrelated dependency? See `resilience.md`, "Isolate."
- A liveness probe that touches a dependency, or a readiness check with no timeout of its own. See
  `resilience.md`, "Health checks that mean something."
- A message consumer's idempotency: is it a database constraint or natural idempotency, or a
  check-then-act across two statements, which races with itself under concurrent delivery? See
  `async-work.md`, "Every consumer is idempotent."
- A consumer `catch` that acknowledges the message, an unbounded consumer retry, or a dead letter
  queue with no alert on its depth and age. See `async-work.md`, "Failure handling: retries, then
  a dead letter queue, never a silent drop."
- Order assumed across partitions or queues. See `async-work.md`, "Ordering, which you probably do
  not have."
- An HTTP call inside a database transaction. See `async-work.md`, "Transaction boundaries, since
  this is where they matter most."
- A scheduled job on a service that can run more than one instance: does it take a lease with an
  expiry, or can two instances run it at once? See `async-work.md`, "Scheduled jobs."
- A new message schema: does it carry trace context, so a job's trace joins the request that
  caused it? See `async-work.md`, "Observability."

## 5. Reuse and simplification

- Is there an existing helper for this? A second implementation of the same thing is worse than
  either alone.
- Is the abstraction earning its place, or is it one use dressed as three?
- Could this be meaningfully shorter? Not golfed, but is there a simpler shape?
- Dead code the change orphaned. The author removes what their change made unused, and nothing
  else.

## 6. Altitude

Is the change at the right layer? A guard added at a leaf where the value should have been
validated at the boundary works today and needs repeating at the next leaf. See
`keel:debug` on fix sites; the same reasoning applies to review.

## 7. Scope

- Every changed line traces to the request. Adjacent improvements are their own change.
- Reformatting mixed with logic makes both unreviewable. Ask for a split.
- Is anything here that no task asked for?

## 8. Documentation

Applies wherever the diff changes behaviour, or touches a document at all.

- Was every document the change made wrong updated in the same commit? A README quickstart, a
  runbook step, an API reference, a diagram, a table of environment variables.
- Where a generator exists, is the output regenerated rather than hand-edited? OpenAPI from the
  framework's decorators, code docs from JSDoc or docstrings, release notes from Conventional
  Commits.
- Does the changed prose describe the current state? Review-history residue is a finding: past-tense
  narration of the work ("initially", "turned out", "was used briefly"), a sentence explaining why
  something is **not** the case, a rejected option described by what happened to it rather than by
  what it is, or any sentence that only makes sense to someone who saw the review. The fix is to
  rewrite the section from the code, not to amend the sentence that carried the wrong claim. See
  [../../write-docs/references/current-state-prose.md](../../write-docs/references/current-state-prose.md).
- A comment describing what the code used to do, next to code that no longer does it.

## Writing a finding

```markdown
**Blocking** `payout.service.ts:212` takes the currency from the request rather than the account.

A caller can submit a UGX payout against a KES account and the ledger will accept it. FR-07 and
the house money defaults both require the currency to come from the account.

Fix: read it from the account, and add the mismatch case to the test written in task 3.
```

Location, what is wrong, why it matters, what to do. A finding missing the "why" gets argued
with; one missing the "what to do" gets deferred.

## Saying it is fine

A review that finds nothing blocking says so first, then names what was checked:

```markdown
Nothing blocking. Ran the suite (83 passing). Checked: the diff against tasks 1 to 4 in the plan,
currency handling against FR-07, the new tests fail when the guard is removed, no credential in
the diff, and no contradiction with ADR-0003.

Two considers below, neither worth holding the merge for.
```

Naming what you checked is what makes an approval worth anything. "Looks good" is indistinguishable
from not having read it.
