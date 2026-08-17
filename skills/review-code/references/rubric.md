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
- A new endpoint with no rate limit, or a limiter doing a get-then-set against shared state, which
  enforces N times its configured rate across N instances.
- An upstream error message returned to a caller.
- A check that fails open where it should fail closed.
- A secret reaching a log, an artifact, or an image.

## 3. Tests

- Does a new behaviour have a test, and would that test fail if the behaviour were removed? Try
  to answer the second part concretely; it is the one that catches vacuous tests.
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
- A removal with no evidence that nobody is still calling it.

## 4c. Personal data, where the diff adds or moves any

- A new personal field with no stated purpose, no classification, and nothing that reads it.
- Personal data reaching a log, an error reporter, an analytics call, a fixture, or a seed script.
- A new store, index, or cache holding personal data that the deletion path does not know about.

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
