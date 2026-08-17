# OWASP checklist

Worked against the diff on a `--diff` run, or the whole repo on `--full`. Ordered by how often
each one is the real finding in a service like ours, not by the OWASP numbering.

## Broken access control

The most common serious finding, and the one scanners miss entirely.

- Is authorisation enforced **by default**, or opt-in per route? Opt-in means a forgotten
  decorator is a public endpoint. Count the routes and count the checks.
- Can a caller reach another tenant's or another merchant's data by changing an id?
- Is the identity taken from the request body anywhere, rather than from the authenticated
  session?
- Do the roles actually differ, or does every authenticated caller get everything?
- Is there an endpoint that reads data using a credential intended only for writing, or vice
  versa?
- Does the code branch on a **role name** rather than on a permission? Every `role == "admin"` is a
  place a new role has to be remembered, and one of them will not be.
- Is a permission check present but the **object check** absent? The shape is a correct annotation on
  the route followed by a load by id straight from the path. Test it: authenticate as one tenant and
  request another tenant's id.
- **How long does a revoked permission keep working?** Roles inside a long-lived JWT with no
  revocation check means access removal takes until expiry. That is a finding when the window is not
  written down anywhere.
- Is a permission set or authorisation decision cached, and is it invalidated when a role changes?
- Does the endpoint answer 403 for an id that exists and 404 for one that does not? That difference
  enumerates your customers.

## Cryptographic failures

- Is anything sensitive hashed without a salt or a key? A bare SHA-256 of a value from a small
  space, such as a card number whose BIN and last four are stored alongside, is reversible by
  brute force. Tokenisation that does this protects nothing.
- Are secrets in the working tree, in history, or in a build artifact?
- Is TLS enforced on every outbound call, and is certificate verification ever disabled?
- Is a signature over the exact bytes transmitted, or over a re-serialisation that can diverge?

## Injection

- SQL built by concatenation, anywhere, including a column or table name.
- Shell commands built from input. Check for a shell string rather than an argument array.
- Path traversal: is a filename from a caller resolved and then re-checked against the intended
  root, or only sanitised?
- Template injection, and deserialisation of untrusted input.

## Insecure design

- Does a check fail open or closed when its dependency is unavailable? A rate limiter that allows
  everything when the cache is down is a rate limiter an attacker turns off.
- Is an operation that must be idempotent actually idempotent, keyed on something the caller
  supplies?
- Can a state machine be driven backwards, or into a terminal state and out again?
- **Is there a timeout on every outbound call?** A missing one is an availability vulnerability: an
  attacker who can make a dependency hang, or who controls one, exhausts your threads or connections
  and takes down endpoints that never touch it.
- Are retries bounded, jittered, and stacked at only one layer? Unbounded or unjittered retries
  amplify a partial outage into a total one, and they do it to your dependency as well as to you.
- On a dependency timeout, is a money-moving transaction left pending rather than assumed failed or
  succeeded? Both assumptions lose money, in opposite directions.
- Is a queue consumer idempotent under at-least-once delivery, and is there a dead letter path? A
  poison message with unbounded retry occupies a worker permanently, which is a denial of service
  anyone able to submit one can trigger.
- Is an event published inside a transaction, or committed with the publish unrecorded? Both produce
  a ledger and a downstream that disagree, and neither raises an error.

## Time

Small section, and it catches the failures that only appear on two days a year.

- Are tokens, sessions, signatures and nonces given expiry compared against a trusted clock, and is
  the comparison in UTC? A local-time comparison across a daylight saving boundary extends or
  collapses a validity window by an hour.
- Is a webhook or signature replay window bounded, and evaluated against an offset-aware timestamp?
- Is any security decision derived from timestamps produced on two different machines, where clock
  skew decides the outcome?
- Is a lockout, retention, or expiry duration measured on a wall clock that can step backwards?

## Rate limiting and resource abuse

A limiter that exists and does not work is the usual finding here, so check the mechanism rather
than its presence. Detail is in the `coding-standards` reference `rate-limiting.md`.

- **Is the check atomic against shared state?** A get-then-set limiter behind N instances enforces
  roughly N times its configured rate. Read the implementation; the configuration will look right
  either way.
- **Can the caller choose their own key?** A key taken from the leftmost `X-Forwarded-For` entry, a
  header, or a body field resets on demand. Only a key established by authentication, or a peer
  address from a proxy layer you control, is a key.
- Is authentication limited **per account** as well as per IP? Credential stuffing rotates IPs, so an
  IP-only limiter does nothing about the attack it was installed for.
- Is anything that sends an email, an SMS, or a push notification limited? Unlimited, it is both an
  enumeration oracle and a bill.
- Is an expensive endpoint (report, export, search) charged the same as a cheap one?
- Does a rejection return 429 with `Retry-After`, or does it drop, time out, or return 200 with an
  error body?
- What happens when the limiter's backing store is unavailable: unlimited, or a conservative local
  fallback that is logged and alerted?
- Is there any bound at all on request body size, page size, upload size, and query depth? An
  unbounded `limit` parameter is a denial of service with a query string.

