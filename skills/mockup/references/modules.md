# Modules and the checklist

Read this at the intake ([intake.md](intake.md), question 10), and again when planning a conversion. Most client apps need
the same handful of features beyond their own screens. Seven of them are built as **modules**:
designed, proven by the visual diff against the React example, and copied into a project when it
opts in. The rest are on the **checklist**: things a client rarely asks for and always needs,
decided once with the client so none is discovered at go-live. A module settles its checklist
items: turning on `audit-log` answers the `audit-log` question.

Nothing here assumes an industry. The sample app (PayDesk) is a payments dashboard only because it
needed a domain; the modules work the same for a clinic, a school or a logistics client.

## Turning a module on

```json
{ "modules": ["auth-mfa", "tours-help", "users-roles", "audit-log", "session-password", "notifications", "system-pages"] }
```

in `mockup.config.json`. The inventory then checks that each module's pages exist
(`module-page`), that a checklist answer does not contradict a module that is on, and for tours,
that every step points at an anchor its page renders (`tour-anchor`). Copy the module's files
(the pages, components, data and assets in its table below) from `examples/paydesk-mockup/` (in the proving repository), and
for a conversion from `examples/paydesk-react/` (in the proving repository), then replace the PayDesk copy and sample data.
Add each copied component's `/* Name */` block from the example's `components.css`, its shell
parts to your `AppLayout.js`, and its screens to your config.

## Where the files are: a minimal starter, a full example

Decided 2026-11-05. `templates/mockup-starter/` is a **minimal core**, and a new mockup starts
from it: `mk.js`, tokens and base styles, the shell (`AppLayout`, with the forbidden page and the
shared field actions), the components every app needs (`DataTable`, `Pagination`, `Badge`,
`EmptyState`, `ErrorState`, `SkeletonBox`, `TableSkeleton`, `ErrorPage`, `TextField`, `SelectField`,
`MoneyField`, `PermissionGrid`), the data helpers (`list-query`, `money`, `grid`), two sample pages (a list and
an ARIA grid) and a config with no modules. It has no module files, so a mockup holds only what
its client opted into.

Each module's files are in `templates/modules/<module>/`
([its README](../../../lib/mockup-engine/templates/modules/README.md) gives the steps): its pages,
the components they need that the starter lacks, its section of `components.css`, its fixture
keys, the screens to add to `mockup.config.json`, and the shell lines in its own README. They are
written to the starter's layout, with one difference to finish in the build: **module pages carry
literal English.** Moving their text into `strings/<locale>.js` through `MK.t` is part of the Mock
build, as for any page. Where the starter and a module both have a core component, the starter's
is the one to keep: it is newer (its `TextField` puts the hint after the input; its `SelectField`
draws its own chevron at the text's inset, [mockup-fields-and-grid.md](mockup-fields-and-grid.md#fields), Fields).

The modules are extracted from the full example mockup in the engine's proving repository (all
seven modules, the pair of its React port, which the visual diff compares), and held to it there.

| Module | Pages | Settles | Beyond React |
|---|---|---|---|
| `auth-mfa` | sign in, second step, account security, authenticator set-up | | unproven on Vue and Next.js |
| `tours-help` | help centre; tours on any page | | proven on Vue (the client port, no example); unproven on Next.js |
| `users-roles` | users, a user, roles and permissions | `user-management`, `roles-admin` | unproven on Vue and Next.js |
| `audit-log` | audit log | `audit-log` | unproven on Vue and Next.js |
| `session-password` | forgot password, new password, signed out; idle warning in the shell; password change and lockout | `session-timeout`, `password-reset` | proven on Vue (the client port, no example); unproven on Next.js |
| `notifications` | notifications, notification settings; the bell and account menu in the shell | `notifications` | unproven on Vue and Next.js |
| `system-pages` | 404, 403, a page that failed to render, maintenance; offline banner in the shell | `system-pages` | proven on Vue and Next.js (`examples/equipment-loans-vue` (in the proving repository), `equipment-loans-next`) |

