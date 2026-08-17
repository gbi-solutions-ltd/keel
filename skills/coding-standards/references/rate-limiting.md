# Rate limiting

Read this when a service exposes an API, whether public, partner-facing, or internal. Every entry
here is about a limiter that exists and does not work, because that is the common case. A limiter
nobody wrote is at least visible in an incident review; a limiter that permits ten times its
configured rate is not.

## The algorithm: token bucket, and why not the other ones

**The rule: token bucket unless there is a written reason for something else.**

| Algorithm | Behaviour | Why not |
|---|---|---|
| Fixed window | Count per calendar minute, reset at the boundary | Permits double the rate across a boundary. 100 requests at 10:00:59 and 100 more at 10:01:00 is 200 in one second, and the counter is satisfied |
| Sliding log | Keep every request timestamp | Correct, and the memory is proportional to the traffic you are trying to survive. It is largest exactly when you are under attack |
| Leaky bucket | Fixed drain rate, queued | Smooths output, but queues requests that the caller has already given up on. Good for outbound, wrong for inbound |
| **Token bucket** | Capacity plus refill rate | Two integers per key, a sustained rate and a bounded burst stated separately |

Token bucket is the default because the two things you actually want to say, "600 per minute
sustained" and "but 50 at once is fine", are its two parameters rather than an emergent property.

## The four parameters, and stating them

Every limiter records these, in configuration, not in code:

- **Capacity.** The burst. How many requests may arrive at once with an empty pipe behind them.
- **Refill rate.** The sustained rate, as tokens per second.
- **Key.** What the bucket belongs to. See below, this is where limiters go wrong.
- **Cost.** How many tokens the operation takes. Default 1.

**Refill lazily, never on a timer.** Store `(tokens, last_refill_at)` and compute the refill when the
bucket is read: `tokens = min(capacity, tokens + (now - last_refill_at) * rate)`. A background timer
touching every bucket is work proportional to the number of keys, most of which are idle, and it
gives a limiter a scaling problem of its own.

**The clock is an input, not an ambient fact.** Inject it. A limiter that calls the system clock
directly can only be tested by sleeping, so its tests are slow, flaky, and get deleted.

## The check must be atomic, or the limit is per-instance

**The rule: one atomic operation against shared state, or the limit is a suggestion.**

The failure is read-modify-write. Fetch the bucket, decide, write it back. Two requests interleave,
both read the same count, and both are allowed. Under load that is not an occasional extra request:
with N application instances behind a load balancer and a non-atomic check, the effective limit is
close to N times the configured one, and the configured number in the runbook is wrong by a factor
nobody has measured.

Use a Redis Lua script, a single `INCR` with an expiry, or an atomic conditional update in the
database. Whichever it is, one round trip that both decides and records.

**An in-process limiter is a per-instance limiter, and must say so.** It is a legitimate choice for
protecting one process from its own workload. It is not an API rate limit, and calling it one in the
documentation is how a service ends up with a limit it does not have.

## The key is the identity, and it must not be spoofable

**The rule: key on the authenticated principal wherever one exists.**

An API key, a client id, or a merchant id. These are established by authentication, so they cannot
be changed by the caller.

**Key on an IP only where there is no principal yet**, which in practice means login, registration,
password reset, and token issue. And where you do, read the client address correctly: the last
untrusted hop in `X-Forwarded-For`, chosen by counting back from the right by the number of proxies
you actually run. Taking the leftmost entry means the caller chooses their own key, and a limiter
the caller can reset is decoration. Where the platform provides the peer address after its own proxy
layer, prefer that over parsing the header at all.

**IPv6 keys on the /64, not the address.** A single client is routinely handed a whole /64, so an
address-keyed limiter is trivially evaded by using the next one.

## Layer the limits, because one number cannot express the requirement

A single global limit lets one caller consume all of it and starve everyone else. A single
per-caller limit does nothing about a thundering herd of well-behaved callers.

