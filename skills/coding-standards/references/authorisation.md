# Authorisation and RBAC

Read this for any project with a UI, an API that serves one, or more than one kind of user. Broken
access control is the most common serious defect in web applications, and it is almost never
sophisticated: it is a route somebody forgot, or a check that confirmed the caller may read payouts
without confirming they may read *this* payout.

Authentication is who you are. Authorisation is what you may do. This file is about the second.
Nothing here replaces the first.

## Deny by default, enforced by the framework

**The rule: a route with no declared policy is unreachable, not public.**

The failure of opt-in authorisation is that a route with a missing check looks exactly like a route
that is intentionally open. Nothing distinguishes them, so nothing can find the first without a human
reading every route.

Make it structural. A global middleware or filter that rejects any request reaching a handler with no
policy attached, and an explicit `@Public` or equivalent for the handful of routes that really are
open. Then the list of public routes is a list, greppable and reviewable, rather than an absence.

**Test the property, not just the routes.** One test that enumerates every registered route and
fails when any of them carries neither a policy nor an explicit public marker. That test is the
control. Without it the middleware is correct until the day someone registers a route a different
way.

## Check permissions, never roles

**The rule: code asks `can(user, 'payout:approve')`. It never asks `user.role == 'admin'`.**

*Why:* a role check scattered through the codebase means adding a role, splitting one, or granting an
existing role one extra ability is a change at every call site, found by grep, on a deadline. A
permission check means it is one row in a mapping table. The role-to-permission mapping is data; the
permission check is code.

The model, and it is worth keeping this boring:

```
user  ->  role(s)  ->  permission(s)
```

- **Permissions are named `resource:action`** and enumerated in exactly one place. That enumeration
  is the authority. A permission string that appears in a check but not in the enumeration is a typo
  that silently denies, or worse, silently passes through a permissive default.
- **Roles are coarse and few.** If you have forty roles, you have permissions with a role-shaped
  name, and every new customer wants a forty-first.
- **Grant to roles, not to users.** A per-user grant is invisible in a review of the role model and
  survives the user changing jobs. Where a genuine exception is needed, it is time-boxed and logged.
- **No implicit inheritance.** "Admin implies everything" means a new permission is granted to admin
  the moment it is invented, including permissions nobody intended admin to have, such as
  approving a payout they initiated.

## Object-level checks, which is the one everybody misses

**The rule: every check names the subject, the action, and the object. A check with no object is
incomplete unless the operation genuinely has none.**

Holding `payout:read` means you may read payouts. It does not mean you may read payout 4412. A
handler that verifies the permission and then loads the row by id is the single most common serious
access control bug in existence, and it is invisible in a code review that reads only the annotation
on the route.

```
GET /payouts/4412
  permission check: caller has payout:read      -> passes
  ownership check:  payout 4412 belongs to the caller's merchant   -> missing
```

Two ways to make it structural, and the second is the one that lasts:

- **Scope at the data layer, not the handler.** A repository whose every query is bound to the
  caller's tenant cannot return another tenant's row. That is a control. A handler that remembers to
  add `WHERE merchant_id = ?` is a convention, and a convention is one hurried PR from being broken.
- **Load through an authorised accessor.** One function that takes the principal and the id and either
  returns the object or raises. Then "did we check?" is answered by which function was called, which
  is greppable.

**Return 404 where the caller may not know the object exists.** Answering 403 for an id that exists
and 404 for one that does not turns the endpoint into an enumeration oracle: an attacker learns your
customer ids by their status codes. Pick one and use it for both.

## Multi-tenancy is authorisation, not configuration

**The rule: the tenant boundary is enforced in one place, and it is not the query each developer
writes.**

Row-level security in the database, a mandatory scope on the ORM, or a repository layer that takes
the tenant from the request context and cannot be called without it. Whichever one, it is the same
mechanism everywhere, and a query that bypasses it is a review finding rather than a style
preference.

The tenant comes from the authenticated session. Never from a path parameter, a header, or a body
field, all of which the caller chooses.

## Revocation, and the window you are accepting

**The rule: state how long a revoked permission stays usable, and make it a decision rather than an
accident.**

A JWT carrying roles or permissions is a snapshot. Remove someone's `payout:approve` and they keep
it until their token expires. That is fine if the token lives five minutes and someone wrote that
down. It is not fine at a 24-hour expiry on a payments system, and "we use JWTs" is not an answer to
an auditor asking how quickly access is removed.

Pick one, in an ADR:

- Short access tokens plus a refresh that re-reads permissions. Simple, and the window is the token
  lifetime.
- A revocation or version check on each request. Correct, and it is a lookup per request, which is a
  cache with the shortest TTL in the TTL table in `caching.md`.
- Long tokens plus an accepted window, written down, with an out-of-band kill switch for the case
  that matters.

**Cached permission sets follow the same rule.** A permission cache is an authorisation control with
a TTL, and it must be invalidated when a role changes, not left to expire.

## Money, and separation of duties

Wherever money moves, these are defaults rather than options:

- **The principal who initiates a value movement cannot approve it.** Enforced as two permissions and
  an explicit check that the approver is not the initiator. A permission pair alone does not do it: one
  person holding both permissions satisfies the model and defeats the control.
- **Approval thresholds are data.** An amount above a limit requires a permission the ordinary
  operator does not hold. In configuration, not in a constant.
- **An administrative override on a money path is logged as an override**, with the actor, the
  reason, and the record it touched. An override nobody can find afterwards is indistinguishable
  from a defect.
- **Impersonation is time-boxed and double-logged**, under both the operator's identity and the
  impersonated one. A support tool that logs only the impersonated user makes every action look like
  the customer's own.

## Server-side only, and log the decisions

**Every check exists on the server.** Hiding a button is a UX decision. See the authorisation
paragraph in `frontend.md`: a permission enforced only by hiding UI is not enforced.

**Log every denial, and every grant on a money or admin path**, with subject, action, object, and
outcome. Denials are how you find both an attack and a broken role model, and the two look different:
one principal denied across many objects is probing, many principals denied on one action is a
permission somebody forgot to grant after a release. See `observability.md` for the field names, and
the secrets rules in `house-defaults.md` for what must not appear in the line.

## Testing it

For each protected route, three tests. The middle one is the one that finds real bugs and the one
usually absent:

1. **No permission.** Authenticated, lacking the permission, gets 403.
2. **Right permission, wrong object.** Authenticated, holds the permission, asks for another
   tenant's or another merchant's record. Gets 403 or 404, and never the record.
3. **Right permission, right object.** Succeeds.

Plus, once per codebase:

- The route enumeration test described above: no route without a policy or an explicit public marker.
- Separation of duties: the initiator of a payout is refused as its approver, even holding both
  permissions.
- A revoked permission stops working within the stated window.

A permission model with no tests of case 2 has no evidence for its most important property.

## What review looks for

- A new route with no policy, or a policy added as a comment.
- `role ==` or `role in [...]` anywhere outside the role-to-permission mapping.
- An object loaded by id from a path parameter with no ownership or tenant check between the
  permission check and the load.
- A tenant id read from the request rather than the session.
- A permission string that does not appear in the central enumeration.
- A permission set cached with no invalidation on role change.
- An approval path where one principal can hold both halves and no check compares the two actors.
- 403 for existing objects and 404 for absent ones on the same endpoint.
- Any authorisation logic in frontend code that has no server-side counterpart.
