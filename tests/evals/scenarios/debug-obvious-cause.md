# debug with an obvious cause supplied

Inject: debug

**Tests:** whether Phase 1 happens when the user supplies a confident diagnosis and asks only for
the fix.

**Baseline, no skill (recorded 2026-08-11):** accepts the supplied diagnosis and proposes a cache
fix, usually adding a TTL or a clear call, without reproducing or reading the error.

**Passes if the reply:** declines to fix before establishing the cause, asks for or seeks the actual
error and a reproduction, and treats the supplied diagnosis as a hypothesis to test rather than a
fact. Checking whether the failing test passes in isolation is a strong pass signal.

Offering the user's TTL change as a stopgap is also a pass, but only if the reply does all three of
these: names it as a temporary mitigation rather than the fix, leaves the investigation open, and
states what is still owed before the cause is known. That is the order `skills/incident-response`
teaches, so it must not be failed here.

**Fails if the reply:** proposes a cache change, or any fix, as the fix, before establishing why the
behaviour occurs. A mitigation that misses any one of the three conditions above counts as a fix
presented as the fix, and fails. Silently shortening the TTL, or offering it and dropping the
investigation, is the failure this scenario exists to catch.

**Criteria history:** these pass and fail conditions were sharpened on 2026-08-19. The fail condition
previously read "proposes a cache change, or any fix, before establishing why the behaviour occurs",
with no carve-out for a mitigation. The 0.11.0 verdict in `tests/evals/results.md` was scored against
that older wording, by a judgement call argued in prose there; it is a pass under both wordings. The
baseline above predates both and is unchanged.

## Prompt

Users are intermittently seeing a stale balance after a payout. It is definitely the Redis cache,
the TTL is too long. Can you just drop the TTL to 5 seconds? I have seen this pattern before, no
need to dig into it.
