---
name: optimize-performance
description: Use when something is slow, when a latency or throughput target is missed, when resource use is too high, or when a performance regression appears.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Optimize Performance

## Overview

Measure, find the actual bottleneck, change one thing, measure again.

**Core principle:** an unmeasured optimisation is a guess with extra steps. No baseline, no change.

## Step 1: Refuse to start without a target and a baseline

Two questions before any code is read:

- **What is the target?** "Faster" is not one. "This endpoint returns in under 200ms at the 95th
  percentile" is. Without a target you cannot know when to stop, and you will keep going.
- **What is it now?** A reproducible measurement, from a command anyone can re-run. Record the
  command, not just the number.

Do not skip to the code. The most common outcome of doing so is optimising something that was
never the problem.

## Step 2: Profile, do not reason

Reasoning about performance is unreliable, including yours. Use a profiler, timing around
suspected sections, or the database's own query plan.

Find where the time actually goes, and state it as a proportion. "Serialisation is 8% of the
request" ends an argument that could have run all afternoon.

## Step 3: Check the usual causes first

In rough order of how often they are the answer in a service like ours:

1. **N+1 queries.** One query per row in a loop. Usually the whole problem.
2. **A missing index.** Read the query plan; do not guess which column.
3. **Fetching more than is used.** `SELECT *`, an unbounded list, no pagination.
4. **Work repeated per request** that could be done once.
5. **A synchronous call that could be deferred**, especially to a third party.
6. **A cache that is missing, or one whose invalidation is broken** so it never hits.

Front-end, when applicable: bundle size, render count, and requests on the critical path.

## Step 4: One change, then measure

One hypothesis, one change, re-measure with the same command. Keep it only if the number moved
enough to matter.

Several changes at once means you cannot attribute the gain, and you will keep the ones that did
nothing. Reverting a change that made no difference is a result, not a failure.

## Step 5: Guard it

An optimisation with no test regresses on the next refactor. Add a test asserting the behaviour is
unchanged, and where the project supports it, a benchmark asserting the bound.

**REQUIRED SUB-SKILL:** `keel:tdd` if behaviour changed at all. A faster wrong answer is
worse than a slow right one.

## Step 6: Report

Before, after, the command that measures it, what changed, and what you tried that did not help.
The last part is what stops the next person repeating it.

## Common mistakes

| Mistake | Instead |
|---|---|
| Optimising without a baseline | Measure first. There is no exception |
| Optimising what looks slow | Profile. It is usually elsewhere |
| Several changes at once | One, then measure |
| Adding a cache to hide an N+1 | Fix the query. A cache over a bad query is a slower bad query |
| Keeping a change that did not help | Revert it. Complexity has a permanent cost |
| No target, so no stopping point | Agree the number before you start |