## Caching

Almost never audited, and it produces cross-customer data disclosure, which is the most serious
outcome on this page. Detail is in the `coding-standards` reference `caching.md`.

- **Does any cache key omit the principal or the tenant on a value that varies by either?** This is
  the bug that serves one customer's data to another. Read the key construction, not the docstring.
- Is a response that varies by user cacheable by a **shared** cache? Look for a missing `private` or
  `no-store` in `Cache-Control`, a missing or wrong `Vary`, and a CDN rule that ignores the
  `Authorization` header when it builds its key.
- Is any part of the cache key attacker-controlled or unbounded, letting a caller evict what they
  choose or poison an entry that others read?
- Are authorisation decisions, feature entitlements, or balances cached, and with what invalidation?
- Is a dependency's error cached as though it were data? That turns a blip into minutes of wrong
  answers and can be induced.
- Is anything cached with no TTL at all?

## Security misconfiguration

- Credentials with defaults. A value that starts the service when empty is worse than one that is
  missing, because it starts.
- CORS: is it `*`, and does it read from a validated config or straight from the environment?
- Is a debugging or sandbox surface registered in production builds?
- Are stack traces or upstream error bodies returned to callers?
- Is an admin or metrics endpoint unauthenticated?

## Vulnerable components

- Outdated majors, known advisories, unmaintained packages.
- A dependency imported but not declared, resolving by hoisting. It works until it does not.
- A lockfile that disagrees with the manifest, or a CI step that resolves fresh rather than
  installing from the lockfile. The latter means the code tested and the code shipped can differ.
- A pipeline step pinned to a moving tag rather than a commit. It runs with your CI credentials, so
  whoever can move that tag can read your secrets.
- An advisory scan that runs and whose findings nothing must act on.

## Identification and authentication failures

- Is credential comparison constant time?
- Are two credentials with different privileges distinguishable, and is anything checking they are
  not set to the same value?
- Session and token lifetime, revocation, and whether revocation is actually checked per request.
- Rate limiting on authentication specifically, and on any code-submission endpoint.
- Does an error distinguish "no such user" from "wrong password"? That is enumeration.

## Software and data integrity failures

- Is an inbound webhook's authenticity verified, or only its sender's key? A shared key
  authenticates the sender and does not bind the message.
- Is a build artifact reproducible, and is the pipeline itself protected?
- Does the deploy verify what it is deploying?

## Personal data, beyond what reaches a log

Redaction is covered under logging below. This is the rest of the lifecycle, which is usually
audited by nobody. Detail is in the `coding-standards` reference `data-protection.md`.

- Is there a retention period for each class of personal data, and does anything actually execute
  it? A documented policy with no scheduled job is a written record of an obligation being missed.
- Does deletion reach the replicas, backups, search indexes, caches, warehouses and third parties,
  or only the primary database? This is the step that is nearly always absent.
- Is "anonymised" data re-identifiable from what remains, for instance a pseudonymous id that still
  joins to a live customer table?
- Does any non-production environment hold real production personal data?
- Is personal data encrypted at rest, and is it clear which threat that stops? Volume encryption
  does nothing against a compromised application or a leaked backup restored with its keys.
- Can a single credential export personal data in bulk with the same permission as a single lookup,
  and would anyone know it had happened?
- Which third parties receive personal data, including error reporters and analytics, and is the
  payload scrubbed before it leaves rather than after?
- Is any encryption key in the repository, in a long-lived environment variable, or without a
  rotation path?

## Logging and monitoring failures

- Is a token, signature, full body, or personal identifier ever logged? Check the log archives too,
  not only the logging calls.
- Is there an audit trail for privileged and money-moving actions, with an actor?
- Would anyone notice this class of attack? An absent alert is a finding.

## Frontend, when the project has a UI

Scanners cover almost none of this and it executes in the user's browser.

- **Token storage.** An access token in `localStorage` or `sessionStorage` is readable by any XSS,
  including one inside a dependency. Look for an `HttpOnly`, `Secure`, `SameSite` cookie instead.
- **Token in a URL.** Reaches logs, the referrer header, and history. Never acceptable.
- **CSRF.** Cookie authentication on a state-changing endpoint needs a token the server verifies.
  `SameSite` alone is defence in depth, not the control. Bearer headers do not need CSRF protection;
  cookies do.
- **XSS.** Any `dangerouslySetInnerHTML`, `v-html`, or equivalent reachable from user input. The
  framework escapes by default, so every XSS is somewhere that default was overridden.
- **Secrets in the bundle.** Anything prefixed `NEXT_PUBLIC_`, `VITE_`, or `REACT_APP_` is public.
  Grep for key-shaped values in the built output, not only in source.
- **Authorisation enforced only in the UI.** A hidden button is not a permission. Every check must
  exist server side; find one that does not.
- **Headers.** `Content-Security-Policy` present and without `unsafe-inline`, plus `nosniff`,
  `Referrer-Policy`, and HSTS.

## Server-side request forgery

- Does any user-supplied value become the target of an outbound request?
- Are outbound targets an allowlist, or anything that parses as a URL?
