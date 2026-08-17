# Frontend standard

Read this when the project has a UI. `profile.stack.has_ui` says whether it does.

## Components: build the shared one first

The failure is not writing a bad component, it is writing the fourth copy of a good one. By then
each copy has diverged and none can be changed safely.

**The rule: the second time you need something, extract it.** Not the third. The second occurrence is
where the shape becomes clear and the cost of extraction is still one file.

| Layer | Holds | Knows about |
|---|---|---|
| Primitives | Button, Input, Select, Modal, Table, Badge | Nothing. No domain, no fetching, no routing |
| Composites | DataTable, FormField, ConfirmDialog | Primitives only |
| Domain | PayoutTable, MerchantForm | Composites, and its own domain types |
| Pages | Route entry points | Everything below, plus data fetching |

A primitive importing a domain type is the boundary breaking, and it is how a design system becomes
unforkable. Check the import direction, not the folder names.

**Before writing any component, search for it.** `grep -ri "button" src/components` costs seconds. A
codebase with `Button`, `AppButton`, and `PrimaryButton` did not decide to have three; nobody looked.

## Theming: a font or colour change touches one file

The test for a theming strategy is concrete: **if the brand colour changes, how many files change?**
The answer must be one. If it is more than five, there is no theming strategy, there is a convention
that people mostly follow.

- **Tokens in one place**, as CSS custom properties or a single theme object. Colour, spacing, radius,
  font family, font size, shadow, z-index.
- **Components reference tokens only.** Never a hex code, never a raw pixel value, never a font name
  in a component file.
- **Semantic names, not literal ones.** `--color-danger`, not `--color-red`. When danger becomes
  orange, a literal name forces a rename across the codebase or leaves a lie in it.
- **Dark mode, if wanted, is a token swap**, not a second set of components. Decide this at the start;
  retrofitting it means auditing every component.
- **One mechanism.** Tailwind config, or CSS variables, or a theme provider. Two mechanisms means a
  colour change touches both and someone forgets one.

Enforce it: a lint rule banning hex colours and raw font declarations outside the token file. This is
mechanical, so it belongs in the linter rather than in prose.

## Accessibility: it is cheap while building and expensive to retrofit

The failure is the same shape as theming. Nobody sets out to build an unusable interface; they build
forty components without thinking about it, and then fixing it means auditing all forty.

**Use the element that already does the job.** A `<button>` is focusable, activates on Enter and
Space, announces itself as a button, and works with every assistive technology. A `<div onClick>`
does none of that and needs four attributes and two handlers to imitate it, which is why the
imitation is usually incomplete. The same for `<a>` for navigation, `<label>` for form fields,
`<table>` for tabular data, and the real heading levels.

**Everything works from the keyboard**, because that is the floor and it is also the cheapest thing
to check: tab through the page. Every interactive element must be reachable, in an order that makes
sense, with a visible focus indicator. Never remove the focus outline without replacing it with
something at least as visible; `outline: none` with no replacement is the single most common
accessibility defect there is.

**Focus is managed at the moments the page changes under the user.** Opening a modal moves focus into
it and traps it there; closing it returns focus to whatever opened it. A route change moves focus to
the new heading. Without this a keyboard user is left on an element that no longer exists and a
screen reader user is not told anything happened.

**Every input has a real label**, associated by `for` and `id`. A placeholder is not a label: it
disappears on typing, it fails contrast in most designs, and it is not reliably announced. An icon
button has an accessible name, from visually hidden text or `aria-label`.

**Colour is never the only signal.** An error shown as a red border and nothing else does not exist
for a colour blind user, and roughly one in twelve men is. Add text, an icon, or both. Contrast is
4.5:1 for body text and 3:1 for large text and interactive boundaries, and it is a token decision
made once rather than a per-component argument.

**Announce what changes without a page load.** A validation error, a toast, or a loading state that
appears silently is invisible to a screen reader. A live region, used sparingly, is the mechanism.

**Prefer no ARIA to wrong ARIA.** An incorrect `role` overrides correct native semantics and makes
the element less usable than the plain one. Reach for ARIA when there is genuinely no native element,
not as decoration.

**Respect the user's stated preferences**, which the browser already tells you: reduced motion, and
the colour scheme the theming section above is built around.

Enforce what a tool can: an accessibility linter for the framework in use, plus an automated check in
CI. Be honest about what that catches, which is roughly a third of real defects, all of them the
mechanical third. Tabbing through the page catches the rest, and it takes a minute.

## Security

The browser is a hostile environment and the frontend is the part an attacker can read.

**Tokens.** An access token in `localStorage` is readable by any XSS on the page, including one in a
dependency. Prefer an `HttpOnly`, `Secure`, `SameSite` cookie set by the server. Where a bearer token
in JavaScript is unavoidable, keep it in memory only, accept that a refresh loses it, and keep the
refresh token in an `HttpOnly` cookie.

Never put a token in a URL. It reaches logs, the referrer header, and browser history.

**CSRF.** Cookie authentication needs CSRF protection; bearer headers do not. Cookie plus a
state-changing endpoint means a per-session token in a header the server checks, and `SameSite=Lax`
or `Strict` as defence in depth rather than as the only control. Never rely on checking `Origin`
alone.

**XSS.** No `dangerouslySetInnerHTML`, `v-html`, or equivalent on anything a user can influence. If
rendering HTML is genuinely required, sanitise with a maintained library, at render, and say why in a
comment. A framework escapes by default; every XSS is somewhere that default was overridden.

**Secrets.** Anything in the bundle is public, including a variable named `NEXT_PUBLIC_*` or
`VITE_*`. There is no such thing as a frontend secret. An API key that must reach a third party goes
through your own backend.

**Authorisation is not a frontend concern.** Hiding a button is a UX decision. Every check must exist
on the server, and a frontend that is the only place a permission is enforced has no permission
enforcement.

**Dependencies.** The bundle is your supply chain and it executes in your users' browsers. Pin, audit,
and be sceptical of a dependency added for one function.

**Headers**, set by the server but a frontend concern because the frontend breaks when they are wrong:
`Content-Security-Policy` without `unsafe-inline`, `X-Content-Type-Options: nosniff`,
`Referrer-Policy`, and `Strict-Transport-Security`.

## What review looks for

- A component that duplicates an existing one. Name both.
- A hex colour, a raw font, or a magic pixel value outside the token file.
- A token in `localStorage`, or a secret in a `PUBLIC_`-prefixed variable.
- A permission enforced only by hiding UI.
- `dangerouslySetInnerHTML` with no sanitiser and no comment.
- A `div` or `span` carrying a click handler where a `button` or `a` belongs.
- `outline: none` with no visible replacement.
- An input whose only label is its placeholder, or an icon button with no accessible name.
- A modal that does not move focus in, trap it, and return it on close.
- An error or status conveyed by colour alone.
