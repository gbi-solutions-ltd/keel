# Observability standard

Logging, telemetry, and traces. A service that cannot be diagnosed from its output is a service
whose next incident is measured in hours rather than minutes.

## Backend

Default is **SigNoz**, over OTLP. Alternatives are allowed and the choice belongs in
`.keel/profile.json`:

```json
"observability": {
  "backend": "signoz",
  "otlp_endpoint_var": "OTEL_EXPORTER_OTLP_ENDPOINT",
  "log_shipping": "otlp"
}
```

| `backend` | Traces and metrics | Logs |
|---|---|---|
| `signoz` (default) | OTLP to the SigNoz collector | OTLP, same pipeline |
| `grafana` | OTLP to Tempo, metrics to Prometheus or Mimir | Loki |
| `datadog` | OTLP or the Datadog agent | Agent |
| `none` | Structured logs to stdout only | stdout |

**Instrument with OpenTelemetry regardless of backend.** The vendor sits behind the exporter, so
switching is a configuration change rather than a rewrite. Never import a vendor SDK into
application code.

Gate export on the endpoint being set, so local development stays quiet without a code path of its
own.

## Every log line carries

| Field | Why |
|---|---|
| `level` | See the level table below |
| `service` | The service name, from one constant, not a string literal per call site |
| `env` | dev, staging, prod |
| `trace_id`, `span_id` | So a log line joins its trace. This is what makes traces worth having |
| `request_id` | Correlates lines within one request even when tracing is off |
| `actor` | **Who caused this.** The API key id, the user id, or the partner name. See below |
| `msg` | Human readable, stable, and low cardinality. Put the variables in fields, not the message |

Structured, always. JSON in production. A log line assembled by string concatenation cannot be
queried, and a field you cannot query is a field you do not have.

## Levels

| Level | Means | Example |
|---|---|---|
| `error` | Something failed that a human must look at | A partner call failed after retries |
| `warn` | Degraded, self-recovering, or a rule was bent | Fell back to the write pool; a rate limit was hit |
| `info` | A business event worth counting | Payout submitted, settlement created |
| `debug` | Developer detail, off in production | Cache hit or miss |

**Not error:** an expected validation failure. A 400 for a bad request is `info`. If your error rate
is dominated by user input, nobody will read it.

## Tag the consumer

Every request-scoped log names who caused it. In practice that is the API key id (never the key),
the authenticated user id, or the partner name for an inbound callback.

Without it you cannot answer "which merchant is generating these errors", which is the first
question asked in every incident involving a partner or a tenant.

## Redaction, at the boundary

Redact where the value is serialised, never at each call site. A call site is a place someone will
forget.

**Never logged, in any form:** passwords, tokens, API keys and secrets, signatures, full card
numbers, CVV, private keys, full request bodies on money-moving endpoints.

**Masked, not removed:** account numbers, phone numbers, emails, names. Keep the last four so a
line stays useful for support.

Give the redactor a deny-list of field names plus a value-shape check, so a secret that arrives
under an unexpected key is still caught. Test it: a redaction with no test regresses the first time
someone adds a field.

Historical note, and the reason this is a standard rather than advice: one repository here had
bearer tokens in log archives that were then committed to git.

## Request and response bodies

Log them at `debug`, redacted, and **never** for a money-moving endpoint at any level. For those,
log the fields you would need to reconstruct the decision: amount, currency, account, idempotency
key, and outcome. That is enough to reconcile, and it does not put a payment instrument in a log
store.

## Traces

Span the boundaries that can be slow or can fail: inbound handler, every outbound HTTP call, every
database query group, every queue publish and consume, and any cache lookup that can miss to a
database.

Put the identifiers on the span as attributes: the tenant, the actor, the idempotency key. A trace
you cannot filter by tenant is a trace you will not use during an incident.

Propagate context across a queue. A job whose trace starts at the worker has lost the reason it
exists.

## Error logs that trigger the right remediation

**Not an industry convention, and the highest-leverage item here.**

An `error` log is frequently pasted straight into an agent CLI by whoever is on call. Phrase it so
that paste is enough to start the right work. In practice that means the line names the failing
operation in words, and carries an explicit remediation hint.

```
level=error service=payouts-api env=prod trace_id=8f3a... actor=key_9d21
  msg="payout settlement failed: ledger credit written without matching debit"
  op=settlement.credit account=acc_4471 idempotency_key=idem_88c1
  remediation="use keel:debug on op=settlement.credit; root cause before any fix"
```

Three properties make that paste useful:

1. **The `msg` states what failed in domain terms**, not `NullPointerException` and not `error in
   handler`. The message is what a reader and an agent both key on.
2. **The identifiers needed to reproduce are fields**, so they survive the paste.
3. **The `remediation` field names the skill.** `debug` for an unexplained failure,
   `security-audit` for anything auth or credential shaped, `optimize-performance` for a timeout
   or a budget breach.

Keep `remediation` a short static string per error site. Do not generate prose: a stable string is
greppable, and a varying one is not.

**The exception log specifically:** log the type, the message, and the stack once, at the boundary
that handles it. Never log and rethrow, which produces the same failure three times in the store and
makes the real cause impossible to identify.

## What good looks like

An engineer paged at 3am can answer, from the logs and traces alone: what failed, for whom, in which
request, how far it got, and what to do next. If any of those five needs a code read, the
observability is incomplete and that is a finding.
