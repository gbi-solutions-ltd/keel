# Payments and cards checklist

The domain-specific pass, and where the real risk sits. Generic tooling covers none of this,
because every item is business logic.

## Money arithmetic

- **No floats for amounts.** Integer minor units or a decimal type. A float in a money path is a
  finding regardless of whether you can currently demonstrate a discrepancy.
- **Rounding is explicit and stated at the point it happens**, and it never favours the house.
  Check the direction, not just the presence.
- **An amount always carries its currency**, and the currency is resolved from the **account**,
  never from the request. A request-supplied currency lets a caller move value across
  denominations.
- **Currency precision comes from a table**, not a constant. A silently zero precision turns
  cents into units.
- **Fee and commission arithmetic is checked against the total.** Net plus fee equals gross,
  proven by a test.

## Idempotency

- Every money-moving endpoint accepts a caller-supplied idempotency key and honours it.
- A retry arriving after a timeout does not double-apply. Test the case where the first attempt
  succeeded but the response was lost.
- References and external ids are unique, and their uniqueness is enforced by the database rather
  than by application logic alone.
- A resubmission used as a status query, which some partners require, does not create a second
  transaction.

## The ledger

- **Is a balance stored or derived?** If stored, what reconciles it, how often, and is the drift
  visible to anyone? An unreconciled stored balance is the highest-consequence design risk in a
  payments system.
- Are postings double-entry, and is that enforced rather than conventional?
- Can a credit exist without its matching debit? Look specifically at cancellation and reversal
  paths, which is where this breaks.
- Is a row locked before a balance decision, and is the lock actually held across the read and the
  write?
- Does a cancellation or refund path leave the ledger consistent, including a partial one?

## Card data

- **Is a PAN ever persisted, in any form, including a log or an error?**
- If a token maps to a card, is the mapping keyed by a salted HMAC or a KDF, not a bare hash? With
  BIN and last four stored alongside, a bare hash of a PAN is brute-forceable and the tokenisation
  is decorative.
- Is CVV ever stored? It must never be, even transiently.
- Is card data in a test fixture, a sample payload, or a captured request in the repository?
- What is in scope for PCI, and does the code respect that boundary?

## Partner integrations

- Is an inbound outcome authenticated in a way that binds the message, not just the sender?
- Can a partner's response drive a state transition that should require a second check?
- What happens on a partner timeout: does the transaction hold as pending, or fail? Failing an
  authorised transaction loses money; approving an unconfirmed one loses more.
- Are both the HTTP status and any body status code interpreted, where the partner uses both? A
  partner returning 400 with a body code meaning "retry later" is not a failure.

## Authorisation on money

- Can the same actor create and approve a settlement? Two permissions do not answer this on their
  own. Look for an explicit comparison of the initiator against the approver.
- Is there a limit per transaction, per day, per account, and is it enforced server side?
- Does a status that authorises disbursement require more than one credential to set?
- Is a manual adjustment logged with an actor, a reason, and a before and after?
- Is a balance, a limit, or an entitlement served from a cache? Anything that gates a disbursement
  and is read from a cache with a TTL rather than invalidated on write can authorise a payment
  against money that is already gone.
- Is a disbursement or payout endpoint rate limited **per account** rather than only globally? A
  global limit lets one compromised account consume the whole budget.

## Reconciliation and evidence

- Could you reconstruct, from stored data alone, who moved what and when?
- Is there a report that would surface a discrepancy, and does anyone read it?
- Are stuck transactions countable? An unbounded `pending` state with no alert is where money
  goes missing quietly.

## Going live

- Is the switch from test to live a separate, explicitly confirmed act, rather than a consequence
  of a general go-ahead? It is the only step that can charge a real card, and
  `docs/07-open-decisions.md` decision 3 resolved that money movement is not overridable by a
  sentence in chat.
- Is the current mode visible to whoever is operating the system, rather than inferable only from a
  credential prefix?
- Before an integration endpoint is created, is the existing set listed first? A second endpoint on
  the same address delivers every event twice, and the stored signing secret matches one delivery
  and fails the other, so the symptom is intermittent rather than obvious.
- Are amounts and currencies read back and confirmed before anything is created live? A live price
  is usually deactivatable and not deletable, so a wrong figure is a permanent record and a
  business event rather than a bug.