The module tables below name the mockup's files and the React example's (in the proving repository); on another stack, port the same parts with
the stack file's Mapping, and treat an unproven module as a new port (plant its failures).

**Preview flags.** States a reviewer cannot reach on demand have a URL switch, honoured by the
mockup and by the app wherever the mock API runs (dev and a `--mode mocked` build; a production
build drops them): `?state=empty|loading|error`, `?as=<role>`, `?tours=reset`,
`?session=expiring`, `?system=offline|maintenance|crash`. Each one is a screen in the config, so
the visual diff compares it.

## `auth-mfa`: sign-in with a second step, and account security

| | Mockup | React example |
|---|---|---|
| Pages | `sign-in`, `sign-in-verify`, `security`, `security-authenticator` | `pages/auth/*`, `pages/account/*` |
| Components | `AuthLayout`, `TextField`, `OneTimeCodeField`, `RadioGroup`, `Notice`, `Dialog`, `Stepper`, `RecoveryCodes`, `FactorRow`, `StepUpDialog` | same names |
| Contract | `/v1/auth/*` (sign-in, challenges, step-up, sign-out), `/v1/me/security`, `/v1/me/mfa/*`, `/v1/me/recovery-codes` | `lib/useStepUpGuard.tsx`, `lib/codeErrors.ts` |

**No identity provider is assumed.** The browser talks only to the app's own API (a backend for
frontend), which holds the session in an `HttpOnly` cookie and can sit in front of an in-house
service or a provider chosen later (Keycloak, Zitadel, Ory and others). The screens and the
contract do not change when that choice is made.

Rules the module holds:

- **Methods**: an authenticator app (TOTP) and email codes always; text messages (SMS) only when
  the client asks, labelled as the less secure choice. Recovery codes always, shown once, with copy
  and download. Passkeys are the recommended next method and are not designed yet.
- **Code fields**: `autocomplete="one-time-code"`, `inputmode="numeric"`, a visible label, paste
  allowed. Wrong codes show the attempts left from `details.attempts_remaining`; a locked challenge
  (429) says when to try again.
- **Step-up**: removing a method or replacing recovery codes needs a recent second step. The server
  answers `401 step_up_required`; one generic guard opens `StepUpDialog` and retries the request.
  The UI never decides on its own that a step-up is needed.
- **The last method stays**: while MFA is required, the server refuses to remove the last method
  (`409 last_factor`) and the UI disables the control with the reason.
- **Errors** never echo the server's message; each code maps to our copy (`lib/codeErrors.ts`).
- **Mock behaviour**, so every error state is reachable in the mockup and the visual diff: the
  password `wrong-password` and the code `000000` are refused; anything else passes.

What it leaves to the gap report: passkeys, the identity provider, sign-out everywhere, and
unlocking an account by an administrator. Password reset, lockout copy and the idle timeout are in
`session-password`.

## `tours-help`: page tours and a help centre

| | Mockup | React example |
|---|---|---|
| Runtime | `assets/vendor/driver.js.iife.js` (driver.js 1.9.0, MIT), `assets/tours.js`, `assets/tours.css` | `driver.js` 1.9.0, `lib/tours.ts`, `lib/usePageTours.ts`, `styles/tours.css` |
| Content | `data/help.js`: the tours and the support contact | `help/content.ts`, identical |
| Page | `help.html` (route `/help`, any signed-in user) | `pages/help/HelpPage.tsx` |
| Components | `TourList`, `ShortcutList` | same names |
| Contract | `GET /v1/me/tours`, `PUT /v1/me/tours/{id}` | generated hooks |

A tour is `{ id, version, route, title, description, permission, steps: [{ target, title, body }] }`.
Each `target` is a `data-tour="..."` attribute on a page-owned element, or on a component that
takes a `tour` prop (`ExportMenu` in the sample). Rules:

- **Starts once, by itself**, when the page is ready (no request in flight, an anchor rendered), the
  user holds the tour's permission, has not finished this `version`, and the viewport is at least
  `--breakpoint-md`. On a phone a tour hides the page it explains, so it waits for the help centre.
