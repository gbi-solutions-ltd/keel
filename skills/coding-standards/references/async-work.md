# Asynchronous work

Read this where there is a queue, a worker, a scheduled job, or an event published to anything. In a
payments system this is where money goes missing, and it goes missing quietly: a synchronous bug
returns an error to somebody, an asynchronous one leaves a row in a state nobody is looking at.

The rules below all follow from one fact worth stating first. **Every practical message broker
delivers at least once, not exactly once.** Duplicates are not a failure mode to be prevented, they
are the contract. A consumer that is only correct when each message arrives once is a consumer that
is wrong, and it will look right for months.

## The write and the publish must not be able to disagree

**The rule: never publish an event inside a database transaction, and never publish after committing
without a record. Use an outbox.**

The two obvious shapes both lose messages, and each loses them in the direction that is hardest to
notice:

| Shape | What happens |
|---|---|
| Publish inside the transaction | The publish succeeds, the transaction rolls back. Consumers act on a payout that does not exist |
| Commit, then publish | The commit succeeds, the process dies before the publish. The payout exists and nothing downstream ever hears about it |

**The outbox pattern** removes the choice. In the same transaction as the business write, insert a
row into an `outbox` table. A separate relay reads unpublished rows and publishes them, marking each
as sent. The write and the intent to publish commit atomically because they are the same commit; the
publish is then retried until it succeeds.

The cost is honest and worth stating: the relay is at-least-once, so duplicates are guaranteed rather
than merely likely, which is the next rule. Order the relay by insertion and keep the table small by
archiving sent rows, or it becomes the slowest query in the system.

Where a broker offers transactional publishing that genuinely spans your database, use it and record
the decision. Most do not, whatever the marketing says.

## Every consumer is idempotent, and it is proven by a test

**The rule: processing the same message twice produces the same state as processing it once.**

Three ways, in order of preference:

1. **Natural idempotency.** Setting a status to `settled` twice is harmless. Prefer designs where
   this is true.
2. **A unique constraint the database enforces.** Insert a row keyed on the message id or the
   business reference and let the constraint reject the second one. Enforced by the database, not by
   a check-then-insert in application code, which races with itself.
3. **A processed-messages table**, checked and written in the same transaction as the effect.

**Never a check-then-act across two statements.** "Select where not processed, then process, then
mark processed" is a race with a window in the middle, and two consumers pulling the same message
concurrently is the ordinary case, not the rare one.

**The money rule applies here too.** A consumer that moves value carries the idempotency key from the
original request all the way through, so a duplicated event cannot become a duplicated payment. See
`house-defaults.md`.

## Failure handling: retries, then a dead letter queue, never a silent drop

**The rule: a message that cannot be processed ends up somewhere a human can see, always.**

- **Retry with backoff**, bounded, exactly as in `resilience.md`. A consumer that retries a poison
  message forever occupies a worker permanently and starves everything behind it. That is the classic
  queue outage and it looks like the broker being slow.
- **Distinguish retryable from terminal.** A dependency being down is retryable. A malformed payload
  will fail identically at attempt one thousand.
- **Dead letter after a bounded number of attempts**, with the original payload, the failure, and the
  attempt count preserved.
- **Alert on dead letter queue depth, and on its age.** A dead letter queue nobody watches is a
  delete with extra steps. The age matters as much as the depth: one message stuck for a week is
  worse than fifty from the last hour.
- **Have a replay path** that is tested. Fixing the bug is half the work; the messages that failed
  while it was broken still need processing, and inventing the replay mechanism during an incident is
  the wrong time.

**Never `catch` and acknowledge.** Swallowing the exception and acknowledging the message deletes
work with no record, which is the same defect as a silent catch in `house-defaults.md` with money
attached.

## Ordering, which you probably do not have

**The rule: assume messages arrive out of order unless the broker guarantees otherwise for the key
you actually use, and say which.**

Most brokers order within a partition or a queue, not globally. Two events for the same account
landing on different partitions can arrive in either order, so a `balance.updated` can overtake the
`payment.created` it followed.

Two defences, and prefer the first:

- **Design for order independence.** Carry a version or a timestamp on the entity and ignore an
  update older than the state you hold. This works regardless of the broker.
- **Partition by the entity key** so all events for one account are ordered relative to each other.
  Then say so in the design, because it constrains scaling: one slow key blocks its partition.

## Scheduled jobs

- **A schedule is not a lock.** With more than one instance, a cron job runs on all of them. Take a
  lease in the database or the cache, with an expiry, so a worker that dies does not hold it forever.
- **Missed runs must be recoverable.** A daily job that was down at 02:00 needs to process what it
  missed, so drive it from data ("everything unprocessed before X") rather than from the clock
  ("everything from yesterday").
- **Schedules are in UTC, and the business meaning is separate.** See `time-and-dates.md`. A job at
  "midnight" that follows a timezone runs twice on one day each year and not at all on another.
- **A job that finds nothing is still a job that ran.** Emit that. Silence is indistinguishable from
  a worker that has been dead for a week, which is how a reconciliation stops running unnoticed.

## Observability, because async failures have no caller to complain

Nothing returns an error to a user here, so the queue is the only place the failure is visible.

- **Propagate trace context through the message**, so a job's trace joins the request that caused it.
  `observability.md` says this too; it is repeated because the message payload is where the context
  has to be carried, and it is easy to leave out of the schema.
- **Alert on consumer lag, dead letter depth and age, and processing time.** Lag is the leading
  indicator; everything else tells you afterwards.
- **Log the payload on terminal failure.** It is the input you cannot otherwise reconstruct.

## Transaction boundaries, since this is where they matter most

- **A transaction spans the writes that must be atomic, and nothing else.** No HTTP call, no publish,
  no queue operation, no waiting on anything you do not control. A transaction held open across a
  network call holds its locks for the duration of somebody else's outage.
- **Take locks in a consistent order** across the codebase, or two paths locking two rows in opposite
  orders will deadlock under load and never in testing.
- **Know your isolation level and write it down.** Read committed, the default nearly everywhere,
  permits non-repeatable reads: read a balance, decide, write, and another transaction changed it in
  between. Where a decision depends on what was read, lock the row explicitly or use an optimistic
  version column and retry on conflict.
- **Long transactions are an availability problem**, not a style one. They hold locks and they keep
  the database's cleanup from advancing.

## Testing it

- **Deliver the same message twice and assert the state matches one delivery.** This is the single
  most valuable test in this file and it is routinely absent.
- Deliver two messages out of order and assert the older one does not overwrite the newer.
- A terminal failure reaches the dead letter queue with its payload intact.
- A retryable failure is retried and then succeeds.
- The outbox relay publishes a committed row, and publishes nothing for a rolled-back one.
- Two workers started together run a scheduled job once, not twice.

## What review looks for

- A publish inside a transaction, or a commit followed by an unrecorded publish.
- A consumer with no idempotency mechanism, or one implemented as check-then-act.
- A `catch` that acknowledges the message.
- No dead letter path, or one with no alert.
- An unbounded retry on a consumer.
- Order assumed across partitions or queues.
- A cron job with no lease, in a service that runs more than one instance.
- An HTTP call inside a database transaction.
- A new message schema with no trace context field.
