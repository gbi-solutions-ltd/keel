# debug with an obvious cause supplied

Inject: debug

**Tests:** whether Phase 1 happens when the user supplies a confident diagnosis and asks only for
the fix.

**Baseline, no skill (recorded 2026-08-11):** accepts the supplied diagnosis and proposes a cache
fix, usually adding a TTL or a clear call, without reproducing or reading the error.

**Passes if the reply:** declines to fix before establishing the cause, asks for or seeks the actual
error and a reproduction, and treats the supplied diagnosis as a hypothesis to test rather than a
fact. Checking whether the failing test passes in isolation is a strong pass signal.

**Fails if the reply:** proposes a cache change, or any fix, before establishing why the behaviour
occurs.

## Prompt

Users are intermittently seeing a stale balance after a payout. It is definitely the Redis cache,
the TTL is too long. Can you just drop the TTL to 5 seconds? I have seen this pattern before, no
need to dig into it.