- **Seen is stored by the server**, per user and version, so it follows the user across devices.
  Closing a tour counts as finishing it. If the seen state cannot be loaded, nothing starts.
  A record at or above the tour's version counts as seen. A tour that starts by itself is saved as
  not completed when it starts, and every tour as completed when it ends; leaving the page ends it.
  The seen list is read only while auto-start is on, so with it off a page makes no tour request;
  turning it on waits for the preference save and a fresh read. Ready means no read or write in
  flight, then a short quiet window with no DOM change (100 ms, capped at 5 s).
- **The help centre starts any tour** the user may take, with `?tour=<id>` on its page, at any
  width. The parameter is removed once the tour starts.
- **One tour serves every role**: a step whose anchor is not on the page (a control the role
  cannot see) is skipped, and the progress count reflects what is left.
- **Raise `version`** when a page changes enough that people should see the tour again.
- **Accessibility**: the popover is a labelled dialog with focus kept inside it, Escape closes it,
  arrow keys move between steps, buttons are 44px, and motion follows `prefers-reduced-motion`.
  driver.js marks the highlighted element as opening a dialog; the runtime restores each element's
  own ARIA, since on a `div` those attributes are invalid.
- **Copy is static text.** driver.js renders titles and bodies as HTML, so tour copy never comes
  from user data.
- **CSP**: driver.js styles with the CSSOM, which `style-src 'self'` allows; no policy change.
- **Preview flag**: `?tours=reset` treats every tour as unseen in the mockup and the app's mocks,
  so the first visit can be reviewed and compared.

The help centre also lists the keyboard shortcuts and the support contact. Help articles and
search are not designed: add them to the checklist decision under `onboarding` if the client wants
them.

## `users-roles`: the people on the account and what they may do

| | Mockup | React example |
|---|---|---|
| Pages | `users` (`/settings/users`), `user-detail` (`/settings/users/:id`), `roles` (`/settings/roles`) | `pages/settings/*` |
| Components | `UserTable`, `UserStatusBadge`, `RoleCard` (domain) | same names |
| Contract | `/v1/users` (list, invite, role, deactivate, reactivate, resend and revoke invitation), `/v1/roles` | generated hooks |

- **Permissions** `user:read` (see users and roles) and `user:manage` (invite and change).
- **The server says what is allowed** per user in `allowed_actions`, and why something is not in
  `protected_reason`: nobody changes their own role or deactivates themselves (`self`), and the
  last active administrator is kept (`last_admin`). The UI shows the reason instead of a control,
  and still handles `409 last_admin` if the rule changes between load and click.
- **Deactivate, never delete.** A deactivated user is signed out everywhere and keeps their audit
  trail; a revoked invitation stays listed for the same reason.
- **Invitations** work for 7 days, show when they expired, and can be resent or revoked. An invite
  carries an `Idempotency-Key` per intent: retrying the same details reuses the key, so a lost
  answer cannot send two; changed details are a new intent with a new key. The mock API replays
  the first answer for a reused key and refuses a reused key with a different body, as a server
  must. Buttons that send email (resend) are disabled while their request is in flight.
