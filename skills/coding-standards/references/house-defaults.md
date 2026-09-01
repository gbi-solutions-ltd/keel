# House defaults

Conventions that apply across this organisation's repositories unless a project records a
deliberate departure.
A project that departs says so in its own `standards.md`, with a reason.

## The other references, and when each applies

Some topics are large enough, specific enough, and got wrong often enough to carry their own file.
This index lives here rather than in the skill body so that adding a tenth costs nothing in the
budget a skill body is held to.

Read the ones that apply and fold their rules into the project's `standards.md`. Do not read them
all: most projects need four or five.

| Reference | Read it when |
|---|---|
| [observability.md](observability.md) | Always. Logging, telemetry, traces |
| [time-and-dates.md](time-and-dates.md) | Always. Short, and the highest defect rate here |
| [resilience.md](resilience.md) | Anything is called over a network |
| [async-work.md](async-work.md) | There is a queue, a worker, or a scheduled job |
| [authorisation.md](authorisation.md) | There is more than one kind of user |
| [rate-limiting.md](rate-limiting.md) | The project exposes an API |
| [api-contracts.md](api-contracts.md) | It has a consumer you cannot deploy: a partner, an app in the field |
| [caching.md](caching.md) | Anything is cached, or somebody is proposing it |
| [data-protection.md](data-protection.md) | Personal data is stored anywhere |
| [frontend.md](frontend.md) | `profile.stack.has_ui` is true and `profile.stack.framework` is not `flutter` |

## Writing, in code and out of it

- **No em dashes, no en dashes, no dash longer than a hyphen.** Use commas, periods, or
  parentheses. Applies to UI strings, comments, commit messages, PR bodies, and docs. A hyphen for
  ranges and compound words is fine. *Why: it is house style, and consistency across everything
  we publish is the point of having one.*
- **Commit messages carry no attribution footers.** No `Co-Authored-By`, no robot emoji, no
  generated-with line. Title and body only. *Why: a commit message is for the reader who has to
  understand the change in two years. Tooling attribution tells them nothing and pushes the useful
  part further from the subject line.*
- **Conventional commits:** `type(scope): summary`, imperative, lower case after the colon.
  *Why: the type and scope make history greppable and let release notes be generated rather than
  written. Imperative mood matches what git itself produces.*
- **PR bodies end with content**, not tooling attribution. *Why: the last thing a reviewer reads
  should be the risk and the rollback, not a footer.*

## Documentation in code

- **Public API surface carries a doc comment**, in the language's own form: JSDoc or TSDoc, a
  docstring, godoc. What it does, any parameter whose meaning its name does not give, and what it
  returns or raises on failure. This one is mechanical, so wire it rather than write it down:
  `eslint-plugin-jsdoc`, ruff's `D` rules, `revive`'s exported rule. *Why: the reader is an IDE
  tooltip or an agent that grepped for the signature, and both see the declaration and nothing
  else. A caller who has to open the implementation to find out what an empty return means will
  guess instead.*
- **A comment says why, never what.** The code already states what it does, and the restatement is
  the half that goes stale. *Why: a comment that contradicts the code beneath it is worse than no
  comment, because the reader now has to work out which of the two is lying, and the usual answer
  is to trust neither.*
- **Logic that looks wrong names the constraint that made it right**, with a link to the ticket,
  spec, or provider document where one exists. *Why: the next reader's first instinct is to simplify
  it back, and the reason they must not is exactly what the code cannot show them. A retry ceiling of
  7 seconds with no note is indistinguishable from a number somebody typed.*
- **Delete commented-out code.** Git has it. *Why: nobody can tell whether it is a fix in progress, a
  rollback waiting to happen, or dead weight, so everybody leaves it alone and it never goes.*
- **A TODO carries an owner and a ticket**, or it is not a TODO and belongs either done or deleted.
  *Why: an unowned TODO is a decision nobody made, and it reads as sanctioned once it has sat there
  long enough.*

## Secrets

- **Never commit a credential, key, keystore, or certificate.** `.gitignore` covers `.env`,
  `*.pem`, `*.key`, `*.pfx`, `*.p12`, `*.jks` from the first commit, not after the first mistake.
  *Why: git keeps it forever. Deleting the file in a later commit leaves it in history, so the only
  real remedy is rotating the credential, which means coordinating with whoever issued it.*
- **Never bake a secret into a build artifact.** A container image or jar containing `.env` is
  readable by anyone who can pull it. Inject at runtime.
- **A credential with no default.** Configuration must fail startup when a credential is missing
  or empty, rather than falling back to a development value. *Why: a service that starts on a
  development default runs, passes its own health check, and is wrong. Failing at startup is
  discovered in seconds; failing at first use is discovered by a customer.*
