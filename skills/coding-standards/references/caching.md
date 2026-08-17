# Caching

Read this before adding a cache, and when reviewing one. Covers the application cache and the
database query cache, which fail in different ways and are usually discussed as one thing.

## A cache is a correctness decision before it is a performance one

**The rule: before adding a cache, write down the staleness you are accepting, in seconds, and who
it affects.**

Adding a cache means deciding that some readers will see out-of-date data. That is often fine. It is
never fine by accident. The sentence to write, in the PR and in the code, is: "a merchant may see a
settlement status up to 30 seconds old, and the balance page is excluded."

Ask two questions first, because a yes to either means the cache is the wrong fix:

- **Is this an index problem?** A query that needs an index and gets a cache instead is now slow and
  memory-hungry, and the slowness returns on the first miss, under exactly the load that caused the
  miss.
- **Is this an N+1?** A hundred cached lookups where one join belongs is still a hundred round trips.
  Fix the query shape. `optimize-performance` exists for this, and it will not let you change
  anything before there is a baseline.

## Never without a TTL

**The rule: every entry has an expiry. No exceptions, including "this never changes".**

An entry with no TTL is permanent, and if it is ever written wrong it is permanently wrong. Eviction
under memory pressure is not an expiry policy: it means the entries that survive are the popular
ones, so the wrong value that everyone reads is the one that never leaves.

TTL by data class, as a starting point rather than a rule:

| Class | TTL | Note |
|---|---|---|
| Reference data (countries, currencies, fee tables) | Hours | Cheap, and a version segment in the key beats a long TTL you have to wait out |
| Configuration and feature flags | Seconds to a minute | Long enough to matter, short enough that a rollback takes effect before someone escalates |
| Authorisation decisions and permission sets | Seconds, and invalidated on change | See `authorization.md`. A revoked permission that stays cached is an access control failure with a timestamp on it |
| Expensive aggregates and reports | Minutes, stated in the UI | "As of 14:32" costs one line and removes the entire class of "the numbers are wrong" tickets |
| Balances, ledger positions, anything that moves money | Do not cache | Or cache with mandatory invalidation on every write path, and treat a missed invalidation as a defect of the same severity as a wrong posting |

**Jitter the TTLs.** A batch of keys written together with an identical TTL expires together, and
the load you were smoothing arrives as a spike. Add a random few percent.

## The key must contain everything that changes the value

**The rule: if two callers can get different answers, the difference is in the key.**

This is the cache bug that becomes an incident report rather than a slow page. The classic shape:
cache an API response keyed on the URL, and serve one customer's data to another, because the
caller's identity was in the token and the token was not in the key.

Every key carries, where any of them apply:

- The tenant or organisation id. In a multi-tenant system this is not optional and it is not
  implicit.
- The principal, or the permission set, wherever the response varies by who is asking. Prefer keying
  on the permission set rather than the user id where you can, since it gives a hit rate worth
  having without the cross-user hazard.
- The currency, the locale, and the timezone, whenever the value is formatted or converted.
- A version segment for the shape of the cached object.

**Naming: `<app>:<entity>:<version>:<discriminators>:<id>`.** For example
`payments-api:merchant-summary:v3:tenant-88:USD:4412`.

The version segment is how a deploy that changes the shape of a cached object invalidates its own
entries: bump `v3` to `v4` and the old entries age out on their own TTL while nothing reads them.
The alternative is flushing the cache on deploy, which is a cold cache and a thundering herd at the
exact moment you have just changed something.

**Never let a key be user-controlled without bounds.** An attacker who can make you cache arbitrary
keys can evict everything you actually wanted cached.

## Invalidation ships with the write, in the same commit

**The rule: whoever writes the data owns invalidating it, and the invalidation lands in the same
commit as the write path.**

An invalidation added later is an invalidation that is added for the write path someone remembered.
The one they forgot is the one that serves stale money data six months on, and it is unfindable
because the symptom appears far from the cause.

- **Delete, do not update.** A write-through update races with a concurrent read that has already
  fetched the old value and is about to store it. A delete is idempotent, and the next read repopulates
  correctly. The cost is one miss.
- **Invalidate after the transaction commits, not inside it.** Delete inside a transaction that then
  rolls back, and the cache has now dropped a valid entry for no reason. More dangerous in the other
  direction: a concurrent read between the in-transaction delete and the commit repopulates the cache
  with the pre-commit value, which then survives the commit. That entry is stale until its TTL.
- **A write path that cannot invalidate must not have a cache in front of it.** Direct SQL from a
  migration, a batch job, or another service writing the same table all bypass your application's
  invalidation. If those exist, either the TTL is the only real control (so make it short and say so)
  or the cache is unsafe.