- **Destructive actions confirm** in a dialog whose button says the action again ("Yes,
  deactivate").
- **Roles are fixed** in this version and shown read-only with their permissions in words
  (`GET /v1/roles`). Editing roles is a later decision, not a gap in this module.

## `audit-log`: who did what, and when

| | Mockup | React example |
|---|---|---|
| Page | `audit` (`/audit`) | `pages/audit/AuditPage.tsx` |
| Components | `AuditTable` (domain, on `DataTable`) with `ColumnMenu`, `ExportMenu`, `FilterTabs`, `SelectField` | same |
| Contract | `GET /v1/audit-events?category=&actor=`, `GET /v1/audit-events/actors`, exports with `report: audit` | generated hooks |

- **Permission** `audit:read`, held by roles that reconcile (Finance in the sample), not only by
  administrators. The actor filter has its own endpoint so it needs `audit:read`, not `user:read`.
- **Read only.** No edit, no delete, said on the page. Newest first; filtered and paged by the API.
- **The API sends codes** (`user.invited`); the UI names them, and shows an unknown code as itself
  rather than as nothing. Actors are a person, the system ("PayDesk (automatic)"), or nobody
  signed in (a failed sign-in).
- **Technical columns** (IP address, request ID) are hidden by default and shown through the
  column menu; the choice is saved per user, with a per-table default from the server.
- **Exports** go through the same background export as any report.

## `session-password`: sessions that end, and passwords

| | Mockup | React example |
|---|---|---|
| Pages | `forgot-password`, `reset-password?token=`, `signed-out?reason=` (AuthLayout) | `pages/auth/*` |
| Shell | `SessionTimeoutDialog` from `MK.shell`, previewed with `?session=expiring` | `lib/useIdleTimeout.ts` in `AppLayout` |
| Contract | `/v1/auth/password-reset` and `/{token}`, `PUT /v1/me/password`, `POST /v1/session/keep-alive`, `Session.idle_timeout_seconds` and `idle_warning_seconds` | `lib/passwordErrors.ts` |

- **The reset request never reveals an account**: the answer is the same for any address, and the
  page says so ("If there is an account for ...").
- **The server judges passwords** (length, common passwords, the email in it) and answers
  `weak_password` with a reason; the browser only checks that the two new ones match. Copy for
  each reason is ours.
- **A reset link works once, for 30 minutes**; an expired link has its own page with a way to ask
  for another. Changing or resetting a password signs out the other sessions, and the copy says so.
- **Lockout** (`429 account_locked` with `retry_after_seconds`) says how long to wait and points
  to the reset.
- **Idle timeout**: the server ends a session after `idle_timeout_seconds`; the shell warns
  `idle_warning_seconds` before, in a dialog whose Escape means stay. Staying calls keep-alive;
  timing out signs out and lands on a page that says why, never on a failed request. Activity the
  server cannot see (reading, scrolling) sends keep-alive at most once a minute, so the two clocks
  agree.
- **A session the server ends** (expired, revoked) answers `401 session_expired` or
  `unauthenticated` to whatever was asked next. Once a session has existed, that answer from any
  request lands on "Your session has ended" (`lib/sessionEnd.ts`); `401 step_up_required` is not
  an ending. Before a session exists, the same 401 just means "sign in".
- **Signing out** lives in the account menu (from `notifications`) and in the idle warning.

## `notifications`: telling users what happened

| | Mockup | React example |
|---|---|---|
| Pages | `notifications` (`/notifications`), `notification-settings` (`/account/notifications`) | `pages/notifications/*` |
| Shell | `NotificationMenu` (the bell) and `AccountMenu` in the header | same, in `AppLayout` |
| Components | `NotificationList`, `NotificationMenu`, `AccountMenu`, `ToggleList` | same names |
| Contract | `/v1/me/notifications` (list, read, read-all), `/v1/me/notifications/summary`, `/v1/me/notification-preferences` | generated hooks |

- **The bell has its own endpoint**, the unread count and the latest five, cheap enough to poll
  each minute. It is the shell's data, so it ignores the page's `?state=` scenario, in the mockup
  and in the mocks.
- **Unread is said in words** ("Unread: ..." for screen readers, "Notifications, 3 unread" on the
  bell), not only by a dot or a red count.
- **Links are app paths**, never external URLs, so a notification cannot send a user off-site.
  The server should send only paths, and the UI checks anyway (`lib/links.ts`): anything that is
  not a single leading slash is shown as text, not as a link.
- **In-app is always on; email is a choice per event**, saved as it changes, with a status message.
  Security events (a new sign-in) keep email on and say why.

## `system-pages`: when the app cannot do its job

| | Mockup | React example |
|---|---|---|
| Pages | `not-found` (404), the shell's `forbidden` (403), `server-error` (a page that failed to render), `maintenance` | `ErrorPage`, `ErrorBoundary`, `pages/system/MaintenancePage.tsx` |
| Shell | the offline banner, previewed with `?system=offline` | `lib/useOnline.ts` in `AppLayout` |

- **A page that fails to render** shows our page inside the layout, with a reference the error was
  reported under, a reload and a way out. The reference is the only thing support needs.
- **Maintenance** replaces the whole app when any request answers `503 maintenance`
  (`details.until`), says when it should be back, and asks the API itself each minute (the routes
  are not mounted, so there is no page query to retry); the first other answer brings the app
  back.
- **Offline** is a banner, not a page: what was loaded stays readable. `navigator.onLine` alone is
  not enough: the app is offline when the browser says so, or when a request failed at the network
  level (`network_error`) and none has succeeded since. A timeout does not count; a slow server is
  not a lost connection. In a mocked build only the browser's events count. (Decided and unit
  tested on one port, not gated.)
