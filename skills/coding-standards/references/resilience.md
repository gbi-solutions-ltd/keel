# Resilience

Read this whenever anything calls anything else over a network, which is nearly every service.
`rate-limiting.md` is the other half: a limiter protects you from your callers, this protects you
from your dependencies. A service with only one of the two has half a resilience story.

Almost every entry here is about a default that is wrong. The libraries ship with no timeout, retry
forever, and treat a failure as a reason to try harder, and each of those defaults is the opposite of
what a payments system needs.

## Every outbound call has a timeout, and the number is written down

**The rule: no network call without an explicit timeout. No exceptions, including a call to your own
database and a call inside a health check.**

*Why:* the default in most HTTP clients is no timeout at all, or one measured in minutes. A
dependency that stops answering, without closing the connection, holds your thread or connection
until you notice. With a request-per-thread model your service stops accepting work; with an async
model your connection pool empties and every unrelated request queues behind it. This is how one slow
partner takes down an unrelated endpoint, and from the outside it looks like your service failed.

Set two, not one:

- **Connect timeout**, small. One or two seconds. A host that has not completed a handshake in two
  seconds is not going to.
- **Read or overall timeout**, from the dependency's real latency, not from a round number. Take its
  p99 and add headroom. If you do not know its p99, that is the finding, not the timeout value.

**The whole request has a budget, and each call spends from it.** If your caller's timeout is 30
seconds, work inward: a handler that makes three sequential calls at 10 seconds each has already
exceeded it before any of them is slow. Pass the remaining budget down where the client supports it,
and fail fast when it is gone rather than starting a call you cannot afford to finish.

## Retries multiply load exactly when there is least to spare

**The rule: retry only what is safe to retry, with exponential backoff and jitter, with a small
bounded attempt count, and with a budget across the service.**

Four conditions, and all four are load-bearing:

- **Safe to retry** means idempotent, or carrying an idempotency key. Retrying a non-idempotent write
  after a timeout is how a payment goes out twice, and a timeout is precisely the case where you
  cannot tell whether the first attempt landed. See the money rules in `house-defaults.md`.
- **Only on the right failures.** A connection refused, a 502, a 503, or a 429 with `Retry-After`. A
  400, a 401, a 403, or a 422 will fail identically every time, and retrying it just spends your
  budget confirming that.
- **Exponential backoff with jitter.** Without jitter, every client that failed at the same moment
  retries at the same moment, and the dependency's first breath after recovery is the entire fleet
  arriving at once. Full jitter (`sleep = random(0, base * 2^attempt)`) is the version to use.
- **Bounded, and small.** Three attempts, not ten. And no retries at more than one layer: a client
  retrying three times inside a handler that is itself retried three times is nine calls, and the
  outer layer usually does not know the inner one exists. Decide which layer owns retrying and make
  the others fail cleanly.

**A retry budget stops the amplification.** Cap retries at a small fraction of total requests, for
example 10%, and stop retrying when the ratio is exceeded. Without it, a dependency at a 50% error
rate receives more traffic than when it was healthy, which is how a partial outage becomes total.

## Circuit breakers, so a failing dependency fails fast

**The rule: any dependency that can be down gets a breaker.**

A retrying client with no breaker keeps sending requests to a service that is already failing, and
each one costs a timeout on your side. Your latency becomes their downtime, multiplied by your retry
count.

Three states, and the middle one is the one people get wrong:

| State | Behaviour |
|---|---|
| Closed | Calls pass through. Failures are counted over a rolling window |
| Open | Calls fail immediately without reaching the dependency. No timeout is spent |
| Half open | After a cooldown, **a small number of trial calls** pass. Success closes it, failure opens it again |

Half open must be limited to a few calls. Reopening the gate to full traffic is how a service that
was recovering is knocked over again by the queue that built up while it was down.

Trip on a failure **rate** over a window with a minimum request count, not on a raw count. Three
failures out of four requests overnight is noise; three hundred out of a thousand is an outage.

**Say what happens when it is open.** A breaker without a defined fallback just moves the error. The
fallback is one of: serve stale data and say so, queue the work for later, degrade the feature, or
return a clean error. For a money movement it is almost always "hold as pending and reconcile", never
"assume it worked" and never "assume it failed".

## Isolate, so one dependency cannot consume everything

**The rule: a slow dependency may exhaust its own resources and no others.**

Separate connection pools, or a bounded concurrency limit per dependency. One shared pool means the
partner that hangs takes every connection and your database calls queue behind an unrelated
integration. Sizing it is the point: a limit of 20 concurrent calls to a partner means the 21st fails
fast rather than joining a queue nobody is draining.

The same reasoning applies to the thread or worker pool behind a queue. One poison partner should
degrade one integration.

## On a partner timeout, the state is unknown, and that is the answer

The payments-specific case, and the one that costs real money.

A timeout is not a failure. The request may have been received, processed, and its response lost. So:

- **Never mark a transaction failed on a timeout.** Hold it in an explicit pending or unknown state.
- **Reconcile it**, by querying the partner's status endpoint with your reference, with backoff, until
  it resolves or a human intervenes.
- **Count the unresolved ones and alert on the count.** An unbounded pending state with no alert is
  where money goes missing quietly, and it goes missing silently for weeks.

Failing an authorised transaction loses money. Approving an unconfirmed one loses more. Neither is
the default; the pending state is.

## Health checks that mean something

**Liveness answers "should I be restarted".** Keep it trivial and dependency-free. A liveness check
that calls the database restarts a healthy service during a database blip, turning a degradation into
an outage.

**Readiness answers "should I receive traffic".** It may check dependencies, and it must have its own
short timeout.

Neither is a monitoring endpoint. A health check that exercises every dependency on every poll is a
load generator with a green tick.

## Testing it

The failures worth testing are the ones that do not happen on a laptop:

- The dependency is slow, not down. Assert the call times out at the configured value rather than
  hanging. This is the case that reaches production untested.
- The retry count is what you think. Count the attempts, do not trust the configuration.
- Backoff uses an injected clock, not a sleep.
- The breaker opens on the configured rate, and half open admits a bounded number.
- A non-idempotent call is not retried, or is retried with the same idempotency key.
- The partner timeout path leaves the transaction pending, and the reconciler resolves it.

## What review looks for

- Any HTTP, database, cache, or queue client constructed with no timeout. Read the client
  construction, not the call site.
- A retry with no jitter, no cap, or on a 4xx.
- Retries at two layers, where neither knows about the other.
- A retried write with no idempotency key.
- A `catch` around a network call that returns a default value, which is a fallback nobody decided
  on and nothing will alert about.
- A liveness probe that touches a dependency.
- A partner timeout path that marks the transaction failed, or succeeded.
- One connection pool shared by a database and an external partner.
