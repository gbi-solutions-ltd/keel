# Data protection

Read this wherever personal data is stored, which for a payments system is everywhere. The existing
rules on secrets and log redaction in `house-defaults.md` and `observability.md` cover one control out
of a lifecycle: they stop personal data reaching a log. They say nothing about how long it is kept,
who can reach it, whether it is encrypted where it sits, or how it is deleted.

This is a set of engineering defaults, not legal advice. Data protection law varies by market and by
which regulator has an interest in a given account, so where a rule below and a written obligation
disagree, the obligation wins and the difference is recorded in an ADR rather than in someone's head.

## Know what you hold, before anything else

**The rule: every table and every event schema has its personal data classified, and the
classification is in the schema, not in a document.**

A comment on the column, an annotation, or a naming convention. Something a script can read, because
the questions that arrive later ("where is this customer's data", "what do we hold about minors",
"which tables cross a border") are answerable in minutes with a machine-readable classification and
in weeks without one.

| Class | Examples | Consequence |
|---|---|---|
| Identifiers | Name, phone, email, national id, account number | Masked in logs, access controlled, retained on a schedule |
| Financial | PAN, IBAN, transaction detail | Never in logs at any level, encrypted at rest, PCI scope where cards are involved |
| Sensitive | Biometrics, health, precise location | Collect only with a written reason. Prefer not to hold it |
| Derived | Risk scores, segments | Still personal data. It is about a person |

**A derived field is personal data.** Teams routinely treat a computed score as anonymous because it
is not a name. If it is attached to a person, it carries the same obligations.

## Collect the minimum, and be able to say why

**The rule: every personal field has a stated purpose, and a field with no purpose is deleted.**

*Why:* data you do not hold cannot leak, cannot be subpoenaed, cannot be retained too long, and costs
nothing to protect. Most fields that become a breach headline were collected because a form template
had them, not because anything used them.

Concretely, at review time: a new personal column in a migration comes with the sentence explaining
what reads it. If nothing reads it, it does not ship.

**Do not collect a full identifier where a partial one does the job.** Storing the last four digits
and a salted HMAC of the whole value supports lookup and support conversations without holding the
value itself.

## Retention is a schedule that runs, not a policy document

**The rule: every class of personal data has a retention period, and something deletes it
automatically. A retention policy nobody executes is worse than none, because it is a written record
of an obligation you are not meeting.**

- **The clock starts at a defined event**, not at row creation. "Seven years after the account closes"
  and "seven years after the row was written" differ by the life of the relationship.
- **Financial records usually have a legal minimum.** Retention is a floor as well as a ceiling, so
  deletion must respect a hold. Where a record is subject to a legal hold or an open dispute, deletion
  is suspended and that suspension is recorded.
- **Deletion covers the copies.** Backups, replicas, analytics warehouses, search indexes, caches,
  object storage, and the third parties you forwarded it to. A deletion that only touches the primary
  database is a deletion that has not happened, and this is the step that is nearly always missing.
- **Where a record must survive, anonymise rather than keep.** A transaction that must remain for
  reconciliation can keep its amount, currency and timestamps while the personal identifiers are
  replaced. Prove it is not reversible from what is left, since a "pseudonymous" id that still joins
  to a live customer table is not anonymised at all.
- **The job reports what it deleted**, and an alert fires when it does not run. See `async-work.md`
  on jobs that find nothing.

## Encryption, and being clear which threat each one stops

**In transit:** TLS everywhere, including inside the network and to the database. Certificate
verification is never disabled, including in staging, because the flag set in staging is the one that
reaches production.

**At rest:** full disk or volume encryption on every store holding personal data, plus backups.
Understand what it actually protects: a stolen disk or a decommissioned volume. It does nothing
against a compromised application, an over-permissive query, or a leaked backup that is restored with
its keys.

**Field level**, for the highest-sensitivity values, where the application encrypts before writing.
This does defend against a database compromise, and it costs you the ability to query or index the
value. Use a deterministic HMAC for lookup and encrypt the value itself, and record the trade in an
ADR rather than discovering it when a report needs the field.

**Keys live in a key management service**, never in the repository, never in an environment variable
that is really a long-lived secret, and they are rotatable. A key you cannot rotate without downtime
is a key you will not rotate.

## Access to personal data is authorisation, and it is logged

Everything in `authorisation.md` applies, with two additions specific to this data:

- **Reading personal data at scale is itself a privileged action.** A support tool that can look up
  one customer is ordinary. One that can export ten thousand is a different permission, with a
  different approval, and an alert on volume.
- **Log every access to sensitive records**, not only every change. For a support or admin surface
  the question asked after an incident is who looked, and an audit trail that records only writes
  cannot answer it.

**Non-production environments do not receive production personal data.** Mask or synthesise on the
way out. A test database restored from production carries every obligation of production into an
environment with weaker access control, and it is the most common way real customer data ends up
somewhere nobody is protecting.

## Subject rights, built once rather than by hand each time

Requests for access, correction, deletion and portability arrive whether or not anything was built
for them, and they arrive with a deadline. Handled by hand, each one is an engineer running ad hoc
queries against production, which is its own risk.

Build, once: **find everything about a subject**, which the classification above makes possible;
**export it** in a readable form; and **delete or anonymise it**, honouring legal holds. Then log
every one of those actions, because the request itself is an event you must be able to evidence.

## Third parties and borders

- **A list of every processor personal data reaches**, what they get, and under what agreement. It is
  maintained when an integration is added, not reconstructed under pressure.
- **Know which country the data sits in**, including the region of every managed service and every
  backup. Cross-border transfer is one of the few areas where a default chosen for latency has
  regulatory consequences.
- **Sending data to a third party is a disclosure**, including to an analytics or error-reporting
  service. Error reports in particular carry request bodies and stack traces with identifiers in
  them, and they leave the country by default. Scrub before sending, not after.

## Testing it

- The retention job deletes what is past its period, keeps what is under legal hold, and reports both.
- Deletion of one subject leaves nothing joinable in replicas, indexes and caches. Assert the absence
  in each store, not only the primary.
- Anonymisation is not reversible from the remaining columns.
- The masking used for non-production data leaves no real identifier behind, checked by a scan rather
  than by reading the script.
- Redaction covers a personal field arriving under an unexpected key, per `observability.md`.
- A bulk export requires the elevated permission and produces an audit record.

## What review looks for

- A new personal field in a migration with no stated purpose and no classification.
- A retention period documented with nothing scheduled to enforce it.
- Deletion that touches the primary store only.
- Personal data in a fixture, a seed script, or a test snapshot.
- Certificate verification disabled anywhere, in any environment.
- An encryption key in the repository, in an environment variable, or with no rotation path.
- A support or admin endpoint that can export in bulk with the same permission as a single lookup.
- An error reporter or analytics SDK receiving an unscrubbed payload.
- A new managed service whose region nobody stated.
