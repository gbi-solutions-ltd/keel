# STRIDE

A threat model over the architecture, not the code. Run it against the container diagram: for each
component and each boundary it crosses, ask the six questions.

| Threat | The question | Control |
|---|---|---|
| **S**poofing | Can someone claim to be a party they are not? | Authentication, per boundary |
| **T**ampering | Can data be altered in transit or at rest without detection? | Signatures, integrity checks, TLS |
| **R**epudiation | Can someone deny an action they took? | Audit log with an actor and a timestamp |
| **I**nformation disclosure | What leaks, to whom, through what? | Authorisation, redaction, error mapping |
| **D**enial of service | What happens under load, or one caller abusing it? | Rate limits, timeouts, quotas |
| **E**levation of privilege | Can a caller do more than their role allows? | Authorisation checked by default, not per route |

## How to run it

Take each arrow on the container diagram. For that arrow, name: who can send it, what
authenticates them, what would happen if the message were forged, and what the sender can reach
once trusted.

The arrows that matter most are the inbound ones you did not design: a partner callback, a webhook,
an internal service you assume is friendly.

## The questions that find real problems

**Spoofing an inbound callback.** A shared key authenticates the sender but does not bind the
message. Ask: if this key leaked, what can the holder assert? A callback that sets a status to
`approved` with no signature means the key holder can approve anything.

**Elevation through opt-in authorisation.** Where a permission check is a decorator per route
rather than a default, a new route is unprotected until someone remembers. Ask: what happens if a
developer forgets? If the answer is "it is public", that is a finding regardless of whether any
route is currently missing one.

**Disclosure through error text.** An upstream error returned verbatim tells a caller your
internal hostnames, endpoints, and stack. Ask what the least-trusted caller sees on each failure
path.

**Tampering with what you sign.** If a signature covers a serialisation of a body rather than the
bytes actually sent, the two can diverge. Ask what exactly is signed and whether it is byte
identical to what is transmitted.

**Repudiation on money.** Ask whether the audit log records enough to reconstruct who moved what
and when, and whether it can be written by the same credential that performs the action.

## What STRIDE does not cover

Business logic. STRIDE will not tell you that a routing engine's decision is discarded, that a
refund can exceed its original, or that a rounding rule favours the house. Those need the domain
checklist and someone who understands the product.

Run STRIDE for structure, then the payments checklist for meaning.