- **Never log a token, signature, full request body, or personal identifier.** Redact at the
  serialisation boundary, not at each call site.

## Errors

- **Never return an upstream error message to a caller.** It leaks internal endpoints and
  topology. Map to a message you wrote.
- **Fail closed.** When a check cannot run (the cache is down, the policy service is unreachable),
  deny rather than allow. Where failing open is genuinely correct, that is an ADR, not a default.
  *Why: a control that fails open is a control an attacker can switch off by making its dependency
  unavailable. A rate limiter that allows everything when Redis is down is not a rate limiter.*
- **No silent catch.** Either handle it, or let it propagate. A swallowed exception is a bug with
  the evidence removed.

## Access control

Detail, including the test shapes, is in [authorisation.md](authorisation.md).

- **Deny by default.** A route with no declared policy is unreachable, not public, and the handful
  that really are open carry an explicit marker. *Why: with opt-in checks, a route somebody forgot
  looks exactly like a route that is deliberately open, so nothing can tell them apart except a human
  reading every route.*
- **Code checks permissions, never roles.** `can(user, "payout:approve")`, never
  `user.role == "admin"`. *Why: the role-to-permission mapping is data, so granting a role one more
  ability is one row. A role check scattered through the codebase makes it a change at every call
  site, found by grep, under time pressure.*
- **Every check names an object, not only an action.** Holding `payout:read` is not permission to
  read payout 4412. *Why: a permission check followed by a load by id from the URL is the most common
  serious access control defect there is, and it reads as correct because the annotation on the route
  is present and right.*
- **The tenant comes from the session, never from the request**, and the boundary is enforced at
  the data layer rather than in each query. *Why: a repository that cannot return another tenant's row
  is a control. A developer remembering a `WHERE` clause is a convention.*
- **Whoever initiates a value movement cannot approve it.** *Why: two permissions alone are not
  separation of duties. One principal holding both satisfies the model and defeats the control, so the
  check has to compare the two actors.*

## Limits

Detail is in [rate-limiting.md](rate-limiting.md).

- **Every public or partner-facing endpoint has a rate limit, and the default algorithm is a token
  bucket.** *Why: a fixed window permits twice its rate across the boundary between two windows, and a
  sliding log costs memory in proportion to the traffic it exists to survive. A token bucket states the
  sustained rate and the tolerable burst as two separate numbers, which is what the requirement
  actually is.*
- **The check is a single atomic operation against shared state.** *Why: a read-modify-write limiter
  behind a load balancer enforces roughly N times its configured rate with N instances, so the number
  in the runbook is wrong by a factor nobody has measured.*
- **Key on the authenticated principal, and on the account for anything that authenticates.** *Why:
  an IP key taken from a header is a key the caller chooses, and credential stuffing rotates IPs, so an
  IP-keyed login limiter does nothing about the attack it exists for.*
- **A rejection is a 429 carrying `Retry-After`.** *Why: a 200 with an error body is treated as
  success by every client library, and a rejection with no delay produces the retry storm the limiter
  was meant to prevent.*

## Money, since much of what we build moves it

- **Never a float for an amount.** Integer minor units, or a decimal type. *Why: binary floating
  point cannot represent most decimal fractions exactly, so `0.1 + 0.2` is not `0.3` and repeated
  arithmetic drifts. On money that drift becomes a reconciliation break nobody can explain, and the
  error grows with volume.*
- **An amount always carries its currency**, and the currency comes from the account, never from
  the request. *Why: a request-supplied currency lets a caller move value across denominations. Send
  1000 in a currency worth ten times the account's and the ledger accepts it.*
- **Money-moving endpoints are idempotent**, keyed on a caller-supplied idempotency key. *Why: the
  network will deliver a request twice. A timeout on the caller's side after the write has committed
  is indistinguishable from a failure, so the caller retries, and without a key the money moves
  twice.*
- **Round explicitly, and never in our favour.** State the rule in code, at the point of rounding.
  *Why: implicit rounding is whatever the language does, which varies by type and platform. And
  rounding that consistently favours us is systematic, so it accumulates into a number a regulator
  will eventually ask about.*
- **A balance is reconcilable.** If it is stored rather than derived, something must compare it
  against the ledger on a schedule, and drift must be visible. *Why: a stored balance and its
  postings are two sources of truth. Without a reconciliation nothing detects them diverging, and by
  the time a customer reports it you cannot tell which figure was ever right.*

## Data

- **Parameterised queries only.** No string-concatenated SQL, ever, including for a column name.
  *Why: it is the only reliable defence against injection, and "this value is safe because it comes
  from our own code" stops being true the moment someone reuses the function. Where a column or table
  name must vary, use an allowlist, since placeholders cannot bind identifiers.*