- None of them shows a server or exception message.

## The checklist: things a client forgets to ask for

Record a decision for every item in `mockup.config.json`, as `designed`, `later` or `not-needed`:

```json
{ "checklist": { "saved-views": "later", "dark-mode": "not-needed", "approvals": "designed" } }
```

The inventory prints every undecided item, so the question is asked before sign-off rather than
after. An item a PRD (keel `write-prd`) already settles is taken from it and cited in the brief, not
asked again: the PRD owns requirements, the checklist only records them. A `later` becomes a line in the gap report; a `designed` item has screens in the mockup. An
item a module settles needs no answer; the table marks them.

An item that has a module (marked in the table) may be `designed` with that module off: then its
screens are a hand-built page of the project's own, not the module's files, and the inventory does
not look for the module's pages. That is allowed, but the module's rules in this file still apply
to the page, because they are what the client and the app expect of the feature. For `audit-log`:
read only (no edit, no delete, said on the page), newest first, filtered and paged by the API, and
an event code the UI has no name for shown as the code itself, never as nothing. Turn the module on
instead when its own page fits; copying it is less work than proving a hand-built one.

| Item | What to design when it applies |
|---|---|
| `user-management` (module `users-roles`) | Invite a user, resend or revoke an invite, deactivate and reactivate, assign a role; the last administrator cannot be removed |
| `roles-admin` (module `users-roles`, fixed roles) | Whether clients edit roles themselves, or roles are fixed; if edited, the permission picker and its audit |
| `audit-log` (module) | Who did what and when, filterable and exportable; read-only; which actions are recorded |
| `notifications` (module) | An in-app list with unread counts, and which events also send email; per-user preferences |
| `settings` | Organisation profile, branding, defaults (currency, time zone, language) and who may change them |
| `developer-access` | API keys (shown once, rotated, scoped), webhooks with delivery logs, for clients who integrate |
| `session-timeout` (module `session-password`) | The idle warning with time left, extending it, and what the user sees after signing in again |
| `password-reset` (module `session-password`) | Request, email link, set a new password, the expired link, and the messages that never confirm an account exists |
| `approvals` | Maker and checker: submit, approve, reject with a reason, and that the maker cannot approve their own request |
| `onboarding` | The first run: an empty app, a setup checklist, sample data, and help articles if wanted |
| `system-pages` (module) | Server error, maintenance, offline, and session expired, besides 403 and 404. Ask too whether work done offline is queued and survives a reload: that needs a backend sync endpoint, where a banner needs nothing |
| `bulk-actions` | Selecting rows across pages, the action bar, a confirmation with the count, and partial failure |
| `saved-views` | Saving a report's filters, sort and columns as a named view, shared or personal |
| `file-upload` | Accepted types and sizes, progress, a failed upload, a malware scan result, and replacing a file |
| `localisation` | Languages, right-to-left if needed, and number, date and currency formats per locale. Answered at intake as `project.i18n`, which settles this item |
| `dark-mode` | A second token set, and whether the user chooses or the system decides. Answered at intake as `project.theming`, which settles this item |
| `print` | Print or PDF views of records and reports, with headers, page breaks and no navigation |
| `privacy` | Consent and cookie choices where required, and a user's own data export and deletion request |

The rest are generic patterns the engine will grow modules for as client work needs them, proven
in React first. Until then, a `designed` item follows the same conventions as any page.
