# Root cause tracing

Trace a bad value backwards to where it was created, then fix it there.

## The technique

An error surfaces where a bad value is finally *used*, which is almost never where it was
*created*. Fixing at the surface adds a guard that hides the real defect and leaves every other
consumer still broken.

Work backwards, one question at a time:

1. What value is wrong, exactly? Print it; do not assume it.
2. What passed it here?
3. Did that caller create it, or receive it?
4. If it received it, repeat from 2.

Stop when you reach the code that *created* the value. That is the fix site.

## Worked example

```
TypeError: Cannot read properties of undefined (reading 'currency')
  at formatAmount (format.ts:14)
  at renderRow (table.tsx:88)
  at PayoutTable (table.tsx:140)
```

The tempting fix is at `format.ts:14`:

```ts
if (!account) return "";   // hides it, and every other caller still breaks
```

Trace instead:

- `format.ts:14` uses `account.currency`, so `account` is undefined. It was passed in.
- `table.tsx:88` passes `row.account`, so the row has no account.
- `table.tsx:140` maps over `payouts` from a hook.
- The hook joins payouts to accounts by `accountId`.
- **The join drops rows whose account was soft-deleted.** There is the cause.

The fix is a decision at the join, not a guard at the leaf: either include soft-deleted accounts
for display, or exclude those payouts from the list. Both are defensible; a silent empty string
is not.

## The reported symptom often refutes the supplied diagnosis

When someone hands you a cause, read their description of the symptom against it before doing
anything. The two frequently contradict each other, and noticing costs nothing.

Observed in an eval: "users are **intermittently** seeing a stale balance, it is definitely the
Redis TTL being too long". If a long TTL were the cause, staleness would be **deterministic**:
every read inside the window after a write would be stale, every time. Intermittent staleness means
something the write path does sometimes and not always, which a shorter TTL hides rather than
removes.

That single observation eliminates the supplied diagnosis for free, before any code is read, and
points at the real candidates: a cache key the write path builds differently from the read path, a
read repopulating the cache between the update and the invalidation, an invalidation firing before
the row is visible to other connections, or a replica that has not caught up.

Words worth reading carefully in a report, because each rules something out:

| The reporter says | It rules out |
|---|---|
| "intermittently", "sometimes" | Anything deterministic: a wrong constant, an always-taken branch, a TTL |
| "always", "every time" | Races, concurrency, replica lag |
| "since Tuesday" | Anything that has not changed since Tuesday |
| "only in production" | Logic identical across environments. Look at config and data |
| "only for one customer" | Anything not keyed on that customer's data or configuration |

A shorter TTL, a longer timeout, or a retry all make an intermittent bug rarer. Rarer reads as
fixed and is not, and the next person has less signal than you did.

## Where to fix, in order of preference

| Fix site | When | Cost |
|---|---|---|
| Where the value is created | Almost always | Fixes every consumer at once |
| At the boundary that let it in | The creator is third-party or outside your control | Validate once, at the edge |
| Where it is used | Only when the value is legitimately optional | Every other consumer needs the same guard |

If you are adding the same guard in a third place, you are fixing at the wrong layer.

## Add validation after you find it, not instead

Once the cause is fixed, a check nearer the boundary is often worth adding so the next occurrence
fails loudly and early rather than deep in a render. That is defence in depth, and it works only
as an addition to the real fix.

Order matters: cause first, then the guard. A guard added first removes the evidence you need.

## When the stack trace is useless

Async boundaries, event handlers, and queue consumers frequently lose the originating stack.

- Log a correlation id where the value is created and carry it through.
- For a queue job, log the full payload on failure. The payload is the input you cannot otherwise
  reconstruct.
- If the value crosses a serialisation boundary, check it on both sides. Correct before
  `JSON.stringify` and wrong after is a serialisation bug, not a logic bug.