- **Migrations are forward-only and reviewed.** A schema reconstructed from application code is
  documentation, not a migration, and must say so.
- **Every table's owner is named.** Shared write access with no owner is how schemas rot.
- **A schema change is expand, then migrate, then contract**, across separate deploys. Add the new
  column nullable, write both, backfill, read the new one, and only then drop the old. *Why: during
  any deploy both versions of the code are running against one database. A rename in a single step
  means the old instances are writing to a column that no longer exists, so the change is an outage
  whose length is however long the rollout takes.*
- **A backfill is its own deploy, batched, and resumable.** *Why: an `UPDATE` over a large table
  inside a migration holds locks for its duration and blocks the deploy behind it. Run it in batches
  with a recorded position, so it can be stopped and resumed rather than restarted.*
- **The index ships before the query that needs it**, and on a large table it is created without
  taking a write lock (`CONCURRENTLY` or the engine's equivalent). *Why: shipping the query first
  means the first production traffic against it is also the first sequential scan of the table.*
- **A migration is reversible or the change is gated.** Where reversing would lose data, the way back
  is a feature flag turning the new path off, not a down migration. *Why: a down migration that drops
  a column deletes what was written since the deploy, so the rollback costs more than the defect.*

## Caching

Detail, including stampede handling and the database query cache, is in [caching.md](caching.md).

- **Every entry has a TTL**, including the data that never changes. *Why: an entry with no expiry
  that is ever written wrong is permanently wrong, and eviction is not an expiry policy, since the
  entries that survive memory pressure are the popular ones. The wrong value everybody reads is the one
  that never leaves.*
- **The key contains everything that changes the value**: the tenant, the principal or permission
  set, the currency, and a version segment for the object's shape. *Why: a response cached on the URL
  alone, where the identity was in the token, serves one customer's data to another. That is an
  incident report rather than a slow page.*
- **Invalidation lands in the same commit as the write path, and deletes rather than updates.**
  *Why: an invalidation added later covers the write path someone remembered. A write-through update
  races with a read that already holds the old value, where a delete is idempotent and costs one miss.*
- **Nothing that moves money is cached without invalidation on every write path.** A missed
  invalidation there is as serious as a wrong posting.
- **A new cache ships with a hit-rate metric.** *Why: a cache at a 4% hit rate is spending memory
  and adding a network hop to be slower, and it is indistinguishable from a cache at 95% without the
  measurement.*

## Tests

- **A bug fix ships with a test that reproduced it.** No exceptions. *Why: the test is how you know
  the fix works, rather than that the symptom stopped. It is also the only thing stopping the bug
  returning the next time someone refactors that path.*
- **Tests assert on observable behaviour**, never on a mock having been called. *Why: a test that
  asserts a mock was called passes when the code calls it with the wrong data, and keeps passing if
  you delete the real implementation entirely.*
- **A test that fails intermittently is broken.** Fix or delete; leaving it teaches people to
  re-run.
- **Test output is pristine.** Expected errors that log noise train people to ignore logs.

## Types and tooling

- **Strict type checking on**, and an escape hatch (`any`, `@ts-ignore`, a cast) carries a comment
  saying why. On code that computes money, an escape hatch needs a reviewer's agreement. *Why: an
  escape hatch is a place the compiler has been told to stop helping, and without a comment the next
  reader cannot tell whether it was reasoned or convenient.*
- **A check-only lint command exists**, separate from any `--fix` variant, so CI can gate on it.
- **CI fails the build on a failing test.** A test step with `continue-on-error` is documentation,
  not a gate.

## Dependencies

- **The lockfile is committed, and CI installs from it** (`npm ci`, `poetry install`, and their
  equivalents), never a resolving install. *Why: an install that resolves fresh means the build tested
  and the build shipped can contain different code, and the difference appears on whichever day an
  upstream publishes.*
- **A dependency is added deliberately, and the reason survives.** For a small utility, prefer
  writing it. *Why: every dependency is code that runs with your privileges, ships in your artifact,
  and becomes your problem when it is abandoned. The cost is not the install, it is the next five
  years.*
- **An advisory scan runs in CI and fails the build on a high severity finding**, with a recorded,
  time-boxed exception where a fix is not available. *Why: a scan whose output nobody must act on
  becomes a list people stop reading.*
- **Pin what executes in a pipeline**, including CI actions, to a commit rather than a moving tag.
  *Why: a mutable tag is a supply chain compromise waiting to be someone else's decision, and it runs
  with your CI credentials.*

## What is deliberately not here

Formatting: indentation, quote style, line length, and trailing commas. Those belong entirely to
the formatter. If they are being discussed, the formatter is missing or not enforced, and that is
the thing to fix.
