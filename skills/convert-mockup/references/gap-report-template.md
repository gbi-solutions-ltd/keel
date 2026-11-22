# Gaps: {{project}}

What the signed-off mockup does not specify. Each item needs a decision from the client, the backend
team or us before the app goes live. Built {{date}}; visual diff {{n}}/{{n}}; quality check
{{n}}/{{n}}. On a sharded gate: {{n}} of {{n}} planned captures measured, not measured: {{0}}.

## Blocking go-live

Every row has an owner and a date (`By`, YYYY-MM-DD): a gap nobody owns, or owns with no date, is not
on its way to closing. `production-bar.mjs` checks this table and Server-side enforcement
([production-bar.md](production-bar.md)); a table with nothing to list says `None` on its own line
under its heading.

| # | Area | Gap | Source | Owner | By | Next step |
|---|---|---|---|---|---|---|
| 1 | Contract | `GET /v1/...` is a draft | `needs.api` on `/x` | backend | 2026-12-01 | Agree `api/openapi.yaml` |
| 2 | Staging | The staging run against the real backend (a `stub` or `sample` run proves the frontend's half) | production bar | backend | 2026-12-01 | Run `staging-run.mjs` against staging |
| 3 | Identity | The real identity provider behind the sign-in (the sample backend's is a stand-in) | sample backend | backend | 2026-12-01 | Name the provider; run the sign-in flow against it |
| 4 | Messaging | A real email and SMS provider (the sample backend's mail catcher takes both) | sample backend | backend | 2026-12-01 | Choose the providers; send one of each on staging |
| 5 | Deploy | TLS, backups and monitoring | production bar | deploy (keel `setup-deployment`) | 2026-12-01 | Record each in the deploy runbook |

## Screens and flows not designed

Every `data-todo` of kind `screen` or `flow`, every action stubbed with a `[todo]` log, every route
the app needed that the mockup did not have (not found, no access).

-

## Server-side enforcement the frontend assumes

The frontend hides and shows; the server decides. One row each, so the backend can confirm it
exists. Status is `assumed` (nobody has confirmed it), `confirmed by backend` (they say it exists)
or `verified on staging` (the staging run showed it). A run against a stub verifies only the
frontend's half (the cookie sent, the CSRF header copied), never the server's enforcement: a row
stays `assumed` until the real backend confirms it.

| Assumption | Owner | By | Status |
|---|---|---|---|
| Session cookie `HttpOnly`, `Secure`, `SameSite`, set at sign-in | backend | 2026-12-01 | assumed |
| CSRF: `csrf_token` cookie set, `X-CSRF-Token` checked on every state-changing request | backend | 2026-12-01 | assumed |
| Each permission in the route table and each permission check in a page (`useCan`, `canIn`) checked on the matching endpoint, against the object and not only the action | backend | 2026-12-01 | assumed |
| Idempotency keys honoured on state-changing operations | backend | 2026-12-01 | assumed |
| Security headers set at the server or CDN from the app's headers file | deploy (keel `setup-deployment`) | 2026-12-01 | assumed |

With the auth-mfa module, add rows for: rate limits and lockout on sign-in and codes,
`step_up_required` on each sensitive operation, `last_factor` while MFA is required, recovery codes
stored hashed. With the tours-help module: `PUT /v1/me/tours/{id}` scoped to the signed-in user.

## Checklist items deferred

Every item marked `later` in the mockup's checklist ([modules.md](../../mockup/references/modules.md)), with who decides and
by when. An item still undecided is listed under Blocking go-live.

-

## Contract

Every operation marked `x-mockup-status: not-designed`, every field whose units or format were
assumed, pagination size, sort order, filters. With a backend's contract, these go into one
`contract-gaps.md` for the backend team, in the structure in
[api-integration.md](api-integration.md) ("Handing contract gaps to the backend"); link it here.

-

## Deviations from the mockup the gate cannot see

Behaviour that differs without a pixel changing: a field drawn but not sent, a value computed on
the page that the server should own, an identifier or report key we invented, copy of ours where
the mockup had none, a button disabled while a request is pending, a preview flag dropped, a
demo-only fact with its production fallback.

-

## Copy, validation and errors

Form rules the mockup did not state; error codes the UI should explain differently; empty and
not-found copy that was written during conversion.

-

## Judgement calls made during conversion

Anything decided without the mockup saying so, every `data-diff-ignore` added in the app and why,
every lint suppression and its reason (and each entry in the mockup's
`docs/inventory-accepted.json`), every expected-diffs entry and the decision it records.
Quality failures inherited from the mockup (the same tool fails on the mockup's screen) are listed
here with design as the owner.

-

## Not blocking

Accessibility follow-ups beyond the automated checks, performance, nice-to-haves.

-