## Stampede: the failure that only shows up in production

One hot key expires. Every request in flight misses, and all of them hit the database with the same
query. The database is now doing the work you built the cache to avoid, at the concurrency the cache
was absorbing.

Three fixes, in order of preference:

1. **Single flight.** One caller acquires a short lock and recomputes; the others wait briefly for
   the result. Bounded and simple.
2. **Serve stale while revalidating.** Keep a soft expiry inside a longer hard expiry. Past the soft
   one, return the stale value and trigger one background refresh. Correct only where the staleness
   is already acceptable, which you have written down.
3. **Early probabilistic refresh.** Refresh with a probability that rises as the entry approaches
   expiry, so the herd never forms.

**Negative caching, with its own shorter TTL.** A miss for an id that does not exist otherwise hits
the database on every request, which is a cheap way to attack you. Cache the absence for a few
seconds. Never cache a dependency's error as though it were data: a timeout is not "no rows", and
storing it turns a blip into minutes of wrong answers.

## Layers add up, and nobody adds them up

An HTTP cache, an application cache, and an ORM cache on the same value give a worst-case staleness
of the sum of the three TTLs, on a path where each layer was reasoned about alone.

**The rule: one cache per value, and where a second layer genuinely earns its place, the total
staleness goes in the same sentence as the requirement.** For a browser or CDN layer, that means
saying what `Cache-Control` is set to, and never letting a response that varies by principal be
cached by a shared cache. `private` on anything user-specific, `no-store` on anything sensitive, and
`Vary` correct wherever content negotiation happens.

## Measure it, or it is not a cache, it is a memory leak

Emit, per key class rather than per key: hit rate, miss rate, eviction rate, and the latency of the
underlying computation on a miss.

A cache at a 4% hit rate is spending memory and adding a network hop to make things slower, and it
looks exactly like a cache at 95% from the outside. Nobody discovers this without the metric. See
`observability.md` for where these go.

Alert on a hit rate falling off a cliff. It usually means a key gained a discriminator and every
lookup is now a miss, which is a deploy-shaped problem with a deploy-shaped fix.

## Database query caching

Different failure modes, so it gets its own section.

**Parameterised queries reuse the plan cache; concatenated ones destroy it.** `house-defaults.md`
requires parameterised queries against injection. This is the second reason: `WHERE id = 4412` and
`WHERE id = 4413` are two different statements to the database, so a concatenating codebase fills
the plan cache with millions of single-use plans and evicts the plans that matter. The security
rule and the performance rule point the same way.

**Know whether your ORM's second-level cache survives another writer.** Most application-level query
caches invalidate on writes made through that application, and are blind to a write from a batch
job, another service, or a database console. If anything else writes those tables, the cache is
wrong on a schedule nobody controls. Either turn it off or restrict it to tables only this
application writes.

**A read replica is not a cache.** Replication lag means a read that follows a write may not see it.
Route read-after-write to the primary, on the same request and for a short window afterwards, and
name the routing rule in code rather than leaving it to an ORM default.

**Never serve an authorisation decision or a money figure from a query cache without invalidation on
write.** This is the same rule as the TTL table above, restated here because a query cache is
usually configured globally, in a file nobody reads during a feature review.

**Materialised views and summary tables are caches with a schema.** They get the same treatment: a
stated refresh interval, a stated staleness, and a reconciliation if the number they hold is money.
See the reconcilable balance rule in `house-defaults.md`.

## Testing it

- A cache hit returns the same value as a miss. Assert on both paths in the same test, because a
  serialisation round trip that loses a field (a decimal becoming a float, a timezone dropping) is
  invisible until someone reads the cached copy.
- The invalidation test writes, then reads, and asserts the new value. Cheap, and it is the test that
  fails when someone adds a second write path.
- Two principals, one key: assert that caller B cannot receive caller A's cached response. Write this
  once per cached endpoint that varies by principal.
- Expiry uses an injected clock, not a sleep.
- With the cache unavailable entirely, the service still serves correct answers, more slowly. A
  service that returns errors when its cache is down has a hard dependency it did not know about.

## What review looks for

- A cache with no TTL, or one whose TTL is set in a different file from the code that reads it.
- A key missing the tenant, the principal, or the currency, on a value that varies by any of them.
- An invalidation in a different commit from the write path, or a write path with no invalidation.
- A cache delete inside a transaction.
- A new cache with no metric, so nobody will ever know its hit rate.
- Anything money-shaped behind a TTL with no invalidation.
- A cache added in place of an index, or in place of fixing an N+1.
- `Cache-Control` allowing a shared cache to hold a response that varies by principal.