| Layer | Protects | Typical key |
|---|---|---|
| Per principal | Fairness between callers | Client id |
| Per principal per endpoint class | One expensive endpoint from eating a caller's whole budget | Client id plus route class |
| Global per endpoint class | The dependency behind it, which has its own capacity | Route class |
| Per account, on authentication | Credential stuffing, which rotates IPs and cannot be caught by an IP key | Account identifier |

That last row is the one most often missing. An IP-keyed login limiter stops one attacker on one
host and does nothing about the same password tried against ten thousand accounts from ten thousand
hosts, which is the attack that actually happens. Key on the account being authenticated as well.

**Cost-weight the expensive routes.** If a report endpoint costs the database a hundred times what a
lookup costs, charge it a hundred tokens. Uniform cost means the limit that keeps the report
endpoint safe is the limit everything else lives under.

## What the caller gets back

**The rule: 429, `Retry-After`, and enough headers to back off correctly.**

- Status `429 Too Many Requests`. Not 200 with an error body, which every client library treats as
  success. Not 503, which means something is broken and invites a retry with no delay.
- `Retry-After`, in seconds. Without it a well-written client guesses, and a badly written one
  retries immediately, which turns a limit into a retry storm.
- `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` on every response, not only on the
  rejection. A caller that can see its remaining budget can pace itself; one that discovers the limit
  only by hitting it has to hit it.
- **Never drop silently.** A limiter that closes the connection or times out is indistinguishable
  from an outage, so the caller retries, and the retry is the thing you were trying to prevent.

Document the numbers. A partner integrating against an undocumented limit will discover it in
production, on their launch day.

## When the backing store is down

`house-defaults.md` says fail closed, and a rate limiter is the example it uses. That still holds, but
"fail closed" for a limiter means something more specific than rejecting everything:

**Degrade to a conservative in-process limit. Do not fail open, and do not reject everything.**

Failing open means an attacker takes the limiter offline by pressuring Redis, which is a cheaper
attack than the one the limiter exists to stop. Rejecting everything converts a cache outage into a
total outage. A per-instance bucket at a fraction of the normal rate keeps the service up, keeps the
ceiling real, and is a state that must be logged at warning level and alerted on, because a service
running on its fallback limiter has already lost a dependency.

## Rate limiting is not the other three things

Worth stating because they get conflated in design discussions, and each conflation leaves a gap:

- **Not idempotency.** A limiter permits a duplicate that arrives inside the budget. Money-moving
  endpoints need an idempotency key regardless. See the money section of `house-defaults.md`.
- **Not a circuit breaker.** A limiter protects you from callers. A breaker protects you from a
  dependency. A service that limits its inbound traffic and retries a failing dependency forever has
  half a resilience story.
- **Not authorisation.** "This caller may do 100 of these an hour" is a quota, and a quota is a
  business rule that belongs with the account, not a defence.

## Testing it

- Allow exactly `capacity` immediately, reject the next one. Assert on both.
- Advance an injected clock, do not sleep. A limiter test that sleeps is a test that gets marked
  slow and then skipped.
- Refill is partial: half the window advanced grants half the tokens, not all of them.
- Concurrency: fire `capacity + 50` requests in parallel against shared state and assert exactly
  `capacity` were allowed. This is the test that catches the read-modify-write race, and it is the
  one usually missing.
- The rejection carries a `Retry-After` that is actually long enough.
- The fallback path: with the backing store unreachable, the service still serves and the limit is
  the reduced one.

## What review looks for

- A limiter keyed on something the caller controls (a header, a query parameter, the leftmost
  `X-Forwarded-For` entry).
- A get-then-set against a shared store with no atomicity, which is the default shape of a
  hand-rolled limiter.
- A fixed window described in the PR as a rate limit.
- No limit at all on login, password reset, token issue, or anything that sends an email or an SMS,
  which is a limit on your own spending as much as a security control.
- A rejection that is not a 429, or a 429 with no `Retry-After`.
- An in-process limiter documented as a service-wide one.
- Retry logic on the calling side with no backoff and no jitter, which produces the load the
  limiter then has to reject.
